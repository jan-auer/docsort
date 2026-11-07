import OSLog

extension Logger {
  /// Loading and showing file previews. It repeats the subsystem of `App/Loggers.swift`, whose constant is private
  /// to that file; the two must stay equal.
  nonisolated static let preview = Logger(subsystem: "org.jauer.Docsort", category: "preview")
}
