#!/usr/bin/env python3
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
PROJECT = REPO / "ios" / "Handrail" / "Handrail.xcodeproj"
VERSION_CONFIG = REPO / "ios" / "Handrail" / "Config" / "HandrailVersion.xcconfig"
DERIVED_DATA = Path("/tmp/handrail-ios-release-derived-data")
DEVICE_LIST_JSON = Path("/tmp/handrail-ios-release-devices.json")
INSTALL_APP_FEATURE = "com.apple.coredevice.feature.installapp"
SUPPORTED_DEVICE_TYPES = {"iPhone", "iPad"}


def main() -> int:
    if not PROJECT.exists():
        print(f"Handrail Xcode project not found: {PROJECT}", file=sys.stderr)
        return 1
    if not VERSION_CONFIG.exists():
        print(f"Handrail version config not found: {VERSION_CONFIG}", file=sys.stderr)
        return 1

    devices, skipped = installable_ios_devices()
    for device in skipped:
        print(f"Skipped {device['name']} ({device['device_type']}): {device['reason']}", file=sys.stderr)
    if not devices:
        print("No install-ready physical iPhone or iPad devices found.", file=sys.stderr)
        return 1

    ensure_release_metadata_clean()
    version, build_number = read_version_config()
    next_version = bump_patch(version)
    next_build_number = build_number + 1
    release_time = datetime.now().strftime("%B %-d, %Y at %-I:%M %p")
    tag = f"ios-v{next_version}"
    ensure_tag_available(tag)

    write_version_config(next_version, next_build_number, release_time)
    commit_release_metadata(next_version)
    push_release(tag, next_version, release_time)
    build_app()

    app = DERIVED_DATA / "Build" / "Products" / "Release-iphoneos" / "Handrail.app"
    if not app.exists():
        print(f"Built app not found: {app}", file=sys.stderr)
        return 1

    for device in devices:
        install_app(device["identifier"], app)
        print(f"Updated {device['name']} ({device['device_type']}) to {next_version} ({next_build_number})")

    return 0


def ensure_release_metadata_clean() -> None:
    staged = capture(["git", "diff", "--cached", "--name-only"]).splitlines()
    if staged:
        print("Staged changes exist. Release commits must contain only release metadata.", file=sys.stderr)
        raise SystemExit(1)

    status = capture(["git", "status", "--porcelain", "--", str(VERSION_CONFIG.relative_to(REPO))])
    if status.strip():
        print(f"Release metadata has uncommitted changes: {VERSION_CONFIG}", file=sys.stderr)
        raise SystemExit(1)


def read_version_config() -> tuple[str, int]:
    values = {}
    for line in VERSION_CONFIG.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([A-Z0-9_]+) = (.+)", line)
        if match:
            values[match.group(1)] = match.group(2)

    version = values.get("MARKETING_VERSION")
    build_number = values.get("CURRENT_PROJECT_VERSION")
    if not version or not re.fullmatch(r"\d+\.\d+\.\d+", version):
        print(f"Invalid MARKETING_VERSION in {VERSION_CONFIG}", file=sys.stderr)
        raise SystemExit(1)
    if not build_number or not re.fullmatch(r"\d+", build_number):
        print(f"Invalid CURRENT_PROJECT_VERSION in {VERSION_CONFIG}", file=sys.stderr)
        raise SystemExit(1)

    return version, int(build_number)


def bump_patch(version: str) -> str:
    major, minor, patch = [int(part) for part in version.split(".")]
    return f"{major}.{minor}.{patch + 1}"


def write_version_config(version: str, build_number: int, release_time: str) -> None:
    VERSION_CONFIG.write_text(
        "\n".join([
            f"MARKETING_VERSION = {version}",
            f"CURRENT_PROJECT_VERSION = {build_number}",
            f"HANDRAIL_LAST_UPDATED = {release_time}",
            "",
        ]),
        encoding="utf-8",
    )


def ensure_tag_available(tag: str) -> None:
    local_tag = capture(["git", "tag", "--list", tag]).strip()
    if local_tag:
        print(f"Git tag already exists locally: {tag}", file=sys.stderr)
        raise SystemExit(1)
    remote_tag = capture(["git", "ls-remote", "--tags", "origin", tag]).strip()
    if remote_tag:
        print(f"Git tag already exists on origin: {tag}", file=sys.stderr)
        raise SystemExit(1)


