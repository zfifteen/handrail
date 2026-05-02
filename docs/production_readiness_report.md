# Handrail Production Readiness Evaluation
**Prepared:** 2026-04-30  
**Repo:** github.com/zfifteen/handrail  
**Target:** Apple App Store — iOS (iPhone), watchOS, iPad  
**Audience:** Codex instance for action

---

## Executive Summary

Handrail is not production-ready for App Store submission across any of its three target platforms. The iPhone app is now blocked by submission evidence rather than known open iPhone UI/reliability bugs: milestone 1 has 3 open artifact/provisioning issues and 11 closed readiness issues. The iPad app has a working split-view surface, but the remaining visible iPad validation is now blocked upstream by live Desktop protocol failures: new chat start does not reliably emit `chat_started`, and approval state is not yet first-class. The watchOS app has zero implementation - only a product spec (issue #5). The report below assigns each gap a priority tier and states the concrete action required.

**Overall Readiness by Platform:**

| Platform | Implementation | Known Open Bugs | App Store Blockers | Status |
|---|---|---|---|---|
| iOS (iPhone) | Feature-complete MVP | 0 known open iPhone UI/reliability bugs in milestone 1 | 3 evidence blockers | NOT READY |
| iPad | Partial split-view workspace | 3 validation-gated bugs + 1 open product spec | 4 milestone blockers plus upstream Desktop approval blocker #2 | NOT READY |
| watchOS | None (spec only) | N/A | All | NOT STARTED |

## App Store Readiness State Refresh - 2026-05-01 16:30Z

GitHub is now the source of truth for issue state. Milestone 1, `iPhone App Store readiness`, has 3 open issues and 11 closed issues after the 2026-05-01 Lead Dev run.

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
- #27 Clear stale global errors when opening New Chat or Chat Detail.

Closed related reliability issues outside the active milestone:

- #14 Preserve chat detail fields when `chat_list` refreshes.
- #15 Treat WebSocket send failure as a disconnect.
- #20 iPad: `chat_list` overwrites detail-only chat state.

Open iPhone readiness scope:

- #25 Release APNs entitlement verification. Source entitlements are correct, but the signed Release archive cannot be produced locally because no production-capable provisioning profile is installed for `com.velocityworks.Handrail` with Push Notifications and `aps-environment`.
- #26 Hosted privacy policy URL. The policy source exists at `docs/privacy-policy.md`; App Store readiness still needs a stable hosted URL.
- #28 iPhone metadata and screenshot package. Listing copy exists at `store-assets/metadata.txt`, the support URL points at the public GitHub issue tracker, and the marketing URL is deliberately omitted for v1. The screenshot plan exists at `store-assets/screenshot-plan.md`; the hosted privacy URL and four required v1 iPhone screenshots are still missing. Approval-response copy and the approval screenshot are deferred until #2 has first-class approval-routing evidence.

The next shippable release remains blocked until milestone 1 is closed with CLI test evidence and iPhone simulator validation for every affected visible flow. iPad stabilization, Desktop protocol hardening beyond #18, and watchOS remain separate milestones.

## iPad Stabilization State Refresh - 2026-05-01 23:05Z

Milestone 2, `iPad MVP stabilization`, has 4 open issues and 2 closed issues after the 2026-05-01 QA Lead, Lead Dev, and live-data root-cause runs. The open iPad issues are no longer blocked by simulator infrastructure alone; the live data needed for closure is blocked by Desktop protocol issues in milestone 3.

Closed in milestone 2:

- #17 Navigate from iPad activity rows to selected chat detail.
- #23 iPad chat routing leaves stale approval selection alive.

Open iPad stabilization scope:

- #6 Product spec: iPad Handrail version. This remains the umbrella product acceptance issue for the iPad surface; it should not be closed by individual bug fixes alone.
- #21 New Chat sheet never closes on success. Current iPad code path is reported fixed, and #29 now provides the live `start_chat` success path needed for simulator closure evidence.
- #22 Activity rows set a hidden chat selection. Current iPad code path is reported fixed, and #29 now provides live chat-linked Activity events needed for simulator closure evidence.
- #24 Waiting approvals look like running chats on Dashboard. Current iPad code path is reported fixed; #29 can now produce a live started chat, but closure still depends on #2 for first-class approval ingestion/routing.

The strongest current iPad finding is that #21 and #22 are ready for live iPad simulator validation, because #29 now makes a real `start_chat` emit `chat_started` and chat-linked activity. #24 still depends on #2 making approval state first-class enough to validate `waiting_for_approval` behavior. Do not broaden product code with test-only launch state to close the iPad issues; use a real simulator-connected local Handrail feed that naturally contains the needed `start_chat`, chat-linked Activity, and approval states.

## Lead Dev Scope Refresh - 2026-05-02 06:07Z

#29 is closed. The live Handrail listener on `127.0.0.1:8788` was restarted from stale PID `16041` to PID `70040` using LaunchAgent `com.velocityworks.handrail.server`. A real `start_chat` through the live server emitted `chat_started`, emitted a chat-linked `chat_event`, refreshed `chat_list`, and appeared in `node cli/dist/src/index.js chats` as Desktop-visible chat `codex:019de74b-9e6e-71e1-a6e1-14028304e776`. Evidence is in `test-artifacts/issue29-resolve-20260502T060625Z/`.

The iPhone App Store metadata package no longer claims approval-response support for v1. `store-assets/metadata.txt` and `store-assets/screenshot-plan.md` now defer the approval screenshot until #2 has first-class Desktop approval request IDs. This keeps milestone 1 focused on submission evidence instead of silently adding #2 to the iPhone release gate through marketing copy.

---

## Part 1: App Store Hard Blockers

These items will cause Apple review rejection or provisioning failure regardless of feature completeness.

### 1.1 Release APNs Entitlement Requires Distribution Signing Verification

**File:** `ios/Handrail/Handrail/Handrail.entitlements`  
**Finding:** The source entitlement now sets `aps-environment` to `production`, and Release build settings point at `Handrail/Handrail.entitlements`. Final App Store evidence is still missing because the local `iOS Team Provisioning Profile: com.velocityworks.Handrail` cannot sign a Release archive with Push Notifications or `aps-environment`.
**Action:** Build a Release archive with a distribution/TestFlight/App Store provisioning profile, then inspect the signed app with `codesign -d --entitlements :- <App.app>` and confirm `aps-environment` is `production`. Keep the Debug target's entitlement-stripping behavior (introduced 2026-04-29) intact so personal-team Debug builds remain installable.

### 1.2 No Paid Apple Developer Program Membership Confirmed

**Finding:** All device install attempts used a personal development team (`com.velocityworks.Handrail`). App Store submission requires an Apple Developer Program membership ($99/year). Push Notifications, HealthKit (if watchOS adds it), and distribution certificates all require the paid program.  
**Action:** Enroll in the Apple Developer Program at developer.apple.com before any other distribution work proceeds. Assign the paid team to the Xcode project's Signing & Capabilities for all targets.

### 1.3 Verify Local Network Usage Description is Shipped

**Finding:** Handrail connects to `ws://` on the local network. iOS 14+ requires `NSLocalNetworkUsageDescription` in the built Info.plist with a human-readable reason. The project currently uses a generated Info.plist (`GENERATE_INFOPLIST_FILE = YES`) and already sets `INFOPLIST_KEY_NSLocalNetworkUsageDescription = "Handrail connects to the desktop CLI on your local network."` in `ios/Handrail/Handrail.xcodeproj/project.pbxproj`.  
**Action:** Verify the key is present in the Release archive’s Info.plist and that a fresh install prompts for Local Network access before the first WebSocket connection attempt.

### 1.4 Privacy Policy URL Not Hosted

**Finding:** Any app that handles personal data, uses local network, or requests notifications must link a privacy policy on the App Store product page. A draft privacy policy now exists at `docs/privacy-policy.md` and covers local-first storage, local-network `ws://` transport, no account, no telemetry, notifications, and Keychain pairing-token storage. App Store submission is still blocked until this text is hosted at a stable URL and the URL is entered in App Store Connect.  
**Action:** Host the policy at a stable URL and add that URL to the App Store Connect listing before submission.

### 1.5 App Store Metadata Package Is Partial

**Finding:** `store-assets/metadata.txt` now contains iPhone-only listing copy, review notes, keyword/category proposal, explicit scope exclusions, a public support URL, and the v1 marketing URL omission decision. The copy no longer markets approval responses while #2 is open. `store-assets/screenshot-plan.md` now lists four required v1 iPhone screenshots and defers the approval screenshot until first-class approval routing is verified. The package is still not complete because the hosted privacy URL and required iPhone screenshots are missing.
**Action:** Capture the four required v1 iPhone screenshots from verified simulator/device flows, place them under `store-assets/screenshots/iphone/`, and replace the privacy policy URL placeholder in `store-assets/metadata.txt`. Do not capture or submit an approval screenshot until #2 produces real approval-routing evidence.

### 1.6 No Automated Build / Distribution Pipeline

**Finding:** All builds in the run log are manual `xcodebuild` calls and XcodeBuildMCP sessions. There is no CI/CD configuration (GitHub Actions, Xcode Cloud, or Fastlane) for archiving, signing, or uploading to App Store Connect.  
**Action:** Add a GitHub Actions workflow (or Xcode Cloud trigger) that: runs `cd cli && npm test`, builds the iOS archive with `xcodebuild archive`, exports with a distribution provisioning profile, and uploads with `xcrun altool` or `xcodebuild -exportArchive`. Gate merges to main on the workflow passing.

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
| #21 New Chat sheet never closes on success | `RootView.swift:37-40` | Code path reported fixed and #29 is closed. Close after a live successful iPad `start_chat` transition dismisses the sheet and selects the started chat in simulator. |
| #23 Chat routing leaves stale `selectedApprovalId` | `RootView.swift:93-96` | Closed 2026-05-01. Started-chat and notification-chat routes now use `IPadWorkspaceSelection.selectChat(id:)`, which clears stale approval selection. |
| #24 Approval-blocked chats show green play icon | `IPadDashboardWorkspaceView.swift:268-270` | Code path reported fixed. Close only after #2 produces a live `waiting_for_approval` chat and the row renders as warning-style approval state in simulator. |
| #22 / #17 Activity rows set hidden chat selection | `IPadActivityWorkspaceView.swift:18-22` | #17 is closed, #22 code path is reported fixed, and #29 now emits live chat-linked Activity events. Close #22 after a live row opens the chat detail in simulator. |
| #20 chat_list overwrites iPad detail state | `HandrailStore.swift:324-333` | Resolved by the fix in item 2.1 above. |
| #12 Project-grouped Chats shows raw slug identifiers | `Views/Chats` | Map `chat.projectId` through the same display-name resolver used by Chat Detail headers. |

Additionally, the iPad app has not been launched on a physical iPad device. Physical iPad device testing is required before submission.

---

## Part 6: watchOS — Not Started

**Issue:** #5  
**Finding:** No watchOS code exists. The `ios/Handrail/Handrail.xcodeproj` has no watchOS target. Issue #5 is a complete product specification with acceptance criteria and a verification plan, but implementation has not begun.

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

### 7.3 Approval Detection is Pattern-Matched, Not Protocol-Routed

**Finding:** The CLI watches Codex output for strings like `approve`, `permission`, `Do you want to proceed`. This is fragile against Codex output format changes. Issue #2 tracks upgrading to first-class approval routing through the Codex Desktop app-server route.  
**Action:** Issue #2 should be addressed before App Store submission if approval is a marketed feature. If it ships as-is, add an explicit user-facing disclosure in Settings: "Approval detection uses text pattern matching and may miss some requests."

---

## Part 8: Pre-Submission Checklist for Codex

Execute in this order:

1. **[VERIFY]** Sign a Release archive with a distribution profile and confirm the signed app entitlement has `aps-environment = production`.
2. **[VERIFY]** Confirm `NSLocalNetworkUsageDescription` is present in the Release build Info.plist.
3. **[DATA]** Fix `HandrailStore` chat_list merge to preserve detail-only fields (issues #14, #20).
4. **[DATA]** Fix WebSocket send failure to mark connection offline (issue #15).
5. **[DATA]** Fix `refreshChatDetail` offline no-op (issue #16).
6. **[DATA]** Fix corrupt pairing metadata handling (issue #19).
7. **[A11Y]** Fix custom tab bar accessibility (issue #8).
8. **[A11Y]** Fix Dashboard header button accessibility (issue #7).
9. **[A11Y]** Fix refresh button accessibility label (issue #9).
10. **[A11Y]** Fix tab bar safe-area inset on content (issue #11).
11. **[FEATURE]** Fix thinking messages not displayed (issue #4).
12. **[FEATURE]** Suppress notifications for active foreground chat (issue #10).
13. **[FEATURE]** Clear stale global errors on sheet/detail open.
14. **[DESKTOP]** Closed 2026-05-02: Desktop `start_chat` handoff emits `chat_started` and chat-linked activity (#29).
15. **[DESKTOP]** Add first-class approval ingestion/routing for live `waiting_for_approval` evidence (#2).
16. **[iPad]** Close the remaining iPad routing/state bugs only after live simulator evidence for #21, #22, and #24.
17. **[iPad]** Keep project-grouped slug fix evidence attached to closed issue #12.
18. **[watchOS]** Implement watchOS target per issue #5 spec.
19. **[INFRA]** Add GitHub Actions CI for archive + TestFlight upload.
20. **[INFRA]** Create `store-assets/` with icon, screenshots, and listing copy.
21. **[INFRA]** Host `docs/privacy-policy.md` at a stable privacy policy URL. Add URL to App Store Connect.
22. **[INFRA]** Enroll in Apple Developer Program (paid) and assign team in Xcode.
