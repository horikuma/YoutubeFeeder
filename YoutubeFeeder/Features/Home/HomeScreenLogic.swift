import Foundation

struct HomeScreenLogic: Hashable {
    var channelSortDescriptor: ChannelBrowseSortDescriptor = .default
    var transferFeedback: ChannelRegistryTransferFeedback?
    var resetFeedback: LocalStateResetFeedback?
    var transferErrorMessage: String?
    var isTransferringRegistry = false
    var isResettingAllSettings = false
    var shouldConfirmReset = false

    mutating func selectChannelSortDescriptor(_ descriptor: ChannelBrowseSortDescriptor) {
        channelSortDescriptor = descriptor
    }

    mutating func requestResetAllSettings() {
        shouldConfirmReset = true
    }

    mutating func beginRegistryTransfer() {
        resetFeedback = nil
        transferErrorMessage = nil
        isTransferringRegistry = true
    }

    mutating func finishRegistryTransfer(_ feedback: ChannelRegistryTransferFeedback) {
        transferFeedback = feedback
        isTransferringRegistry = false
    }

    mutating func failRegistryTransfer(_ error: Error) {
        transferFeedback = nil
        transferErrorMessage = error.localizedDescription
        isTransferringRegistry = false
    }

    mutating func beginResetAllSettings() {
        transferFeedback = nil
        transferErrorMessage = nil
        shouldConfirmReset = false
        isResettingAllSettings = true
    }

    mutating func finishResetAllSettings(_ feedback: LocalStateResetFeedback) {
        resetFeedback = feedback
        isResettingAllSettings = false
    }

    mutating func failResetAllSettings(_ error: Error) {
        resetFeedback = nil
        transferErrorMessage = error.localizedDescription
        isResettingAllSettings = false
    }
}
