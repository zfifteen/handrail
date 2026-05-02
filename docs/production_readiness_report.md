# Handrail Production Readiness Evaluation
**Prepared:** 2026-04-30  
**Repo:** github.com/zfifteen/handrail  
**Target:** Apple App Store — iOS (iPhone), watchOS, iPad  
**Audience:** Codex instance for action

---

## Executive Summary

Handrail is not production-ready for App Store submission across any of its three target platforms. The iPhone app is now blocked by submission evidence rather than known open iPhone UI/reliability bugs: milestone 1 has 2 open artifact/provisioning issues and 12 closed readiness issues. The iPad app has a working split-view surface, but the remaining visible iPad validation is blocked upstream by first-class approval-routing evidence. The watchOS app has zero implementation, and issue #5 is now labeled `blocked` because its acceptance plan requires paired iPhone + Apple Watch hardware evidence. The report below assigns each gap a priority tier and states the concrete action required.

**Overall Readiness by Platform:**

| Platform | Implementation | Known Open Bugs | App Store Blockers | Status |
|---|---|---|---|---|
| iOS (iPhone) | Feature-complete MVP | 0 known open iPhone UI/reliability bugs in milestone 1 | 2 evidence blockers | NOT READY |
| iPad | Partial split-view workspace | 1 validation-gated bug + 1 open product spec | 2 milestone blockers plus upstream Desktop approval blocker #2 | NOT READY |
| watchOS | None (spec only) | N/A | All; blocked on paired Apple Watch acceptance path | BLOCKED |

## App Store Readiness State Refresh - 2026-05-02 11:08Z

GitHub is now the source of truth for issue state. Milestone 1, `iPhone App Store readiness`, has 2 open issues and 12 closed issues after the 2026-05-02 Lead Dev run and PM reconciliation.

Closed in milestone 1 since this report was prepared:

- #4 Show Codex Desktop thinking messages in iOS.
- #7 Dashboard header actions are missing from the accessibility tree.
- #8 Custom tab bar items are not individually accessible.
- #9 Refresh control announces the sync status instead of the action.
- #10 Notification is shown for the chat currently open in iOS.
- #11 Custom tab bar overlays lower content on Dashboard and Chats.
- #12 Project-grouped Chats shows raw slug identifiers instead of project names.
- #16 Reconnect or report when chat detail refresh is requested offline.
- #18 Surface unknown server message types instead of silently ignoring them.
- #19 Report corrupt stored pairing metadata.
- #26 Hosted privacy policy URL.
- #27 Clear stale global errors when opening New Chat or Chat Detail.

Closed related reliability issues outside the active milestone:

- #14 Preserve chat detail fields when `chat_list` refreshes.
- #15 Treat WebSocket send failure as a disconnect.
- #20 iPad: `chat_list` overwrites detail-only chat state.

Open iPhone readiness scope:

- #25 Release APNs entitlement verification. Source entitlements are correct, but the signed Release archive cannot be produced locally because the available automatic profile for `com.velocityworks.Handrail` expired on May 2, 2026 and lacks Push Notifications plus `aps-environment`. No installed `.mobileprovision` profile is present under `~/Library/MobileDevice/Provisioning Profiles`.
- #28 iPhone metadata and screenshot package. Listing copy exists at `store-assets/metadata.txt`, the support URL points at the public GitHub issue tracker, the privacy URL points at the public GitHub-rendered policy, and the marketing URL is deliberately omitted for v1. Draft iPhone 17 live screenshots now exist under `store-assets/screenshots/iphone/` for Dashboard, Chats list, Chat Detail, and New Chat. #28 is now labeled `blocked` because final 6.9-inch App Store screenshot-class captures require either a paired iPhone 17 Pro Max simulator/device state or XcodeBuildMCP running with the LLDB CLI backend to seed the app container without product code changes. Approval-response copy and the approval screenshot are deferred until #2 has first-class approval-routing evidence.

The next shippable release remains blocked until milestone 1 is closed with CLI test evidence and iPhone simulator validation for every affected visible flow. iPad stabilization, Desktop protocol hardening beyond #18, and watchOS remain separate milestones.

