import Foundation

#if canImport(UIKit)
    import UIKit
#endif

/// Makes it so the manager is mockable
protocol MockablePasteboard {
    var string: String? { get set }
    var hasURLs: Bool { get }
}

extension UIPasteboard: MockablePasteboard {}

/// Result from clipboard retrieval
internal struct ClipboardResult {
    let url: URL?
}

/// Manages clipboard-based deferred deep links
internal class ClipboardManager {
    private let logger = AppLinksSDKLogger.shared.withCategory("clipboard-manager")
    private var pasteBoard: MockablePasteboard

    init(pasteboard: MockablePasteboard = UIPasteboard.general) {
        self.pasteBoard = pasteboard
    }

    /// Retrieve deferred deep link from clipboard
    func retrieveDeferredDeepLink() async -> ClipboardResult {
        // First check if clipboard has URLs (doesn't trigger permission)
        guard hasUrlOnClipboard() else {
            logger.debug("[AppLinksSDK] No URL detected in clipboard")
            return ClipboardResult(url: nil)
        }

        // Now access the content (may trigger permission on first use)
        guard let clipboardContent = pasteBoard.string,
            !clipboardContent.isEmpty
        else {
            logger.debug("[AppLinksSDK] No content in clipboard")
            return ClipboardResult(url: nil)
        }

        // Try to parse as URL
        guard let url = URL(string: clipboardContent.trimmingCharacters(in: .whitespaces)) else {
            logger.debug("[AppLinksSDK] Clipboard content is not a valid URL")
            return ClipboardResult(url: nil)
        }

        logger.info("[AppLinksSDK] Found URL in clipboard: \(url)")

        // Clear clipboard to prevent re-processing
        clearClipboard()

        return ClipboardResult(url: url)
    }

    // MARK: - Private Methods

    private func clearClipboard() {
        pasteBoard.string = ""
        logger.debug("[AppLinksSDK] Cleared clipboard content")
    }

    private func hasUrlOnClipboard() -> Bool {
        #if !os(tvOS)
            return pasteBoard.hasURLs
        #else
            return false
        #endif
    }
}
