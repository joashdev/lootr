import {
  ReportValidationError,
  buildIssue,
  maxScreenshotBytes,
  parseReportJson,
} from './report'

interface Env {
  SCREENSHOTS: R2Bucket
  RATE_LIMITER: RateLimit
  REPORT_QUOTA: DurableObjectNamespace
  GITHUB_TOKEN: string
  GITHUB_OWNER: string
  GITHUB_REPO: string
  ATTACHMENT_RETENTION_DAYS: string
  TURNSTILE_SECRET: string
  TURNSTILE_SITE_KEY: string
  REPORTING_ENABLED: string
}

interface GitHubIssueResponse {
  number: number
  html_url: string
}

interface TurnstileResponse {
  success: boolean
  action?: string
}

interface QuotaRequest {
  hasScreenshot: boolean
}

const dailyReportLimit = 25
const hourlyScreenshotLimit = 10

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true })
    }
    if (request.method === 'GET' && url.pathname === '/challenge') {
      return challengePage(env.TURNSTILE_SITE_KEY)
    }
    if (request.method === 'GET' && url.pathname.startsWith('/attachments/')) {
      return getAttachment(url.pathname.slice('/attachments/'.length), env)
    }
    if (request.method !== 'POST' || url.pathname !== '/reports') {
      return json({ error: 'not_found' }, 404)
    }
    if (env.REPORTING_ENABLED !== 'true') {
      return json(
        {
          error: 'reporting_unavailable',
          message: 'In-app reporting is temporarily unavailable.',
        },
        503,
      )
    }

    const startedAt = Date.now()
    let reportId = 'unparsed'
    let reportType = 'unknown'
    let hasScreenshot = false
    let payloadBytes = 0
    let screenshotKey: string | undefined
    let dedupeKey: string | undefined
    let dedupeReserved = false
    let r2Outcome = 'not_attempted'
    let turnstileOutcome = 'not_attempted'
    let quotaOutcome = 'not_attempted'
    let dedupeOutcome = 'not_attempted'
    let githubCommitted = false

    try {
      const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown'
      const rateLimit = await env.RATE_LIMITER.limit({ key: ip })
      if (!rateLimit.success) {
        throw new ReportValidationError(
          'Too many reports. Try again later.',
          429,
          'rate_limited',
        )
      }

      const contentLength = request.headers.get('content-length')
      if (
        contentLength === null ||
        !/^[1-9][0-9]*$/.test(contentLength) ||
        !Number.isSafeInteger(Number(contentLength))
      ) {
        throw new ReportValidationError(
          'A valid Content-Length header is required.',
          411,
          'content_length_required',
        )
      }
      const declaredLength = Number(contentLength)
      if (declaredLength > maxScreenshotBytes + 128 * 1024) {
        throw new ReportValidationError(
          'Report request is too large.',
          413,
          'request_too_large',
        )
      }

      const form = await request.formData()
      const unknownParts = [...form.keys()].filter(
        (key) =>
          key !== 'report' &&
          key !== 'turnstileToken' &&
          key !== 'screenshot',
      )
      if (
        unknownParts.length > 0 ||
        form.getAll('report').length !== 1 ||
        form.getAll('turnstileToken').length > 1 ||
        form.getAll('screenshot').length > 1
      ) {
        throw new ReportValidationError(
          'Report request contains unknown or duplicate fields.',
        )
      }
      const reportPart = form.get('report')
      const turnstileToken = form.get('turnstileToken')
      const screenshot = form.get('screenshot')
      if (typeof reportPart !== 'string') {
        throw new ReportValidationError('Missing report metadata.')
      }
      if (
        typeof turnstileToken !== 'string' ||
        turnstileToken.length === 0 ||
        new TextEncoder().encode(turnstileToken).byteLength > 2048
      ) {
        throw new ReportValidationError(
          'Complete the anti-abuse check before sending.',
          422,
          'turnstile_required',
        )
      }
      if (screenshot !== null && !(screenshot instanceof File)) {
        throw new ReportValidationError('Screenshot is invalid.')
      }

      payloadBytes = new TextEncoder().encode(reportPart).byteLength
      const report = parseReportJson(reportPart)
      reportId = report.id
      reportType = report.type
      hasScreenshot = screenshot instanceof File

      const turnstileValid = await verifyTurnstile(turnstileToken, env)
      turnstileOutcome = turnstileValid ? 'accepted' : 'rejected'
      if (!turnstileValid) {
        throw new ReportValidationError(
          'The anti-abuse check expired or could not be verified.',
          422,
          'turnstile_invalid',
        )
      }

      let screenshotBytes: ArrayBuffer | undefined
      if (screenshot instanceof File) {
        if (!report.consent.publicScreenshot) {
          throw new ReportValidationError(
            'Public screenshot consent is required.',
            422,
            'screenshot_consent_required',
          )
        }
        if (
          screenshot.type !== 'image/jpeg' ||
          screenshot.size > maxScreenshotBytes
        ) {
          throw new ReportValidationError(
            'Screenshot must be a JPEG no larger than 1 MiB.',
            413,
            'invalid_screenshot',
          )
        }

        screenshotBytes = await screenshot.arrayBuffer()
        const jpeg = new Uint8Array(screenshotBytes)
        if (
          jpeg.length < 4 ||
          jpeg[0] !== 0xff ||
          jpeg[1] !== 0xd8 ||
          jpeg[2] !== 0xff ||
          jpeg.at(-2) !== 0xff ||
          jpeg.at(-1) !== 0xd9
        ) {
          throw new ReportValidationError(
            'Screenshot content is not a valid JPEG.',
            415,
            'invalid_screenshot',
          )
        }
      }

      const quotaResponse = await consumeQuota(hasScreenshot, env)
      if (!quotaResponse.ok) {
        const quotaError = (await quotaResponse.json()) as { error?: string }
        quotaOutcome = quotaError.error ?? 'rejected'
        throw new ReportValidationError(
          'The public reporting limit has been reached. Try again later.',
          429,
          quotaError.error ?? 'report_quota_exceeded',
        )
      }
      quotaOutcome = 'accepted'

      dedupeKey = `dedupe/${report.id}`
      const reservation = await env.SCREENSHOTS.put(dedupeKey, 'pending', {
        onlyIf: { etagDoesNotMatch: '*' },
      })
      if (reservation === null) {
        throw new ReportValidationError(
          'This report was already submitted.',
          409,
          'duplicate_report',
        )
      }
      dedupeReserved = true
      dedupeOutcome = 'reserved'

      let screenshotUrl: string | undefined
      if (screenshotBytes !== undefined) {
        const token = randomToken()
        screenshotKey = `attachments/${report.id}/${token}.jpg`
        r2Outcome = 'store_started'
        await env.SCREENSHOTS.put(screenshotKey, screenshotBytes, {
          httpMetadata: { contentType: 'image/jpeg' },
          customMetadata: {
            reportId: report.id,
            deleteAfter: new Date(
              Date.now() +
                Number(env.ATTACHMENT_RETENTION_DAYS) * 24 * 60 * 60 * 1000,
            ).toISOString(),
          },
        })
        r2Outcome = 'stored'
        screenshotUrl = `${url.origin}/${screenshotKey}`
      }

      const issue = buildIssue(report, screenshotUrl)
      const githubResponse = await fetch(
        `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/issues`,
        {
          method: 'POST',
          headers: {
            Accept: 'application/vnd.github+json',
            Authorization: `Bearer ${env.GITHUB_TOKEN}`,
            'Content-Type': 'application/json',
            'User-Agent': 'lootr-report-relay',
            'X-GitHub-Api-Version': '2022-11-28',
          },
          body: JSON.stringify(issue),
        },
      )

      if (!githubResponse.ok) {
        if (screenshotKey !== undefined) {
          r2Outcome = (await deleteObject(env.SCREENSHOTS, screenshotKey))
            ? 'deleted_after_github_failure'
            : 'delete_failed'
        }
        if (dedupeKey !== undefined) {
          await deleteObject(env.SCREENSHOTS, dedupeKey)
          dedupeReserved = false
          dedupeOutcome = 'released_after_github_failure'
        }
        operationalLog({
          event: 'report.failed',
          reportId,
          reportType,
          hasScreenshot,
          payloadBytes,
          r2Outcome,
          turnstileOutcome,
          quotaOutcome,
          githubStatus: githubResponse.status,
          durationMs: Date.now() - startedAt,
        })
        return json({ error: 'github_unavailable' }, 502)
      }

      githubCommitted = true
      const created = (await githubResponse.json()) as GitHubIssueResponse
      try {
        await env.SCREENSHOTS.put(dedupeKey, 'submitted', {
          customMetadata: {
            issueNumber: String(created.number),
            deleteAfter: new Date(
              Date.now() +
                Number(env.ATTACHMENT_RETENTION_DAYS) * 24 * 60 * 60 * 1000,
            ).toISOString(),
          },
        })
        dedupeReserved = false
        dedupeOutcome = 'submitted'
      } catch {
        dedupeOutcome = 'finalization_failed'
      }
      operationalLog({
        event: 'report.created',
        reportId,
        reportType,
        hasScreenshot,
        payloadBytes,
        r2Outcome,
        turnstileOutcome,
        quotaOutcome,
        dedupeOutcome,
        githubStatus: githubResponse.status,
        durationMs: Date.now() - startedAt,
      })
      return json(
        {
          reportId,
          issueNumber: created.number,
          issueUrl: created.html_url,
        },
        201,
      )
    } catch (error) {
      if (!githubCommitted) {
        if (screenshotKey !== undefined) {
          r2Outcome = (await deleteObject(env.SCREENSHOTS, screenshotKey))
            ? 'deleted_after_rejection'
            : 'delete_failed'
        } else if (r2Outcome === 'store_started') {
          r2Outcome = 'store_failed'
        }
        if (dedupeReserved && dedupeKey !== undefined) {
          await deleteObject(env.SCREENSHOTS, dedupeKey)
          dedupeOutcome = 'released_after_rejection'
        }
      }
      const validation =
        error instanceof ReportValidationError ? error : undefined
      operationalLog({
        event: 'report.rejected',
        reportId,
        reportType,
        hasScreenshot,
        payloadBytes,
        r2Outcome,
        turnstileOutcome,
        quotaOutcome,
        dedupeOutcome,
        status: validation?.status ?? 500,
        errorType: error instanceof Error ? error.constructor.name : 'Unknown',
        durationMs: Date.now() - startedAt,
      })
      return json(
        {
          error: validation?.code ?? 'internal_error',
          message: validation?.message ?? 'Could not submit the report.',
        },
        validation?.status ?? 500,
      )
    }
  },
}

