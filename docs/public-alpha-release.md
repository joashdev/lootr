# Public Alpha Release — Personal Finance App

Defines how Lootr publishes an auditable Android alpha and collects privacy-safe feedback.
References: `product-strategy.md` (privacy and V1 scope), `security-model.md` (release integrity), `solutions-arch.md` (application boundary).

---

## 1. Scope and Version

The first public build is `v0.1.0-alpha.2`. It is a universal Android APK distributed only through GitHub Releases under `joashdev/lootr`.

Alpha releases are daily-use previews, not stable financial or accounting advice. Users must be warned to back up data before upgrades and to install only artifacts produced by the official repository.

## 2. Public Audit and Governance

Lootr source is licensed under `AGPL-3.0-or-later`. The repository includes the canonical license, copyright and warranty notice, public architecture/security documentation, and a link to source from the app.

The repository owner retains sole discretion over changes merged into the official repository and artifacts presented as official Lootr releases. AGPL-compliant forks do not require approval, but the license grants no right to imply endorsement or identify a modified distribution as official Lootr.

GitHub governance must include:

- `@joashdev` as code owner
- A `main` ruleset requiring code-owner review and passing CI
- Restricted direct pushes to `main`
- A `v*` tag ruleset restricting release-tag creation and changes
- An owner-approved `android-release` Environment containing signing secrets

## 3. Privacy-Safe Bug Reporting

The About screen provides **Send feedback** with three report types:

- **Bug** — something did not work as expected
- **Feature request** — a new capability or workflow
- **Layout request** — a visual, spacing, hierarchy, or interaction change

The app submits the reviewed report through a Cloudflare Worker to the public `joashdev/lootr` GitHub issue tracker. The user does not need GitHub or leave Lootr. Every report is public by design: before submission, Lootr renders the exact user-authored issue title, body, diagnostics, and screenshot that will be published. When a screenshot is present, the preview clearly marks the attachment URL as generated during upload; that unguessable URL is the only server-generated difference. Submission remains disabled until the user confirms both:

- **I reviewed this report and removed private financial and personal information.**
- **I understand this public report may remain in caches or notifications after editing or deletion.**

Vulnerabilities never use this flow and instead open GitHub private vulnerability reporting.

### 3.1 Public Issue Payload

| **Field** | **Allowed value** | **Forbidden examples** |
|---|---|---|
| `type` | `bug`, `feature`, or `layout` | Security vulnerability details |
| `description` | User-authored and explicitly reviewed text | Unreviewed application content |
| `version` | Public application version/build | Database/schema contents |
| `platform` | Operating-system name | Device identifier or account name |
| `diagnostics` | Allowlisted event codes and sanitized stack frames | Transactions, balances, free-form values, SQL parameters |
| `screenshot` | One user-selected, previewed, re-encoded image | Automatic capture, receipt/database files |

Bug reports include recent sanitized diagnostics by default. Feature and layout requests default diagnostics off. The user may remove diagnostics before preview or submission. Screenshots default off for every type and require a separate public-attachment confirmation.

### 3.2 Local Diagnostics

Lootr maintains a bounded local JSON Lines diagnostic log in the private application-support directory. It retains the current and previous rotating files, capped at 512 KiB total and pruned to seven days. Events use a closed schema:

```text
timestamp + severity + feature + event_code + outcome + duration_ms
```

Application code must never pass arbitrary domain values to the logger. Error capture stores exception type and sanitized application stack frames, never `error.toString()`. The logger captures Flutter framework errors and unhandled asynchronous errors without installing an analytics or remote crash-reporting SDK. Diagnostics remain on-device until the user previews and submits a report.

### 3.3 Cloudflare Relay

The app sends one `multipart/form-data` request to the Cloudflare Worker:

- `report` — UTF-8 JSON, maximum 64 KiB
- `turnstileToken` — single-use Cloudflare Turnstile token, maximum 2 KiB
- `screenshot` — optional JPEG, maximum 1 MiB

After the user reviews and consents, Lootr opens a Cloudflare Turnstile Managed challenge inside an in-app WebView. The challenge token is never published, persisted, or logged. The Worker verifies it server-side through Turnstile Siteverify; tokens expire after five minutes and are accepted only once.