## iPad Stabilization State Refresh - 2026-05-02 16:15Z

Milestone 2, `iPad MVP stabilization`, has 2 open issues and 4 closed issues after the 2026-05-02 Lead Dev run. The live `start_chat` path now provides closure evidence for #21 and #22. Both remaining open issues are now labeled `blocked`: #24 is blocked by #2 live first-class approval evidence, and #6 is blocked by #24 because umbrella iPad acceptance requires a full walkthrough after the approval-row evidence exists.

Closed in milestone 2:

- #17 Navigate from iPad activity rows to selected chat detail.
- #21 New Chat sheet never closes on success.
- #22 Activity rows set a hidden chat selection.
- #23 iPad chat routing leaves stale approval selection alive.

Open iPad stabilization scope:

- #6 Product spec: iPad Handrail version. This remains the umbrella product acceptance issue for the iPad surface; it should not be closed by individual bug fixes alone. It is now labeled `blocked` until #24 has real iPad simulator evidence for a live `waiting_for_approval` row and the full iPad walkthrough can be performed without fixture-only state.
- #24 Waiting approvals look like running chats on Dashboard. Current iPad code path is reported fixed; #29 can now produce a live started chat, but closure still depends on #2 for first-class approval ingestion/routing.

The strongest current iPad finding is that #21 and #22 are closed with live iPad simulator evidence. A real New Chat start dismissed the popover, switched to Chats, and selected the started chat in detail for #21. A live chat-linked Activity row switched from Activity to Chats and selected the same chat detail for #22. #24 still depends on #2 making approval state first-class enough to validate `waiting_for_approval` behavior. Do not broaden product code with test-only launch state to close the remaining iPad issue; use a real simulator-connected local Handrail feed that naturally contains the needed approval state.

## Lead Dev Scope Refresh - 2026-05-02 06:07Z

#29 is closed. The live Handrail listener on `127.0.0.1:8788` was restarted from stale PID `16041` to PID `70040` using LaunchAgent `com.velocityworks.handrail.server`. A real `start_chat` through the live server emitted `chat_started`, emitted a chat-linked `chat_event`, refreshed `chat_list`, and appeared in `node cli/dist/src/index.js chats` as Desktop-visible chat `codex:019de74b-9e6e-71e1-a6e1-14028304e776`. Evidence is in `test-artifacts/issue29-resolve-20260502T060625Z/`.

The iPhone App Store metadata package no longer claims approval-response support for v1. `store-assets/metadata.txt` and `store-assets/screenshot-plan.md` now defer the approval screenshot until #2 has first-class Desktop approval request IDs. This keeps milestone 1 focused on submission evidence instead of silently adding #2 to the iPhone release gate through marketing copy.

## Lead Dev Approval Routing Refresh - 2026-05-02 14:45Z

#2 now has a code-level first-class approval route for Handrail-started app-server turns. The CLI accepts Codex app-server `item/commandExecution/requestApproval` and `item/fileChange/requestApproval` server requests, exposes the app-server request id as Handrail `approvalId`, marks the matching `codex:` chat as `waiting_for_approval` while pending, and sends iOS approve/deny decisions back as app-server `accept`/`decline` responses on the same request id. Verification: `cd cli && npm test` passed 42/42.

The issue remains open and is now labeled `blocked` for live evidence. The local LaunchAgent still needs a permitted restart before the running server can expose the rebuilt `cli/dist`; `launchctl kickstart -k gui/501/com.velocityworks.handrail.server` returned `Operation not permitted` and listener PID `4657` did not change. #24 still needs simulator evidence from a real live `waiting_for_approval` row before closure.

## Lead Dev Live App-server Event Refresh - 2026-05-02 15:44Z

#3 is now implemented at the CLI protocol layer for Handrail-started app-server turns. The retained Codex app-server connection maps observed `turn/started`, `turn/completed`, and `item/agentMessage/delta` notifications into Handrail `chat_event` messages, overlays live status on the Desktop-visible `codex:` chat row, and broadcasts refreshed `chat_list` state without creating mobile-only chats. Verification: `cd cli && npm test` passed 44/44.

