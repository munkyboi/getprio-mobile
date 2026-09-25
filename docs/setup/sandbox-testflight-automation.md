# Sandbox TestFlight automation

The `Sandbox TestFlight` GitHub Actions workflow builds and uploads the
Sandbox iOS app on demand or every other month. TestFlight builds are available
for 90 days, so the schedule leaves a renewal margin without producing a build
for every source change.

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
to the external group. Apple may still require TestFlight review for a first
external build or after a material change. The workflow does not bypass that
review gate.

Run it manually from GitHub under **Actions → Sandbox TestFlight → Run
workflow**. Scheduled runs are intentionally limited to the Sandbox app; the
production app has a separate release path.
