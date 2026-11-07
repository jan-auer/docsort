import Foundation
import OSLog

extension Logger {
  /// The unified-logging subsystem for all of the app's loggers: the app's bundle identifier.
  nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "org.jauer.Docsort"

  /// App launch and termination.
  nonisolated static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
