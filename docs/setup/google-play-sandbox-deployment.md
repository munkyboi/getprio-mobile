# Android Google Play deployment

The Sandbox and production Android flavors are published to their respective
Google Play internal testing tracks. The Developer Portal displays the Sandbox
tester opt-in URL; it does not accept Play credentials or let individual
developers publish builds.

## Play Console setup

1. Create the Sandbox Android app with the exact package name
   `com.getprio.getprioMobile.android.sandbox`.
2. Create the production Android app with the exact package name
   `com.getprio.getprio_mobile`.
3. Enroll both apps in Play App Signing and configure their upload keys.
4. Create an Internal testing track for each app and add the appropriate tester
   list or group.
5. Upload and publish the first AAB for each app manually. Play does not expose the
   tester opt-in link until the test release is published.
6. Copy the Sandbox tester URL, normally
   `https://play.google.com/apps/testing/com.getprio.getprioMobile.android.sandbox`.
7. Keep production-track promotion separate from this workflow until the
   production listing, policy declarations, signing, and release acceptance are
   complete.

Google's Play guidance recommends AAB for Play distribution and says internal
tests can support up to 100 testers. Use a closed test later if the Sandbox
audience needs a larger controlled group.

## GitHub environment

Create `sandbox-google-play` and `production-google-play` environments in the
`getprio-mobile` repository with these protected secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

The service account should be created in Google Cloud, invited in Play Console,
and granted only the permissions needed to release these apps to their internal
testing tracks. Keep the JSON key and upload keys in Bitwarden and the GitHub
environments; never commit either file.

Run the manually dispatched workflow. It builds both flavors and publishes both
to their internal testing tracks:

```bash
gh workflow run android-sandbox-google-play.yml \
  --repo munkyboi/getprio-mobile \
  --ref main
```

## Developer Portal configuration

Add the copied tester URL as the protected `production` environment secret
`SANDBOX_ANDROID_GOOGLE_PLAY_PUBLIC_URL` in `munkyboi/getprio`. The web
deployment passes it to the backend, which validates the exact Sandbox package
and exposes it only to authenticated project members.
