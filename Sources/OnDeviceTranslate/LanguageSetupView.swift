import AppKit
import SwiftUI
import TranslateCore

struct LanguageSetupView: View {
    var direction: TranslationDirection
    var unsupported: Bool
    var checkAgain: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 12)
            Image(systemName: unsupported ? "exclamationmark.bubble" : "translate")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.tint(.accentColor.opacity(0.12)), in: RoundedRectangle(cornerRadius: 15))
            VStack(spacing: 6) {
                Text(unsupported ? "Translation isn’t available yet" : "A little setup. Then offline.")
                    .font(.title2.weight(.semibold))
                Text(unsupported
                     ? "This Mac currently doesn’t support \(direction.sourceName) ↔ \(direction.targetName) translation. Choose another pair or check again after updating macOS."
                     : "Download the \(direction.sourceName) and \(direction.targetName) language packs in System Settings, then come back here.")
                    .font(.callout).foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            if !unsupported {
                VStack(spacing: 0) {
                    languageRow(direction.sourceName)
                    Divider().padding(.leading, 12)
                    languageRow(direction.targetName)
                }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 4)

                Text("General → Language & Region → Translation Languages")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if !unsupported {
                    Button("Open System Settings", action: openSettings)
                        .buttonStyle(.glassProminent)
                }
                Button("Check Again", action: checkAgain)
                    .buttonStyle(.glass)
            }
            .controlSize(.large)
            .padding(.top, 4)

            if !unsupported {
                Text("Downloading packs needs an internet connection. This app never goes online.")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 40).padding(.vertical, 24)
        .frame(maxWidth: 430, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }

    private func languageRow(_ name: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Label("Not installed", systemImage: "arrow.down.circle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
