import Combine
import SwiftUI

@MainActor
final class HomeScreenViewModel: ObservableObject {
    let coordinator: FeedCacheCoordinator
    let diagnostics: StartupDiagnostics
    let layout: AppLayout

    @Published var state = HomeScreenLogic()
    @Published var shouldMountRemoteSearchPrewarmHost = false
    @Published var remoteSearchPrewarmPath = NavigationPath()

    private var didRunAutoRefresh = false
    private var didPrewarmRemoteSearch = false

    init(
        coordinator: FeedCacheCoordinator,
        layout: AppLayout,
        diagnostics: StartupDiagnostics
    ) {
        self.coordinator = coordinator
        self.layout = layout
        self.diagnostics = diagnostics
    }

    func onAppear() {
        diagnostics.mark("maintenanceShown")
        AppConsoleLogger.appLifecycle.info(
            "home_shown",
            metadata: [
                "layout": layout.usesSplitChannelBrowser ? "split" : "compact",
                "registered_channels": String(coordinator.homeSystemStatus.registeredChannelCount),
                "cached_videos": String(coordinator.homeSystemStatus.cachedVideoCount)
            ]
        )
    }

    func refreshHome() async {
        _ = await coordinator.performRefreshAction(.home)
    }

    func performAutoRefreshTaskIfNeeded() async {
        AppConsoleLogger.appLifecycle.info(
            "home_auto_refresh_task_started",
            metadata: [
                "auto_refresh_on_launch": AppLaunchMode.current.autoRefreshOnLaunch ? "true" : "false",
                "background_refresh": AppLaunchMode.current.allowsBackgroundRefresh ? "true" : "false",
                "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
            ]
        )
        guard AppLaunchMode.current.autoRefreshOnLaunch else {
            AppConsoleLogger.appLifecycle.info(
                "home_auto_refresh_task_skipped",
                metadata: [
                    "reason": "disabled_on_launch",
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                ]
            )
            return
        }
        guard !didRunAutoRefresh else {
            AppConsoleLogger.appLifecycle.info(
                "home_auto_refresh_task_skipped",
                metadata: [
                    "reason": "already_ran",
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                ]
            )
            return
        }
        didRunAutoRefresh = true
        AppConsoleLogger.appLifecycle.info(
            "home_auto_refresh_manual_refresh_started",
            metadata: [
                "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
            ]
        )
        await coordinator.refreshCacheManually()
        AppConsoleLogger.appLifecycle.info(
            "home_auto_refresh_manual_refresh_finished",
            metadata: [
                "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
            ]
        )
        guard AppLaunchMode.current.allowsBackgroundRefresh else {
            AppConsoleLogger.appLifecycle.info(
                "home_auto_refresh_wall_clock_scheduler_skipped",
                metadata: [
                    "reason": "background_refresh_disabled",
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                ]
            )
            return
        }
        AppConsoleLogger.appLifecycle.info(
            "home_auto_refresh_wall_clock_scheduler_requested",
            metadata: [
                "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
            ]
        )
        coordinator.startChannelRefreshWallClockSchedulerIfNeeded()
    }

    func prewarmRemoteSearchIfNeeded() async {
        guard !didPrewarmRemoteSearch else { return }
        didPrewarmRemoteSearch = true
        coordinator.prewarmRemoteSearchSnapshot(keyword: FeedCacheCoordinator.homeSearchKeyword)
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        shouldMountRemoteSearchPrewarmHost = true
    }

    func selectChannelSortDescriptor(_ descriptor: ChannelBrowseSortDescriptor) {
        state.selectChannelSortDescriptor(descriptor)
    }

    func requestResetAllSettings() {
        state.requestResetAllSettings()
    }

    func exportRegistry() {
        guard !state.isTransferringRegistry else { return }
        state.beginRegistryTransfer()
        let logger = AppConsoleLogger.homeTransfer
        logger.info("export_started", metadata: ["backend": "localDocuments"])

        Task {
            do {
                let feedback = try coordinator.exportChannelRegistry(backend: .localDocuments)
                state.finishRegistryTransfer(feedback)
                logger.info(
                    "export_completed",
                    metadata: [
                        "backend": feedback.backend.rawValue,
                        "channel_count": String(feedback.channelCount)
                    ]
                )
            } catch {
                state.failRegistryTransfer(error)
                logger.error(
                    "export_failed",
                    message: AppConsoleLogger.errorSummary(error),
                    metadata: ["backend": "localDocuments"]
                )
            }
        }
    }

    func importRegistry() {
        guard !state.isTransferringRegistry else { return }
        state.beginRegistryTransfer()

        Task {
            do {
                let feedback = try await coordinator.importChannelRegistry(backend: .localDocuments)
                state.finishRegistryTransfer(feedback)
            } catch {
                state.failRegistryTransfer(error)
            }
        }
    }

    func resetAllSettings() {
        guard !state.isResettingAllSettings else { return }
        state.beginResetAllSettings()

        Task {
            do {
                let feedback = try await coordinator.resetAllSettings()
                state.finishResetAllSettings(feedback)
            } catch {
                state.failResetAllSettings(error)
            }
        }
    }
}
