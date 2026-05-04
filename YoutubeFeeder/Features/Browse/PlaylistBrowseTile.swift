import SwiftUI

struct PlaylistBrowseTile: View {
    let item: PlaylistBrowseItem
    let previewVideo: CachedVideo
    let index: Int?
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ThumbnailView(video: previewVideo, contentMode: .fill)
                    .opacity(0.9)
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.red.opacity(0.95) : hoverBorderColor,
                        lineWidth: (isHovered || isSelected) ? 3 : 0
                    )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(item.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Text(item.itemCount.map { "\($0)本" } ?? "件数不明")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                if let index {
                    PlaylistTileIndexBadge(index: index)
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onHover {
                isHovered = $0
                AppConsoleLogger.browseTileInteraction.debug(
                    "tile_hover_state_changed",
                    metadata: [
                        "kind": "playlist_browse",
                        "playlistID": item.playlistID,
                        "isHovered": "\($0)"
                    ]
                )
            }
    }

    private var hoverBorderColor: Color {
        isHovered ? Color.blue.opacity(0.95) : .clear
    }
}

private struct PlaylistTileIndexBadge: View {
    let index: Int

    var body: some View {
        Text("\(index)")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(
                Circle().fill(Color.black.opacity(0.72))
            )
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}
