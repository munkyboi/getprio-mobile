import plistlib
import tempfile
import unittest
from pathlib import Path

from ota_ios import APP_ID, BUNDLE_ID, dry_run_command, inspect_archive, validate_inputs


class OtaReleaseChecks(unittest.TestCase):
    def test_dry_run_cannot_upload_and_pins_toolchain(self):
        command = dry_run_command("shorebird", "1.0.2+4", "https://api.example.com", "example.com")
        self.assertIn("--dry-run", command)
        self.assertIn("--no-codesign", command)
        self.assertEqual(command[command.index("--flutter-version") + 1], "3.47.2")

    def test_rejects_latest_and_non_origin_urls(self):
        for version, origin in [("latest", "https://api.example.com"),
                                ("1.0.2+4", "http://api.example.com"),
                                ("1.0.2+4", "https://api.example.com/api/v1"),
                                ("1.0.2+4", "https://secret@api.example.com")]:
            with self.subTest(version=version, origin=origin), self.assertRaises(ValueError):
                validate_inputs(version, origin, "example.com")

    def test_archive_rejects_version_and_identity_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory)
            app = archive / "Products/Applications/Runner.app"
            assets = app / "Frameworks/App.framework/flutter_assets"
            assets.mkdir(parents=True)
            plist = {"CFBundleShortVersionString": "1.0.2", "CFBundleVersion": "4",
                     "CFBundleIdentifier": BUNDLE_ID}
            (app / "Info.plist").write_bytes(plistlib.dumps(plist))
            (assets / "shorebird.yaml").write_text("app_id: " + APP_ID + "\n")
            self.assertEqual(inspect_archive(archive, "1.0.2+4")["version"], "1.0.2+4")
            with self.assertRaises(ValueError):
                inspect_archive(archive, "1.0.2+5")
            (assets / "shorebird.yaml").write_text("app_id: other-app\n")
            with self.assertRaises(ValueError):
                inspect_archive(archive, "1.0.2+4")


if __name__ == "__main__":
    unittest.main()
