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
  /// Saves a pending filing history at quit, asking before quitting when that fails.
  @NSApplicationDelegateAdaptor private var quitSaveDelegate: QuitSaveDelegate
  /// The configured folders, loaded and resolved at launch.
  @State private var folders: FolderLibrary
  /// The index of archive folders, rebuilt whenever the folders change.
  @State private var archive: ArchiveLibrary
  /// The destination-search settings.
  @State private var search: SearchSettings
  /// The inbox rows, rescanned whenever the inboxes change.
  @State private var inboxes: InboxLibrary
  /// Moving, trashing and undoing, with the filing history.
  @State private var filing: FilingModel
  /// The state of the one main window.
  @State private var mainWindowModel: MainWindowModel
  /// The state of the History window.
  @State private var historyModel: HistoryModel

  /// Builds the app's models from the environment for this launch: the user's real settings normally, an inert
  /// environment when the app hosts unit tests (see `AppEnvironment`).
  init() {
    Logger.lifecycle.notice("Docsort launched")
    let environment = AppEnvironment.forCurrentProcess()
    let folders = FolderLibrary(environment: environment)
    _folders = State(initialValue: folders)
    let archive = ArchiveLibrary(folders: folders)
    let search = SearchSettings(defaults: environment.defaults)
    let inboxes = InboxLibrary(folders: folders)
    let filing = FilingModel(
      service: .make(environment: environment), historyFileURL: environment.filingHistoryURL)
    _archive = State(initialValue: archive)
    _search = State(initialValue: search)
    _inboxes = State(initialValue: inboxes)
    _filing = State(initialValue: filing)
    let mainWindowModel = MainWindowModel(
      folders: folders, inboxes: inboxes, archive: archive, filing: filing, search: search)
    _mainWindowModel = State(initialValue: mainWindowModel)
    _historyModel = State(initialValue: HistoryModel(mainWindow: mainWindowModel))
  }

  var body: some Scene {
    Window("docsort", id: SceneID.main) {
      MainWindowView(model: mainWindowModel)
        .onAppear { quitSaveDelegate.filing = filing }
    }
    .defaultSize(width: 1280, height: 800)
    .commands {
      MainCommands()
    }

    Window("History", id: SceneID.history) {
      HistoryWindowView(model: historyModel)
    }
    .defaultSize(width: 1040, height: 560)
    // Window › History (⌘Y) in `MainCommands` opens it instead of the item SwiftUI would add for the scene.
    .commandsRemoved()

    Settings {
      SettingsView(folders: folders, archive: archive, search: search)
    }

    #if DEBUG
      // Shown only with the launch argument `-docsort-picker-test-host`, for the picker's own UI tests.
      PickerTestHostScene()
    #endif
  }
}
