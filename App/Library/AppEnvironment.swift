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
/// - `.uiTestFixture` (debug builds only): `UITestFixture.makeEnvironment()`, a freshly built invented archive and
///   inboxes in the app's temporary directory, for the UI tests.
///
/// The models only ever see the environment.
struct AppEnvironment {
  /// Where the folder settings and the other preferences are stored.
  let defaults: UserDefaults
  /// Creates bookmarks for picked folders and resolves the configured folders, starting their security scopes.
  let folderResolver: FolderResolver
  /// The JSON file the filing history is loaded from and saved to.
  let filingHistoryURL: URL
  /// Where Move to Trash sends files: the user's Trash, except in the UI-test fixture.
  var fileTrash: any FileTrash = SystemTrash()

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
    case .uiTestFixture:
      #if DEBUG
        Logger.lifecycle.notice("Running with the UI-test fixture, not the user's settings")
        return UITestFixture.makeEnvironment()
      #else
        // `current()` returns this mode only in debug builds.
        return live()
      #endif
    }
  }
}

/// How the app process was started, which decides its `AppEnvironment`.
nonisolated enum AppLaunchMode: Equatable, Sendable {
  /// A normal launch by the user.
  case standard
  /// The app hosts the `DocsortTests` unit tests: XCTest has set `XCTestConfigurationFilePath` in its environment.
  case unitTestHost
  /// A UI test launched the app with `uiTestFixtureArgument` (debug builds only).
  case uiTestFixture

  /// The launch argument with which UI tests ask for the UI-test fixture.
  static let uiTestFixtureArgument = "-docsort-ui-test-fixture"

  /// The launch mode that `processEnvironment` and `arguments` (by default this process's environment variables and
  /// launch arguments) describe.
  static func current(
    processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) -> AppLaunchMode {
    #if DEBUG
      if arguments.contains(uiTestFixtureArgument) { return .uiTestFixture }
    #endif
    return processEnvironment["XCTestConfigurationFilePath"] == nil ? .standard : .unitTestHost
  }
}