async function deleteObject(bucket: R2Bucket, key: string): Promise<boolean> {
  try {
    await bucket.delete(key)
    return true
  } catch {
    return false
  }
}

async function getAttachment(key: string, env: Env): Promise<Response> {
  if (
    !/^[-A-Za-z0-9]+\/[-A-Za-z0-9]+\.jpg$/.test(key) ||
    key.length > 180
  ) {
    return new Response('Not found', { status: 404 })
  }
  const object = await env.SCREENSHOTS.get(`attachments/${key}`)
  if (object === null) {
    return new Response('Not found', { status: 404 })
  }
  const deleteAfter = object.customMetadata?.deleteAfter
  if (
    deleteAfter === undefined ||
    !Number.isFinite(Date.parse(deleteAfter)) ||
    Date.parse(deleteAfter) <= Date.now()
  ) {
    await deleteObject(env.SCREENSHOTS, `attachments/${key}`)
    return new Response('Not found', { status: 404 })
  }
  return new Response(object.body, {
    headers: {
      'Content-Type': object.httpMetadata?.contentType ?? 'image/jpeg',
      'Cache-Control': 'private, no-store, max-age=0',
      'X-Content-Type-Options': 'nosniff',
    },
  })
}

async function verifyTurnstile(
  token: string,
  env: Env,
): Promise<boolean> {
  const response = await fetch(
    'https://challenges.cloudflare.com/turnstile/v0/siteverify',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        secret: env.TURNSTILE_SECRET,
        response: token,
      }),
    },
  )
  if (!response.ok) return false
  const result = (await response.json()) as TurnstileResponse
  return result.success === true && result.action === 'report'
}

