import OSLog
import SwiftUI

@main
struct DocsortApp: App {
  init() {
    Logger.lifecycle.notice("Docsort launched")
  }

  var body: some Scene {
    WindowGroup {
      MainWindowView()
    }
    Settings {
      SettingsView()
    }
  }
}
