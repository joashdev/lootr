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

- A signed universal APK and a smaller APK for each supported ABI
- A SHA-256 checksum and GitHub artifact provenance for each APK
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

## 7. Android Package Size

The universal APK keeps the `-android.apk` filename. Single-ABI APKs
add `-arm64-v8a`, `-armeabi-v7a`, or `-x86_64` before `.apk`.
All four APKs use the same app ID, version code, and signing certificate.
Each single-ABI build uses one Flutter target and a matching native library filter.
Flutter's split-per-ABI flag assigns a higher version code to the smaller
APKs, which would block a return to the universal APK.

The GitHub workflow reports each unsigned APK's size and verifies its
version, ABIs, and required native libraries before signing. The size limits
in `tool/check_android_apks.py` allow small changes above the alpha.3
baseline. If an APK exceeds its limit, measure the change before increasing
the limit. The workflow saves each APK's native symbols as a separate
workflow artifact for crash analysis.

### Alpha.3 baseline

The published, checksum-verified universal alpha.3 APK is **122,539,448 bytes**.
A separate local universal release APK measured **117,865,060 bytes**. Both
numbers are APK download sizes.

| ZIP payload | Bytes in published APK |
| --- | ---: |
| All Dart AOT libraries | 38,963,564 |
| All Flutter engine libraries | 32,888,708 |
| All ML Kit OCR libraries | 29,472,612 |
| All SQLCipher libraries | 15,064,712 |
| Flutter assets | 1,905,969 |
| Android bytecode | 1,809,759 |
| ML Kit models | 1,272,325 |
| Android resources | 396,129 |

These counts use compressed ZIP entry sizes and exclude archive overhead.
Native libraries are stored without ZIP compression. Each arm64 library in
this artifact was already stripped. The Android build already uses release
code and resource shrinking.

| ABI | Native payload bytes in the universal APK | Release APK limit |
| --- | ---: | ---: |
| arm64-v8a | 40,328,528 | 49,000,000 |
| armeabi-v7a | 33,152,132 | 41,500,000 |
| x86_64 | 43,356,160 | 52,000,000 |
| Universal | 116,836,820 | 126,000,000 |

An arm64 build from current source measured **45,909,841 bytes** before
signing. That is 62.5% smaller than the published universal APK. It uses
Flutter 3.44.2 and the release version, build number, and reporting endpoint
used for alpha.3. Flutter size analysis reports Dart AOT at about 12 MiB,
including about 4 MiB of Flutter framework code, 2 MiB of Lootr code,
and 805 KiB of image processing code.

GitHub distributes APKs. Bundle download estimates and installed sizes use
different measurements. When measuring a bundle, record the tool and
device specification. When measuring installed size, record the device and
Android version. Keep the future AI runtime, model downloads, and installed
model storage in separate budgets.
