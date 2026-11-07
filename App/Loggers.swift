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
}
