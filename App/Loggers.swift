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
}
