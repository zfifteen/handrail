#!/bin/sh
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

status=0

desktop_refs="desktop-chat-list desktop-new-chat desktop-active-thread desktop-running-thinking desktop-approval-required desktop-approval-result desktop-file-artifact desktop-diff-artifact desktop-error desktop-search desktop-settings-menu"
clone_matrix_ids="unpaired-first-launch qr-pairing pairing-success paired-chat-list empty-chat-list search-chats new-chat active-chat-thread completed-chat-thread focused-composer sending-input running-thinking stop-codex approval-required approve-flow deny-flow approval-result file-artifact diff-artifact error-state disconnected-mac reconnecting settings pairing-management local-network-help automations alerts-attention"
desktop_comparison_matrix_ids="paired-chat-list empty-chat-list search-chats new-chat active-chat-thread completed-chat-thread focused-composer sending-input running-thinking stop-codex approval-required approve-flow deny-flow approval-result file-artifact diff-artifact error-state disconnected-mac reconnecting settings automations alerts-attention"
comparison_review_simulator_shots="paired-chat-list empty-chat-list disconnected-mac reconnecting search-chats new-chat new-chat-project-menu approval-required-active-thread completed-chat-thread focused-composer running-thinking sending-input stop-codex approval-required approve-flow deny-flow approval-result deny-result diff-artifact error-state overflow-menu settings automations alerts-attention"
comparison_review_pairs="desktop-chat-list:paired-chat-list desktop-chat-list:empty-chat-list desktop-chat-list:disconnected-mac desktop-chat-list:reconnecting desktop-search:search-chats desktop-new-chat:new-chat desktop-new-chat:new-chat-project-menu desktop-active-thread:approval-required-active-thread desktop-active-thread:completed-chat-thread desktop-active-thread:focused-composer desktop-file-artifact:completed-chat-thread desktop-running-thinking:running-thinking desktop-running-thinking:sending-input desktop-running-thinking:stop-codex desktop-approval-required:approval-required desktop-approval-required:approve-flow desktop-approval-required:deny-flow desktop-approval-result:approval-result desktop-approval-result:deny-result desktop-diff-artifact:diff-artifact desktop-error:error-state desktop-settings-menu:overflow-menu desktop-settings-menu:settings desktop-settings-menu:automations desktop-settings-menu:alerts-attention"
simulator_shots="unpaired-first-launch empty-unpaired-first-launch empty-chat-list paired-chat-list search-chats new-chat new-chat-project-menu approval-required approval-required-active-thread approve-flow deny-flow approval-result deny-result diff-artifact completed-chat-thread running-thinking stop-codex error-state disconnected-mac overflow-menu settings pairing-management local-network-help alerts-attention automations reconnecting qr-pairing pairing-success focused-composer sending-input"
banned_pattern="\\.purple|Color\\.purple|TabView|Round |Files to change|Ready for follow-up|Send input|Codex is working"
product_expansion_pattern="(?i)cloud relay|hosted execution|cloud chat storage|\\blogin\\b|\\bpayment\\b|generic terminal|\\bssh\\b|\\bclaude\\b|\\bgemini\\b|\\bopencode\\b|\\bmulti-agent\\b|\\bnon-codex agents?\\b|direct file editing"
test_log="/Users/velocityworks/Library/Developer/XcodeBuildMCP/workspaces/handrail-146601e045e5/logs/test_sim_2026-05-08T20-27-02-371Z_pid56442_2d382629.log"
build_run_log="/Users/velocityworks/Library/Developer/XcodeBuildMCP/workspaces/handrail-146601e045e5/logs/build_run_sim_2026-05-08T20-53-16-451Z_pid56442_a912b1db.log"
root_view="ios/Handrail/Handrail/Views/RootView.swift"
chats_view="ios/Handrail/Handrail/Views/ChatsView.swift"
mockup_board="docs/design/phase-1-codex-clone-mockups/index.html"
readme="docs/design/phase-1-codex-clone-mockups/README.md"
implementation_handoff="docs/design/phase-1-codex-clone-mockups/implementation-handoff.md"
completion_audit="docs/design/phase-1-codex-clone-mockups/completion-audit-20260508.md"
end_of_day_summary="docs/design/phase-1-codex-clone-mockups/end-of-day-summary-20260508.md"
clone_matrix="docs/design/phase-1-codex-clone-mockups/clone-matrix.md"
reference_manifest="docs/design/phase-1-codex-clone-mockups/reference-capture-manifest.md"
reference_blocker="docs/design/phase-1-codex-clone-mockups/references/BLOCKED.md"
desktop_reference_runbook="docs/design/phase-1-codex-clone-mockups/desktop-reference-capture-runbook.md"
comparison_map="docs/design/phase-1-codex-clone-mockups/reference-comparison-map.md"
comparison_review_template="docs/design/phase-1-codex-clone-mockups/reference-comparison-review.template.md"
desktop_reference_check="docs/design/phase-1-codex-clone-mockups/check-desktop-references.sh"
handoff_text_files="docs/design/phase-1-codex-clone-mockups/README.md docs/design/phase-1-codex-clone-mockups/check-desktop-references.sh docs/design/phase-1-codex-clone-mockups/clone-matrix.md docs/design/phase-1-codex-clone-mockups/completion-audit-20260508.md docs/design/phase-1-codex-clone-mockups/desktop-reference-capture-runbook.md docs/design/phase-1-codex-clone-mockups/end-of-day-summary-20260508.md docs/design/phase-1-codex-clone-mockups/focused-composer-keyboard-waiver.md docs/design/phase-1-codex-clone-mockups/focused-composer-keyboard-waiver.template.md docs/design/phase-1-codex-clone-mockups/implementation-audit-20260508.md docs/design/phase-1-codex-clone-mockups/implementation-handoff.md docs/design/phase-1-codex-clone-mockups/index.html docs/design/phase-1-codex-clone-mockups/qc-checklist.md docs/design/phase-1-codex-clone-mockups/reference-capture-manifest.md docs/design/phase-1-codex-clone-mockups/reference-comparison-map.md docs/design/phase-1-codex-clone-mockups/reference-comparison-review.template.md docs/design/phase-1-codex-clone-mockups/references/BLOCKED.md docs/design/phase-1-codex-clone-mockups/verify-evidence.sh"

