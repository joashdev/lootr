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

The About screen provides **Report a bug**. It opens—not silently submits—a public GitHub issue composer.

The app may prefill only:

| **Field** | **Allowed value** | **Forbidden examples** |
|---|---|---|
| `version` | Public application version | Database/schema contents |
| `build` | Public Android build number | Device identifier |
| `platform` | Operating-system name | Account or user name |
| `body` | Empty reproduction prompts | Transactions, balances, receipts, logs |

Before leaving Lootr, the user sees a warning that GitHub issues are public. The repository issue form repeats the warning and requires a privacy confirmation. Vulnerabilities use GitHub private vulnerability reporting.

No GitHub token, analytics SDK, crash reporter, database export, or automatic attachment is included in the APK.

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
- Bug reporting warns first and prepopulates only public app context
- The repository contains README, AGPL license, notice, security policy, issue form, and release guide
- Analysis passes and the full automated test suite passes
- A release APK builds through both unsigned-local and configured-signing paths
- `apksigner` verifies the signed artifact
- The GitHub workflow publishes only matching tags reachable from protected `main`
- The release exposes an APK, checksum, generated notes, and provenance