Milestone 3 now has one open issue: #2. #3 is closed with deterministic CLI test evidence. #2 has code-level approval request-id routing but remains blocked for live evidence until the running server can expose the rebuilt CLI and a real approval request can be captured through iPad simulator validation.

## PM Milestone Reconciliation - 2026-05-02 11:08Z

Milestone descriptions were reconciled to match the current GitHub issue state:

- Milestone 1, `iPhone App Store readiness`, is now narrowed to #25 and #28. #25 is blocked on a non-expired APNs-capable distribution/TestFlight/App Store profile; #28 is narrowed to four required iPhone screenshots because #26 closed with a public privacy policy URL.
- Milestone 2, `iPad MVP stabilization`, is now narrowed to blocked umbrella acceptance issue #6 plus blocked approval-row evidence issue #24. #21 and #22 are closed with live iPad simulator evidence. #24 remains blocked by #2 because the live feed still lacks first-class `waiting_for_approval` state.
- Milestone 3, `Desktop protocol hardening`, is now narrowed to blocked #2. #29 and #3 are closed, so the remaining Desktop protocol blocker is live first-class approval request evidence.

No GitHub release exists yet, and no release should be created until the relevant milestone is closed with recorded CLI and required simulator/device evidence.

## watchOS Companion State Refresh - 2026-05-02 17:46Z

Milestone 4, `watchOS companion`, has one open issue: #5. It is now labeled `blocked` because the acceptance criteria require WatchConnectivity delivery on paired iPhone + Apple Watch hardware, while the current local environment has no usable watch acceptance path.

Current evidence:

- `xcodebuild -list -project ios/Handrail/Handrail.xcodeproj` lists only `Handrail` and `HandrailTests`; no watchOS target exists.
- `find ios/Handrail -maxdepth 3 -iname '*watch*' -o -iname '*Widget*'` found no watch or widget source files.
- `xcrun xctrace list devices` listed only the Mac and reported CoreSimulator access errors.
- `xcrun devicectl list devices` timed out waiting for CoreDeviceService to initialize.

The next watchOS action requires either a usable paired iPhone + Apple Watch hardware path, or an explicit product decision to accept a partial simulator/build-only watchOS implementation before hardware acceptance. Do not close #5 from simulator layout evidence alone.

## Lead Dev CI Hygiene Refresh - 2026-05-02 18:20Z

The repo now has a narrow GitHub Actions smoke workflow at `.github/workflows/ci.yml`. It runs `npm ci` plus `npm test` for the CLI and builds the `Handrail` app plus test bundle for iOS Simulator with signing disabled. This adds a review gate for normal code movement without pretending to solve the signed Release archive or App Store upload path. The workflow now uses read-only repository permissions and bounded job timeouts so smoke CI has a tighter execution contract. Distribution automation remains blocked until the Apple signing inputs in #25 exist.

## Lead Dev Repository Hygiene Refresh - 2026-05-02 21:25Z

The repository now has `.gitattributes` with LF normalization for text files plus explicit binary handling for common image, PDF, and video artifacts. This turns the local agent line-ending contract into a Git-level review guard for generated Markdown, JSONL, CSV, Swift, TypeScript, shell, and plain-text outputs without changing product behavior or CI scope.

---

## Part 1: App Store Hard Blockers

These items will cause Apple review rejection or provisioning failure regardless of feature completeness.

### 1.1 Release APNs Entitlement Requires Distribution Signing Verification

**File:** `ios/Handrail/Handrail/Handrail.entitlements`  
**Finding:** The source entitlement now sets `aps-environment` to `production`, and Release build settings point at `Handrail/Handrail.entitlements`. Final App Store evidence is still missing because the available automatic `iOS Team Provisioning Profile: com.velocityworks.Handrail` expired on May 2, 2026 and cannot sign a Release archive with Push Notifications or `aps-environment`.
**Action:** Build a Release archive with a distribution/TestFlight/App Store provisioning profile, then inspect the signed app with `codesign -d --entitlements :- <App.app>` and confirm `aps-environment` is `production`. Keep the Debug target's entitlement-stripping behavior (introduced 2026-04-29) intact so personal-team Debug builds remain installable.

