import AppKit
import OSLog

/// Opening a file in its default app or another one, revealing it in Finder and copying its name or path, shared by
/// the main window, the History window, the destination picker (which opens and reveals archive folders) and Folder
/// contents.
enum FileActions {
  /// Opens the file at `url` in the app Launch Services opens it with by default, a folder in a Finder window. A
  /// failure is logged.
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

  /// Opens the file at `url` with the app at `applicationURL`. A failure is logged.
  static func open(_ url: URL, with applicationURL: URL) {
    Task {
      do {
        _ = try await NSWorkspace.shared.open(
          [url], withApplicationAt: applicationURL, configuration: NSWorkspace.OpenConfiguration())
      } catch {
        Logger.fileActions.error(
          "Opening \(url.path(percentEncoded: false), privacy: .private) with \(applicationURL.lastPathComponent, privacy: .public) failed: \(error.localizedDescription)"
        )
      }
    }
  }

  /// The apps that open the file at `url`: the default one first, then the others by name.
  static func applications(toOpen url: URL) -> [OpenWithApplication] {
    let workspace = NSWorkspace.shared
    let defaultURL = workspace.urlForApplication(toOpen: url)
    return workspace.urlsForApplications(toOpen: url)
      .map { applicationURL in
        OpenWithApplication(
          url: applicationURL,
          name: displayName(ofApplicationAt: applicationURL),
          icon: workspace.icon(forFile: applicationURL.path(percentEncoded: false)),
          isDefault: applicationURL == defaultURL)
      }
      .sorted { lhs, rhs in
        if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
      }
  }

  /// The app's name as Finder shows it, without a trailing ".app" (shown when the user has extensions turned on).
  private static func displayName(ofApplicationAt url: URL) -> String {
    let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
    return name.hasSuffix(".app") ? String(name.dropLast(".app".count)) : name
  }

  /// Puts `text` on the general pasteboard, as Copy does.
  static func copy(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}

/// An app that can open a file, for Open With.
struct OpenWithApplication: Identifiable {
  /// Where the app is.
  let url: URL
  /// The app's name as Finder shows it.
  let name: String
  /// The app's icon.
  let icon: NSImage
  /// Whether it is the app the file opens with by default.
  let isDefault: Bool

  var id: URL { url }
}
