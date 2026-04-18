import Foundation

extension FeedCacheCoordinator {
    func addChannel(input: String) async throws -> ChannelRegistrationFeedback {
        let beforeChannels = channels
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_start",
            source: "user_add_channel",
            beforeChannels: beforeChannels,
            afterChannels: beforeChannels
        )
        let execution: FeedChannelRegistrationExecution
        do {
            execution = try await channelRegistryMaintenanceService.addChannel(input: input)
        } catch {
            logChannelRegistryUserBoundary(
                "coordinator_user_mutation_failed",
                source: "user_add_channel",
                beforeChannels: beforeChannels,
                afterChannels: ChannelRegistryStore.loadAllChannelIDs(),
                metadata: ["error": AppConsoleLogger.errorSummary(error)]
            )
            throw error
        }
        channels = execution.channels
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError, includesVideos: false)
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_complete",
            source: "user_add_channel",
            beforeChannels: beforeChannels,
            afterChannels: channels
        )
        return execution.feedback
    }

    func removeChannel(_ channelID: String) async -> ChannelRemovalFeedback? {
        let beforeChannels = channels
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_start",
            source: "user_remove_channel",
            beforeChannels: beforeChannels,
            afterChannels: beforeChannels,
            metadata: ["channel_id": channelID]
        )
        guard let execution = await channelRegistryMaintenanceService.removeChannel(
            channelID: channelID,
            maintenanceItems: maintenanceItems,
            videos: videos
        ) else {
            logChannelRegistryUserBoundary(
                "coordinator_user_mutation_noop",
                source: "user_remove_channel",
                beforeChannels: beforeChannels,
                afterChannels: ChannelRegistryStore.loadAllChannelIDs(),
                metadata: ["channel_id": channelID]
            )
            return nil
        }

        channels = execution.channels
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_complete",
            source: "user_remove_channel",
            beforeChannels: beforeChannels,
            afterChannels: channels,
            metadata: ["channel_id": channelID]
        )
        return execution.feedback
    }

    func exportChannelRegistry(backend: ChannelRegistryTransferBackend) throws -> ChannelRegistryTransferFeedback {
        try channelRegistryMaintenanceService.exportChannelRegistry(backend: backend)
    }

    func importChannelRegistry(backend: ChannelRegistryTransferBackend) async throws -> ChannelRegistryTransferFeedback {
        let beforeChannels = channels
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_start",
            source: "user_import_channel_registry",
            beforeChannels: beforeChannels,
            afterChannels: beforeChannels
        )
        let execution: FeedChannelImportExecution
        do {
            execution = try channelRegistryMaintenanceService.importChannelRegistry(
                backend: backend,
                usesMockData: AppLaunchMode.current.usesMockData
            )
        } catch {
            logChannelRegistryUserBoundary(
                "coordinator_user_mutation_failed",
                source: "user_import_channel_registry",
                beforeChannels: beforeChannels,
                afterChannels: ChannelRegistryStore.loadAllChannelIDs(),
                metadata: ["error": AppConsoleLogger.errorSummary(error)]
            )
            throw error
        }
        await completeImportedChannelUpdate(
            channels: execution.channels,
            importedChannelIDs: execution.channels
        )
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_complete",
            source: "user_import_channel_registry",
            beforeChannels: beforeChannels,
            afterChannels: channels
        )

        return execution.feedback
    }

    func importChannelCSV(data: Data, fileURL: URL) async throws -> ChannelCSVImportFeedback {
        let beforeChannels = channels
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_start",
            source: "user_import_channel_csv",
            beforeChannels: beforeChannels,
            afterChannels: beforeChannels
        )
        let execution: FeedChannelCSVImportExecution
        do {
            execution = try channelRegistryMaintenanceService.importChannelsCSV(
                data: data,
                fileURL: fileURL,
                usesMockData: AppLaunchMode.current.usesMockData
            )
        } catch {
            logChannelRegistryUserBoundary(
                "coordinator_user_mutation_failed",
                source: "user_import_channel_csv",
                beforeChannels: beforeChannels,
                afterChannels: ChannelRegistryStore.loadAllChannelIDs(),
                metadata: ["error": AppConsoleLogger.errorSummary(error)]
            )
            throw error
        }
        await completeImportedChannelUpdate(
            channels: execution.channels,
            importedChannelIDs: execution.importedChannelIDs
        )
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_complete",
            source: "user_import_channel_csv",
            beforeChannels: beforeChannels,
            afterChannels: channels,
            metadata: ["imported_count": String(execution.importedChannelIDs.count)]
        )
        return execution.feedback
    }

    func resetAllSettings() async throws -> LocalStateResetFeedback {
        let beforeChannels = channels
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_start",
            source: "user_reset_all_settings",
            beforeChannels: beforeChannels,
            afterChannels: beforeChannels
        )
        let feedback: LocalStateResetFeedback
        do {
            feedback = try await channelRegistryMaintenanceService.resetAllSettings()
        } catch {
            logChannelRegistryUserBoundary(
                "coordinator_user_mutation_failed",
                source: "user_reset_all_settings",
                beforeChannels: beforeChannels,
                afterChannels: ChannelRegistryStore.loadAllChannelIDs(),
                metadata: ["error": AppConsoleLogger.errorSummary(error)]
            )
            throw error
        }

        resetRemoteSearchSnapshotCache()
        channels = []
        freshnessInterval = 60
        manualRefreshCount = 0
        lastManualChannelRefreshID = nil
        refreshProgress = .idle
        progress = CacheProgress(
            totalChannels: 0,
            cachedChannels: 0,
            cachedVideos: 0,
            cachedThumbnails: 0,
            currentChannelID: nil,
            currentChannelNumber: nil,
            lastUpdatedAt: nil,
            isRunning: false,
            lastError: nil
        )
        maintenanceItems = []
        videos = []
        await refreshHomeSystemStatus(
            snapshot: .empty,
            currentProgress: progress
        )
        logChannelRegistryUserBoundary(
            "coordinator_user_mutation_complete",
            source: "user_reset_all_settings",
            beforeChannels: beforeChannels,
            afterChannels: channels
        )

        return feedback
    }

    func logChannelRegistryCoordinatorSync(
        _ event: String,
        reason: String,
        storedChannels: [String],
        metadata: [String: String] = [:]
    ) {
        var result = metadata
        result["reason"] = reason
        result["coordinator_count"] = String(channels.count)
        result["store_count"] = String(storedChannels.count)
        result["store_minus_coordinator"] = String(storedChannels.count - channels.count)
        result["coordinator_fingerprint"] = AppConsoleLogger.channelIDsFingerprint(channels)
        result["store_fingerprint"] = AppConsoleLogger.channelIDsFingerprint(storedChannels)
        result["first_coordinator_channel"] = channels.first ?? ""
        result["first_store_channel"] = storedChannels.first ?? ""
        result["last_coordinator_channel"] = channels.last ?? ""
        result["last_store_channel"] = storedChannels.last ?? ""
        result["freshness_interval"] = String(Int(freshnessInterval))
        result["maintenance_items"] = String(maintenanceItems.count)
        result["has_manual_refresh"] = manualRefreshTask != nil ? "true" : "false"
        result["has_automatic_refresh"] = automaticRefreshTask != nil ? "true" : "false"
        result["main_thread"] = AppConsoleLogger.mainThreadFlag()
        AppConsoleLogger.channelRegistry.notice(event, metadata: result)
    }

    func logChannelRegistryUserBoundary(
        _ event: String,
        source: String,
        beforeChannels: [String],
        afterChannels: [String],
        metadata: [String: String] = [:]
    ) {
        var result = metadata
        result["source"] = source
        result["before_count"] = String(beforeChannels.count)
        result["after_count"] = String(afterChannels.count)
        result["delta"] = String(afterChannels.count - beforeChannels.count)
        result["before_fingerprint"] = AppConsoleLogger.channelIDsFingerprint(beforeChannels)
        result["after_fingerprint"] = AppConsoleLogger.channelIDsFingerprint(afterChannels)
        result["coordinator_count"] = String(channels.count)
        result["main_thread"] = AppConsoleLogger.mainThreadFlag()
        AppConsoleLogger.channelRegistry.notice(event, metadata: result)
    }
}
