# GetPrio OTA updates

Next milestone: [TestFlight rollout plan](../specs/ota-testflight-rollout-plan.md).

Status: account connected and app configuration initialized on 2026-09-15.
No enabled release, patch delivery, or device acceptance has been verified yet.

Registered app: `GetPrio`, ID `54a10b8a-f4a5-4e60-855c-30af3cb5f3b4`.
The generated `shorebird.yaml` is registered in Flutter assets with the default
automatic updater enabled. Credentials remain outside the repository.

Local preparation on 2026-09-14: installed Shorebird 1.6.120 with Flutter 3.47.2
and Dart 3.13.2. Added the Android main manifest's required INTERNET permission.
Initialization used a temporary copy of the iOS project and pubspec because
full-project flavor detection requires an Android SDK, which is not configured
on this Mac. No iOS flavors were detected; the Android Gradle configuration also
declares no product flavors. Only the generated updater config and asset entry
were applied to this checkout. Android build readiness remains unverified.

Verification on 2026-09-15: `shorebird doctor` passes configuration, reachability,
permission, Xcode-setting, asset-registration, and lockfile checks; it reports
only a newer-CLI notice. `git diff --check` passes. Asset-bundle verification is
not complete: default `flutter build bundle --debug` requires the missing Android
SDK; the iOS-targeted bundle command fails in native-asset hooks because Flutter
does not supply `SdkRoot` through that command. Verify packaging through the
normal iOS build/release path before distribution. No device test was performed.

## Update behavior

Use Shorebird's default automatic updater for the first integration. It checks
for and downloads patches in the background on engine launch, then loads the
patch on the next app launch. Do not force a restart during queue joins, OAuth,
MFA, or hosted payments. Normal app use must remain available when update
delivery is offline or unavailable.

This behavior is provided by the Shorebird engine; it does not require a Dart
update service or the optional `shorebird_code_push` package. Standard Flutter
builds do not gain OTA support just by adding a dependency.

## Connect the app

1. Install the official Shorebird CLI and run `shorebird doctor`.
2. Sign in to the GetPrio owner's Shorebird account with `shorebird login`.
3. Run `shorebird init` in this app directory. Review its changes, including the
   generated `shorebird.yaml` and Flutter asset registration. Use the real
   registered app ID; do not commit a placeholder. Keep automatic updates enabled.
4. Keep production and Sandbox identities and release configuration separate.
   Sandbox identity setup is still pending in the API versioning handoff.
5. Verify a supported Shorebird Flutter version satisfies this app's Dart SDK
   constraint and dependencies before creating the first release.

The public app ID belongs in source control. Authentication credentials and any
patch-signing private keys belong outside the repository.

## First enabled release

### Repeatable local validation

The helper pins Shorebird Flutter 3.47.2 and always uses an unsigned dry-run.
It cannot publish a release or patch:

```bash
python3 scripts/ota_ios.py check
python3 -m unittest discover -s scripts -p 'test_ota_ios.py'
python3 scripts/ota_ios.py dry-run \
  --version <explicit-version+build> \
  --api-origin https://api.example.com \
  --approved-hosts example.com
python3 scripts/ota_ios.py inspect \
  --archive build/ios/archive/Runner.xcarchive \
  --version <same-version+build>
```

Inspection rejects a mismatched bundle ID, app version/build, updater app ID,
missing updater asset or disabled automatic updates. It reports the packaged
configuration checksum. It is not an engine/signing/device verification.
Local dirty-tree dry-runs are allowed for diagnosis; the shipping baseline must
come from an explicitly reviewed source commit with recorded build flags.

For the signed baseline, after M26/M23 and release-version checks pass, use
`shorebird release ios` with the same explicit Flutter version, app version/build,
API/host defines and App Store export configuration. Do not use the helper's
unsigned dry-run archive for TestFlight. Verify the signed artifact separately.
When exporting in Xcode, turn off "Manage Version and Build Number" so the
distributed version still matches Shorebird's recorded baseline.

Stage patches with explicit `--release-version` and `--track staging`; preserve
the baseline's build flags. Do not pass native/asset-diff override flags. Capture
the CLI's release and patch identifiers before preview, promotion or rollback.

Build through `shorebird release ios` (or `shorebird release android`) with the
reviewed app identity, explicit version/build, API origin, approved hosts, and
the same release configuration used for normal distribution. Record the source
commit, Flutter version, app ID, platform, store version/build, and build flags.
Distribute the resulting baseline through TestFlight/store distribution.

Existing installations built with ordinary Flutter need this baseline update
before they can receive patches. Reconcile the actual distributed version before
choosing a build number; the current local pubspec is not distribution evidence.
The [API versioning handoff](../specs/api-versioning-rollout-handoff.md) and
[iOS release contract](../specs/ios-mvp-quality-privacy-release-contract.md) still
gate mobile distribution, including M26 backend-route verification before M24.

## Patch and rollback workflow

- Target the exact previously released platform and release version. Retain its
  API configuration, app identity, and build flags.
- Restrict OTA changes to supported changes such as Dart bug fixes. Native
  changes, native plugin changes, permissions, and engine upgrades need a new
  baseline store release. Follow current store policies for functionality changes.
- Use Shorebird's staging track to test a patch before promoting it to stable.
  Record the release version, patch number, source commit, checks, and promotion.
- Use Shorebird rollback for a faulty patch and verify that devices recover.
  Rollback also requires a network check and subsequent launch; it is not an
  instantaneous recall. Maintain backend compatibility for older app/patch versions.

## Acceptance evidence required

- Install an enabled baseline on a physical iPhone and verify the app's normal
  authentication, active-ticket, payment-return, and resume behavior.
- Deliver a harmless staging patch, witness download followed by activation on a
  later launch, and record baseline/patch identifiers and visible evidence.
- Check offline startup and update-service unavailability without blocking use.
- Verify an active customer flow is not interrupted by a downloaded patch.
- Roll back the staging patch and witness recovery across subsequent launches.
- Verify production/Sandbox separation before enabling both environments.
- Record Android device evidence separately if Android distribution is included.

Keep the OTA KanbanFlow card open until these checks are complete. Local tests
and CLI setup alone do not establish working OTA delivery.

## References

- [Official setup](https://docs.shorebird.dev/getting-started/)
- [Automatic update behavior](https://docs.shorebird.dev/code-push/update-strategies/)
- [Staging patches](https://docs.shorebird.dev/code-push/guides/staging-patches/)
- [Limitations and store compliance](https://docs.shorebird.dev/code-push/faq/)
