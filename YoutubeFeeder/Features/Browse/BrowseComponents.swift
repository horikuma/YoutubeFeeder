import SwiftUI
import UIKit

struct InteractiveListView<Content: View>: View {
    let title: String
    let subtitle: String
    let coordinator: FeedCacheCoordinator
    @Binding var path: NavigationPath
    let layout: AppLayout
    let onRefresh: (() async -> Void)?
    let allowsRefreshCommandBinding: Bool
    @ViewBuilder let content: () -> Content

    private var refreshCommandAction: (() async -> Void)? {
        if allowsRefreshCommandBinding {
            return onRefresh
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(layout.isPad ? .system(size: 34, weight: .black, design: .rounded) : .largeTitle.bold())
                    .accessibilityIdentifier("screen.title")

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                content()
            }
            .frame(maxWidth: layout.readableContentWidth ?? layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
        .refreshable {
            guard let onRefresh else { return }
            await onRefresh()
        }
        .bindRefreshCommand(refreshCommandAction)
    }
}

struct TileMenuAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void
}

enum TileMenuTriggerStyle {
    case primaryClick
    case contextMenu
}

struct TileHighlightBorder: View {
    let isHovered: Bool
    let isSelected: Bool

    private var borderColor: Color {
        if isSelected {
            return .red.opacity(0.95)
        }
        if isHovered {
            return .blue.opacity(0.95)
        }
        return .clear
    }

    private var borderWidth: CGFloat {
        (isHovered || isSelected) ? 3 : 0
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }
}

struct TileMenuConfiguration {
    let primaryAction: TileMenuAction?
    let secondaryActions: [TileMenuAction]

    init(primaryAction: TileMenuAction? = nil, secondaryActions: [TileMenuAction]) {
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
    }

    var hasActions: Bool {
        primaryAction != nil || !secondaryActions.isEmpty
    }

    func presentedActions(for platform: AppInteractionPlatform) -> [TileMenuAction] {
        if platform.usesPrimaryClickForMenus, let primaryAction {
            return [primaryAction] + secondaryActions
        }
        return secondaryActions
    }
}

private struct TileActionMenuModifier: ViewModifier {
    let menu: TileMenuConfiguration
    let accessibilityIdentifier: String?
    let desktopTriggerStyle: TileMenuTriggerStyle
    @State private var isShowingMenu = false

    private var platform: AppInteractionPlatform {
        AppInteractionPlatform.current
    }

    func body(content: Content) -> some View {
        let presentedActions = menu.presentedActions(for: platform)

        if platform.usesPrimaryClickForMenus, desktopTriggerStyle == .primaryClick, menu.hasActions {
            primaryClickMenu(content: content, presentedActions: presentedActions)
        } else if platform.usesPrimaryClickForMenus, desktopTriggerStyle == .contextMenu {
            contextMenu(content: content, presentedActions: presentedActions)
        } else {
            fallbackMenu(content: content, presentedActions: presentedActions)
        }
    }

    private func primaryClickMenu<Content: View>(content: Content, presentedActions: [TileMenuAction]) -> some View {
        Button {
            isShowingMenu = true
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .confirmationDialog("", isPresented: $isShowingMenu, titleVisibility: .hidden) {
            presentedActionsButtons(presentedActions)
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func contextMenu<Content: View>(content: Content, presentedActions: [TileMenuAction]) -> some View {
        content
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
            .contextMenu {
                if presentedActions.isEmpty {
                    Button("未定義") {}
                } else {
                    presentedActionsButtons(presentedActions)
                }
            }
    }

    private func fallbackMenu<Content: View>(content: Content, presentedActions: [TileMenuAction]) -> some View {
        content
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        isShowingMenu = true
                    }
            )
            .confirmationDialog("", isPresented: $isShowingMenu, titleVisibility: .hidden) {
                if presentedActions.isEmpty {
                    Button("未定義") {}
                } else {
                    presentedActionsButtons(presentedActions)
                }
                Button("キャンセル", role: .cancel) {}
            }
    }

    @ViewBuilder
    private func presentedActionsButtons(_ presentedActions: [TileMenuAction]) -> some View {
        ForEach(Array(presentedActions.enumerated()), id: \.offset) { _, action in
            Button(action.title, role: action.role) {
                action.action()
            }
        }
    }
}

extension View {
    func tileActionMenu(
        menu: TileMenuConfiguration,
        accessibilityIdentifier: String? = nil,
        desktopTriggerStyle: TileMenuTriggerStyle = .primaryClick
    ) -> some View {
        modifier(
            TileActionMenuModifier(
                menu: menu,
                accessibilityIdentifier: accessibilityIdentifier,
                desktopTriggerStyle: desktopTriggerStyle
            )
        )
    }
}

struct VideoTile: View {
    let video: CachedVideo
    let tapAction: (() -> Void)?
    let openVideoAction: (() -> Void)?
    let primaryMenuAction: (() -> Void)?
    let removeChannel: (() -> Void)?
    let index: Int?
    let desktopPrimaryClickAction: (() -> Void)?
    let desktopMenuTriggerStyle: TileMenuTriggerStyle
    let includesOpenVideoInMenu: Bool
    @State private var isHovered = false
    @State private var shareURL: URL?

