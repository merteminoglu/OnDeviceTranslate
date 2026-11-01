import AppKit
import SwiftUI
import TranslateCore

struct TranslatorView: View {
    let model: TranslationModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var copied = false
    @State private var copyReset: Task<Void, Never>?
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    private var showsSetup: Bool { model.availability == .needsDownload || model.availability == .unsupported }

    var body: some View {
        Group {
            if showsSetup {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        languagePicker(source: true)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        languagePicker(source: false)
                    }
                    .padding(.top, 20)
                    LanguageSetupView(direction: model.direction, unsupported: model.availability == .unsupported) {
                        Task { await model.refreshAvailability() }
                    }
                }
            } else {
                workspace
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .background(WindowConfiguration())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Label(option.title, systemImage: option.symbolName).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Appearance", systemImage: appearance.symbolName)
                }
                .help("Appearance: \(appearance.title)")
                .accessibilityValue(appearance.title)
            }
            ToolbarItem(placement: .primaryAction) {
                Label("On device", systemImage: "lock.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .help("Translations use Apple’s installed models on this Mac. The app has no network access.")
            }
        }
        .task(id: model.direction) { await model.refreshAvailability() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshAvailability() } }
        }
        .onChange(of: model.translatedText) { _, _ in copied = false; copyReset?.cancel() }
    }

    // MARK: - Workspace

    private var workspace: some View {
        VStack(spacing: 0) {
            source
            Divider()
                .overlay { swapButton }
                .zIndex(1)
            result
        }
    }

    private var swapButton: some View {
        Button { model.swap() } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .glassEffect(.regular.interactive(), in: Circle())
        .help("Swap languages (⇧⌘S)")
        .accessibilityLabel("Swap \(model.direction.sourceName) and \(model.direction.targetName)")
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                languagePicker(source: true)
                Spacer()
                if !model.sourceText.isEmpty || model.isTranslating {
                    Button { model.clear() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear text (⌘K)")
                    .accessibilityLabel("Clear text")
                    .transition(.opacity)
                }
            }
            .frame(height: 28)

            ZStack(alignment: .topLeading) {
                if model.sourceText.isEmpty {
                    Text("Type or paste \(model.direction.sourceName) text")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                NativeTextEditor(
                    text: Binding(get: { model.sourceText }, set: { model.updateSource($0) }),
                    languageName: model.direction.sourceName,
                    onTranslate: translate
                )
            }
            .frame(minHeight: 96, maxHeight: .infinity)

            HStack(alignment: .center) {
                Text(model.wordCount == 0
                     ? "Translates as you type"
                     : "\(model.wordCount) \(model.wordCount == 1 ? "word" : "words")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .help("Translation starts after you pause typing for half a second. Use Translate or ⌘Return to start immediately.")
                Spacer()
                Button(action: translate) {
                    Text("Translate")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!model.canTranslate)
                .help("Translate now (⌘Return)")
                .accessibilityLabel("Translate to \(model.direction.targetName)")
            }
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 22)
        .frame(maxHeight: .infinity)
        .animation(.snappy(duration: 0.18), value: model.sourceText.isEmpty)
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                languagePicker(source: false)
                Spacer()
                status
            }
            .frame(height: 28)

            ScrollView {
                Group {
                    if model.translatedText.isEmpty {
                        Text(model.isTranslating ? " " : "Translation")
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(model.translatedText)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
                .font(.system(size: 22))
                .lineSpacing(4)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(model.direction.targetName) translation")
            }
            .scrollIndicators(.automatic)
            .frame(minHeight: 96, maxHeight: .infinity)
            .opacity(model.isTranslating ? 0.5 : 1)
            .animation(.easeOut(duration: 0.15), value: model.isTranslating)

            if let error = model.errorMessage {
                HStack(spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Try Again", action: translate)
                        .controlSize(.small)
                        .disabled(!model.canTranslate)
                }
                .accessibilityAddTraits(.updatesFrequently)
            }

            HStack {
                Spacer()
                Button(action: copy) {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.horizontal, 2)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(!model.canCopy)
                .help("Copy translation (⇧⌘C)")
                .accessibilityLabel(copied ? "Copied" : "Copy translation")
            }
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 22)
        .frame(maxHeight: .infinity)
        .background(Color.accentColor.opacity(0.05))
    }

    @ViewBuilder private var status: some View {
        if model.availability == .checking {
            ProgressView().controlSize(.small)
            Text("Checking languages…").font(.system(size: 11)).foregroundStyle(.secondary)
        } else if model.isTranslating {
            ProgressView().controlSize(.small)
            Text("Translating…").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Language menus

    private func languagePicker(source: Bool) -> some View {
        let selected = source ? model.direction.sourceLanguage : model.direction.targetLanguage
        return Menu {
            ForEach(TranslationLanguage.allCases) { language in
                Toggle(language.name, isOn: Binding(
                    get: { language == selected },
                    set: { _ in
                        if source { model.selectSource(language) } else { model.selectTarget(language) }
                    }
                ))
            }
        } label: {
            Text(selected.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(source ? Color.primary : Color.accentColor)
        }
        .menuStyle(.button)
        .menuIndicator(.visible)
        .buttonStyle(.glass)
        .fixedSize()
        .accessibilityLabel(source ? "Source language" : "Target language")
        .accessibilityValue(selected.name)
        .help(source ? "Choose the language to translate from" : "Choose the language to translate to")
    }

    // MARK: - Actions

    private func translate() { Task { await model.translate() } }

    private func copy() {
        guard copyTranslation(model) else { return }
        withAnimation(.snappy) { copied = true }
        copyReset?.cancel()
        copyReset = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { withAnimation(.snappy) { copied = false } }
        }
    }
}

private struct WindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ConfiguringView() }
    func updateNSView(_ view: NSView, context: Context) {}

    @MainActor private final class ConfiguringView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isRestorable = false
        }
    }
}
