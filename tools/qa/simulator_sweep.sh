#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1
  pwd
}

describe_udid() {
  local udid="$1"
  local line=""

  line="$(
    xcrun simctl list devices available |
      awk -v id="$udid" '$0 ~ id { sub(/^[[:space:]]+/, "", $0); print; exit }'
  )"

  if [[ -z "$line" ]]; then
    echo "$udid"
    return
  fi

  echo "$line"
}

require_device_udid() {
  local device_name="$1"
  local -a udids=()

  mapfile -t udids < <(
    xcrun simctl list devices available |
      awk -v name="$device_name" '
        $0 ~ name" \\(" {
          match($0, /\\(([0-9A-F-]+)\\)/, m)
          if (m[1] != "") { print m[1] }
        }
      '
  )

  if [[ "${#udids[@]}" -eq 0 ]]; then
    echo "error: simulator device not found: '$device_name'" >&2
    echo "hint: list devices with: xcrun simctl list devices available" >&2
    exit 1
  fi

  if [[ "${#udids[@]}" -ne 1 ]]; then
    echo "error: simulator device name is ambiguous: '$device_name'" >&2
    printf "matches:\n" >&2
    printf "  %s\n" "${udids[@]}" >&2
    echo "hint: set IPHONE_UDID / IPAD_UDID explicitly for a deterministic target" >&2
    exit 1
  fi

  echo "${udids[0]}"
}

main() {
  local root
  root="$(repo_root)"

  local scheme="Handrail"
  local project="$root/ios/Handrail/Handrail.xcodeproj"
  local bundle_id="com.velocityworks.Handrail"

  local iphone_device="${IPHONE_DEVICE:-iPhone 17}"
  local ipad_device="${IPAD_DEVICE:-iPad Pro (13-inch) (M4)}"

  local run_stamp
  run_stamp="$(date +%Y-%m-%d-%H%M%S)"

  local out_dir="$root/test-artifacts/qa-simulator-sweep-$run_stamp"
  mkdir -p "$out_dir"

  local derived="/private/tmp/handrail-qa-deriveddata-$run_stamp"

  local iphone_udid="${IPHONE_UDID:-}"
  if [[ -z "$iphone_udid" ]]; then
    iphone_udid="$(require_device_udid "$iphone_device")"
  fi

  local ipad_udid="${IPAD_UDID:-}"
  if [[ -z "$ipad_udid" ]]; then
    ipad_udid="$(require_device_udid "$ipad_device")"
  fi

  local iphone_desc
  iphone_desc="$(describe_udid "$iphone_udid")"

  local ipad_desc
  ipad_desc="$(describe_udid "$ipad_udid")"

  echo "QA simulator sweep:"
  echo "- iPhone: $iphone_desc"
  echo "- iPad:   $ipad_desc"
  echo "- out:    $out_dir"

  xcrun simctl bootstatus "$iphone_udid" -b
  xcrun simctl bootstatus "$ipad_udid" -b

  xcodebuild \
    -project "$project" \
    -scheme "$scheme" \
    -configuration Debug \
    -sdk iphonesimulator \
    -derivedDataPath "$derived" \
    -destination "id=$iphone_udid" \
    build >"$out_dir/build-iphone.log"

  xcodebuild \
    -project "$project" \
    -scheme "$scheme" \
    -configuration Debug \
    -sdk iphonesimulator \
    -derivedDataPath "$derived" \
    -destination "id=$ipad_udid" \
    build >"$out_dir/build-ipad.log"

  local app_path="$derived/Build/Products/Debug-iphonesimulator/Handrail.app"
  if [[ ! -d "$app_path" ]]; then
    echo "error: expected built app at: $app_path" >&2
    exit 1
  fi

  xcrun simctl install "$iphone_udid" "$app_path"
  xcrun simctl install "$ipad_udid" "$app_path"

  xcrun simctl launch "$iphone_udid" "$bundle_id" >"$out_dir/launch-iphone.txt"
  xcrun simctl launch "$ipad_udid" "$bundle_id" >"$out_dir/launch-ipad.txt"

  xcrun simctl io "$iphone_udid" screenshot "$out_dir/iphone-launch.png"
  xcrun simctl io "$ipad_udid" screenshot "$out_dir/ipad-launch.png"

  echo "ok: captured:"
  echo "- $out_dir/iphone-launch.png"
  echo "- $out_dir/ipad-launch.png"
}

main "$@"
