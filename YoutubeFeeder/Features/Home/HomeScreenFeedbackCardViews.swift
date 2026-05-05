import SwiftUI

struct HomeScreenRegistryTransferFeedbackCardView: View {
    let feedback: ChannelRegistryTransferFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedback.title)
                .font(.headline)

            Text(feedback.detail)
                .font(.subheadline)

            Text(feedback.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let refreshMessage = feedback.refreshMessage {
                Text(refreshMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct HomeScreenRegistryTransferErrorCardView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("バックアップを完了できませんでした")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(ChannelRegistryTransferStore.fixedPathDescription(backend: .localDocuments))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct HomeScreenResetFeedbackCardView: View {
    let feedback: LocalStateResetFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedback.title)
                .font(.headline)

            Text(feedback.detail)
                .font(.subheadline)

            Text("バックアップから戻す場合は、Documents/YoutubeFeeder/channel-registry.json を読み込んでください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
