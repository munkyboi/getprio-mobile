# Shorebird-enabled TestFlight rollout plan

Status: implementation started on 2026-09-15 after the user requested execution.
Distribution remains gated on the prerequisites below. The original planning
turn did not authorize a release; the subsequent implementation request starts
execution, preserving the agreed dependency and verification gates.

## Target and prerequisites

Deliver the first iOS TestFlight baseline capable of receiving OTA patches, then
demonstrate patch activation and rollback on a physical iPhone. Use the registered
GetPrio app ID `54a10b8a-f4a5-4e60-855c-30af3cb5f3b4` and default background
updates. Android distribution and Sandbox provisioning are separate work.

- Account connection, updater configuration, and asset registration are complete.
- M26 must verify versioned backend routes and migrated mobile flows before M24
  distribution. Follow the [API handoff](api-versioning-rollout-handoff.md).
- M23 accessibility/regression acceptance and Apple signing/TestFlight access
  remain M24 prerequisites. The baseline portion of M27 precedes M24 upload;
  M27 device patch/rollback work follows baseline delivery, avoiding a circular
  dependency between the whole cards.
- `1.0.2+4` remains the candidate production version, not a reserved build number.
  Read App Store Connect and reconcile the local version before building.
- Review the dirty checkout into an explicit release scope and reproducible source
  commit. Preserve unrelated work; do not silently include every local change.
- Select and record a supported Shorebird/Flutter toolchain, bundle ID, signing
  team, production API origin and approved hosts. Confirm updater privacy/network
  behavior against the existing privacy contract before distributing.
- Resolve packaging through the normal iOS archive path. Earlier standalone bundle
  commands failed on missing Android SDK and iOS native-asset `SdkRoot`; those
  failures neither prove nor disprove that an iOS archive works.

## Sequence and estimates

| Step | Card | Effort | Exit evidence |
| --- | --- | --- | --- |
| Pin toolchain, review source/configuration, resolve iOS packaging and run analysis/tests | M27 | 2h | Reviewed source SHA, tool versions, passing relevant checks |
| Create signed Shorebird iOS baseline and inspect updater asset/identity | M27 | 2h | Shorebird release ID/version and IPA metadata |
| Upload baseline, complete processing/compliance and enable controlled testers | M24 | 2h | TestFlight availability and actual installation |
| Run normal mobile acceptance on baseline | M24 | 4h | Physical-iPhone results under existing release contract |
| Stage a harmless Dart patch and exercise download/activation | M27 | 2h | Baseline/patch IDs, track, visible before/after evidence |
| Exercise rollback, controlled stable delivery and record handoff | M27 | 2h | Recovery evidence and final known-good state |

M27 remains 8h; M24 remains 6h. Proposed Sprint 10 totals 14h, leaving 2h
unallocated within the usual 16h task budget plus 4h reserve in a 20h week.
Re-sequence M24 from its legacy Sprint 8 placement to Sprint 10 with M27; both
remain Product Backlog until prerequisites are ready and the sprint is selected.
Sprint 9's M26 (8h) and M25 (6h) remain unchanged. No time spent is inferred.
Apple processing/review, device availability and backend readiness are elapsed
dependencies outside the estimates; these are sequential sprints, not date promises.
Re-estimate if tooling recovery consumes the reserve.

## Patch routing and device procedure

1. Reserve a dedicated test iPhone, controlled customer account, and safe queue
   and payment fixtures. Record device/iOS version without exposing credentials.
2. Install the actual TestFlight baseline and complete baseline acceptance before
   any preview reinstall. Preserve evidence of account/ticket continuity across
   the normal TestFlight upgrade from the prior app.
3. Create a minimal, reversible Dart-only UI change with a visible test marker.
   Keep API contracts, native code, dependencies, assets and build flags fixed.
   Target the exact baseline release version; publish explicitly to `staging`.
4. Use `shorebird preview --track staging` for the exact release on the dedicated
   phone, checking the installed CLI's iOS signing requirements first. Preview
   may reinstall the app and clear local data: it is not evidence of TestFlight
   upgrade continuity. Confirm the actual device/track and compatible signing.
5. Launch online to download, then relaunch to witness activation. Confirm the
   visible marker and patch identity. Background/resume alone is not a guaranteed
   cold launch. Do not restart while a customer operation is active.
6. Test offline launch, interrupted download/recovery, active queue viewing and
   payment/auth return while a patch is available. Updating must not block startup,
   restart active flows, duplicate operations, or erase the customer's state.
7. Roll back the staging patch through Shorebird, reconnect/relaunch, and witness
   the known-good state. Rollback is not immediate and cannot undo server writes;
   it is not a guarantee of recovery from every crash. Keep the baseline usable.
8. After staging acceptance, reinstall the actual TestFlight baseline as needed.
   Publish/promote only a reviewed harmless patch to `stable` for this exact
   controlled baseline and verify activation on the TestFlight installation.
   Test the corresponding rollback and leave a documented known-good final state.
   Do not promote the test marker to a publicly distributed baseline.

TestFlight controls baseline distribution; it does not subscribe phones to a
Shorebird track. Default automatic clients request `stable`. Staging validation
therefore needs explicit preview routing. If preview signing cannot support the
physical-device test, stop and revise the plan for a separately signed QA baseline
or explicit test-only track selection; do not claim staging delivery was verified.

## Completion and release record

M24 is Done only after its existing [iOS acceptance contract](ios-mvp-quality-privacy-release-contract.md)
passes and testers can install the build. M27 is Done only after patch activation,
failure/offline handling, track targeting and rollback are witnessed on-device.
Neither an upload nor `shorebird doctor` proves these outcomes.

Record source SHA, toolchain, app/bundle IDs, version/build, API configuration,
Shorebird release/patch IDs, track, IPA location, TestFlight status, device/iOS,
test results, rollback result and final active patch. Redact personal information.
Monitor the free account's remaining patch-install allowance before the exercise;
keep the tester cohort small and do not enable paid overages as part of this plan.

First implementation action: verify M26 readiness, audit the candidate release
scope/version, and prove the normal iOS archive path before scheduling upload.

## Sources

- [Local setup and verified limitations](../setup/ota-updates.md)
- [Shorebird staging workflow](https://docs.shorebird.dev/code-push/guides/staging-patches/)
- [Tracks and TestFlight distinction](https://docs.shorebird.dev/code-push/tracks/)
- [Rollback behavior](https://docs.shorebird.dev/code-push/rollback/)
