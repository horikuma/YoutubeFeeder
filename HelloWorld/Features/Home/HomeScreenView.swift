import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    let navigationPath: Binding<NavigationPath>
    @State private var didRunAutoRefresh = false
    @State private var channelSortDescriptor: ChannelBrowseSortDescriptor = .default
    @State private var transferFeedback: ChannelRegistryTransferFeedback?
    @State private var transferErrorMessage: String?
    @State private var isTransferringRegistry = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                if AppLaunchMode.current.usesMockData {
                    UITestMarker(
                        identifier: "test.manualRefreshCount",
                        value: "\(coordinator.manualRefreshCount)"
                    )
                }

                Text("ホーム")
                    .font(layout.isPad ? .system(size: 38, weight: .black, design: .rounded) : .largeTitle.bold())
                    .accessibilityIdentifier("screen.home")

                navigationSection

                if let transferFeedback {
                    registryTransferFeedbackCard(transferFeedback)
                        .accessibilityIdentifier("home.transferFeedback")
                } else if let transferErrorMessage {
                    registryTransferErrorCard(transferErrorMessage)
                        .accessibilityIdentifier("home.transferError")
                }
            }
            .frame(maxWidth: layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await coordinator.refreshCacheManually()
        }
        .onAppear {
            diagnostics.mark("maintenanceShown")
        }
        .task {
            guard AppLaunchMode.current.autoRefreshOnLaunch else { return }
            guard !didRunAutoRefresh else { return }
            didRunAutoRefresh = true
            await coordinator.refreshCacheManually()
        }
    }

    private var navigationSection: some View {
        LazyVGrid(columns: layoutColumns, spacing: 16) {
            Menu {
                ForEach(ChannelBrowseSortMetric.allCases) { metric in
                    Section(metric.label) {
                        ForEach(SortDirection.allCases, id: \.self) { direction in
                            let option = ChannelBrowseSortDescriptor(metric: metric, direction: direction)
                            Button {
                                channelSortDescriptor = option
                                navigationPath.wrappedValue.append(MaintenanceRoute.channelList(option))
                            } label: {
                                HStack {
                                    Text(option.shortLabel)
                                    if option == channelSortDescriptor {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                MetricTile(
                    title: "チャンネル",
                    value: channelSortDescriptor.shortLabel,
                    detail: "並び順を選んでチャンネル一覧へ"
                )
            }
            .menuStyle(.borderlessButton)
            .accessibilityIdentifier("nav.channels")

            NavigationLink(value: MaintenanceRoute.allVideos) {
                MetricTile(
                    title: "動画",
                    value: "",
                    detail: "タップで動画一覧"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.videos")

            NavigationLink(value: MaintenanceRoute.channelRegistration) {
                MetricTile(
                    title: "チャンネル登録",
                    value: "",
                    detail: "タップで追加"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.channelRegistration")

            Menu {
                Button {
                    exportRegistry()
                } label: {
                    Label("iCloudへ書き出し", systemImage: "square.and.arrow.up")
                }

                Button {
                    importRegistry()
                } label: {
                    Label("iCloudから読み込み", systemImage: "square.and.arrow.down")
                }
            } label: {
                MetricTile(
                    title: "環境引き継ぎ",
                    value: isTransferringRegistry ? "処理中..." : "",
                    detail: transferFeedback?.detail ?? "iCloud の固定JSONへ書き出し / 読み戻し"
                )
            }
            .menuStyle(.borderlessButton)
            .disabled(isTransferringRegistry)
            .accessibilityIdentifier("nav.registryTransfer")
        }
    }

    private func exportRegistry() {
        guard !isTransferringRegistry else { return }
        transferErrorMessage = nil
        isTransferringRegistry = true

        Task {
            do {
                let feedback = try coordinator.exportChannelRegistryToICloud()
                await MainActor.run {
                    transferFeedback = feedback
                    isTransferringRegistry = false
                }
            } catch {
                await MainActor.run {
                    transferFeedback = nil
                    transferErrorMessage = error.localizedDescription
                    isTransferringRegistry = false
                }
            }
        }
    }

    private func importRegistry() {
        guard !isTransferringRegistry else { return }
        transferErrorMessage = nil
        isTransferringRegistry = true

        Task {
            do {
                let feedback = try await coordinator.importChannelRegistryFromICloud()
                await MainActor.run {
                    transferFeedback = feedback
                    isTransferringRegistry = false
                }
            } catch {
                await MainActor.run {
                    transferFeedback = nil
                    transferErrorMessage = error.localizedDescription
                    isTransferringRegistry = false
                }
            }
        }
    }

    private func registryTransferFeedbackCard(_ feedback: ChannelRegistryTransferFeedback) -> some View {
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

    private func registryTransferErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("環境引き継ぎを完了できませんでした")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(ChannelRegistryTransferStore.fixedPathDescription())
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var layoutColumns: [GridItem] {
        if layout.isPad {
            return [
                GridItem(.flexible(), spacing: 16, alignment: .top),
                GridItem(.flexible(), spacing: 16, alignment: .top),
            ]
        }

        return [GridItem(.flexible(), spacing: 16, alignment: .top)]
    }
}

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
