import AppKit
import OSLog

/// Opening a file in its default app and revealing it in Finder, shared by the main window and the History window.
enum FileActions {
  /// Opens the file at `url` in the app Launch Services opens it with by default. A failure is logged.
  static func open(_ url: URL) {
    Task {
      do {
        _ = try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
      } catch {
        Logger.fileActions.error(
          "Opening \(url.path(percentEncoded: false), privacy: .private) failed: \(error.localizedDescription)"
        )
      }
    }
  }

  /// Shows the file at `url` selected in a Finder window and brings Finder to the front.
  static func revealInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}
