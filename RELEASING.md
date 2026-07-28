# Android Alpha Releases

References: `docs/security-model.md` (release integrity), `.github/workflows/flutter_ci.yml` (release checks).

---

## 1. Release Model

Android alpha releases are built by `.github/workflows/android_release.yml`
when a version tag is pushed. Use semantic prerelease tags such as
`v0.1.0-alpha.3`.

The tag without its leading `v` must match the version in `pubspec.yaml` before
the `+` build suffix. GitHub's monotonically increasing workflow run number is
used as Android's `versionCode`.

Each prerelease contains:

- A signed universal Android APK
- A SHA-256 checksum
- GitHub artifact provenance
- Generated release notes

## 2. Create the Android Upload Key

Create the key once on a trusted machine and keep redundant encrypted backups:

```sh
keytool -genkeypair -v \
  -keystore lootr-upload.jks \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -alias lootr-upload
```

Losing this key prevents an APK from upgrading an existing Lootr installation.
Never commit the keystore or its passwords.

## 3. Configure GitHub Secrets

Encode the keystore as one line:

```sh
base64 < lootr-upload.jks | tr -d '\n'
```

Create these `android-release` Environment secrets:

| **Secret** | **Value** |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore |
| `ANDROID_KEY_ALIAS` | Key alias, for example `lootr-upload` |
| `ANDROID_KEY_PASSWORD` | Private-key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |

Record the release certificate's SHA-256 fingerprint:

```sh
keytool -list -v \
  -keystore lootr-upload.jks \
  -alias lootr-upload
```

Create the non-secret `ANDROID_SIGNING_CERT_SHA256` variable in the same
Environment using the displayed SHA-256 certificate fingerprint. The workflow
normalizes colons and letter case, then rejects any APK signed by a different
key. Do not change this value after the first installed release unless the
project deliberately performs a supported signing-key rotation.

The workflow reconstructs the keystore only on the ephemeral GitHub runner.
Pull-request workflows do not receive or use signing secrets.

Create an `android-release` GitHub Environment and require `@joashdev` approval
before deployment. The workflow targets this environment, so the signing
secrets should be environment secrets rather than unprotected repository
secrets.

## 4. Protect the Official Project

Before publishing:

1. Add a `main` ruleset requiring pull requests, passing Flutter CI, and review
   from the code owner in `.github/CODEOWNERS`.
2. Restrict direct pushes to `main` to the repository owner.
3. Add a tag ruleset for `v*` that restricts tag creation and updates to the
   repository owner.
4. Protect the `android-release` Environment with `@joashdev` as its required
   reviewer. Leave **Prevent self-review** disabled while `@joashdev` is the
   sole reviewer; otherwise the tag creator cannot approve the release. If a
   second trusted release reviewer is added later, self-review can be disabled.

`CODEOWNERS` identifies the reviewer but does not enforce approval without the
branch ruleset. These controls reserve official merges, tags, and signed
releases to the repository owner; they do not restrict AGPL-compliant forks.

## 5. Publish a Prerelease

1. Update `pubspec.yaml`, for example `0.1.0-alpha.3+3`.
2. Merge the release-ready commit into `main`.
3. Confirm Flutter CI passes on `main`.
4. Create and push the matching tag:

   ```sh
   git tag -s v0.1.0-alpha.3 -m "Lootr v0.1.0-alpha.3"
   git push origin v0.1.0-alpha.3
   ```

5. Confirm the Android Release workflow succeeds.
6. Install the published APK on a test device before using it for daily data.

## 6. Verify a Download

```sh
sha256sum -c lootr-v0.1.0-alpha.3-android.apk.sha256
gh attestation verify lootr-v0.1.0-alpha.3-android.apk \
  --repo joashdev/lootr
```

The checksum detects file corruption or replacement. The attestation connects
the binary to the public GitHub Actions build that produced it.