### 1.2 No Paid Apple Developer Program Membership Confirmed

**Finding:** All device install attempts used a personal development team (`com.velocityworks.Handrail`). App Store submission requires an Apple Developer Program membership ($99/year). Push Notifications, HealthKit (if watchOS adds it), and distribution certificates all require the paid program.  
**Action:** Enroll in the Apple Developer Program at developer.apple.com before any other distribution work proceeds. Assign the paid team to the Xcode project's Signing & Capabilities for all targets.

### 1.3 Verify Local Network Usage Description is Shipped

**Finding:** Handrail connects to `ws://` on the local network. iOS 14+ requires `NSLocalNetworkUsageDescription` in the built Info.plist with a human-readable reason. The project currently uses a generated Info.plist (`GENERATE_INFOPLIST_FILE = YES`) and already sets `INFOPLIST_KEY_NSLocalNetworkUsageDescription = "Handrail connects to the desktop CLI on your local network."` in `ios/Handrail/Handrail.xcodeproj/project.pbxproj`.  
**Action:** Verify the key is present in the Release archive’s Info.plist and that a fresh install prompts for Local Network access before the first WebSocket connection attempt.

### 1.4 Privacy Policy URL Hosted

**Finding:** Any app that handles personal data, uses local network, or requests notifications must link a privacy policy on the App Store product page. The privacy policy exists at `docs/privacy-policy.md`, covers local-first storage, local-network `ws://` transport, no account, no telemetry, notifications, and Keychain pairing-token storage, and is publicly reachable at `https://github.com/zfifteen/handrail/blob/main/docs/privacy-policy.md`.
**Action:** Enter the public privacy policy URL in App Store Connect before submission.

### 1.5 App Store Metadata Package Is Partial

**Finding:** `store-assets/metadata.txt` now contains iPhone-only listing copy, review notes, keyword/category proposal, explicit scope exclusions, a public support URL, a public privacy policy URL, and the v1 marketing URL omission decision. The copy no longer markets approval responses while #2 is open. `store-assets/screenshot-plan.md` lists four required v1 iPhone screenshots, records draft iPhone 17 live captures under `store-assets/screenshots/iphone/`, and defers the approval screenshot until first-class approval routing is verified. The package is still not complete because final 6.9-inch App Store screenshot-class captures are blocked by unavailable paired 6.9-inch simulator/device state in the current automation environment.
**Action:** Recapture the four required v1 iPhone screenshots from a verified paired 6.9-inch simulator/device flow and place them under `store-assets/screenshots/iphone/`. Do not capture or submit an approval screenshot until #2 produces real approval-routing evidence.

### 1.6 CI Exists; Distribution Pipeline Still Blocked

**Finding:** `.github/workflows/ci.yml` now runs CLI tests and an unsigned iOS Simulator `build-for-testing` on pushes and pull requests. This catches ordinary TypeScript, protocol-test, Swift app build, and Swift test-target build regressions before review. It does not archive, export, sign, or upload an App Store build.
**Action:** After the #25 signing inputs exist, extend release automation to build a signed Release archive, export with a distribution/TestFlight/App Store provisioning profile, inspect the signed entitlements, and upload through App Store Connect tooling.

---

## Part 2: Data Integrity Bugs (Crash / Silent Data Loss Risk)

### 2.1 chat_list Overwrites Detail-Only Chat Fields on Every Poll

**Issues:** #14 (iOS), #20 (iPad)  
**File:** `ios/Handrail/Handrail/Stores/HandrailStore.swift:324-333`  
**Finding:** `HandrailStore` replaces the entire `self.chats` array with lightweight `chat_list` summary records. Any chat loaded through `chat_detail` (which carries `transcript`, `thinking`, `files`, `acceptsInput`) is silently overwritten. The Chat Detail view reads `store.chat(...).thinking`, so thinking content disappears on every list poll. This is the most data-destructive bug in the store layer and will produce confusing user-facing behavior.  
**Action:** Merge incoming `chat_list` records into the existing `chats` array by `id`. Preserve any detail-only fields (`transcript`, `thinking`, `files`, `acceptsInput`) from the existing record when the incoming summary record does not carry them. Only replace a field if the incoming record explicitly provides a non-nil value for it.

