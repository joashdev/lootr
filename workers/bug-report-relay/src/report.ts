export const maxReportBytes = 64 * 1024
export const maxScreenshotBytes = 1024 * 1024

const reportTypes = ['bug', 'feature', 'layout'] as const
const severities = ['debug', 'info', 'warning', 'error'] as const
const outcomes = ['started', 'succeeded', 'failed', 'cancelled'] as const

export type ReportType = (typeof reportTypes)[number]

export interface DiagnosticEvent {
  timestamp: string
  severity: (typeof severities)[number]
  feature: string
  eventCode: string
  outcome: (typeof outcomes)[number]
  durationMs?: number
  exceptionType?: string
  stack?: string[]
}

export interface PublicReport {
  id: string
  type: ReportType
  title: string
  description: string
  app: {
    version: string
    build: string
    platform: string
  }
  diagnostics: DiagnosticEvent[]
  consent: {
    publicReport: true
    persistence: true
    publicScreenshot: boolean
  }
}

export class ReportValidationError extends Error {
  constructor(
    message: string,
    readonly status = 422,
    readonly code = 'invalid_report',
  ) {
    super(message)
  }
}

export function parseReportJson(raw: string): PublicReport {
  if (new TextEncoder().encode(raw).byteLength > maxReportBytes) {
    throw new ReportValidationError(
      'Report metadata exceeds 64 KiB.',
      413,
      'report_too_large',
    )
  }

  let value: unknown
  try {
    value = JSON.parse(raw)
  } catch {
    throw new ReportValidationError('Report metadata is not valid JSON.')
  }
  return validateReport(value)
}

export function validateReport(value: unknown): PublicReport {
  const root = record(value, 'report')
  exactKeys(root, [
    'id',
    'type',
    'title',
    'description',
    'app',
    'diagnostics',
    'consent',
  ])

  const type = enumValue(root.type, reportTypes, 'type')
  const app = record(root.app, 'app')
  exactKeys(app, ['version', 'build', 'platform'])
  const consent = record(root.consent, 'consent')
  exactKeys(consent, ['publicReport', 'persistence', 'publicScreenshot'])

  if (consent.publicReport !== true || consent.persistence !== true) {
    throw new ReportValidationError(
      'Both public disclosure confirmations are required.',
      422,
      'consent_required',
    )
  }

  if (!Array.isArray(root.diagnostics) || root.diagnostics.length > 100) {
    throw new ReportValidationError(
      'Diagnostics must contain at most 100 events.',
    )
  }

  return {
    id: text(root.id, 'id', 64, /^[A-Za-z0-9-]+$/),
    type,
    title: text(root.title, 'title', 120),
    description: text(root.description, 'description', 4000),
    app: {
      version: text(app.version, 'app.version', 40),
      build: text(app.build, 'app.build', 40),
      platform: text(app.platform, 'app.platform', 40),
    },
    diagnostics: root.diagnostics.map(validateDiagnostic),
    consent: {
      publicReport: true,
      persistence: true,
      publicScreenshot: booleanValue(
        consent.publicScreenshot,
        'consent.publicScreenshot',
      ),
    },
  }
}

function validateDiagnostic(value: unknown, index: number): DiagnosticEvent {
  const event = record(value, `diagnostics[${index}]`)
  exactKeys(event, [
    'timestamp',
    'severity',
    'feature',
    'eventCode',
    'outcome',
    'durationMs',
    'exceptionType',
    'stack',
  ])

  const stack = event.stack
  if (
    stack !== undefined &&
    (!Array.isArray(stack) ||
      stack.length > 12 ||
      stack.some((line) => typeof line !== 'string'))
  ) {
    throw new ReportValidationError(
      `diagnostics[${index}].stack is invalid.`,
    )
  }

  const durationMs = event.durationMs
  if (
    durationMs !== undefined &&
    (typeof durationMs !== 'number' ||
      !Number.isInteger(durationMs) ||
      durationMs < 0 ||
      durationMs > 3600000)
  ) {
    throw new ReportValidationError(
      `diagnostics[${index}].durationMs is invalid.`,
    )
  }

  return {
    timestamp: isoTimestamp(event.timestamp, `diagnostics[${index}].timestamp`),
    severity: enumValue(
      event.severity,
      severities,
      `diagnostics[${index}].severity`,
    ),
    feature: token(event.feature, `diagnostics[${index}].feature`),
    eventCode: token(event.eventCode, `diagnostics[${index}].eventCode`),
    outcome: enumValue(
      event.outcome,
      outcomes,
      `diagnostics[${index}].outcome`,
    ),
    ...(durationMs === undefined ? {} : { durationMs }),
    ...(event.exceptionType === undefined
      ? {}
      : {
          exceptionType: token(
            event.exceptionType,
            `diagnostics[${index}].exceptionType`,
          ),
        }),
    ...(stack === undefined
      ? {}
      : {
          stack: stack.map((line) =>
            sanitizeStackLine(text(line, 'stack line', 240)),
          ),
        }),
  }
}

