#!/usr/bin/env python3
"""Validate GetPrio OTA config and produce a local, non-uploading iOS archive.

Publishing is deliberately a separate Shorebird release operation after M26/M24
acceptance. A successful check or dry-run does not establish release readiness.
"""
import argparse
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
APP_ID = "54a10b8a-f4a5-4e60-855c-30af3cb5f3b4"
BUNDLE_ID = "com.getprio.getprioMobile"
FLUTTER_VERSION = "3.47.2"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def app_id(text):
    match = re.search(r"^app_id:\s*([\w-]+)\s*$", text, re.M)
    require(match is not None, "Missing Shorebird app_id")
    return match.group(1)


def validate_config(root):
    config = (root / "shorebird.yaml").read_text()
    require(app_id(config) == APP_ID, "Unexpected Shorebird app identity")
    require(not re.search(r"^\s*auto_update:\s*false\b", config, re.M),
            "This rollout requires the automatic updater")
    require(re.search(r"^\s*- shorebird\.yaml\s*$",
                      (root / "pubspec.yaml").read_text(), re.M),
            "shorebird.yaml must be a Flutter asset")


def validate_inputs(version, origin, hosts):
    require(re.fullmatch(r"\d+\.\d+\.\d+\+[1-9]\d*", version),
            "Use an explicit release version such as 1.0.2+4")
    uri = urlsplit(origin)
    require(uri.scheme == "https" and uri.hostname and not uri.username
            and not uri.password and uri.path in ("", "/")
            and not uri.query and not uri.fragment,
            "API URL must be an HTTPS origin, without /api or credentials")
    values = hosts.split(",")
    require(all(re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?", h)
                for h in values), "Approved hosts must be comma-separated hostnames")


def dry_run_command(cli, version, origin, hosts):
    validate_inputs(version, origin, hosts)
    name, number = version.split("+")
    return [cli, "release", "ios", "--dry-run", "--no-codesign",
            "--flutter-version", FLUTTER_VERSION,
            "--build-name", name, "--build-number", number,
            "--dart-define=GETPRIO_API_BASE_URL=" + origin.rstrip("/"),
            "--dart-define=GETPRIO_APPROVED_HOSTS=" + hosts]


def inspect_archive(archive, version):
    apps = list((archive / "Products/Applications").glob("*.app"))
    require(len(apps) == 1, "Expected exactly one app inside the archive")
    app = apps[0]
    with (app / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    actual = str(info.get("CFBundleShortVersionString")) + "+" + str(info.get("CFBundleVersion"))
    require(actual == version, "Archive version differs from the requested Shorebird version")
    require(info.get("CFBundleIdentifier") == BUNDLE_ID, "Archive bundle ID mismatch")
    asset = app / "Frameworks/App.framework/flutter_assets/shorebird.yaml"
    data = asset.read_bytes()
    require(app_id(data.decode()) == APP_ID, "Packaged Shorebird app ID mismatch")
    require(not re.search(r"^\s*auto_update:\s*false\b", data.decode(), re.M),
            "Packaged automatic updater is disabled")
    return {"archive": str(archive.resolve()), "version": actual,
            "bundle_id": BUNDLE_ID, "shorebird_app_id": APP_ID,
            "updater_asset_sha256": hashlib.sha256(data).hexdigest(),
            "scope": "Archive metadata and asset only; not signing, engine, or OTA delivery proof"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("check")
    dry = sub.add_parser("dry-run")
    dry.add_argument("--version", required=True)
    dry.add_argument("--api-origin", required=True)
    dry.add_argument("--approved-hosts", required=True)
    inspect = sub.add_parser("inspect")
    inspect.add_argument("--archive", type=Path, required=True)
    inspect.add_argument("--version", required=True)
    args = parser.parse_args()
    validate_config(ROOT)
    if args.action == "check":
        print("OTA configuration valid. Distribution still requires M26/M24 acceptance.")
    elif args.action == "inspect":
        print(json.dumps(inspect_archive(args.archive, args.version), indent=2))
    else:
        cli = shutil.which("shorebird")
        if not cli:
            candidate = Path.home() / ".shorebird/bin/shorebird"
            require(candidate.is_file(), "Install Shorebird and sign in first")
            cli = str(candidate)
        command = dry_run_command(cli, args.version, args.api_origin, args.approved_hosts)
        print("Local unsigned dry-run only; nothing will be uploaded.", flush=True)
        return subprocess.run(command, cwd=ROOT).returncode
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError) as error:
        print("OTA check failed: " + str(error), file=sys.stderr)
        sys.exit(1)
