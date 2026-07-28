import { beforeEach, describe, expect, it, vi } from 'vitest'

import worker from '../src/index'

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

  beforeEach(() => {
    bucket = new FakeBucket()
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        Response.json(
          {
            number: 17,
            html_url: 'https://github.com/joashdev/lootr/issues/17',
          },
          { status: 201 },
        ),
      ),
    )
  })

  it('rejects unknown multipart fields', async () => {
    const form = new FormData()
    form.set('report', JSON.stringify(validReport))
    form.set('privateNote', 'must not pass through')

    const response = await submit(form, bucket)

    expect(response.status).toBe(422)
    expect(await response.json()).toMatchObject({ error: 'invalid_report' })
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

    const response = await submit(form, bucket)

    expect(response.status).toBe(415)
    expect(await response.json()).toMatchObject({ error: 'invalid_screenshot' })
    expect(fetch).not.toHaveBeenCalled()
  })

  it('atomically reserves report IDs before issue creation', async () => {
    const first = await submit(reportForm(), bucket)
    const duplicate = await submit(reportForm(), bucket)

    expect(first.status).toBe(201)
    expect(duplicate.status).toBe(409)
    expect(fetch).toHaveBeenCalledTimes(1)
  })
})

function reportForm(): FormData {
  const form = new FormData()
  form.set('report', JSON.stringify(validReport))
  return form
}

function submit(form: FormData, bucket: FakeBucket): Promise<Response> {
  return worker.fetch(
    new Request('https://reports.example.test/reports', {
      method: 'POST',
      body: form,
      headers: { 'CF-Connecting-IP': '127.0.0.1' },
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
    },
  )
}

class FakeBucket {
  private readonly values = new Map<string, unknown>()

  async put(
    key: string,
    value: unknown,
    options?: R2PutOptions,
  ): Promise<R2Object | null> {
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
}
