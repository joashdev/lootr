# Running Lootr on Emulators & Taking Screenshots

A practical, battle-tested guide for running the Lootr Flutter app on the
**iOS Simulator** and **Android emulator**, and capturing screenshots for
review. Every command here was run and verified on a macOS (Apple Silicon)
machine. Gotchas that actually bit us are called out with ⚠️.

> **Run from the right worktree.** This app is developed across multiple git
> worktrees. Always `cd` into the worktree you intend to test (e.g.
> `.worktrees/tasks-11-17-ui-changes`) before building. The integration branch
> `feat/tasks-11-17-ui-changes` contains Tasks 11–17 + the Android/nav fixes.

---

## 0. One-time prerequisites

| Tool | Where it is on this machine | Notes |
|---|---|---|
| Flutter | `/opt/homebrew/bin/flutter` (3.44.x) | `flutter --version` |
| Xcode | standard | needed for iOS |
| Android SDK | `~/Library/Android/sdk` | `adb`, `emulator` live under it |
| JDK (for Gradle) | `/Applications/Android Studio.app/Contents/jbr/Contents/Home` | ⚠️ **no `java` on PATH by default** |
| iOS Simulator (used) | `iPhone 15 Pro` — UDID `507D5842-B9E0-4326-891E-7942DF25C782` | yours may differ; discover it (below) |
| Android AVD (used) | `lootr_avd` (arm64-v8a) | `emulator -list-avds` |

Handy PATH exports (Android):
```bash
export PATH="$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator:$PATH"
```

---

## 1. Codegen (do this after any pull / branch switch)

The repo uses Drift + json_serializable; generated `*.g.dart` files are **not**
committed. Build them or analysis/tests/builds fail:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Quick health check before launching anything:
```bash
flutter analyze --no-pub        # expect 0 errors (≈44 pre-existing infos/warnings are OK)
flutter test --no-pub           # expect all green (537+ tests)
```

---

## 2. iOS Simulator

### 2a. Pick / boot a simulator
```bash
xcrun simctl list devices available | grep -i iphone
# Boot one if none is "(Booted)":
xcrun simctl boot "iPhone 15 Pro"
open -a Simulator                 # show the window (optional)
```
Grab the UDID from the list; everything below uses `$SIM`:
```bash
SIM=507D5842-B9E0-4326-891E-7942DF25C782   # <-- replace with yours
```

