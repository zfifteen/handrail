import SwiftUI
import UIKit

struct RootView: View {
    @Environment(HandrailStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var iPadSelection: IPadWorkspaceSelection
    @Binding var showsIPadNewChat: Bool
    @Binding var focusesIPadChatSearch: Bool
    @State private var showsLaunchSplash = true
    @State private var launchSplashOpacity = 1.0
    @State private var phoneRoute: PhoneRootRoute?
    @State private var phoneRouteToken = 0

    init(
        iPadSelection: Binding<IPadWorkspaceSelection> = .constant(IPadWorkspaceSelection()),
        showsIPadNewChat: Binding<Bool> = .constant(false),
        focusesIPadChatSearch: Binding<Bool> = .constant(false)
    ) {
        self._iPadSelection = iPadSelection
        self._showsIPadNewChat = showsIPadNewChat
        self._focusesIPadChatSearch = focusesIPadChatSearch
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            rootContent

            if showsLaunchSplash {
                LaunchSplashView()
                    .opacity(launchSplashOpacity)
                    .allowsHitTesting(true)
            }
        }
        .onChange(of: store.lastStartedChatId) { _, chatId in
            guard let chatId else { return }
            routeToStartedChat(chatId)
            store.consumeLastStartedChatId()
        }
        .onChange(of: store.notificationChatId) { _, chatId in
            guard let chatId else { return }
            routeToNotificationChat(chatId)
            store.consumeNotificationChatId()
        }
        .sheet(isPresented: $store.showsApprovalFromNotification) {
            NavigationStack {
                ApprovalRequiredView()
            }
        }
        .sheet(isPresented: $showsIPadNewChat) {
            NavigationStack {
                IPadNewChatPanel()
            }
            .environment(store)
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.5)) {
                launchSplashOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.5))
            showsLaunchSplash = false
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch HandrailRootLayoutResolver.mode(
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass
        ) {
        case .phone:
            PhoneRootView(route: $phoneRoute)
        case .iPadRegular:
            IPadWorkspaceRootView(
                selection: $iPadSelection,
                showsNewChat: $showsIPadNewChat,
                focusesChatSearch: $focusesIPadChatSearch
            )
        }
    }

    private func routeToStartedChat(_ chatId: String) {
        switch HandrailRootLayoutResolver.mode(
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass
        ) {
        case .phone:
            phoneRouteToken += 1
            phoneRoute = PhoneRootRoute(kind: .startedChat, chatId: chatId, token: phoneRouteToken)
        case .iPadRegular:
            iPadSelection.selectChat(id: chatId)
            showsIPadNewChat = false
        }
    }

    private func routeToNotificationChat(_ chatId: String) {
        switch HandrailRootLayoutResolver.mode(
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass
        ) {
        case .phone:
            phoneRouteToken += 1
            phoneRoute = PhoneRootRoute(kind: .notificationChat, chatId: chatId, token: phoneRouteToken)
        case .iPadRegular:
            iPadSelection.selectChat(id: chatId)
        }
    }
}

enum HandrailRootLayoutMode: Equatable {
    case phone
    case iPadRegular
}

enum HandrailRootLayoutResolver {
    static func mode(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> HandrailRootLayoutMode {
        guard userInterfaceIdiom == .pad, horizontalSizeClass == .regular else {
            return .phone
        }
        return .iPadRegular
    }
}

struct PhoneRootRoute: Equatable {
    enum Kind: Equatable {
        case startedChat
        case notificationChat
    }

    let kind: Kind
    let chatId: String
    let token: Int
}

struct PhoneRootView: View {
    @Binding var route: PhoneRootRoute?
    @State private var path = NavigationPath()
    @State private var currentChatId: String?

    var body: some View {
        NavigationStack(path: $path) {
            ChatsView { chatId in
                currentChatId = chatId
                path.append(chatId)
            }
        }
        .tint(.primary)
        .onChange(of: path.count) { _, count in
            if count == 0 {
                currentChatId = nil
            }
        }
        .onChange(of: route) { _, route in
            guard let route else { return }
            handle(route)
        }
    }

    private func handle(_ route: PhoneRootRoute) {
        guard PhoneRouteNavigationDecision.shouldRoute(currentChatId: currentChatId, routeChatId: route.chatId) else {
            return
        }
        path = NavigationPath()
        path.append(route.chatId)
        currentChatId = route.chatId
    }
}

enum PhoneRouteNavigationDecision {
    static func shouldRoute(currentChatId: String?, routeChatId: String) -> Bool {
        currentChatId != routeChatId
    }
}

#Preview {
    RootView()
        .environment(PreviewData.store)
        .preferredColorScheme(.dark)
}