The Worker rejects unknown fields, missing or invalid challenge tokens, invalid consent, oversized input, unsupported media types, forbidden diagnostic keys, duplicate report IDs, and excessive request rates. A Durable Object applies an exact global quota after successful challenge verification and before any R2 write: 25 accepted report attempts per UTC day, including no-screenshot reports, and 10 screenshot attempts per UTC hour. Attempts consume quota even when the downstream GitHub request fails. The existing per-IP Worker rate limit remains an inexpensive first filter, and `REPORTING_ENABLED=false` is an emergency kill switch.

After validation, the Worker performs a second redaction pass, creates a GitHub issue using a repository-scoped secret stored only in Cloudflare, and returns the public issue number and URL. No GitHub credential is included in the APK.

The issue mapping is:

| **Report type** | **Title prefix** | **GitHub label** |
|---|---|---|
| `bug` | `[Bug]` | `bug` |
| `feature` | `[Feature]` | `enhancement` |
| `layout` | `[Layout]` | `enhancement` |

If submission fails, Lootr keeps the draft in memory, shows a neutral retry action, and does not claim the report was received. The existing browser-based GitHub composer remains a secondary fallback.

### 3.4 Screenshot Handling

The user selects an existing screenshot and sees it before consent. Lootr constrains the longest edge to 1280 pixels, re-encodes at bounded quality, removes source metadata, and rejects output over 1 MiB.

The Worker stores the image under an unguessable key in a private R2 bucket and adds a public time-bounded attachment URL to the GitHub issue only after the separate screenshot consent. The bucket lifecycle deletes screenshots after 30 days. The attachment route also checks the object's deletion deadline and deletes expired objects before returning `404`, so lifecycle configuration is not the only enforcement. If issue creation fails, the Worker deletes the orphaned object.

### 3.5 Relay Observability

Cloudflare Workers Observability records invocation status, duration, Turnstile outcome category, quota outcome, GitHub response status, R2 outcome, payload size, report type, and opaque report ID. It must never log challenge tokens, descriptions, diagnostics, screenshot keys or URLs, authorization headers, IP addresses, or financial data. PostHog, session replay, autocapture, and client analytics remain excluded.

## 4. Signed Release Pipeline

Pushing a matching semantic tag starts the Android release workflow:

```text
tag on protected main
        |
        v
version + tests + analysis
        |
        v
restore ephemeral signing key
        |
        v
build + verify APK signature
        |
        v
checksum + provenance attestation
        |
        v
GitHub prerelease
```

The workflow rejects a tag that does not match `pubspec.yaml` or does not point to a commit reachable from `main`. Signing material is restored only after validation and is deleted in an always-run cleanup step.

The published assets are:

- `lootr-vX.Y.Z-prerelease-android.apk`
- `lootr-vX.Y.Z-prerelease-android.apk.sha256`
- GitHub artifact provenance linked to the APK

## 5. Signing and Update Continuity

The release keystore and passwords exist only as protected GitHub Environment secrets and encrypted offline backups. They are never committed. The public SHA-256 fingerprint of the release certificate is pinned as an Environment variable, and every signed APK must match it.

All official APK upgrades use the same signing identity. Loss of the key prevents an update from replacing an installed build without uninstalling it, which may also remove local app data. Key backup is therefore part of user-data continuity.

Local release builds without `android/key.properties` must never fall back to the debug key.

## 6. Acceptance Criteria

- `pubspec.yaml` declares `0.1.0-alpha.2`
- The About screen displays runtime version/build values
- Bug, feature, and layout reports are composed and submitted without leaving Lootr
- Submission requires a public preview of all user-authored content, marks any server-generated screenshot URL, and requires both disclosure confirmations
- Bug diagnostics are local, rotating, allowlisted, bounded, removable, and never uploaded before consent
- Screenshots are optional, separately approved, re-encoded, size-capped, and deleted from R2 after 30 days
- The in-app Managed Turnstile challenge is verified server-side, single-use, short-lived, and neither persisted nor logged
- A Durable Object enforces exact global limits of 25 report attempts per UTC day and 10 screenshot attempts per UTC hour before any R2 write
- The Cloudflare relay validates, rate-limits, redacts, supports an emergency kill switch, creates the public GitHub issue, and exposes no GitHub credential to the APK
- Cloudflare observability contains operational metadata only; PostHog and client analytics remain absent
- The repository contains README, AGPL license, notice, security policy, issue form, and release guide
- Analysis passes and the full automated test suite passes
- A release APK builds through both unsigned-local and configured-signing paths
- `apksigner` verifies the signed artifact
- The GitHub workflow publishes only matching tags reachable from protected `main`
- The release exposes an APK, checksum, generated notes, and provenance
