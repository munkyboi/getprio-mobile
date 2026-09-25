# Sandbox TestFlight automation

The `Sandbox TestFlight` GitHub Actions workflow builds and uploads the
Sandbox iOS app on demand or monthly. TestFlight builds are available for 90
days, so monthly renewal leaves room for one missed run.

The workflow uses the App Store Connect API key for both Xcode automatic
signing and the TestFlight upload. The repository secrets are:

- `GETPRIO_APP_STORE_CONNECT_ISSUER_ID`
- `GETPRIO_APP_STORE_CONNECT_KEY_ID`
- `GETPRIO_APP_STORE_CONNECT_PRIVATE_KEY`

The build uses the `sandbox` Xcode scheme and the isolated Sandbox runtime:

- Bundle ID: `com.getprio.getprioMobile.ios.sandbox`
- API: `https://sandbox-api.getprio.online`
- Approved host: `sandbox.getprio.online`
- TestFlight group: `Portal Developers`

The workflow waits for App Store Connect processing before assigning the build
to the external group and submits the build for beta review. Apple may still
require metadata, export-compliance, or first-build approval in App Store
Connect before external testers can install it; those gates remain in the
Developer portal.

The workflow runs only from `main`, uses the `sandbox-testflight` environment,
allocates the next build number from App Store Connect, runs
`flutter analyze` and `flutter test`, and verifies the signed bundle ID,
production APNs entitlement, and exported IPA metadata before upload. Configure
required reviewers for the environment in **Settings → Environments**.

Run it manually from GitHub under **Actions → Sandbox TestFlight → Run
workflow**. Scheduled runs are intentionally limited to the Sandbox app; the
production app has a separate release path.
