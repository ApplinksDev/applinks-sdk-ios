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
    private let enableLogging: Bool
    private var pasteBoard: MockablePasteboard

    init(enableLogging: Bool, pasteboard: MockablePasteboard = UIPasteboard.general) {
        self.enableLogging = enableLogging
        self.pasteBoard = pasteboard
    }

    /// Retrieve deferred deep link from clipboard
    func retrieveDeferredDeepLink() async -> ClipboardResult {
        // First check if clipboard has URLs (doesn't trigger permission)
        guard hasUrlOnClipboard() else {
            if enableLogging {
                print("[ClipboardManager] No URL detected in clipboard")
            }
            return ClipboardResult(url: nil)
        }

        // Now access the content (may trigger permission on first use)
        guard let clipboardContent = pasteBoard.string,
            !clipboardContent.isEmpty
        else {
            if enableLogging {
                print("[ClipboardManager] No content in clipboard")
            }
            return ClipboardResult(url: nil)
        }

        // Try to parse as URL
        guard let url = URL(string: clipboardContent.trimmingCharacters(in: .whitespaces)) else {
            if enableLogging {
                print("[ClipboardManager] Clipboard content is not a valid URL")
            }
            return ClipboardResult(url: nil)
        }

        if enableLogging {
            print("[ClipboardManager] Found URL in clipboard: \(url)")
        }

        // Clear clipboard to prevent re-processing
        clearClipboard()

        return ClipboardResult(url: url)
    }

    // MARK: - Private Methods

    private func clearClipboard() {
        pasteBoard.string = ""
        if enableLogging {
            print("[ClipboardManager] Cleared clipboard content")
        }
    }

    private func hasUrlOnClipboard() -> Bool {
        #if !os(tvOS)
            return pasteBoard.hasURLs
        #else
            return false
        #endif
    }
}
