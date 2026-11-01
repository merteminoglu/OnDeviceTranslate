import Foundation

public enum TranslationLanguage: String, Sendable, CaseIterable, Identifiable {
    case dutch = "nl", english = "en", turkish = "tr"

    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .dutch: "Dutch"
        case .english: "English"
        case .turkish: "Turkish"
        }
    }
}

public enum TranslationDirection: String, Sendable, CaseIterable {
    case dutchToEnglish, englishToDutch
    case turkishToEnglish, englishToTurkish
    case turkishToDutch, dutchToTurkish

    private var languages: (source: TranslationLanguage, target: TranslationLanguage) {
        switch self {
        case .dutchToEnglish: (.dutch, .english)
        case .englishToDutch: (.english, .dutch)
        case .turkishToEnglish: (.turkish, .english)
        case .englishToTurkish: (.english, .turkish)
        case .turkishToDutch: (.turkish, .dutch)
        case .dutchToTurkish: (.dutch, .turkish)
        }
    }

    public var sourceLanguage: TranslationLanguage { languages.source }
    public var targetLanguage: TranslationLanguage { languages.target }
    public var sourceName: String { sourceLanguage.name }
    public var targetName: String { targetLanguage.name }
    public var sourceCode: String { sourceLanguage.rawValue }
    public var targetCode: String { targetLanguage.rawValue }
    public var reversed: Self {
        switch self {
        case .dutchToEnglish: .englishToDutch
        case .englishToDutch: .dutchToEnglish
        case .turkishToEnglish: .englishToTurkish
        case .englishToTurkish: .turkishToEnglish
        case .turkishToDutch: .dutchToTurkish
        case .dutchToTurkish: .turkishToDutch
        }
    }

    public static func between(_ source: TranslationLanguage, and target: TranslationLanguage) -> Self? {
        allCases.first { $0.sourceLanguage == source && $0.targetLanguage == target }
    }
}

public enum PackAvailability: Sendable, Equatable {
    case checking, installed, needsDownload, unsupported
}

public enum TranslationServiceError: LocalizedError {
    case packsMissing, unsupported, failed

    public var errorDescription: String? {
        switch self {
        case .packsMissing: "Install the selected language packs in System Settings, then try again."
        case .unsupported: "Translation between these languages is unavailable on this Mac."
        case .failed: "Translation couldn’t finish. Your text is still here. Try again."
        }
    }
}

@MainActor
public protocol TranslationService: AnyObject {
    func availability(for direction: TranslationDirection) async -> PackAvailability
    func translate(_ text: String, direction: TranslationDirection) async throws -> String
    func cancel()
}