### 2.2 WebSocket Send Failure Does Not Mark Connection Offline

**Issue:** #15  
**File:** `ios/Handrail/Handrail/Networking/HandrailWebSocketClient.swift:51-54`  
**Finding:** When `send` fails, the error is surfaced as a generic error but `pairedMachine.isOnline` is not set to false and no reconnect is scheduled. The Dashboard can show "Online" while every command silently fails on a dead socket.  
**Action:** In the `send` failure path, call the same disconnect handler used by the WebSocket `onDisconnect` callback. This will flip `isOnline` to false, trigger the existing reconnect logic, and surface the correct UI state.

### 2.3 Chat Detail Refresh Silent No-Op When Offline

**Issue:** #16  
**File:** `ios/Handrail/Handrail/Stores/HandrailStore.swift:113-118`  
**Finding:** `refreshChats()` attempts reconnect when offline, but `refreshChatDetail(chatId:)` just returns early with no reconnect attempt and no per-chat error. Opening a chat after a disconnect shows empty or stale content with no way to recover.  
**Action:** In `refreshChatDetail`, check `pairedMachine?.isOnline`. If offline, trigger the same reconnect path used by `refreshChats()`, then re-request the detail once the connection is restored, or surface a per-chat "Reconnect to refresh" error.

### 2.4 Corrupt Pairing Metadata Swallowed Silently

**Issue:** #19  
**File:** `ios/Handrail/Handrail/Stores/HandrailStore.swift:532-548`  
**Finding:** Both metadata and legacy pairing decode failures use `try?`, silently leaving `pairedMachine` nil. The user sees the app as unpaired with no explanation or repair path.  
**Action:** Replace the outer `try?` with an explicit `do/catch`. On decode failure, set a `pairingError` state var and surface an alert in Settings explaining the pairing data is corrupt and offering to reset it.

---

## Part 3: Accessibility Bugs (App Store Review Risk)

Apple reviewers check VoiceOver compliance. The following bugs make core navigation inaccessible.

### 3.1 Custom Tab Bar Items Not Individually Accessible

**Issue:** #8  
**Finding:** The custom tab bar is a single accessibility group with no child buttons. VoiceOver users cannot navigate between Dashboard, Chats, Attention, Activity, and More. `tap(label: "More")` fails in automation.  
**Action:** Add `.accessibilityElement(children: .contain)` to the tab bar container. Add `.accessibilityLabel("Dashboard")`, `.accessibilityRole(.button)`, and `.accessibilityAddTraits(.isSelected)` (when active) to each tab item view.

### 3.2 Dashboard Header Buttons Not in Accessibility Tree

**Issue:** #7  
**Finding:** The `+` new-chat button and QR scanner button in the Dashboard navigation bar are not exposed as accessibility elements. Their Nav bar container reports zero children.  
**Action:** Ensure the buttons use SwiftUI `Button` with explicit `.accessibilityLabel` values ("New Chat", "Scan QR Code"). If using custom `Image`-only buttons, attach `.accessibilityLabel` and `.accessibilityHint` modifiers explicitly.

### 3.3 Refresh Button Announces Sync State Instead of Action

**Issue:** #9  
**Finding:** The refresh button's accessibility label is the current sync-state string ("Synced just now") rather than the action ("Refresh"). VoiceOver announces state, not the affordance.  
**Action:** Set `.accessibilityLabel("Refresh")` on the button wrapper. Move the sync-state string to a separate `.accessibilityElement(children: .ignore)` Text view so it is announced as static text, not a button label.

### 3.4 Tab Bar Overlaps Lower Content

**Issue:** #11  
**Finding:** On iPhone 17 / iOS 26.4, the custom tab bar covers the bottom content on Dashboard ("Pinned" heading) and Chats ("All chats" heading). Content is both visually hidden and not tappable.  
**Action:** Add `.safeAreaInset(edge: .bottom)` with the tab bar height, or use `.padding(.bottom, tabBarHeight)` on the scroll content. Prefer `GeometryReader` or the environment `safeAreaInsets` to derive the correct inset dynamically rather than hardcoding a pixel value.

