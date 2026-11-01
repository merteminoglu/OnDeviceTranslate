import Testing
@testable import TranslateCore

// Releasing controlled requests out of order exercises races that the Apple
// framework can produce, without requiring installed models on the test Mac.
@MainActor
private final class ControlledService: TranslationService {
    var packState: PackAvailability = .installed
    var translations: [(text: String, direction: TranslationDirection, continuation: CheckedContinuation<String, any Error>)] = []
    var delayAvailability = false
    var checks: [(direction: TranslationDirection, continuation: CheckedContinuation<PackAvailability, Never>)] = []

    func availability(for direction: TranslationDirection) async -> PackAvailability {
        if delayAvailability {
            return await withCheckedContinuation { checks.append((direction, $0)) }
        }
        return packState
    }

    func translate(_ text: String, direction: TranslationDirection) async throws -> String {
        try await withCheckedThrowingContinuation { translations.append((text, direction, $0)) }
    }

    func cancel() {}
}

@Suite @MainActor
struct TranslationModelTests {
    @Test(arguments: [
        ("dutchToEnglish", "nl", "en"), ("englishToDutch", "en", "nl"),
        ("turkishToEnglish", "tr", "en"), ("englishToTurkish", "en", "tr"),
        ("turkishToDutch", "tr", "nl"), ("dutchToTurkish", "nl", "tr")
    ])
    func languagePairsRouteAndReverseCorrectly(_ raw: String, _ source: String, _ target: String) throws {
        let direction = try #require(TranslationDirection(rawValue: raw))
        #expect(direction.sourceCode == source)
        #expect(direction.targetCode == target)
        #expect(direction.reversed.sourceCode == target)
        #expect(direction.reversed.targetCode == source)
        #expect(direction.reversed.reversed == direction)
    }

    private func ready(_ service: ControlledService = ControlledService()) async -> TranslationModel {
        let model = TranslationModel(service: service)
        await model.refreshAvailability()
        return model
    }

    private func waitForRequest(_ service: ControlledService, count: Int = 1) async throws {
        for _ in 0..<1000 {
            if service.translations.count >= count { return }
            await Task.yield()
        }
        throw TestFailure.requestDidNotStart
    }

