import OSLog
import SwiftUI

/// Identifiers of the app's window scenes, for `openWindow(id:)`.
enum SceneID {
  /// The main window.
  static let main = "main"
  /// The History window.
  static let history = "history"
}

@main
struct DocsortApp: App {
  /// The configured folders, loaded and resolved at launch.
  @State private var folders: FolderLibrary
  /// The index of archive folders, rebuilt whenever the folders change.
  @State private var archive: ArchiveLibrary
  /// The destination-search settings.
  @State private var search: SearchSettings
  /// The state of the one main window.
  @State private var mainWindowModel: MainWindowModel

  /// Builds the app's models from the environment for this launch: the user's real settings normally, an inert
  /// environment when the app hosts unit tests (see `AppEnvironment`).
  init() {
    Logger.lifecycle.notice("Docsort launched")
    let environment = AppEnvironment.forCurrentProcess()
    let folders = FolderLibrary(environment: environment)
    _folders = State(initialValue: folders)
    _archive = State(initialValue: ArchiveLibrary(folders: folders))
    _search = State(initialValue: SearchSettings(defaults: environment.defaults))
    _mainWindowModel = State(initialValue: MainWindowModel(folders: folders))
  }

  var body: some Scene {
    Window("docsort", id: SceneID.main) {
      MainWindowView(model: mainWindowModel)
    }
    .defaultSize(width: 1280, height: 800)
    .commands {
      MainCommands()
    }

    Window("History", id: SceneID.history) {
      HistoryWindowView(rows: [])
    }
    .defaultSize(width: 960, height: 520)
    // Window › History (⌘Y) in `MainCommands` opens it instead of the item SwiftUI would add for the scene.
    .commandsRemoved()

    Settings {
      SettingsView(folders: folders, archive: archive, search: search)
    }
  }
}
