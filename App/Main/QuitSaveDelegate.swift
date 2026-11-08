import AppKit
import DocsortCore
import OSLog

/// Saves a filing history that failed to save earlier one last time before the app quits (the approved
/// history-save-failure policy), and asks the user whether to quit anyway when it still fails.
///
/// `DocsortApp` installs it as the application delegate and hands it the app's `FilingModel` once the models exist.
final class QuitSaveDelegate: NSObject, NSApplicationDelegate {
  /// The app's filing model; until it is set there is nothing to save.
  var filing: FilingModel?

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let filing, filing.pendingSaveError != nil else { return .terminateNow }
    Task {
      let saved = await filing.saveBeforeQuit()
      if saved {
        Logger.filing.notice("Saved the filing history before quitting")
        sender.reply(toApplicationShouldTerminate: true)
        return
      }
      let reason = filing.pendingSaveError?.description ?? "Unknown error."
      Logger.filing.error(
        "The filing history still cannot be saved at quit: \(reason, privacy: .public)")
      sender.reply(toApplicationShouldTerminate: Self.confirmQuitWithoutSaving(reason: reason))
    }
    return .terminateLater
  }

  /// Asks whether to quit although the latest filing history could not be saved; true for Quit Anyway.
  private static func confirmQuitWithoutSaving(reason: String) -> Bool {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "The filing history could not be saved"
    alert.informativeText =
      "If you quit now, the files moved since the last successful save can't be moved back after a restart. "
      + "Reason: \(reason)"
    alert.addButton(withTitle: "Cancel")
    let quitButton = alert.addButton(withTitle: "Quit Anyway")
    quitButton.hasDestructiveAction = true
    return alert.runModal() == .alertSecondButtonReturn
  }
}
