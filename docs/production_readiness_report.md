# Handrail Production Readiness Evaluation
**Prepared:** 2026-04-30  
**Repo:** github.com/zfifteen/handrail  
**Target:** Apple App Store — iOS (iPhone), watchOS, iPad  
**Audience:** Codex instance for action

---

## Executive Summary

Handrail is not production-ready for App Store submission across any of its three target platforms. The iOS iPhone app is the most advanced (CLI tests 27/27, core flows verified on device), but carries open accessibility bugs that Apple reviewers are likely to flag and data-flow bugs that corrupt the UI under normal use. The iPad app has six confirmed routing and state-management bugs with no verified device run. The watchOS app has zero implementation — only a product spec (issue #5). The report below assigns each gap a priority tier and states the concrete action required.

**Overall Readiness by Platform:**

| Platform | Implementation | Known Open Bugs | App Store Blockers | Status |
|---|---|---|---|---|
| iOS (iPhone) | Feature-complete MVP | 11 open | 5 | NOT READY |
| iPad | Partial (split-view scaffolding) | 6 open | 6 | NOT READY |
| watchOS | None (spec only) | N/A | All | NOT STARTED |

## PM State Refresh - 2026-05-01

GitHub is now the source of truth for issue state. Milestone 1, `iPhone App Store readiness`, has 12 open issues and 2 closed issues after the 2026-05-01 PM run.

Closed since this report was prepared:

- #7 Dashboard header actions are missing from the accessibility tree.
- #9 Refresh control announces the sync status instead of the action.
- #14 Preserve chat detail fields when `chat_list` refreshes.
- #15 Treat WebSocket send failure as a disconnect.
- #20 iPad: `chat_list` overwrites detail-only chat state.

Open iPhone readiness scope:

- App Store submission artifacts: #25 Release APNs entitlement verification, #26 hosted privacy policy URL, #28 iPhone metadata and screenshot package.
- User-visible iPhone blockers: #4 thinking messages, #8 tab bar accessibility, #10 active-chat notification suppression, #11 tab bar safe-area overlap, #12 project display names, #16 offline chat-detail refresh, #18 unknown protocol message surfacing, #19 corrupt pairing metadata, #27 stale global errors.

The next shippable release remains blocked until milestone 1 is closed with CLI test evidence and iPhone simulator validation for every affected visible flow. iPad stabilization, Desktop protocol hardening beyond #18, and watchOS remain separate milestones.

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

### 1.5 No App Store Metadata Package

**Finding:** App Store submission requires: app name, subtitle, description, keywords, support URL, marketing URL, screenshots (at minimum iPhone 6.9-inch and iPad 12.9-inch if iPad is universal), and an app icon at 1024x1024. None of these assets exist in the repo.  
**Action:** Create a `store-assets/` directory in the repo. Add the icon, screenshots for each target device size, and a `metadata.txt` with the listing copy. Use Xcode Organizer or Fastlane Deliver to manage the upload workflow.

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
| #21 New Chat sheet never closes on success | `RootView.swift:37-40` | Set `showsIPadNewChat = false` in the `lastStartedChatId` observation handler. |
| #23 Chat routing leaves stale `selectedApprovalId` | `RootView.swift:93-96` | Clear `selectedApprovalId` in every code path that sets `selectedChatId`. |
| #24 Approval-blocked chats show green play icon | `IPadDashboardWorkspaceView.swift:268-270` | Add a `waitingForApproval` icon/color branch before the default `activeRow` rendering. |
| #22 / #17 Activity rows set hidden chat selection | `IPadActivityWorkspaceView.swift:18-22` | After setting `selectedChatId`, also set `selectedSection = .chats` so the split-view detail column mounts the chat detail. |
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
14. **[iPad]** Fix all six iPad routing/state bugs (issues #17, #20, #21, #22, #23, #24).
15. **[iPad]** Fix project-grouped slugs (issue #12).
16. **[watchOS]** Implement watchOS target per issue #5 spec.
17. **[INFRA]** Add GitHub Actions CI for archive + TestFlight upload.
18. **[INFRA]** Create `store-assets/` with icon, screenshots, and listing copy.
19. **[INFRA]** Host `docs/privacy-policy.md` at a stable privacy policy URL. Add URL to App Store Connect.
20. **[INFRA]** Enroll in Apple Developer Program (paid) and assign team in Xcode.