---

## Part 4: Core Feature Bugs

### 4.1 Codex Desktop Thinking Messages Not Displayed

**Issue:** #4  
**Finding:** While Codex Desktop shows a `Thinking` state for an active chat, the iOS app shows "No thinking messages yet." The `thinking` field is present in the `HandrailStore` model but is not being populated from live events. This is a visible regression against the documented product behavior.  
**Action:** Audit the `chat_detail` WebSocket response and the `HandrailStore` handler for `thinking` field mapping. Ensure the `thinking` array is populated when `chat_detail` contains thinking entries and that `chat_list` merge (see 2.1) does not overwrite it.

### 4.2 Notification Shown for Currently Open Chat

**Issue:** #10  
**Finding:** The user receives a local notification for a chat they already have open in the foreground. This is the standard `UNUserNotificationCenter` foreground delivery behavior, but it should be suppressed for the active chat.  
**Action:** Implement `UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)`. Inside, compare the notification's `chatId` payload against `store.selectedChatId` (or the active route). If they match, call `completionHandler([])` to suppress the banner. Otherwise call `completionHandler([.banner, .sound])`.

### 4.3 Stale Global Errors Leak into New Chat and Chat Detail

**Issues:** UI_PATH_ISSUES.md (New Chat, Chat Detail sections)  
**Finding:** Prior error state from the global store leaks into the New Chat sheet and Chat Detail on open, showing irrelevant "Codex Desktop did not become ready" errors before any user action.  
**Action:** Clear `store.lastError` (or equivalent) when the New Chat sheet is presented and when Chat Detail loads a new `chatId`. Alternatively, scope errors per context (pairing error vs. chat-specific error vs. new-chat error) rather than sharing a single global error property.

---

## Part 5: iPad-Specific Bugs

All six issues must be resolved before an iPad target can be submitted. The iPad feature is implemented at a scaffolding level but is not functionally verified.

| Issue | File | Action |
|---|---|---|
| #21 New Chat sheet never closes on success | `RootView.swift:37-40` | Closed 2026-05-02. Live iPad simulator `start_chat` dismissed the popover, selected the started `Hi` chat, and showed its detail. |
| #23 Chat routing leaves stale `selectedApprovalId` | `RootView.swift:93-96` | Closed 2026-05-01. Started-chat and notification-chat routes now use `IPadWorkspaceSelection.selectChat(id:)`, which clears stale approval selection. |
| #24 Approval-blocked chats show green play icon | `IPadDashboardWorkspaceView.swift:268-270` | Code path reported fixed. Close only after #2 produces a live `waiting_for_approval` chat and the row renders as warning-style approval state in simulator. |
| #22 / #17 Activity rows set hidden chat selection | `IPadActivityWorkspaceView.swift:18-22` | Closed 2026-05-02. Live iPad simulator Activity row for `codex:019de79c-6c3f-7ae3-a4af-aef51c7597c1` opened the selected chat detail. |
| #20 chat_list overwrites iPad detail state | `HandrailStore.swift:324-333` | Resolved by the fix in item 2.1 above. |
| #12 Project-grouped Chats shows raw slug identifiers | `Views/Chats` | Map `chat.projectId` through the same display-name resolver used by Chat Detail headers. |

Additionally, the iPad app has not been launched on a physical iPad device. Physical iPad device testing is required before submission.

---

## Part 6: watchOS — Not Started

**Issue:** #5  
**Finding:** No watchOS code exists. The `ios/Handrail/Handrail.xcodeproj` has no watchOS target. Issue #5 is a complete product specification with acceptance criteria and a verification plan, but implementation is now blocked on paired iPhone + Apple Watch hardware evidence or an explicit decision to accept a partial pre-hardware implementation.