    init(
        video: CachedVideo,
        tapAction: (() -> Void)? = nil,
        openVideoAction: (() -> Void)? = nil,
        primaryMenuAction: (() -> Void)? = nil,
        removeChannel: (() -> Void)? = nil,
        index: Int? = nil,
        desktopPrimaryClickAction: (() -> Void)? = nil,
        desktopMenuTriggerStyle: TileMenuTriggerStyle = .primaryClick,
        includesOpenVideoInMenu: Bool = true
    ) {
        self.video = video
        self.tapAction = tapAction
        self.openVideoAction = openVideoAction
        self.primaryMenuAction = primaryMenuAction
        self.removeChannel = removeChannel
        self.index = index
        self.desktopPrimaryClickAction = desktopPrimaryClickAction
        self.desktopMenuTriggerStyle = desktopMenuTriggerStyle
        self.includesOpenVideoInMenu = includesOpenVideoInMenu
    }

    var body: some View {
        let menu = buildMenuConfiguration()
        let tile = VideoHeroTile(video: video, index: index, isHovered: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .tileActionMenu(menu: menu, desktopTriggerStyle: desktopMenuTriggerStyle)
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil },
                    set: { if !$0 { shareURL = nil } }
                )
            ) {
                if let shareURL {
                    ActivityShareSheet(activityItems: [shareURL])
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(accessibilityHint)
            .accessibilityIdentifier("video.tile.\(video.id)")

        if AppInteractionPlatform.current.usesPrimaryClickForMenus, desktopMenuTriggerStyle == .primaryClick, menu.hasActions {
            tile
                .onHover {
                    isHovered = $0
                    AppConsoleLogger.browseTileInteraction.debug(
                        "tile_hover_state_changed",
                        metadata: [
                            "kind": "video_primary_menu",
                            "videoID": video.id,
                            "channelID": video.channelID,
                            "isHovered": "\($0)"
                        ]
                    )
                }
        } else if AppInteractionPlatform.current.usesPrimaryClickForMenus, let desktopPrimaryClickAction {
            Button(action: desktopPrimaryClickAction) {
                tile
            }
            .buttonStyle(.plain)
            .onHover {
                isHovered = $0
                AppConsoleLogger.browseTileInteraction.debug(
                    "tile_hover_state_changed",
                    metadata: [
                        "kind": "video_primary_click",
                        "videoID": video.id,
                        "channelID": video.channelID,
                        "isHovered": "\($0)"
                    ]
                )
            }
        } else if let tapAction {
            Button(action: tapAction) {
                tile
            }
            .buttonStyle(.plain)
            .onHover {
                isHovered = $0
                AppConsoleLogger.browseTileInteraction.debug(
                    "tile_hover_state_changed",
                    metadata: [
                        "kind": "video_tap",
                        "videoID": video.id,
                        "channelID": video.channelID,
                        "isHovered": "\($0)"
                    ]
                )
            }
        } else {
            tile
                .onHover {
                    isHovered = $0
                    AppConsoleLogger.browseTileInteraction.debug(
                        "tile_hover_state_changed",
                        metadata: [
                            "kind": "video_fallback",
                            "videoID": video.id,
                            "channelID": video.channelID,
                            "isHovered": "\($0)"
                        ]
                    )
                }
        }
    }

    private var accessibilityHint: String {
        if AppInteractionPlatform.current.usesPrimaryClickForMenus {
            if desktopMenuTriggerStyle == .contextMenu, desktopPrimaryClickAction != nil {
                return "クリックで YouTube を開きます。右クリックでメニューを開きます"
            }
            return "クリックでメニューを開きます"
        }
        return "長押しでメニューを開きます"
    }

    private func buildMenuConfiguration() -> TileMenuConfiguration {
        var actions: [TileMenuAction] = []

        if let shareURL = VideoSharePolicy.shareURL(for: video) {
            actions.append(
                TileMenuAction(title: "共有", role: nil) {
                    self.shareURL = shareURL
                }
            )
        }

        if includesOpenVideoInMenu, let openVideoAction {
            actions.append(
                TileMenuAction(title: "YouTubeで開く", role: nil) {
                    openVideoAction()
                }
            )
        }

        if let removeChannel {
            actions.append(
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    removeChannel()
                }
            )
        }

        let primaryAction: TileMenuAction?
        if AppInteractionPlatform.current.usesPrimaryClickForMenus, let action = primaryMenuAction ?? tapAction {
            primaryAction = TileMenuAction(title: "チャンネルを開く", role: nil) {
                action()
            }
        } else {
            primaryAction = nil
        }

        return TileMenuConfiguration(primaryAction: primaryAction, secondaryActions: actions)
    }
}