if [ ! -x "docs/design/phase-1-codex-clone-mockups/verify-evidence.sh" ]; then
  echo "verify-evidence.sh is not executable"
  status=1
fi
if [ ! -x "$desktop_reference_check" ]; then
  echo "check-desktop-references.sh is not executable"
  status=1
fi
if ! rg -q "check-desktop-references\\.sh" "$readme"; then
  echo "README missing check-desktop-references.sh unblock step"
  status=1
fi
if ! rg -q "verify-evidence\\.sh" "$readme"; then
  echo "README missing verify-evidence.sh final gate"
  status=1
fi
if ! rg -q "implementation-handoff\\.md" "$readme"; then
  echo "README missing implementation-handoff.md artifact entry"
  status=1
fi
if ! rg -q "Completion Audit Against Objective 2026-05-08 22:20 EDT" "$readme"; then
  echo "README missing latest completion audit entrypoint"
  status=1
fi
if ! rg -q "end-of-day-summary-20260508\\.md" "$readme"; then
  echo "README missing end-of-day summary entrypoint"
  status=1
fi
if ! rg -q "^## Completion Audit Against Objective 2026-05-08 22:20 EDT$" "$completion_audit"; then
  echo "completion audit missing latest objective audit section"
  status=1
fi
if ! rg -q "^## Next Session First Action$" "$end_of_day_summary"; then
  echo "end-of-day summary missing next-session first action"
  status=1
fi
if ! rg -q "check-desktop-references\\.sh" "$end_of_day_summary"; then
  echo "end-of-day summary missing desktop-reference validator command"
  status=1
fi
if ! rg -q "verify-evidence\\.sh" "$end_of_day_summary"; then
  echo "end-of-day summary missing final verifier command"
  status=1
fi
if ! rg -q "check-desktop-references\\.sh" "$reference_blocker"; then
  echo "references/BLOCKED.md missing check-desktop-references.sh unblock step"
  status=1
