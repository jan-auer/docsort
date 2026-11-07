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
  /// The state of the one main window.
  ///
  /// No folders can be configured yet, so the window starts with the welcome view; the Settings step drives
  /// `areFoldersConfigured` from the folder settings.
  @State private var mainWindowModel = MainWindowModel(areFoldersConfigured: false)

  init() {
    Logger.lifecycle.notice("Docsort launched")
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
      SettingsView()
    }
  }
}
