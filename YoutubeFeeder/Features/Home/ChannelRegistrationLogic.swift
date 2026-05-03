import Foundation

struct ChannelRegistrationLogic: Hashable {
    var errorMessage: String?
    var feedback: ChannelRegistrationFeedback?
    var isSubmitting = false
    var isImportingCSV = false
    var importFeedback: ChannelCSVImportFeedback?
    var isCSVImporterPresented = false

    mutating func beginSubmit() {
        errorMessage = nil
        feedback = nil
        importFeedback = nil
        isSubmitting = true
    }

    mutating func finishSubmit(_ feedback: ChannelRegistrationFeedback) {
        self.feedback = feedback
        isSubmitting = false
    }

    mutating func failSubmit(_ error: Error) {
        errorMessage = error.localizedDescription
        isSubmitting = false
    }

    mutating func beginCSVImport() {
        errorMessage = nil
        feedback = nil
        importFeedback = nil
    }

    mutating func requestCSVImport() {
        guard !isImportingCSV else { return }
        beginCSVImport()
        isCSVImporterPresented = true
    }

    mutating func failCSVImportPresentation(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    mutating func beginCSVImport(fromFile _: URL) {
        errorMessage = nil
        feedback = nil
        importFeedback = nil
        isImportingCSV = true
    }

    mutating func finishCSVImport(_ feedback: ChannelCSVImportFeedback) {
        importFeedback = feedback
        isImportingCSV = false
    }

    mutating func failCSVImport(_ error: Error) {
        errorMessage = error.localizedDescription
        isImportingCSV = false
    }
}
