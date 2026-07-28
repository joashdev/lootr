import {
  ReportValidationError,
  buildIssue,
  maxScreenshotBytes,
  parseReportJson,
} from './report'

interface Env {
  SCREENSHOTS: R2Bucket
  RATE_LIMITER: RateLimit
  GITHUB_TOKEN: string
  GITHUB_OWNER: string
  GITHUB_REPO: string
  ATTACHMENT_RETENTION_DAYS: string
}

interface GitHubIssueResponse {
  number: number
  html_url: string
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true })
    }
    if (request.method === 'GET' && url.pathname.startsWith('/attachments/')) {
      return getAttachment(url.pathname.slice('/attachments/'.length), env)
    }
    if (request.method !== 'POST' || url.pathname !== '/reports') {
      return json({ error: 'not_found' }, 404)
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

      const declaredLength = Number(request.headers.get('content-length') ?? 0)
      if (declaredLength > maxScreenshotBytes + 128 * 1024) {
        throw new ReportValidationError(
          'Report request is too large.',
          413,
          'request_too_large',
        )
      }

      const form = await request.formData()
      const unknownParts = [...form.keys()].filter(
        (key) => key !== 'report' && key !== 'screenshot',
      )
      if (
        unknownParts.length > 0 ||
        form.getAll('report').length !== 1 ||
        form.getAll('screenshot').length > 1
      ) {
        throw new ReportValidationError(
          'Report request contains unknown or duplicate fields.',
        )
      }
      const reportPart = form.get('report')
      const screenshot = form.get('screenshot')
      if (typeof reportPart !== 'string') {
        throw new ReportValidationError('Missing report metadata.')
      }
      if (screenshot !== null && !(screenshot instanceof File)) {
        throw new ReportValidationError('Screenshot is invalid.')
      }

      payloadBytes = new TextEncoder().encode(reportPart).byteLength
      const report = parseReportJson(reportPart)
      reportId = report.id
      reportType = report.type
      hasScreenshot = screenshot instanceof File

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

      let screenshotUrl: string | undefined
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

        const screenshotBytes = await screenshot.arrayBuffer()
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
        }
        operationalLog({
          event: 'report.failed',
          reportId,
          reportType,
          hasScreenshot,
          payloadBytes,
          r2Outcome,
          githubStatus: githubResponse.status,
          durationMs: Date.now() - startedAt,
        })
        return json({ error: 'github_unavailable' }, 502)
      }

      const created = (await githubResponse.json()) as GitHubIssueResponse
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
      operationalLog({
        event: 'report.created',
        reportId,
        reportType,
        hasScreenshot,
        payloadBytes,
        r2Outcome,
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
      if (screenshotKey !== undefined) {
        r2Outcome = (await deleteObject(env.SCREENSHOTS, screenshotKey))
          ? 'deleted_after_rejection'
          : 'delete_failed'
      } else if (r2Outcome === 'store_started') {
        r2Outcome = 'store_failed'
      }
      if (dedupeReserved && dedupeKey !== undefined) {
        await deleteObject(env.SCREENSHOTS, dedupeKey)
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
  return new Response(object.body, {
    headers: {
      'Content-Type': object.httpMetadata?.contentType ?? 'image/jpeg',
      'Cache-Control': 'private, no-store, max-age=0',
      'X-Content-Type-Options': 'nosniff',
    },
  })
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
