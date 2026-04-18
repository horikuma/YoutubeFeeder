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
            Button {
                isShowingMenu = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
            .confirmationDialog("", isPresented: $isShowingMenu, titleVisibility: .hidden) {
                ForEach(Array(presentedActions.enumerated()), id: \.offset) { _, action in
                    Button(action.title, role: action.role) {
                        action.action()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        } else if platform.usesPrimaryClickForMenus, desktopTriggerStyle == .contextMenu {
            content
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
                .contextMenu {
                    if presentedActions.isEmpty {
                        Button("未定義") {}
                    } else {
                        ForEach(Array(presentedActions.enumerated()), id: \.offset) { _, action in
                            Button(action.title, role: action.role) {
                                action.action()
                            }
                        }
                    }
                }
        } else {
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
                        ForEach(Array(presentedActions.enumerated()), id: \.offset) { _, action in
                            Button(action.title, role: action.role) {
                                action.action()
                            }
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
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
        let tile = VideoHeroTile(video: video, index: index)
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
        } else if AppInteractionPlatform.current.usesPrimaryClickForMenus, let desktopPrimaryClickAction {
            Button(action: desktopPrimaryClickAction) {
                tile
            }
            .buttonStyle(.plain)
        } else if let tapAction {
            Button(action: tapAction) {
                tile
            }
            .buttonStyle(.plain)
        } else {
            tile
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

extension View {
    func listInsertionTransition() -> some View {
        transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum ChannelSummaryTileAppearance {
    case navigation
    case unselected
    case selected

    var gradientColors: [Color] {
        switch self {
        case .navigation:
            [.teal, .blue]
        case .unselected:
            [.teal.opacity(0.8), .blue.opacity(0.8)]
        case .selected:
            [.cyan, .blue]
        }
    }

    var thumbnailOpacity: Double {
        switch self {
        case .navigation:
            1.0
        case .unselected:
            0.78
        case .selected:
            0.92
        }
    }

    var overlayOpacity: Double {
        switch self {
        case .navigation:
            0.75
        case .unselected, .selected:
            0.78
        }
    }

    var selectionBorderColor: Color {
        switch self {
        case .selected:
            .white.opacity(0.95)
        case .navigation, .unselected:
            .clear
        }
    }
}

fileprivate struct ChannelTile: View {
    let item: ChannelBrowseItem
    let appearance: ChannelSummaryTileAppearance
    let index: Int?

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: appearance.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let latestVideo = item.latestVideo {
                    ThumbnailView(video: latestVideo, contentMode: .fill)
                        .opacity(appearance.thumbnailOpacity)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(appearance.overlayOpacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(appearance.selectionBorderColor, lineWidth: 3)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.channelDisplayTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("\(item.cachedVideoCount)件")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(item.latestPublishedAtText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                if let index {
                    TileIndexBadge(index: index)
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ChannelNavigationTile: View {
    let item: ChannelBrowseItem
    let index: Int?

    var body: some View {
        ChannelTile(item: item, appearance: .navigation, index: index)
    }
}

struct ChannelSelectionTile: View {
    let item: ChannelBrowseItem
    let isSelected: Bool
    let index: Int?

    var body: some View {
        ChannelTile(
            item: item,
            appearance: isSelected ? .selected : .unselected,
            index: index
        )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct VideoHeroTile: View {
    let video: CachedVideo
    let index: Int?

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ThumbnailView(video: video, contentMode: .fill)
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(video.channelDisplayTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Text(video.publishedAtText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            }
            .overlay(alignment: .bottomTrailing) {
                VideoMetadataBadge(video: video)
                    .padding(14)
            }
            .overlay(alignment: .topTrailing) {
                if let index {
                    TileIndexBadge(index: index)
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct TileIndexBadge: View {
    let index: Int

    var body: some View {
        Text("\(index)")
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.7), in: Capsule())
    }
}

private struct VideoMetadataBadge: View {
    let video: CachedVideo

    var body: some View {
        Text(video.metadataBadgeText)
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.72), in: Capsule())
    }
}

struct ThumbnailView: View {
    private static let referenceStore = FeedCacheStore()
    private static let writeService = FeedCacheWriteService(
        store: FeedCacheStore(),
        remoteSearchCacheStore: RemoteVideoSearchCacheStore()
    )

    let video: CachedVideo
    var contentMode: ContentMode = .fill
    @State private var cachedThumbnail: CachedThumbnailReference?
    @State private var lastTrackedFilename: String?

    var body: some View {
        Group {
            if let filename = localFilename {
                AsyncImage(url: FeedCachePaths.thumbnailURL(filename: filename)) { image in
                    image.resizable().aspectRatio(contentMode: contentMode)
                } placeholder: {
                    placeholder
                }
                .task(id: filename) {
                    guard lastTrackedFilename != filename else { return }
                    lastTrackedFilename = filename
                    await Self.referenceStore.recordThumbnailReference(filename: filename)
                }
            } else {
                placeholder
                    .task(id: video.id) {
                        guard video.thumbnailRemoteURL != nil else { return }
                        if cachedThumbnail?.videoID == video.id { return }
                        if let filename = await Self.writeService.cacheThumbnail(for: video) {
                            cachedThumbnail = CachedThumbnailReference(videoID: video.id, filename: filename)
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var localFilename: String? {
        if let filename = video.thumbnailLocalFilename {
            return filename
        }
        if cachedThumbnail?.videoID == video.id {
            return cachedThumbnail?.filename
        }
        return nil
    }

    private struct CachedThumbnailReference {
        let videoID: String
        let filename: String
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.gray.opacity(0.18))
    }
}

struct BackSwipePopModifier: ViewModifier {
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            if !path.isEmpty {
                Color.clear
                    .frame(width: BackSwipePolicy.activeRegionWidth)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                if BackSwipePolicy.shouldNavigateBack(startX: value.startLocation.x, translation: value.translation) {
                                    path.removeLast()
                                }
                            }
                    )
            }
        }
    }
}
