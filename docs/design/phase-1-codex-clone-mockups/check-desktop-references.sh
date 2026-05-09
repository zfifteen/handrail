#!/bin/sh
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

status=0
required="desktop-chat-list desktop-new-chat desktop-active-thread desktop-running-thinking desktop-approval-required desktop-approval-result desktop-file-artifact desktop-diff-artifact desktop-error desktop-search desktop-settings-menu"
references_dir="docs/design/phase-1-codex-clone-mockups/references"

for name in $required; do
  path="$references_dir/$name.png"
  if [ ! -f "$path" ]; then
    echo "missing $path"
    status=1
  elif ! file "$path" | rg -q "PNG image data"; then
    echo "invalid PNG $path"
    status=1
  else
    width=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    height=$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    if ! printf '%s\n' "$width" | rg -q '^[0-9]+$' || ! printf '%s\n' "$height" | rg -q '^[0-9]+$' || [ "$width" -le 0 ] || [ "$height" -le 0 ]; then
      echo "unreadable PNG dimensions $path"
      status=1
    else
      echo "ok $path ${width}x${height}"
    fi
  fi
done

for path in "$references_dir"/desktop-*.png; do
  if [ "$path" = "$references_dir/desktop-*.png" ]; then
    continue
  fi
  name=$(basename "$path" .png)
  if ! printf '%s\n' $required | rg -q "^$name$"; then
    echo "unexpected desktop PNG $path"
    status=1
  fi
done

exit "$status"
