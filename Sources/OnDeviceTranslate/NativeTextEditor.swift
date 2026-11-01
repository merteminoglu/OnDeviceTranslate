import AppKit
import SwiftUI

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var languageName: String
    var onTranslate: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let editor = TranslationTextView()
        editor.delegate = context.coordinator
        editor.drawsBackground = false
        editor.isRichText = false
        editor.isEditable = true
        editor.isSelectable = true
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.font = .systemFont(ofSize: 22)
        editor.textColor = .labelColor
        editor.insertionPointColor = .controlAccentColor
        editor.textContainerInset = NSSize(width: 0, height: 4)
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.widthTracksTextView = true
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.onTranslate = onTranslate
        editor.setAccessibilityLabel("\(languageName) text to translate")
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? TranslationTextView else { return }
        context.coordinator.parent = self
        editor.onTranslate = onTranslate
        editor.setAccessibilityLabel("\(languageName) text to translate")
        if editor.string != text {
            let wasEmpty = editor.string.isEmpty
            editor.string = text
            // An external Clear or Swap starts a new document; undo must not
            // resurrect the preceding translation's source text.
            editor.undoManager?.removeAllActions()
            editor.setSelectedRange(NSRange(location: wasEmpty ? text.utf16.count : 0, length: 0))
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        init(_ parent: NativeTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}

@MainActor
private final class TranslationTextView: NSTextView {
    var onTranslate: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers == .command, event.keyCode == 36 || event.keyCode == 76 {
            onTranslate?()
            return
        }
        super.keyDown(with: event)
    }
}
