# Lootr

Lootr is a calm, offline-first personal finance app. It keeps the primary
ledger on your device, works without a bank connection, and avoids guilt-based
language or attention-seeking design.

> [!WARNING]
> Lootr is alpha software. Back up important data before upgrading, verify the
> release checksum, and do not treat calculations as financial advice.

## Why Lootr

- Local-first ledger backed by SQLite
- Accounts, transactions, transfers, budgets, goals, debts, and recurring items
- Optional on-device natural-language entry and receipt recognition
- Local backup, export, and Cashew migration tools
- No bank integrations
- No advertising or automatic analytics
- Open source for public privacy and security review

The application is usable without an account. Server sync and backup are
future, opt-in capabilities and are not required for the local V1 experience.

## Install the Android alpha

1. Open the repository's [Releases](https://github.com/joashdev/lootr/releases).
2. Download the APK and its `.sha256` file from the desired prerelease.
3. Verify the checksum:

   ```sh
   sha256sum -c lootr-v0.1.0-alpha.2-android.apk.sha256
   ```

4. Allow installation from the browser or file manager when Android asks.
5. Install the APK.

Only APKs published under `joashdev/lootr` are official Lootr builds. Android
updates must be signed by the same release key, so protecting that key is part
of the project's release process.

## Privacy and bug reports

Lootr keeps bounded, sanitized diagnostic events locally. The in-app **Send
feedback** flow can publish a bug, feature request, or layout request to the
public GitHub issue tracker without requiring a GitHub account. It shows the
exact public payload and requires explicit consent before anything is uploaded.
Diagnostics are included by default only for bugs and can be removed.

Screenshots are optional, separately approved, re-encoded, and temporarily
stored for the public report. Before submitting, remove:

- Names, account numbers, balances, and transaction details
- Receipt images and merchant information you consider private
- Export, backup, or database files
- Authentication tokens, secrets, and personally identifying information

Public reports may remain in caches or notifications after editing or deletion.
Security vulnerabilities must not use the public in-app flow.

Use the [bug report template](https://github.com/joashdev/lootr/issues/new?template=bug_report.md)
for ordinary defects. Security vulnerabilities should be reported privately as
described in [SECURITY.md](SECURITY.md).

## Build and test

The release workflow uses Flutter 3.44.2. With a matching Flutter installation:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
```

A signed release additionally requires the private Android signing configuration
described in [RELEASING.md](RELEASING.md). Never commit a keystore or
`key.properties`.

The major product and architecture decisions live in [`docs/`](docs/), starting
with:

- [`product-strategy.md`](docs/product-strategy.md)
- [`solutions-arch.md`](docs/solutions-arch.md)
- [`security-model.md`](docs/security-model.md)
- [`database-schema.md`](docs/database-schema.md)
- [`specs-backlog.md`](docs/specs-backlog.md)

## Contributions and official project control

Issues and pull requests are welcome. A contribution is a proposal: the
repository owner decides whether, when, and in what form it is accepted into
this repository. Other maintainers may assist only with authority the owner
grants. Submitting a change does not guarantee review, merge, or inclusion in
an official release.

The AGPL permits compliant forks. Forks and modified distributions must not
claim to be official Lootr releases or imply endorsement by the Lootr
maintainers.

## License and marks

Lootr's source code is licensed under the
[GNU Affero General Public License v3.0 or later](LICENSE). This lets anyone
inspect, run, modify, and redistribute the software—including commercially—while
requiring source availability when covered software is conveyed and when a
modified version is offered for users to interact with over a network.

The license does not grant permission to use the Lootr name, logo, or other
project branding to identify or promote a modified distribution. Descriptive
use, such as saying that a project is a fork of Lootr, is unaffected.