fi
if ! rg -q "verify-evidence\\.sh" "$reference_blocker"; then
  echo "references/BLOCKED.md missing verify-evidence.sh final gate"
  status=1
fi
if ! rg -q "Completion Audit Against Objective 2026-05-08 22:20 EDT" "$reference_blocker"; then
  echo "references/BLOCKED.md missing latest completion audit entrypoint"
  status=1
fi
if ! rg -q "check-desktop-references\\.sh" "$reference_manifest"; then
  echo "reference-capture-manifest.md missing check-desktop-references.sh capture-status gate"
  status=1
fi
if ! rg -q "2026-05-08 22:20 EDT completion audit" "$reference_manifest"; then
  echo "reference-capture-manifest.md missing latest completion audit status text"
  status=1
fi
if ! rg -q "2026-05-08 22:20 EDT completion audit" "$clone_matrix"; then
  echo "clone-matrix.md missing latest completion audit status text"
  status=1
fi
if ! rg -q "check-desktop-references\\.sh" "$implementation_handoff"; then
  echo "implementation-handoff.md missing check-desktop-references.sh evidence"
  status=1
fi
if ! rg -q "references/BLOCKED\\.md" "$implementation_handoff"; then
  echo "implementation-handoff.md missing references/BLOCKED.md blocker evidence"
  status=1
fi
if ! rg -q "test-artifacts/phase-1-codex-clone-20260508/" "$implementation_handoff"; then
  echo "implementation-handoff.md missing simulator screenshot evidence directory"
  status=1
fi
if ! rg -q "Completion Audit Against Objective 2026-05-08 22:20 EDT" "$implementation_handoff"; then
  echo "implementation-handoff.md missing latest completion audit entrypoint"
  status=1
fi
if ! rg -q "end-of-day-summary-20260508\\.md" "$implementation_handoff"; then
  echo "implementation-handoff.md missing end-of-day summary entrypoint"
  status=1
fi
if rg -q "21:53 EDT" "$readme" "$implementation_handoff" "$clone_matrix" "$reference_manifest"; then
  echo "active handoff docs contain stale 21:53 EDT status text"
  status=1
fi
desktop_reference_check_refs=$(awk -F'"' '/^required="/ { print $2 }' "$desktop_reference_check")
for name in $desktop_refs; do
  if ! printf '%s\n' $desktop_reference_check_refs | rg -q "^$name$"; then
    echo "check-desktop-references.sh missing required desktop reference $name"
    status=1
  fi
done
for name in $desktop_reference_check_refs; do
  if ! printf '%s\n' $desktop_refs | rg -q "^$name$"; then
    echo "check-desktop-references.sh contains unexpected desktop reference $name"
    status=1
  fi
done

