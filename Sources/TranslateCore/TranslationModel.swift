import Foundation
import Observation

@MainActor @Observable
public final class TranslationModel {
    public private(set) var sourceText = ""
    public private(set) var translatedText = ""
    public private(set) var direction: TranslationDirection = .dutchToEnglish
    public private(set) var availability: PackAvailability = .checking
    public private(set) var isTranslating = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let service: any TranslationService
    @ObservationIgnored private var translationRevision: UInt64 = 0
    @ObservationIgnored private var availabilityRevision: UInt64 = 0
    @ObservationIgnored private var automaticTranslationTask: Task<Void, Never>?

    public init(service: any TranslationService) { self.service = service }

    public var canTranslate: Bool {
        availability == .installed && !isTranslating && !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var canCopy: Bool { !translatedText.isEmpty && !isTranslating && errorMessage == nil }
    public var wordCount: Int { sourceText.split(whereSeparator: \.isWhitespace).count }

    public func updateSource(_ text: String) {
        guard text != sourceText else { return }
        invalidateTranslation()
        sourceText = text
        translatedText = ""
        errorMessage = nil
        scheduleAutomaticTranslation()
    }

    public func clear() {
        invalidateTranslation()
        sourceText = ""
        translatedText = ""
        errorMessage = nil
    }

    public func swap() {
        let newSource = canCopy ? translatedText : sourceText
        invalidateTranslation()
        direction = direction.reversed
        sourceText = newSource
        translatedText = ""
        errorMessage = nil
        availabilityRevision &+= 1
        availability = .checking
    }

    public func selectSource(_ language: TranslationLanguage) {
        guard language != direction.sourceLanguage else { return }
        if language == direction.targetLanguage { swap(); return }
        guard let selected = TranslationDirection.between(language, and: direction.targetLanguage) else { return }
        changeDirection(to: selected)
    }

    public func selectTarget(_ language: TranslationLanguage) {
        guard language != direction.targetLanguage else { return }
        if language == direction.sourceLanguage { swap(); return }
        guard let selected = TranslationDirection.between(direction.sourceLanguage, and: language) else { return }
        changeDirection(to: selected)
    }

    private func changeDirection(to selected: TranslationDirection) {
        invalidateTranslation()
        direction = selected
        translatedText = ""
        errorMessage = nil
        availabilityRevision &+= 1
        availability = .checking
    }

    public func refreshAvailability() async {
        availabilityRevision &+= 1
        let revision = availabilityRevision
        let requestedDirection = direction
        availability = .checking
        let status = await service.availability(for: requestedDirection)
        guard revision == availabilityRevision, !Task.isCancelled else { return }
        availability = status
        if status != .installed {
            invalidateTranslation()
            translatedText = ""
        } else if translatedText.isEmpty && errorMessage == nil {
            scheduleAutomaticTranslation()
        }
    }

    public func translate() async {
        guard canTranslate else { return }
        automaticTranslationTask?.cancel()
        automaticTranslationTask = nil
        translationRevision &+= 1
        let revision = translationRevision
        availabilityRevision &+= 1
        let packRevision = availabilityRevision
        let text = sourceText
        let requestedDirection = direction
        isTranslating = true
        errorMessage = nil
        translatedText = ""
        defer { if revision == translationRevision { isTranslating = false } }

        let status = await service.availability(for: requestedDirection)
        guard revision == translationRevision, !Task.isCancelled else { return }
        if packRevision == availabilityRevision {
            guard status == .installed else {
                availability = status
                return
            }
        } else {
            // A newer completed check is authoritative. The installed-only
            // session still refuses downloads if packs disappear after it.
            guard availability == .installed else { return }
        }

        do {
            let result = try await service.translate(text, direction: requestedDirection)
            guard revision == translationRevision, !Task.isCancelled else { return }
            translatedText = result
        } catch is CancellationError {
            // Clearing, editing, and changing direction intentionally cancel work.
        } catch {
            guard revision == translationRevision, !Task.isCancelled else { return }
            if case TranslationServiceError.packsMissing = error {
                availabilityRevision &+= 1
                availability = .needsDownload
            } else if case TranslationServiceError.unsupported = error {
                availabilityRevision &+= 1
                availability = .unsupported
            } else {
                errorMessage = TranslationServiceError.failed.localizedDescription
            }
        }
    }

    private func scheduleAutomaticTranslation() {
        automaticTranslationTask?.cancel()
        automaticTranslationTask = nil
        guard canTranslate else { return }
        automaticTranslationTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.automaticTranslationTask = nil
            await self.translate()
        }
    }

    private func invalidateTranslation() {
        automaticTranslationTask?.cancel()
        automaticTranslationTask = nil
        translationRevision &+= 1
        if isTranslating { service.cancel() }
        isTranslating = false
    }
}
