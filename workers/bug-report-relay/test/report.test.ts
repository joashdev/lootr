import { describe, expect, it } from 'vitest'

import {
  ReportValidationError,
  buildIssue,
  parseReportJson,
  validateReport,
} from '../src/report'

const validReport = {
  id: 'report-123',
  type: 'bug',
  title: 'Dashboard stays blank',
  description: 'The dashboard remains blank after launch.',
  app: {
    version: '0.1.0-alpha.2',
    build: '2',
    platform: 'Android',
  },
  diagnostics: [
    {
      timestamp: '2026-07-27T01:00:00.000Z',
      severity: 'error',
      feature: 'app',
      eventCode: 'flutter.error',
      outcome: 'failed',
      exceptionType: 'StateError',
      stack: ['package:lootr/main.dart 10:2'],
    },
  ],
  consent: {
    publicReport: true,
    persistence: true,
    publicScreenshot: false,
  },
}

describe('report validation', () => {
  it('accepts only the closed public report schema', () => {
    expect(validateReport(validReport)).toMatchObject({
      id: 'report-123',
      type: 'bug',
    })
  })

  it('rejects unknown fields that could smuggle private data', () => {
    expect(() =>
      validateReport({ ...validReport, accountBalance: '1000' }),
    ).toThrowError(ReportValidationError)
  })

  it('requires both public disclosure confirmations', () => {
    expect(() =>
      validateReport({
        ...validReport,
        consent: { ...validReport.consent, persistence: false },
      }),
    ).toThrowError(/confirmations/)
  })

  it('rejects oversized metadata before parsing', () => {
    expect(() => parseReportJson(`{"x":"${'a'.repeat(70 * 1024)}"}`)).toThrowError(
      /64 KiB/,
    )
  })

  it('rejects diagnostic features outside the app allowlist', () => {
    expect(() =>
      validateReport({
        ...validReport,
        diagnostics: [{ ...validReport.diagnostics[0], feature: 'dashboard' }],
      }),
    ).toThrowError(/feature is invalid/)
  })

  it('rejects diagnostic event codes outside the app allowlist', () => {
    expect(() =>
      validateReport({
        ...validReport,
        diagnostics: [
          { ...validReport.diagnostics[0], eventCode: 'dashboard.load_failed' },
        ],
      }),
    ).toThrowError(/eventCode is invalid/)
  })
})

describe('GitHub issue rendering', () => {
  it('maps bug reports to the bug label and includes diagnostics', () => {
    const issue = buildIssue(validateReport(validReport))

    expect(issue.title).toBe('[Bug] Dashboard stays blank')
    expect(issue.labels).toEqual(['bug'])
    expect(issue.body).toContain('flutter.error')
    expect(issue.body).toContain('reviewed this issue')
  })

  it('maps layout requests to enhancement without diagnostics by default', () => {
    const report = validateReport({
      ...validReport,
      type: 'layout',
      diagnostics: [],
    })
    const issue = buildIssue(
      report,
      'https://relay.example/attachments/report/token.jpg',
    )

    expect(issue.title).toBe('[Layout] Dashboard stays blank')
    expect(issue.labels).toEqual(['enhancement'])
    expect(issue.body).toContain('User-approved public screenshot')
    expect(issue.body).toContain('No diagnostics included')
  })
})
