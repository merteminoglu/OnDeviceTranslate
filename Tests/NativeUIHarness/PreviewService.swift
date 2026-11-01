// This file is compiled only by build-ui-preview.sh, never into Translate.app.
// It lets native focus/editor/copy behavior be checked without installed packs.
import Foundation
import TranslateCore

@MainActor
final class AppleTranslationService: TranslationService {
    func availability(for direction: TranslationDirection) async -> PackAvailability { .installed }

    func translate(_ text: String, direction: TranslationDirection) async throws -> String {
        try await Task.sleep(for: .milliseconds(200))
        if direction == .dutchToEnglish, text == "Hallo.\nHoe gaat het?" {
            return "Hello.\nHow are you?"
        }
        if direction == .englishToDutch, text == "Hello.\nHow are you?" {
            return "Hallo.\nHoe gaat het?"
        }
        throw TranslationServiceError.failed
    }

    func cancel() {}
}