for name in $desktop_refs; do
  if ! rg -q "^\| $name \|" "$reference_manifest"; then
    echo "missing reference manifest row for $name"
    status=1
  fi

  ref_path="docs/design/phase-1-codex-clone-mockups/references/$name.png"
  if [ ! -f "$ref_path" ]; then
    echo "missing references/$name.png"
    status=1
  elif ! file "$ref_path" | rg -q "PNG image data"; then
    echo "invalid PNG reference references/$name.png"
    status=1
  else
    ref_width=$(sips -g pixelWidth "$ref_path" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    ref_height=$(sips -g pixelHeight "$ref_path" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    if ! printf '%s\n' "$ref_width" | rg -q '^[0-9]+$' || ! printf '%s\n' "$ref_height" | rg -q '^[0-9]+$' || [ "$ref_width" -le 0 ] || [ "$ref_height" -le 0 ]; then
      echo "unreadable PNG reference dimensions references/$name.png"
      status=1
    fi
  fi

  if ! rg -q "references/$name\\.png" "$comparison_map"; then
    echo "missing comparison map entry for references/$name.png"
    status=1
  fi
  if ! rg -q "references/$name\\.png" "$comparison_review_template"; then
    echo "missing comparison review template input for references/$name.png"
    status=1
  fi
  if ! rg -q "$name\\.png" "$desktop_reference_runbook"; then
    echo "missing desktop reference runbook entry for $name.png"
    status=1
  fi
  if ! rg -q "$name\\.png" "$reference_blocker"; then
    echo "missing references/BLOCKED.md unblock entry for $name.png"
    status=1
  fi
done

reference_pngs_from_directory=$(find docs/design/phase-1-codex-clone-mockups/references -maxdepth 1 -type f -name 'desktop-*.png' -exec basename {} .png \; | sort)
for name in $reference_pngs_from_directory; do
  if ! printf '%s\n' $desktop_refs | rg -q "^$name$"; then
    echo "references directory contains unexpected desktop PNG: $name.png"
    status=1
  fi
done

manifest_refs_from_file=$(awk -F'|' '{ gsub(/^ +| +$/, "", $2); if ($2 ~ /^desktop-/) print $2 }' "$reference_manifest")
for name in $manifest_refs_from_file; do
  if ! printf '%s\n' $desktop_refs | rg -q "^$name$"; then
    echo "reference manifest row missing from verifier list: $name"
    status=1
  fi
done

for name in $comparison_review_simulator_shots; do
  if ! rg -q "test-artifacts/phase-1-codex-clone-20260508/$name\\.jpg" "$comparison_map"; then
    echo "comparison review simulator input missing from comparison map $name.jpg"
    status=1
  fi
  if ! rg -q "test-artifacts/phase-1-codex-clone-20260508/$name\\.jpg" "$comparison_review_template"; then
    echo "missing comparison review template input for simulator evidence $name.jpg"
    status=1
  fi
done
for pair in $comparison_review_pairs; do
  desktop_name=${pair%:*}
  simulator_name=${pair#*:}
  if ! rg -q "references/$desktop_name\\.png.*$simulator_name\\.jpg" "$comparison_map"; then
    echo "comparison map missing mapped pair references/$desktop_name.png -> $simulator_name.jpg"
    status=1
  fi
  if ! rg -q "references/$desktop_name\\.png.*$simulator_name\\.jpg" "$comparison_review_template"; then
    echo "comparison review template missing mapped pair references/$desktop_name.png -> $simulator_name.jpg"
    status=1
  fi
done
comparison_map_pairs_from_file=$(awk -F'|' '
  $2 ~ /references\/desktop-.*\.png/ && $3 ~ /\.jpg/ {
    desktop=$2
    simulator=$3
    gsub(/`/, "", desktop)
    gsub(/`/, "", simulator)
    gsub(/^ +| +$/, "", desktop)
    gsub(/^ +| +$/, "", simulator)
    sub(/^references\//, "", desktop)
    sub(/\.png$/, "", desktop)
    sub(/^.*\//, "", simulator)
    sub(/\.jpg$/, "", simulator)
    print desktop ":" simulator
  }
' "$comparison_map" | sort -u)
for pair in $comparison_map_pairs_from_file; do
  if ! printf '%s\n' $comparison_review_pairs | rg -q "^$pair$"; then
    echo "comparison map contains unexpected mapped pair $pair"
    status=1
  fi
done
comparison_review_template_pairs_from_file=$(awk -F'|' '
  $2 ~ /references\/desktop-.*\.png/ && $3 ~ /\.jpg/ {
    desktop=$2
    simulator=$3
    gsub(/`/, "", desktop)
    gsub(/`/, "", simulator)
    gsub(/^ +| +$/, "", desktop)
    gsub(/^ +| +$/, "", simulator)
    sub(/^references\//, "", desktop)
    sub(/\.png$/, "", desktop)
    sub(/^.*\//, "", simulator)
    sub(/\.jpg$/, "", simulator)
    print desktop ":" simulator
  }
' "$comparison_review_template" | sort -u)
for pair in $comparison_review_template_pairs_from_file; do
  if ! printf '%s\n' $comparison_review_pairs | rg -q "^$pair$"; then
    echo "comparison review template contains unexpected mapped pair $pair"
    status=1
  fi
done

if ! rg -q "reference-comparison-map.md" "$comparison_review_template"; then
  echo "comparison review template missing comparison map input"
  status=1
fi
if ! rg -q "index.html" "$comparison_review_template"; then
  echo "comparison review template missing mockup board input"
  status=1
fi
if ! rg -q "clone-matrix.md" "$comparison_review_template"; then
  echo "comparison review template missing clone matrix input"
  status=1
fi
if ! rg -q "qc-checklist.md" "$comparison_review_template"; then
  echo "comparison review template missing QC checklist input"
  status=1
fi

comparison_map_refs_from_file=$(rg -o "references/desktop-[a-z-]+\\.png" "$comparison_map" | sed 's|references/||; s|\.png||' | sort -u)
for name in $comparison_map_refs_from_file; do
  if ! printf '%s\n' $desktop_refs | rg -q "^$name$"; then
    echo "comparison map desktop reference missing from verifier list: $name"
    status=1
  fi
done

comparison_map_simulator_shots_from_file=$(rg -o "test-artifacts/phase-1-codex-clone-20260508/[a-z-]+\\.jpg" "$comparison_map" | sed 's|test-artifacts/phase-1-codex-clone-20260508/||; s|\.jpg||' | sort -u)
for name in $comparison_map_simulator_shots_from_file; do
  if ! printf '%s\n' $comparison_review_simulator_shots | rg -q "^$name$"; then
    echo "comparison map simulator evidence missing from verifier list: $name.jpg"
    status=1
  fi
done

for name in $simulator_shots; do
  shot_path="test-artifacts/phase-1-codex-clone-20260508/$name.jpg"
  if [ ! -f "$shot_path" ]; then
    echo "missing test-artifacts/phase-1-codex-clone-20260508/$name.jpg"
    status=1
  elif ! file "$shot_path" | rg -q "JPEG image data"; then
    echo "invalid JPEG simulator screenshot test-artifacts/phase-1-codex-clone-20260508/$name.jpg"
    status=1
  else
    shot_width=$(sips -g pixelWidth "$shot_path" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    shot_height=$(sips -g pixelHeight "$shot_path" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    if [ "$shot_width" != "368" ] || [ "$shot_height" != "800" ]; then
      echo "unexpected simulator screenshot dimensions test-artifacts/phase-1-codex-clone-20260508/$name.jpg ${shot_width}x${shot_height}"
      status=1
    fi
  fi
done

for matrix_id in $clone_matrix_ids; do
  case "$matrix_id" in
    active-chat-thread)
      matrix_shot="approval-required-active-thread"
      ;;
    file-artifact)
      matrix_shot="completed-chat-thread"
      ;;
    *)
      matrix_shot="$matrix_id"
      ;;
  esac

  if ! printf '%s\n' $simulator_shots | rg -q "^$matrix_shot$"; then
    echo "missing simulator verifier entry for clone matrix row $matrix_id"
    status=1
  fi
  if [ ! -f "test-artifacts/phase-1-codex-clone-20260508/$matrix_shot.jpg" ]; then
    echo "missing simulator evidence for clone matrix row $matrix_id"
    status=1
  fi
  if ! rg -q "id=\"$matrix_id\"" "$mockup_board"; then
    echo "missing mockup board section for clone matrix row $matrix_id"
    status=1
  fi

  if printf '%s\n' $desktop_comparison_matrix_ids | rg -q "^$matrix_id$" && ! rg -q "$matrix_shot\\.jpg" "$comparison_map"; then
    echo "missing comparison map simulator evidence for clone matrix row $matrix_id"
    status=1
  fi
done

clone_matrix_ids_from_file=$(awk -F'|' '$3 ~ /`/ { gsub(/`/, "", $3); gsub(/^ +| +$/, "", $3); if ($3 != "") print $3 }' "$clone_matrix")
for matrix_id in $clone_matrix_ids_from_file; do
  if ! printf '%s\n' $clone_matrix_ids | rg -q "^$matrix_id$"; then
    echo "clone matrix row missing from verifier list: $matrix_id"
    status=1
  fi
done
for matrix_id in $clone_matrix_ids; do
  if ! printf '%s\n' $clone_matrix_ids_from_file | rg -q "^$matrix_id$"; then
    echo "verifier clone matrix id missing from clone matrix: $matrix_id"
    status=1
  fi
done

keyboard_shot="test-artifacts/phase-1-codex-clone-20260508/focused-composer-keyboard.jpg"
keyboard_waiver="docs/design/phase-1-codex-clone-mockups/focused-composer-keyboard-waiver.md"
if [ -f "$keyboard_shot" ]; then
  if ! file "$keyboard_shot" | rg -q "JPEG image data"; then
    echo "invalid focused composer keyboard screenshot"
    status=1
  else
    keyboard_width=$(sips -g pixelWidth "$keyboard_shot" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    keyboard_height=$(sips -g pixelHeight "$keyboard_shot" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    if [ "$keyboard_width" != "368" ] || [ "$keyboard_height" != "800" ]; then
      echo "unexpected focused composer keyboard screenshot dimensions ${keyboard_width}x${keyboard_height}"
      status=1
    fi
  fi
elif [ -f "$keyboard_waiver" ]; then
  if ! rg -q "^Decision: Waive the focused-composer visible software-keyboard screenshot requirement for Phase 1\\.$" "$keyboard_waiver"; then
    echo "focused composer keyboard waiver missing explicit decision"
    status=1
  fi
  if ! rg -q "^Name: [^ ].*$" "$keyboard_waiver"; then
    echo "focused composer keyboard waiver missing reviewer name"
    status=1
  fi
  if ! rg -q "^Date: [^ ].*$" "$keyboard_waiver"; then
    echo "focused composer keyboard waiver missing reviewer date"
    status=1
  fi
  if rg -q "^State the concrete reason the screenshot is not required\\.$" "$keyboard_waiver"; then
    echo "focused composer keyboard waiver still contains template reason placeholder"
    status=1
  fi
  waiver_reason=$(awk '
    /^## Reason$/ { in_reason=1; next }
    /^## / { in_reason=0 }
    in_reason && NF { print }
  ' "$keyboard_waiver" | rg -v "^State the concrete reason the screenshot is not required\\.$" || true)
  if [ -z "$waiver_reason" ]; then
    echo "focused composer keyboard waiver missing concrete reason"
    status=1
  fi
  if ! rg -q "test-artifacts/phase-1-codex-clone-20260508/focused-composer\\.jpg" "$keyboard_waiver"; then
    echo "focused composer keyboard waiver missing existing focused-composer evidence input"
    status=1
  fi
  if rg -q "Do not rename this template|The completed waiver must" "$keyboard_waiver"; then
    echo "focused composer keyboard waiver still contains template instructions"
    status=1
  fi
else
  echo "missing focused composer keyboard evidence or waiver"
  status=1
fi

comparison_review="docs/design/phase-1-codex-clone-mockups/reference-comparison-review.md"
if [ ! -f "$comparison_review" ]; then
  echo "missing reference comparison review"
  status=1
elif ! rg -q "^Decision: PASS\\.$" "$comparison_review"; then
  echo "reference comparison review missing PASS decision"
  status=1
elif ! rg -q "^QC hard rejection review: PASS\\.$" "$comparison_review"; then
  echo "reference comparison review missing QC hard rejection PASS"
  status=1
else
  if ! rg -q "^Reviewer: [^ ].*$" "$comparison_review"; then
    echo "reference comparison review missing reviewer"
    status=1
  fi
  if ! rg -q "^Date: [^ ].*$" "$comparison_review"; then
    echo "reference comparison review missing date"
    status=1
  fi
  if rg -q "^- $" "$comparison_review"; then
    echo "reference comparison review still contains blank template bullets"
    status=1
  fi
  review_findings=$(awk '
    /^Findings:$/ { in_findings=1; next }
    /^Required corrections:$/ { in_findings=0 }
    in_findings && NF { print }
  ' "$comparison_review" | rg -v "^- $" || true)
  if [ -z "$review_findings" ]; then
    echo "reference comparison review missing findings content"
    status=1
  fi
  review_corrections=$(awk '
    /^Required corrections:$/ { in_corrections=1; next }
    in_corrections && NF { print }
  ' "$comparison_review" | rg -v "^- $" || true)
  if [ -z "$review_corrections" ]; then
    echo "reference comparison review missing required corrections content"
    status=1
  fi
  if rg -q '^\| `references/desktop-[^`]+\.png` \| `[^`]+\.jpg` \| [^|]+ \| *\|$' "$comparison_review"; then
    echo "reference comparison review has blank comparison result cells"
    status=1
  fi
  if awk -F'|' '$2 ~ /references\/desktop-.*\.png/ && $3 ~ /\.jpg/ { result=$5; gsub(/^ +| +$/, "", result); if (result != "PASS") print }' "$comparison_review" >/tmp/handrail-phase-1-review-non-pass-results.txt && [ -s /tmp/handrail-phase-1-review-non-pass-results.txt ]; then
    echo "reference comparison review has non-PASS comparison result cells"
    cat /tmp/handrail-phase-1-review-non-pass-results.txt
    status=1
  fi
  if rg -q "Do not rename this template|The completed review must|Use exactly|Each mapped row must|Replace with concrete" "$comparison_review"; then
    echo "reference comparison review still contains template instructions"
    status=1
  fi
  if ! rg -q "reference-comparison-map.md" "$comparison_review"; then
    echo "reference comparison review missing comparison map input"
    status=1
  fi
  if ! rg -q "index.html" "$comparison_review"; then
    echo "reference comparison review missing mockup board input"
    status=1
  fi
  if ! rg -q "clone-matrix.md" "$comparison_review"; then
    echo "reference comparison review missing clone matrix input"
    status=1
  fi
  if ! rg -q "qc-checklist.md" "$comparison_review"; then
    echo "reference comparison review missing QC checklist input"
    status=1
  fi
  for name in $desktop_refs; do
    if ! rg -q "references/$name\\.png" "$comparison_review"; then
      echo "reference comparison review missing input references/$name.png"
      status=1
    fi
  done
  for name in $comparison_review_simulator_shots; do
    if ! rg -q "test-artifacts/phase-1-codex-clone-20260508/$name\\.jpg" "$comparison_review"; then
      echo "reference comparison review missing simulator input $name.jpg"
      status=1
    fi
  done
  for pair in $comparison_review_pairs; do
    desktop_name=${pair%:*}
    simulator_name=${pair#*:}
    if ! rg -q "references/$desktop_name\\.png.*$simulator_name\\.jpg" "$comparison_review"; then
      echo "reference comparison review missing mapped pair references/$desktop_name.png -> $simulator_name.jpg"
      status=1
    fi
  done
  comparison_review_pairs_from_file=$(awk -F'|' '
    $2 ~ /references\/desktop-.*\.png/ && $3 ~ /\.jpg/ {
      desktop=$2
      simulator=$3
      gsub(/`/, "", desktop)
      gsub(/`/, "", simulator)
      gsub(/^ +| +$/, "", desktop)
      gsub(/^ +| +$/, "", simulator)
      sub(/^references\//, "", desktop)
      sub(/\.png$/, "", desktop)
      sub(/^.*\//, "", simulator)
      sub(/\.jpg$/, "", simulator)
      print desktop ":" simulator
    }
  ' "$comparison_review" | sort -u)
  for pair in $comparison_review_pairs_from_file; do
    if ! printf '%s\n' $comparison_review_pairs | rg -q "^$pair$"; then
      echo "reference comparison review contains unexpected mapped pair $pair"
      status=1
    fi
  done
fi

if rg -n "$banned_pattern" ios/Handrail/Handrail/Views ios/Handrail/HandrailTests -S >/tmp/handrail-phase-1-static-drift.txt; then
  echo "static banned UI drift found"
  cat /tmp/handrail-phase-1-static-drift.txt
  status=1
fi

if rg -n "$product_expansion_pattern" ios/Handrail/Handrail ios/Handrail/HandrailTests cli/src cli/test -S | rg -v "does not use a cloud relay" >/tmp/handrail-phase-1-product-expansion.txt; then
  echo "product expansion drift found"
  cat /tmp/handrail-phase-1-product-expansion.txt
  status=1
fi

if ! rg -q "struct PhoneRootView: View" "$root_view"; then
  echo "missing PhoneRootView in RootView.swift"
  status=1
fi
if ! rg -q 'NavigationStack\(path: \$path\)' "$root_view"; then
  echo "PhoneRootView does not use NavigationStack(path:)"
  status=1
fi
if ! rg -q "ChatsView \\{ chatId in" "$root_view"; then
  echo "PhoneRootView does not enter ChatsView directly"
  status=1
fi
if rg -n "TabView|DashboardView" "$root_view" >/tmp/handrail-phase-1-root-drift.txt; then
  echo "RootView contains rejected phone root surface"
  cat /tmp/handrail-phase-1-root-drift.txt
  status=1
fi

if ! rg -q 'NewChatProject\(id: "no-project", name: "No project", path: nil\)' "$chats_view"; then
  echo "NewChatView does not define No project option"
  status=1
fi
if ! rg -q 'return \[noProject\] \+ optionProjects' "$chats_view"; then
  echo "NewChatView does not prepend No project when server projects omit it"
  status=1
fi
if ! rg -Fq 'projects.first { $0.id == id }?.name ?? id' "$chats_view"; then
  echo "NewChat project menu does not display project names"
  status=1
fi

if rg -n "^\|.*(REFERENCE BLOCKED|SIMULATOR WEAK)" "$clone_matrix" >/tmp/handrail-phase-1-clone-matrix-blocked.txt; then
  echo "clone matrix still has REFERENCE BLOCKED or SIMULATOR WEAK rows"
  cat /tmp/handrail-phase-1-clone-matrix-blocked.txt
  status=1
fi
if awk -F'|' '$3 ~ /`/ { qc=$8; gsub(/^ +| +$/, "", qc); if (qc != "" && qc !~ /PASS/) print NR ":" $0 }' "$clone_matrix" >/tmp/handrail-phase-1-clone-matrix-not-pass.txt && [ -s /tmp/handrail-phase-1-clone-matrix-not-pass.txt ]; then
  echo "clone matrix has rows without PASS in QC Status"
  cat /tmp/handrail-phase-1-clone-matrix-not-pass.txt
  status=1
fi

for name in $desktop_refs; do
  manifest_status=$(awk -F'|' -v id="$name" '{ ref=$2; gsub(/^ +| +$/, "", ref); if (ref == id) { status=$4; gsub(/^ +| +$/, "", status); print status } }' "$reference_manifest")
  if [ "$manifest_status" != "Captured" ]; then
    echo "reference manifest row not marked Captured for $name"
    status=1
  fi
done

for text_file in $handoff_text_files; do
  if perl -ne 'if (/\r\n?/) { exit 1 }' "$text_file"; then
    :
  else
    echo "CRLF or CR line ending found in $text_file"
    status=1
  fi
done

for text_file in "$keyboard_waiver" "$comparison_review"; do
  if [ -f "$text_file" ]; then
    if perl -ne 'if (/\r\n?/) { exit 1 }' "$text_file"; then
      :
    else
      echo "CRLF or CR line ending found in $text_file"
      status=1
    fi
  fi
done

if [ ! -f "$test_log" ]; then
  echo "missing test log $test_log"
  status=1
else
  passed_count=$(rg -c "^Test case '.*' passed" "$test_log")
  if [ "$passed_count" != "52" ]; then
    echo "expected 52 passed test cases in test log, found $passed_count"
    status=1
  fi
  if ! rg -q "\*\* TEST EXECUTE SUCCEEDED \*\*" "$test_log"; then
    echo "missing TEST EXECUTE SUCCEEDED in test log"
    status=1
  fi
  if rg -n "failed|Failing|FAILED|Testing failed" "$test_log" >/tmp/handrail-phase-1-test-failures.txt; then
    echo "test log contains failure text"
    cat /tmp/handrail-phase-1-test-failures.txt
    status=1
  fi
fi

if [ ! -f "$build_run_log" ]; then
  echo "missing build/run log $build_run_log"
  status=1
else
  if ! rg -q "\*\* BUILD SUCCEEDED \*\*" "$build_run_log"; then
    echo "missing BUILD SUCCEEDED in build/run log"
    status=1
  fi
  if rg -n "FAILED|error:" "$build_run_log" >/tmp/handrail-phase-1-build-run-failures.txt; then
    echo "build/run log contains failure text"
    cat /tmp/handrail-phase-1-build-run-failures.txt
    status=1
  fi
fi

exit "$status"
