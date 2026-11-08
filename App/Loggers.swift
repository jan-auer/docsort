import OSLog

extension Logger {
  /// The unified-logging subsystem for all of the app's loggers. It matches the app's bundle identifier but is
  /// spelled out, because in SwiftUI previews `Bundle.main` is the preview host.
  nonisolated private static let subsystem = "org.jauer.Docsort"

  /// App launch and termination.
  nonisolated static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

  /// The destination picker: listing the files of the chosen or highlighted folder.
  nonisolated static let picker = Logger(subsystem: subsystem, category: "picker")
}