**Pre-implementation checklist for Codex:**
1. Add a watchOS App target to `Handrail.xcodeproj` with a companion WatchKit extension (or a modern SwiftUI watchOS app target for watchOS 7+).
2. Add a Watch Connectivity session manager to the iOS app (`WCSession.default.delegate`).
3. Implement the snapshot model and `sendMessage` path from iOS to watchOS as specified in issue #5 section 1.
4. Implement the five watchOS screens (Status, Attention, Running, Chat Detail, Approval Detail) using SwiftUI watchOS.
5. Implement the four command types (approve, deny, stop, refresh) as `WCSession.default.sendMessage` calls from watchOS to iOS.
6. Add a WidgetKit complication target for the Smart Stack widget.
7. Add an ActivityKit Live Activity in the iOS target for the Smart Stack bridge.
8. Add unit tests for snapshot derivation and command encoding per the verification plan in issue #5.
9. Run a smoke test on paired iPhone + Apple Watch hardware. WatchConnectivity delivery cannot be verified on simulator alone.

---

## Part 7: Protocol and Security Gaps

### 7.1 Unknown Server Message Types Silently Dropped

**Issue:** #18  
**File:** `ios/Handrail/Handrail/Networking/HandrailMessages.swift:164-167`  
**Finding:** Unknown message types map to `.ignored` and are silently discarded. Protocol drift between CLI and iOS is invisible during development and production.  
**Action:** Log unknown message types to the console in Debug builds. In Release, emit a non-fatal diagnostic (OSLog or a store-level debug event) so field issues are discoverable without raw-crashing.

### 7.2 Plain `ws://` Local Network Transport

**Finding:** The WebSocket server uses `ws://` (no TLS). This is acceptable for a local-network-only product but must be explicitly documented in the App Store privacy declaration. Apple may ask about network transport in review for apps that handle tokens.  
**Action:** Add a sentence to the privacy policy and App Store description: "Handrail communicates only on your local Wi-Fi network using an unencrypted WebSocket connection secured by a per-device pairing token. No data is sent to the internet."

### 7.3 Approval Routing Needs Live Evidence

**Finding:** The CLI now has first-class app-server approval request-id routing for Handrail-started turns. Live release evidence is still missing because the running LaunchAgent did not restart in the automation sandbox, and #24 still needs a real simulator-connected `waiting_for_approval` row.
**Action:** Restart the local Handrail server with the rebuilt CLI, produce a real app-server approval request, verify iOS approve/deny sends `accept`/`decline` on the app-server request id, then capture the iPad Dashboard approval-row evidence for #24.

---

## Part 8: Pre-Submission Checklist for Codex

Execute in this order:

1. **[SIGNING]** Enroll or configure a paid Apple Developer Program team for `com.velocityworks.Handrail`.
2. **[SIGNING]** Install/select a non-expired distribution/TestFlight/App Store provisioning profile with Push Notifications and `aps-environment`.
3. **[VERIFY]** Sign a Release archive and confirm the signed app entitlement has `aps-environment = production` (#25).
4. **[VERIFY]** Confirm `NSLocalNetworkUsageDescription` is present in the signed Release build Info.plist.
5. **[APP STORE]** Enter `https://github.com/zfifteen/handrail/blob/main/docs/privacy-policy.md` in App Store Connect.
6. **[APP STORE]** Confirm the `store-assets/metadata.txt` age-rating and export-compliance draft answers in App Store Connect with an Account Holder, Admin, or App Manager.
7. **[SCREENSHOTS]** Capture the four required v1 iPhone screenshots from a paired 6.9-inch iPhone simulator/device: Dashboard, Chats list, Chat Detail, and New Chat (#28).
8. **[SCREENSHOTS]** Record simulator/device name, OS version, local CLI/server state, screenshot paths, and visible-flow validation for #28.
9. **[DESKTOP]** Produce live first-class approval ingestion/routing evidence for `waiting_for_approval` and approve/deny decisions (#2).
10. **[iPad]** Close #24 only after live simulator evidence for a real `waiting_for_approval` row.
11. **[iPad]** Run and record a full iPad walkthrough before closing umbrella issue #6 or claiming iPad App Store support.
12. **[watchOS]** Provide a paired iPhone + Apple Watch hardware path for #5, or explicitly approve a partial simulator/build-only implementation before hardware acceptance.
13. **[INFRA]** Keep the smoke CI workflow green; add a signed distribution pipeline only after signing inputs exist.