export function buildIssue(
  report: PublicReport,
  screenshotUrl?: string,
): { title: string; body: string; labels: string[] } {
  const prefix = {
    bug: '[Bug]',
    feature: '[Feature]',
    layout: '[Layout]',
  }[report.type]
  const label = report.type === 'bug' ? 'bug' : 'enhancement'
  const diagnostics = report.diagnostics.length
    ? [
        '<details>',
        `<summary>Sanitized diagnostics (${report.diagnostics.length})</summary>`,
        '',
        '```json',
        JSON.stringify(report.diagnostics, null, 2),
        '```',
        '</details>',
      ].join('\n')
    : '_No diagnostics included._'
  const screenshot = screenshotUrl
    ? `![User-approved public screenshot](${screenshotUrl})\n\n_The screenshot is scheduled for deletion after 30 days._`
    : '_No screenshot included._'

  return {
    title: `${prefix} ${report.title}`,
    labels: [label],
    body: [
      '> This issue was submitted from Lootr after the reporter reviewed the exact public payload and confirmed that private financial and personal information was removed.',
      '',
      `**Report ID:** \`${report.id}\``,
      `**Type:** ${report.type}`,
      '',
      '## Request',
      '',
      report.description,
      '',
      '## App context',
      '',
      `- Version: ${report.app.version}`,
      `- Build: ${report.app.build}`,
      `- Platform: ${report.app.platform}`,
      '',
      '## Screenshot',
      '',
      screenshot,
      '',
      '## Diagnostics',
      '',
      diagnostics,
      '',
      '## Public disclosure',
      '',
      '- [x] The reporter reviewed this issue and removed private financial and personal information.',
      '- [x] The reporter understands public content may remain in caches or notifications after editing or deletion.',
    ].join('\n'),
  }
}

function sanitizeStackLine(value: string): string {
  return value
    .replaceAll(/https?:\/\/[^ )]+/g, '<url>')
    .replaceAll(/0x[0-9a-fA-F]+/g, '<address>')
}

function record(value: unknown, name: string): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new ReportValidationError(`${name} must be an object.`)
  }
  return value as Record<string, unknown>
}

function exactKeys(
  value: Record<string, unknown>,
  allowed: readonly string[],
): void {
  const unknown = Object.keys(value).filter((key) => !allowed.includes(key))
  if (unknown.length) {
    throw new ReportValidationError(`Unknown field: ${unknown[0]}.`)
  }
}

function text(
  value: unknown,
  name: string,
  max: number,
  pattern?: RegExp,
): string {
  if (
    typeof value !== 'string' ||
    value.trim().length === 0 ||
    value.length > max ||
    (pattern !== undefined && !pattern.test(value))
  ) {
    throw new ReportValidationError(`${name} is invalid.`)
  }
  return value.trim()
}

function token(value: unknown, name: string): string {
  return text(value, name, 64, /^[A-Za-z][A-Za-z0-9_.-]*$/)
}

function enumValue<T extends string>(
  value: unknown,
  allowed: readonly T[],
  name: string,
): T {
  if (typeof value !== 'string' || !allowed.includes(value as T)) {
    throw new ReportValidationError(`${name} is invalid.`)
  }
  return value as T
}

function booleanValue(value: unknown, name: string): boolean {
  if (typeof value !== 'boolean') {
    throw new ReportValidationError(`${name} must be a boolean.`)
  }
  return value
}

function isoTimestamp(value: unknown, name: string): string {
  const result = text(value, name, 40)
  if (Number.isNaN(Date.parse(result))) {
    throw new ReportValidationError(`${name} is invalid.`)
  }
  return result
}
