import OSLog

extension Logger {
  /// The unified-logging subsystem for all of the app's loggers. It matches the app's bundle identifier but is
  /// spelled out, because in SwiftUI previews `Bundle.main` is the preview host.
  nonisolated private static let subsystem = "org.jauer.Docsort"

  /// App launch and termination.
  nonisolated static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
