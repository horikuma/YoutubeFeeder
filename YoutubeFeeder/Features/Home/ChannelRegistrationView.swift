import SwiftUI
import UniformTypeIdentifiers

struct ChannelRegistrationView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator

    @State private var input = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var feedback: ChannelRegistrationFeedback?
    @State private var isImportingCSV = false
    @State private var importFeedback: ChannelCSVImportFeedback?
    @State private var isCSVImporterPresented = false

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

                if let importFeedback {
                    csvImportFeedbackCard(importFeedback)
                        .accessibilityIdentifier("channelRegistration.csvFeedback")
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

                Button {
                    beginCSVImport()
                } label: {
                    HStack {
                        if isImportingCSV {
                            ProgressView()
                        }
                        Text(isImportingCSV ? "CSVを読み込み中..." : "登録チャンネルCSVを読み込む")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting || isImportingCSV)
                .accessibilityIdentifier("channelRegistration.importCSV")

                Text("YouTube の登録チャンネル CSV を選ぶと、未登録の Channel ID だけを追加します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("チャンネル登録")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isCSVImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleCSVImporterResult
        )
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedInput.isEmpty else { return }

        errorMessage = nil
        feedback = nil
        importFeedback = nil
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

    private func beginCSVImport() {
        guard !isImportingCSV else { return }
        errorMessage = nil
        feedback = nil
        importFeedback = nil
        isCSVImporterPresented = true
    }

    private func handleCSVImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            importCSV(from: url)
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    private func importCSV(from url: URL) {
        errorMessage = nil
        feedback = nil
        importFeedback = nil
        isImportingCSV = true

        Task {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let result = try await coordinator.importChannelCSV(data: data, fileURL: url)
                await MainActor.run {
                    importFeedback = result
                    isImportingCSV = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImportingCSV = false
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

    @ViewBuilder
    private func csvImportFeedbackCard(_ feedback: ChannelCSVImportFeedback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
