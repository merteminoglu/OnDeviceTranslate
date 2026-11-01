import Foundation
@preconcurrency import Translation
import TranslateCore

@MainActor
final class AppleTranslationService: TranslationService {
    private let languageAvailability = LanguageAvailability()
    private var activeSession: TranslationSession?

    func availability(for direction: TranslationDirection) async -> PackAvailability {
        let status = await languageAvailability.status(
            from: Locale.Language(identifier: direction.sourceCode),
            to: Locale.Language(identifier: direction.targetCode)
        )
        switch status {
        case .installed: return .installed
        case .supported: return .needsDownload
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    func translate(_ text: String, direction: TranslationDirection) async throws -> String {
        try Task.checkCancellation()
        // This initializer cannot request downloads, including if packs disappear
        // between the availability check and the translation call.
        let session = TranslationSession(
            installedSource: Locale.Language(identifier: direction.sourceCode),
            target: Locale.Language(identifier: direction.targetCode)
        )
        activeSession = session
        defer { if activeSession === session { activeSession = nil } }
        do {
            let response = try await session.translate(text)
            try Task.checkCancellation()
            return response.targetText
        } catch TranslationError.notInstalled {
            throw TranslationServiceError.packsMissing
        } catch TranslationError.unsupportedLanguagePairing {
            throw TranslationServiceError.unsupported
        } catch TranslationError.unsupportedSourceLanguage {
            throw TranslationServiceError.unsupported
        } catch TranslationError.unsupportedTargetLanguage {
            throw TranslationServiceError.unsupported
        } catch TranslationError.alreadyCancelled {
            throw CancellationError()
        }
    }

    func cancel() {
        activeSession?.cancel()
        activeSession = nil
    }
}