def commit_release_metadata(version: str) -> None:
    run(["git", "add", str(VERSION_CONFIG.relative_to(REPO))])
    run(["git", "commit", "-m", f"Release iOS v{version}"])


def push_release(tag: str, version: str, release_time: str) -> None:
    run(["git", "tag", tag])
    run(["git", "push", "origin", "HEAD"])
    run(["git", "push", "origin", tag])
    run([
        "gh",
        "release",
        "create",
        tag,
        "--title",
        f"iOS v{version}",
        "--notes",
        f"Handrail iOS v{version}\n\nLast updated {release_time}",
    ])


def installable_ios_devices() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    run(["xcrun", "devicectl", "list", "devices", "--json-output", str(DEVICE_LIST_JSON), "--quiet"])
    with DEVICE_LIST_JSON.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    devices = []
    skipped = []
    for device in payload.get("result", {}).get("devices", []):
        hardware = device.get("hardwareProperties", {})
        device_type = hardware.get("deviceType")
        if hardware.get("platform") != "iOS" or device_type not in SUPPORTED_DEVICE_TYPES:
            continue
        if hardware.get("reality") and hardware.get("reality") != "physical":
            continue
        identifier = device.get("identifier")
        if not identifier:
            continue

        detail = device_details(identifier)
        ready_device, skip = installable_device_from_details(detail)
        if ready_device:
            devices.append(ready_device)
        else:
            skipped.append(skip)

    return (
        sorted(devices, key=lambda item: (item["device_type"], item["name"], item["identifier"])),
        sorted(skipped, key=lambda item: (item["device_type"], item["name"], item["identifier"])),
    )


def device_details(identifier: str) -> dict:
    details_json = Path(f"/tmp/handrail-ios-release-details-{safe_name(identifier)}.json")
    run([
        "xcrun",
        "devicectl",
        "device",
        "info",
        "details",
        "--device",
        identifier,
        "--json-output",
        str(details_json),
        "--quiet",
    ])
    with details_json.open("r", encoding="utf-8") as handle:
        return json.load(handle).get("result", {})


def installable_device_from_details(device: dict) -> tuple[dict[str, str] | None, dict[str, str]]:
    hardware = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    properties = device.get("deviceProperties", {})
    capabilities = {
        capability.get("featureIdentifier")
        for capability in device.get("capabilities", [])
    }
    identifier = device.get("identifier", "")
    name = properties.get("name") or identifier or "unknown device"
    device_type = hardware.get("deviceType") or "unknown"

    result = {"identifier": identifier, "name": name, "device_type": device_type}
    if not identifier:
        return None, result | {"reason": "identifier is missing"}
    if hardware.get("platform") != "iOS" or device_type not in SUPPORTED_DEVICE_TYPES:
        return None, result | {"reason": "device is not an iPhone or iPad"}
    if connection.get("tunnelState") != "connected":
        return None, result | {"reason": f"tunnelState is {connection.get('tunnelState', 'missing')}"}
    if INSTALL_APP_FEATURE not in capabilities:
        return None, result | {"reason": "Install Application capability is not available"}

    return result, {}


def build_app() -> None:
    run([
        "xcodebuild",
        "-project",
        str(PROJECT),
        "-scheme",
        "Handrail",
        "-configuration",
        "Release",
        "-destination",
        "generic/platform=iOS",
        "-derivedDataPath",
        str(DERIVED_DATA),
        "-allowProvisioningUpdates",
        "build",
    ], cwd=REPO)


def install_app(identifier: str, app: Path) -> None:
    install_json = Path(f"/tmp/handrail-ios-release-install-{safe_name(identifier)}.json")
    run([
        "xcrun",
        "devicectl",
        "device",
        "install",
        "app",
        "--device",
        identifier,
        str(app),
        "--json-output",
        str(install_json),
        "--quiet",
    ])


def run(command: list[str], cwd: Path | None = None) -> None:
    subprocess.run(command, cwd=cwd or REPO, check=True)


def capture(command: list[str]) -> str:
    return subprocess.check_output(command, cwd=REPO, text=True)


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "-", value)


if __name__ == "__main__":
    raise SystemExit(main())