async function consumeQuota(
  hasScreenshot: boolean,
  env: Env,
): Promise<Response> {
  const id = env.REPORT_QUOTA.idFromName('global')
  return env.REPORT_QUOTA.get(id).fetch('https://quota.internal/consume', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ hasScreenshot }),
  })
}

function challengePage(siteKey: string): Response {
  const safeSiteKey = siteKey.replaceAll('&', '&amp;').replaceAll('"', '&quot;')
  return new Response(
    `<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<style>html,body{height:100%;margin:0}body{display:grid;place-items:center;background:#fafafa;font:16px system-ui;color:#222}</style>
</head><body>
<div class="cf-turnstile" data-sitekey="${safeSiteKey}" data-theme="auto" data-action="report"
 data-callback="verified" data-error-callback="failed"></div>
<script>
function verified(token){LootrTurnstile.postMessage(token)}
function failed(){LootrTurnstile.postMessage("__turnstile_error__")}
</script></body></html>`,
    {
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store',
        'Content-Security-Policy':
          "default-src 'none'; script-src 'unsafe-inline' https://challenges.cloudflare.com; frame-src https://challenges.cloudflare.com; connect-src https://challenges.cloudflare.com; style-src 'unsafe-inline'; img-src https://challenges.cloudflare.com data:",
        'Referrer-Policy': 'no-referrer',
        'X-Content-Type-Options': 'nosniff',
      },
    },
  )
}

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24))
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('')
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  })
}

function operationalLog(value: Record<string, unknown>): void {
  console.log(JSON.stringify(value))
}

export class ReportQuota {
  constructor(private readonly state: DurableObjectState) {}

  async fetch(request: Request): Promise<Response> {
    if (request.method !== 'POST') {
      return json({ error: 'method_not_allowed' }, 405)
    }
    const body = (await request.json()) as QuotaRequest
    if (typeof body.hasScreenshot !== 'boolean') {
      return json({ error: 'invalid_quota_request' }, 422)
    }

    const now = new Date()
    const dayKey = `reports:${now.toISOString().slice(0, 10)}`
    const hourKey = `screenshots:${now.toISOString().slice(0, 13)}`

    return this.state.storage.transaction(async (transaction) => {
      const reports = (await transaction.get<number>(dayKey)) ?? 0
      if (reports >= dailyReportLimit) {
        return json({ error: 'daily_quota_exceeded' }, 429)
      }
      const screenshots = body.hasScreenshot
        ? ((await transaction.get<number>(hourKey)) ?? 0)
        : 0
      if (body.hasScreenshot && screenshots >= hourlyScreenshotLimit) {
        return json({ error: 'screenshot_quota_exceeded' }, 429)
      }

      await transaction.put(dayKey, reports + 1)
      if (body.hasScreenshot) {
        await transaction.put(hourKey, screenshots + 1)
      }
      return json({ ok: true })
    })
  }
}
