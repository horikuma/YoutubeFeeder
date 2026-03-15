import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    let navigationPath: Binding<NavigationPath>
    @State private var didRunAutoRefresh = false

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
            NavigationLink(value: MaintenanceRoute.channelList) {
                MetricTile(
                    title: "チャンネル",
                    value: "",
                    detail: "タップでチャンネル一覧"
                )
            }
            .buttonStyle(.plain)
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
        }
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
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("チャンネル登録")
                    .font(.largeTitle.bold())

                Text("Channel ID、@handle、YouTube のチャンネル URL を入力できます。登録時は解決後の Channel ID を使います。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    TextField("UC... / @handle / URL", text: $input)
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
        isSubmitting = true

        Task {
            do {
                _ = try await coordinator.addChannel(input: trimmedInput)
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}
