import DocsortCore
import Foundation
import OSLog

/// The dependencies the app's models are built with: where preferences are stored, how configured folders are
/// resolved, and where the filing history lives.
///
/// `DocsortApp` builds one per process with `forCurrentProcess()`, which picks by `AppLaunchMode`:
/// - `.standard`: `live()`, the user's real preferences, security-scoped bookmarks and history file.
/// - `.unitTestHost`: `inert(named:)`, so that the `DocsortTests` unit tests, which the app hosts, never read or change
///   the user's settings, bookmarks or filing history. The app then starts with no folders configured. Tests build
///   their own environments (with fake bookmarks) for the models they test.
///
/// A further launch mode, for example a UI-test fixture, gets its own case in `AppLaunchMode` and its own factory
/// here; the models only ever see the environment.
struct AppEnvironment {
  /// Where the folder settings and the other preferences are stored.
  let defaults: UserDefaults
  /// Creates bookmarks for picked folders and resolves the configured folders, starting their security scopes.
  let folderResolver: FolderResolver
  /// The JSON file the filing history is loaded from and saved to.
  let filingHistoryURL: URL

  /// The environment of a normal launch: standard user defaults, security-scoped bookmarks with the system's scope
  /// access, and the history file in Application Support.
  static func live() -> AppEnvironment {
    AppEnvironment(
      defaults: .standard,
      folderResolver: FolderResolver(),
      filingHistoryURL: FilingHistoryStore.defaultFileURL())
  }

  /// An environment that touches nothing of the user's: an emptied `UserDefaults` suite of its own (so no folders
  /// are configured), and a history file in the temporary directory.
  ///
  /// `name` keeps different inert environments apart (the unit-test host, previews). The suite is cleared each time
  /// this is called, so every launch starts from nothing.
  static func inert(named name: String) -> AppEnvironment {
    let suiteName = "org.jauer.Docsort.inert.\(name)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      // `UserDefaults(suiteName:)` fails only for the app's own bundle identifier or the global domain, which the
      // fixed prefix above rules out.
      preconditionFailure("Could not create the user defaults suite \(suiteName)")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return AppEnvironment(
      defaults: defaults,
      folderResolver: FolderResolver(),
      filingHistoryURL: URL.temporaryDirectory
        .appending(path: "Docsort-\(name)", directoryHint: .isDirectory)
        .appending(path: "FilingHistory.json", directoryHint: .notDirectory))
  }

  /// The environment for this process's launch mode; see the type's documentation.
  static func forCurrentProcess() -> AppEnvironment {
    let launchMode = AppLaunchMode.current()
    switch launchMode {
    case .standard:
      return live()
    case .unitTestHost:
      Logger.lifecycle.notice(
        "Running as the unit-test host: using an inert environment, not the user's settings")
      return inert(named: "unit-test-host")
    }
  }
}

/// How the app process was started, which decides its `AppEnvironment`.
nonisolated enum AppLaunchMode: Equatable, Sendable {
  /// A normal launch by the user.
  case standard
  /// The app hosts the `DocsortTests` unit tests: XCTest has set `XCTestConfigurationFilePath` in its environment.
  case unitTestHost

  /// The launch mode that `processEnvironment` (by default this process's environment variables) describes.
  static func current(
    processEnvironment: [String: String] = ProcessInfo.processInfo.environment
  ) -> AppLaunchMode {
    processEnvironment["XCTestConfigurationFilePath"] == nil ? .standard : .unitTestHost
  }
}
