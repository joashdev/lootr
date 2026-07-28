import { beforeEach, describe, expect, it, vi } from 'vitest'

import worker, { ReportQuota } from '../src/index'

const validReport = {
  id: 'report-123',
  type: 'layout',
  title: 'Move the add button',
  description: 'Place it above the transaction list.',
  app: { version: '0.1.0-alpha.1', build: '42', platform: 'Android' },
  diagnostics: [],
  consent: {
    publicReport: true,
    persistence: true,
    publicScreenshot: true,
  },
}

describe('report relay', () => {
  let bucket: FakeBucket
  let quota: FakeQuotaNamespace

  beforeEach(() => {
    bucket = new FakeBucket()
    quota = new FakeQuotaNamespace()
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: RequestInfo | URL) => {
        const url = input.toString()
        if (url.includes('/turnstile/v0/siteverify')) {
          return Response.json({ success: true, action: 'report' })
        }
        return Response.json(
          {
            number: 17,
            html_url: 'https://github.com/joashdev/lootr/issues/17',
          },
          { status: 201 },
        )
      }),
    )
  })

  it('rejects unknown multipart fields', async () => {
    const form = reportForm()
    form.set('privateNote', 'must not pass through')

    const response = await submit(form, bucket, quota)

    expect(response.status).toBe(422)
    expect(await response.json()).toMatchObject({ error: 'invalid_report' })
    expect(fetch).not.toHaveBeenCalled()
  })

  it('rejects requests without a valid Content-Length', async () => {
    const response = await submit(reportForm(), bucket, quota, {
      contentLength: null,
    })

    expect(response.status).toBe(411)
    expect(await response.json()).toMatchObject({
      error: 'content_length_required',
    })
    expect(fetch).not.toHaveBeenCalled()
    expect(bucket.puts).toBe(0)
  })

  it('rejects malformed Content-Length values', async () => {
    const response = await submit(reportForm(), bucket, quota, {
      contentLength: 'not-a-number',
    })

    expect(response.status).toBe(411)
    expect(await response.json()).toMatchObject({
      error: 'content_length_required',
    })
    expect(fetch).not.toHaveBeenCalled()
  })

  it('rejects declared request bodies above the hard limit', async () => {
    const response = await submit(reportForm(), bucket, quota, {
      contentLength: String(1024 * 1024 + 128 * 1024 + 1),
    })

    expect(response.status).toBe(413)
    expect(await response.json()).toMatchObject({
      error: 'request_too_large',
    })
    expect(fetch).not.toHaveBeenCalled()
  })

  it('validates JPEG bytes before creating the issue', async () => {
    const form = reportForm()
    form.set(
      'screenshot',
      new File([new Uint8Array([1, 2, 3, 4])], 'fake.jpg', {
        type: 'image/jpeg',
      }),
    )

    const response = await submit(form, bucket, quota)

    expect(response.status).toBe(415)
    expect(await response.json()).toMatchObject({ error: 'invalid_screenshot' })
    expect(fetch).toHaveBeenCalledTimes(1)
    expect(quota.requests).toBe(0)
  })

  it('atomically reserves report IDs before issue creation', async () => {
    const first = await submit(reportForm(), bucket, quota)
    const duplicate = await submit(reportForm(), bucket, quota)

    expect(first.status).toBe(201)
    expect(duplicate.status).toBe(409)
    expect(fetch).toHaveBeenCalledTimes(3)
  })

  it('requires a Turnstile token', async () => {
    const form = reportForm()
    form.delete('turnstileToken')

    const response = await submit(form, bucket, quota)

    expect(response.status).toBe(422)
    expect(await response.json()).toMatchObject({
      error: 'turnstile_required',
    })
    expect(fetch).not.toHaveBeenCalled()
    expect(quota.requests).toBe(0)
  })

  it('limits the Turnstile token by UTF-8 byte size', async () => {
    const form = reportForm()
    form.set('turnstileToken', '€'.repeat(700))

    const response = await submit(form, bucket, quota)

    expect(response.status).toBe(422)
    expect(await response.json()).toMatchObject({
      error: 'turnstile_required',
    })
    expect(fetch).not.toHaveBeenCalled()
  })

  it('rejects an invalid Turnstile token before quota or R2', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => Response.json({ success: false })),
    )

    const response = await submit(reportForm(), bucket, quota)

    expect(response.status).toBe(422)
    expect(await response.json()).toMatchObject({
      error: 'turnstile_invalid',
    })
    expect(quota.requests).toBe(0)
    expect(bucket.puts).toBe(0)
  })

  it('rejects a valid token issued for a different Turnstile action', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        Response.json({ success: true, action: 'different-action' }),
      ),
    )

    const response = await submit(reportForm(), bucket, quota)

    expect(response.status).toBe(422)
    expect(await response.json()).toMatchObject({
      error: 'turnstile_invalid',
    })
    expect(quota.requests).toBe(0)
  })

  it('stops quota-exhausted reports before R2 and GitHub', async () => {
    quota.response = Response.json(
      { error: 'daily_quota_exceeded' },
      { status: 429 },
    )

    const response = await submit(reportForm(), bucket, quota)

    expect(response.status).toBe(429)
    expect(await response.json()).toMatchObject({
      error: 'daily_quota_exceeded',
    })
    expect(bucket.puts).toBe(0)
    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it('passes screenshot presence to the exact quota', async () => {
    const form = reportForm()
    form.set(
      'screenshot',
      new File([new Uint8Array([0xff, 0xd8, 0xff, 0xd9])], 'screen.jpg', {
        type: 'image/jpeg',
      }),
    )

    const response = await submit(form, bucket, quota)

    expect(response.status).toBe(201)
    expect(quota.lastBody).toEqual({ hasScreenshot: true })
  })

  it('keeps committed issue state when dedupe finalization fails', async () => {
    bucket.failSubmittedPut = true
    const form = reportForm()
    form.set(
      'screenshot',
      new File([new Uint8Array([0xff, 0xd8, 0xff, 0xd9])], 'screen.jpg', {
        type: 'image/jpeg',
      }),
    )

    const response = await submit(form, bucket, quota)
    const duplicate = await submit(reportForm(), bucket, quota)

    expect(response.status).toBe(201)
    expect(duplicate.status).toBe(409)
    expect(bucket.keys().filter((key) => key.startsWith('attachments/'))).toHaveLength(1)
    expect(fetch).toHaveBeenCalledTimes(3)
  })

  it('serves the managed challenge without caching it', async () => {
    const response = await worker.fetch(
      new Request('https://reports.example.test/challenge'),
      {
        TURNSTILE_SITE_KEY: 'public-site-key',
      } as never,
    )

    expect(response.status).toBe(200)
    expect(response.headers.get('Cache-Control')).toBe('no-store')
    expect(await response.text()).toContain('data-action="report"')
  })
})