    private enum TestFailure: Error { case requestDidNotStart, engineFailed }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw TestFailure.requestDidNotStart
    }

    @Test func typingAutomaticallyTranslatesAfterPause() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        try await Task.sleep(for: .milliseconds(200))
        model.updateSource("Hallo wereld")
        try await Task.sleep(for: .milliseconds(350))
        #expect(service.translations.isEmpty)
        try await waitUntil { service.translations.count == 1 }
        #expect(service.translations[0].text == "Hallo wereld")
        service.translations[0].continuation.resume(returning: "Hello world")
        try await waitUntil { model.canCopy }
        #expect(model.translatedText == "Hello world")
    }

    @Test func clearingCancelsPendingAutomaticTranslation() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        model.clear()
        try await Task.sleep(for: .milliseconds(650))
        #expect(service.translations.isEmpty)
        #expect(model.translatedText.isEmpty)
    }

    @Test func whitespaceDoesNotStartAutomaticTranslation() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        model.updateSource(" \n\t ")
        try await Task.sleep(for: .milliseconds(650))
        #expect(service.translations.isEmpty)
    }

    @Test func manualTranslationDoesNotRunAgainAfterDelay() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        service.translations[0].continuation.resume(returning: "Hello")
        await task.value
        try await Task.sleep(for: .milliseconds(650))
        #expect(service.translations.count == 1)
        #expect(model.translatedText == "Hello")
    }

    @Test func editingDuringAutomaticTranslationRejectsOldResult() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Oud")
        try await waitUntil { service.translations.count == 1 }
        model.updateSource("Nieuw")
        try await waitUntil { service.translations.count == 2 }
        service.translations[1].continuation.resume(returning: "New")
        try await waitUntil { model.translatedText == "New" }
        service.translations[0].continuation.resume(returning: "Old")
        try await Task.sleep(for: .milliseconds(50))
        #expect(model.translatedText == "New")
        #expect(model.canCopy)
    }

    @Test func changingLanguageAutomaticallyRetranslates() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        model.selectTarget(.turkish)
        await model.refreshAvailability()
        try await waitUntil { service.translations.count == 1 }
        #expect(service.translations[0].direction == .dutchToTurkish)
        service.translations[0].continuation.resume(returning: "Merhaba")
        try await waitUntil { model.canCopy }
        #expect(model.translatedText == "Merhaba")
    }

    @Test func swapAutomaticallyTranslatesSuccessfulResult() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        service.translations[0].continuation.resume(returning: "Hello")
        await task.value
        model.swap()
        await model.refreshAvailability()
        try await waitUntil { service.translations.count == 2 }
        #expect(service.translations[1].text == "Hello")
        #expect(service.translations[1].direction == .englishToDutch)
        service.translations[1].continuation.resume(returning: "Hallo")
        try await waitUntil { model.canCopy }
        #expect(model.translatedText == "Hallo")
    }

    @Test func installingPacksAutomaticallyTranslatesWaitingText() async throws {
        let service = ControlledService()
        service.packState = .needsDownload
        let model = await ready(service)
        model.updateSource("Hallo")
        try await Task.sleep(for: .milliseconds(650))
        #expect(service.translations.isEmpty)
        service.packState = .installed
        await model.refreshAvailability()
        try await waitUntil { service.translations.count == 1 }
        service.translations[0].continuation.resume(returning: "Hello")
        try await waitUntil { model.canCopy }
        await model.refreshAvailability()
        try await Task.sleep(for: .milliseconds(650))
        #expect(service.translations.count == 1)
        #expect(model.translatedText == "Hello")
    }

    @Test func turkishSelectionRoutesUnicodeText() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.selectSource(.turkish)
        await model.refreshAvailability()
        model.updateSource("İyi günler. Yarın görüşürüz.")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        #expect(service.translations[0].direction == .turkishToEnglish)
        #expect(service.translations[0].text == "İyi günler. Yarın görüşürüz.")
        service.translations[0].continuation.resume(returning: "Good day. See you tomorrow.")
        await task.value
        #expect(model.translatedText == "Good day. See you tomorrow.")
        model.swap()
        #expect(model.direction == .englishToTurkish)
        #expect(model.sourceText == "Good day. See you tomorrow.")
    }

    @Test func targetChangeRejectsOldResult() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        model.selectTarget(.turkish)
        service.translations[0].continuation.resume(returning: "Hello")
        await task.value
        #expect(model.direction == .dutchToTurkish)
        #expect(model.sourceText == "Hallo")
        #expect(model.translatedText.isEmpty)
        #expect(model.availability == .checking)
        #expect(!model.canCopy)
    }

    @Test func selectingOtherSideLanguageReversesPair() async {
        let model = await ready()
        model.updateSource("Hallo")
        model.selectSource(.english)
        #expect(model.direction == .englishToDutch)
        #expect(model.sourceText == "Hallo")
        model.selectTarget(.english)
        #expect(model.direction == .dutchToEnglish)
    }

    @Test func selectingCurrentLanguageKeepsSuccessfulResult() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        service.translations[0].continuation.resume(returning: "Hello")
        await task.value
        model.selectSource(.dutch)
        model.selectTarget(.english)
        #expect(model.translatedText == "Hello")
        #expect(model.canCopy)
    }

    @Test func whitespaceCannotTranslate() async {
        let model = await ready()
        model.updateSource(" \n\t ")
        #expect(!model.canTranslate)
        #expect(model.wordCount == 0)
    }

    @Test func successfulTranslationPreservesMultilineInput() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo.\nHoe gaat het?")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        #expect(service.translations[0].text == "Hallo.\nHoe gaat het?")
        #expect(service.translations[0].direction == .dutchToEnglish)
        service.translations[0].continuation.resume(returning: "Hello.\nHow are you?")
        await task.value
        #expect(model.translatedText == "Hello.\nHow are you?")
        #expect(model.canCopy)
        #expect(!model.isTranslating)
        #expect(model.wordCount == 4)
    }

    @Test(arguments: [PackAvailability.needsDownload, .unsupported])
    func unavailablePacksPreventTranslation(_ state: PackAvailability) async {
        let service = ControlledService()
        service.packState = state
        let model = await ready(service)
        model.updateSource("Hallo")
        await model.translate()
        #expect(model.availability == state)
        #expect(!model.canTranslate)
        #expect(service.translations.isEmpty)
    }

    @Test func removedPacksAreRecheckedBeforeTranslation() async {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        service.packState = .needsDownload
        await model.translate()
        #expect(model.availability == .needsDownload)
        #expect(service.translations.isEmpty)
    }

    @Test func changedInputRejectsLateResult() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Oud")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        model.updateSource("Nieuw")
        service.translations[0].continuation.resume(returning: "Old")
        await task.value
        #expect(model.sourceText == "Nieuw")
        #expect(model.translatedText.isEmpty)
        #expect(!model.canCopy)
        #expect(!model.isTranslating)
    }

    @Test func clearRejectsLateError() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        model.clear()
        service.translations[0].continuation.resume(throwing: TestFailure.engineFailed)
        await task.value
        #expect(model.sourceText.isEmpty)
        #expect(model.translatedText.isEmpty)
        #expect(model.errorMessage == nil)
        #expect(!model.isTranslating)
    }

    @Test func failurePreservesTextAndAllowsRetry() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        service.translations[0].continuation.resume(throwing: TestFailure.engineFailed)
        await task.value
        #expect(model.sourceText == "Hallo")
        #expect(model.errorMessage != nil)
        #expect(model.canTranslate)
        #expect(!model.canCopy)
    }

    @Test func swapUsesSuccessfulResultAsNewSource() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        service.translations[0].continuation.resume(returning: "Hello")
        await task.value
        model.swap()
        #expect(model.direction == .englishToDutch)
        #expect(model.sourceText == "Hello")
        #expect(model.translatedText.isEmpty)
        #expect(!model.canCopy)
    }

    @Test func swapDuringRequestPreservesInputAndRejectsResult() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        let task = Task { await model.translate() }
        try await waitForRequest(service)
        model.swap()
        service.translations[0].continuation.resume(returning: "Hello")
        await task.value
        #expect(model.direction == .englishToDutch)
        #expect(model.sourceText == "Hallo")
        #expect(model.translatedText.isEmpty)
    }

    @Test func availabilityChecksCannotOverwriteNewDirection() async {
        let service = ControlledService()
        service.delayAvailability = true
        let model = TranslationModel(service: service)
        let first = Task { await model.refreshAvailability() }
        while service.checks.count < 1 { await Task.yield() }
        model.swap()
        let second = Task { await model.refreshAvailability() }
        while service.checks.count < 2 { await Task.yield() }
        service.checks[1].continuation.resume(returning: .installed)
        await second.value
        service.checks[0].continuation.resume(returning: .needsDownload)
        await first.value
        #expect(model.direction == .englishToDutch)
        #expect(model.availability == .installed)
    }

    @Test func translationPreflightCannotOverwriteNewerAvailability() async throws {
        let service = ControlledService()
        let model = await ready(service)
        model.updateSource("Hallo")
        service.delayAvailability = true
        let translation = Task { await model.translate() }
        while service.checks.count < 1 { await Task.yield() }
        let newerCheck = Task { await model.refreshAvailability() }
        while service.checks.count < 2 { await Task.yield() }
        service.checks[1].continuation.resume(returning: .installed)
        await newerCheck.value
        service.checks[0].continuation.resume(returning: .needsDownload)
        try await waitForRequest(service)
        service.translations[0].continuation.resume(returning: "Hello")
        await translation.value
        #expect(model.availability == .installed)
        #expect(model.translatedText == "Hello")
        #expect(!model.isTranslating)
    }
}