### 2b. Build, install, launch
```bash
flutter build ios --debug --simulator --no-pub
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl launch  "$SIM" com.lootr.app          # prints the PID on success
```
Confirm it stayed alive (didn't crash on launch):
```bash
xcrun simctl spawn "$SIM" launchctl list | grep -i lootr   # shows the PID if running
```

`flutter run -d "$SIM"` also works but stays attached/interactive — prefer the
build+install+launch sequence for scripted/headless verification.

### ⚠️ iOS gotchas (these cost us real time)
- **`Pods_Runner not found` / linker error:** caused by **DerivedData collisions
  across worktrees** — every worktree builds an Xcode project literally named
  `Runner`, and Xcode keys DerivedData by project name. Cure:
  ```bash
  flutter clean
  rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
  rm -rf ios/Pods ios/Podfile.lock
  flutter pub get
  (cd ios && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install)
  flutter build ios --debug --simulator --no-pub
  ```
- ⚠️ **`pod install` crashes with a Unicode/ASCII-8BIT error** in a
  non-interactive shell → set the locale: `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`.
- ⚠️ **ML Kit has no `arm64` iOS-simulator slice.** On Apple Silicon, Flutter
  builds the **x86_64** simulator slice and it runs via Rosetta — works, but you
  will always see "does not support arm64 architecture" warnings. The OCR/scan
  feature is best tested on a **physical device**. (On Android it works natively.)

---

## 3. Android emulator

### 3a. Boot the emulator
```bash
export PATH="$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator:$PATH"
emulator -list-avds
nohup emulator -avd lootr_avd -no-snapshot -no-boot-anim -gpu swiftshader_indirect > /tmp/emu.log 2>&1 &
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
adb devices    # expect: emulator-5554  device
```

### 3b. Build the APK
⚠️ Gradle needs a JDK on PATH — point it at Android Studio's JBR:
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

flutter build apk --release            # output: build/app/outputs/flutter-apk/app-release.apk
# smaller per-ABI builds (optional):
# flutter build apk --release --split-per-abi
```
⚠️ **Capture the real exit code.** `flutter build ... | tail` hides failures
behind `tail`'s exit code. Redirect instead: `flutter build apk --release > /tmp/apk.log 2>&1; echo $?`.

### 3c. Install, launch, screenshot
```bash
adb install -r -d build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.lootr.app/.MainActivity
adb shell pidof com.lootr.app          # non-empty = running
```

### 3d. Reproducing a crash (get the stack trace)
```bash
adb logcat -c                          # clear
adb shell am start -n com.lootr.app/.MainActivity
adb logcat -d -b crash | tail -60      # the crash buffer has the Java stack trace
```

### ⚠️ Android gotchas (already fixed on this branch — keep them)
- **ML Kit + R8 release build failure** (`minifyReleaseWithR8`, "Missing class
  com.google.mlkit.vision.text.{chinese,devanagari,japanese,korean}…"): fixed by
  `android/app/proguard-rules.pro` (`-dontwarn` those packages, `-keep` ML Kit/GMS)
  wired into the release build type in `android/app/build.gradle.kts`.
- **Immediate crash, `ClassNotFoundException: com.lootr.app.MainActivity`:** the
  scaffolded `MainActivity.kt` had the wrong `package` (`com.lootr.app.lootr`).
  Fixed to `com.lootr.app`. If a future scaffold regresses this, the manifest
  launches `.MainActivity` = `com.lootr.app.MainActivity` — the package MUST match.
- ⚠️ **ABI must match.** Use an **arm64-v8a** AVD on Apple Silicon. Check with
  `adb shell getprop ro.product.cpu.abi` and confirm the APK ships that ABI:
  `unzip -l <apk> | grep -oE 'lib/[^/]+/' | sort -u`.

---

## 4. Taking screenshots

**iOS Simulator** (writes device-resolution PNG):
```bash
xcrun simctl io "$SIM" screenshot /path/to/out.png
```

**Android emulator/device:**
```bash
adb exec-out screencap -p > /path/to/out.png
```

Save screenshots to the session scratchpad (not the repo), e.g. under the
session's `scratchpad/` dir. To view a PNG, read the file path with the Read
tool — it renders the image inline.

⚠️ **There is no built-in tap automation** in this environment (`idb` is not
installed; `simctl`/`adb` screenshot but don't reliably tap a scaled window).
To verify interactive flows:
- prefer **widget/integration tests** (deterministic) — e.g. the router test
  `test/core/router/transactions_new_route_test.dart` proves `/transactions/new`
  resolves correctly without rendering;
- or `adb shell input tap <x> <y>` on Android (device pixels — map from a
  screenshot using its real resolution), and `adb shell input swipe …` for paging;
- on iOS, `flutter run` + hot-restart is usually the fastest manual loop.

---

## 5. First-launch / onboarding note

The app shows the onboarding flow on first launch (Task 17) and redirects there
until completed (persisted via SharedPreferences). After a fresh install you'll
land on "Welcome to Lootr". Tap **Skip** (top-right) → confirm, or page through
with **Next** → **Get Started**, to reach the main tab shell (Dashboard).
To force a clean first-launch state:
- iOS: `xcrun simctl uninstall "$SIM" com.lootr.app` then reinstall.
- Android: `adb shell pm clear com.lootr.app` (clears app data incl. prefs).

---

## 6. Quick reference — full happy path

```bash
# --- shared ---
cd .worktrees/tasks-11-17-ui-changes
flutter pub get && dart run build_runner build --delete-conflicting-outputs

# --- iOS ---
SIM=$(xcrun simctl list devices available | grep -m1 -oE '[0-9A-F-]{36}')
xcrun simctl boot "$SIM" 2>/dev/null; open -a Simulator
flutter build ios --debug --simulator --no-pub
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl launch  "$SIM" com.lootr.app
xcrun simctl io "$SIM" screenshot /tmp/ios.png

# --- Android ---
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator:$PATH"
emulator -avd lootr_avd -no-snapshot -no-boot-anim -gpu swiftshader_indirect >/tmp/emu.log 2>&1 &
adb wait-for-device; until [ "$(adb shell getprop sys.boot_completed|tr -d '\r')" = 1 ]; do sleep 2; done
flutter build apk --release > /tmp/apk.log 2>&1; echo "build exit=$?"
adb install -r -d build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.lootr.app/.MainActivity
adb exec-out screencap -p > /tmp/android.png
```