describe('exact report quota', () => {
  it('allows 25 reports in a UTC day and rejects the next one', async () => {
    const quota = quotaObject()

    for (var attempt = 0; attempt < 25; attempt += 1) {
      expect((await consume(quota, false)).status).toBe(200)
    }

    const response = await consume(quota, false)
    expect(response.status).toBe(429)
    expect(await response.json()).toMatchObject({
      error: 'daily_quota_exceeded',
    })
  })

  it('allows 10 screenshots in a UTC hour and preserves report capacity', async () => {
    const quota = quotaObject()

    for (var attempt = 0; attempt < 10; attempt += 1) {
      expect((await consume(quota, true)).status).toBe(200)
    }

    const screenshotResponse = await consume(quota, true)
    expect(screenshotResponse.status).toBe(429)
    expect(await screenshotResponse.json()).toMatchObject({
      error: 'screenshot_quota_exceeded',
    })
    expect((await consume(quota, false)).status).toBe(200)
  })
})

function quotaObject(): ReportQuota {
  const values = new Map<string, unknown>()
  const storage = {
    transaction: async <T>(
      closure: (transaction: DurableObjectTransaction) => Promise<T>,
    ): Promise<T> =>
      closure({
        get: async (key: string) => values.get(key),
        put: async (key: string, value: unknown) => {
          values.set(key, value)
        },
      } as unknown as DurableObjectTransaction),
  }
  return new ReportQuota({ storage } as unknown as DurableObjectState)
}

function consume(quota: ReportQuota, hasScreenshot: boolean): Promise<Response> {
  return quota.fetch(
    new Request('https://quota.internal/consume', {
      method: 'POST',
      body: JSON.stringify({ hasScreenshot }),
    }),
  )
}

function reportForm(): FormData {
  const form = new FormData()
  form.set('report', JSON.stringify(validReport))
  form.set('turnstileToken', 'test-turnstile-token')
  return form
}

function submit(
  form: FormData,
  bucket: FakeBucket,
  quota: FakeQuotaNamespace,
  options: { contentLength?: string | null } = {},
): Promise<Response> {
  const contentLength =
    options.contentLength === undefined ? '1024' : options.contentLength
  return worker.fetch(
    new Request('https://reports.example.test/reports', {
      method: 'POST',
      body: form,
      headers: {
        'CF-Connecting-IP': '127.0.0.1',
        ...(contentLength === null ? {} : { 'Content-Length': contentLength }),
      },
    }),
    {
      SCREENSHOTS: bucket as unknown as R2Bucket,
      RATE_LIMITER: {
        limit: async () => ({ success: true }),
      } as RateLimit,
      GITHUB_TOKEN: 'test-token',
      GITHUB_OWNER: 'joashdev',
      GITHUB_REPO: 'lootr',
      ATTACHMENT_RETENTION_DAYS: '30',
      TURNSTILE_SECRET: 'turnstile-secret',
      TURNSTILE_SITE_KEY: 'turnstile-site-key',
      REPORTING_ENABLED: 'true',
      REPORT_QUOTA: quota as unknown as DurableObjectNamespace,
    },
  )
}

class FakeBucket {
  private readonly values = new Map<string, unknown>()
  puts = 0
  failSubmittedPut = false

  async put(
    key: string,
    value: unknown,
    options?: R2PutOptions,
  ): Promise<R2Object | null> {
    this.puts += 1
    if (this.failSubmittedPut && value === 'submitted') {
      throw new Error('dedupe finalization failed')
    }
    if (
      options?.onlyIf !== undefined &&
      this.values.has(key)
    ) {
      return null
    }
    this.values.set(key, value)
    return { key } as R2Object
  }

  async head(key: string): Promise<R2Object | null> {
    return this.values.has(key) ? ({ key } as R2Object) : null
  }

  async delete(key: string): Promise<void> {
    this.values.delete(key)
  }

  keys(): string[] {
    return [...this.values.keys()]
  }
}

class FakeQuotaNamespace {
  requests = 0
  lastBody: unknown
  response = Response.json({ ok: true })

  idFromName(): DurableObjectId {
    return {} as DurableObjectId
  }

  get(): DurableObjectStub {
    return {
      fetch: async (input: RequestInfo | URL, init?: RequestInit) => {
        const request =
          input instanceof Request ? input : new Request(input, init)
        this.requests += 1
        this.lastBody = await request.json()
        return this.response.clone()
      },
    } as DurableObjectStub
  }
}
