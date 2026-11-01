import AppKit
import SwiftUI
import TranslateCore

@main
struct OnDeviceTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = TranslationModel(service: AppleTranslationService())
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        Window("Translate", id: "translate") {
            TranslatorView(model: model)
                .frame(minWidth: 420, minHeight: 510)
                .onChange(of: appearance, initial: true) { _, value in
                    NSApp.appearance = value.nsAppearance
                }
        }
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 540, height: 560)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(before: .toolbar) {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Divider()
            }
            CommandMenu("Translation") {
                Button("Translate") { Task { await model.translate() } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canTranslate)
                Button("Swap Languages") { model.swap() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Clear Text") { model.clear() }
                    .keyboardShortcut("k", modifiers: .command)
                Divider()
                Button("Copy Translation") { copyTranslation(model) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(!model.canCopy)
            }
        }
    }
}

/// Window appearance. `.system` (the default) follows System Settings, including
/// automatic light/dark switching; the others pin the app regardless of it.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"
    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// nil hands control back to macOS, so the app tracks the system setting live.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
@discardableResult
func copyTranslation(_ model: TranslationModel) -> Bool {
    guard model.canCopy else { return false }
    NSPasteboard.general.clearContents()
    return NSPasteboard.general.setString(model.translatedText, forType: .string)
}
