import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("HelloWorld")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Launching...")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(32)
        }
        .onAppear {
            StartupDiagnostics.shared.mark("splashShown")
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(minHeight: 120)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)

                if !value.isEmpty {
                    Text(value)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChannelStateLiveCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SystemStatusTile: View {
    let status: HomeSystemStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("システム状況")
                    .font(.headline)
                Spacer()
                Text("情報")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            statusRow(title: "登録チャンネル", value: "\(status.registeredChannelCount)件")
            statusRow(title: "動画キャッシュ", value: "\(status.cachedVideoCount)件")
            statusRow(title: "検索キャッシュ", value: "\(status.searchCacheStatus.label) / \(status.searchCacheStatus.totalCount)件")
            statusRow(title: "YouTube API", value: status.apiKeyConfigured ? "設定済み" : "未設定")
            statusRow(title: "最終更新", value: status.cacheLastUpdatedAt.map(Self.timestampFormatter.string(from:)) ?? "まだありません")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.secondary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityIdentifier("home.systemStatus")
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}
