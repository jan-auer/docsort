import OSLog

extension Logger {
  /// The unified-logging subsystem for all of the app's loggers. It matches the app's bundle identifier but is
  /// spelled out, because in SwiftUI previews `Bundle.main` is the preview host.
  nonisolated private static let subsystem = "org.jauer.Docsort"

  /// App launch and termination.
  nonisolated static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

  /// Loading and showing file previews.
  nonisolated static let preview = Logger(subsystem: subsystem, category: "preview")

  /// Opening files in other apps and revealing them in Finder.
  nonisolated static let fileActions = Logger(subsystem: subsystem, category: "file-actions")

  /// Loading, resolving and saving the configured folders (archive root and inboxes), and their bookmarks.
  nonisolated static let folders = Logger(subsystem: subsystem, category: "folders")

  /// Building the index of archive folders that destinations are searched in.
  nonisolated static let archiveIndex = Logger(subsystem: subsystem, category: "archive-index")

  /// The app's own preferences other than the folders, such as the search ranking.
  nonisolated static let preferences = Logger(subsystem: subsystem, category: "preferences")

  /// Scanning the inbox folders and marking the files handled in this session.
  nonisolated static let inbox = Logger(subsystem: subsystem, category: "inbox")

  /// Moving, trashing and undoing files, and loading and saving the filing history.
  nonisolated static let filing = Logger(subsystem: subsystem, category: "filing")

  /// Building the UI-test fixture (debug builds only).
  nonisolated static let fixture = Logger(subsystem: subsystem, category: "fixture")

  /// How AppKit laid out the main window: split view items and toolbar (debug builds only, `WindowLayoutProbe`).
  nonisolated static let windowLayout = Logger(subsystem: subsystem, category: "window-layout")

  /// The destination picker: listing the files of the chosen or highlighted folder.
  nonisolated static let picker = Logger(subsystem: subsystem, category: "picker")
}
