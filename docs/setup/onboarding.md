# Customer onboarding

The three-slide onboarding uses the approved GetPrio reference design. The first slide's front photo comes from `_materials/stocks/Reception Interaction.png`.

## Installation lifecycle

`OnboardingGate` runs before authentication and permission prompts. `Get started` saves completion before opening the normal authentication flow. Until completion, closing the app leaves onboarding available on the next launch. A failed read or write provides a retry action.

Completion is installation-local, not an account preference:

- iOS: `Library/Application Support/GetPrioInstallation/onboarding-completed`, excluded from device/iCloud backups.
- Android: `noBackupFilesDir/onboarding-completed`, excluded from Android backup/restore.
- Normal relaunches, sign-outs, and app updates retain the marker.
- Removing the app's data or fully uninstalling removes the marker. A new installation shows onboarding again. iOS offloading retains application data and therefore retains completion.
- Installations of a version before onboarding was introduced do not yet have a marker and will receive the introduction once. There is no previous onboarding flag to migrate.

No onboarding state is written to Keychain: iOS Keychain values can outlive an uninstall.

## Validation

`flutter test test/onboarding_test.dart` covers navigation, installation state, save/read recovery, native channel contract, and responsive layouts with larger text. Existing app-launch tests supply an already-completed installation to keep testing their authentication scenarios.

The artwork is illustrative, not live queue data. Notification permission remains part of the existing authenticated notification flow.

## Slide images

Run `./tool/export_onboarding.sh` on macOS to render the production widgets and
write RGB PNGs to `../_materials/onboarding-slides/`. The helper requires Python
Pillow for removing the PNG alpha channel and validating dimensions. It exports
three iPhone images at 1320 × 2868 and three iPad images at 2064 × 2752, without OS
status bars or device frames. The opt-in Flutter harness loads real sans-serif
and packaged icon fonts and retains the production shadows.

Native iOS verification: the app built successfully for the simulator, the first
slide appeared on an empty installation, completion created the local marker,
and a subsequent process launch opened sign-in. Flutter validation passed all
181 regular tests, plus the focused pagination regression and image-export run.
Android storage implementation has not been device- or build-verified on this
host, which does not have an Android SDK configured.
