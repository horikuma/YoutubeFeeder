import SwiftUI

struct ChannelRegistrationView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator

    @State private var input = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var feedback: ChannelRegistrationFeedback?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("チャンネル登録")
                    .font(.largeTitle.bold())

                Text("Channel ID、@handle、YouTube のチャンネル URL、動画 URL を入力できます。登録時は解決後の Channel ID を使います。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    TextField("UC... / @handle / チャンネルURL / 動画URL", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("channelRegistration.input")
                        .padding(14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("channelRegistration.error")
                    }
                }

                if let feedback {
                    registrationFeedbackCard(feedback)
                        .accessibilityIdentifier("channelRegistration.feedback")
                }

                Button {
                    submit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSubmitting ? "解決中..." : "追加する")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || trimmedInput.isEmpty)
                .accessibilityIdentifier("channelRegistration.submit")
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("チャンネル登録")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedInput.isEmpty else { return }

        errorMessage = nil
        feedback = nil
        isSubmitting = true

        Task {
            do {
                let result = try await coordinator.addChannel(input: trimmedInput)
                await MainActor.run {
                    feedback = result
                    input = ""
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }

    @ViewBuilder
    private func registrationFeedbackCard(_ feedback: ChannelRegistrationFeedback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(feedback.status == .added ? "チャンネルを登録しました" : "すでに登録済みでした")
                .font(.headline)

            Text(feedback.channelTitle)
                .font(.title3.bold())

            Text(feedback.channelID)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let latestVideoTitle = feedback.latestVideoTitle {
                Text("最新動画: \(latestVideoTitle)")
                    .font(.subheadline)

                if let latestPublishedAt = feedback.latestPublishedAt {
                    Text("公開日: \(latestPublishedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("最新動画はまだ取得できていません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("キャッシュ済み動画: \(feedback.cachedVideoCount) 件")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let latestFeedError = feedback.latestFeedError {
                Text("最新情報の取得は完了していません: \(latestFeedError)")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
