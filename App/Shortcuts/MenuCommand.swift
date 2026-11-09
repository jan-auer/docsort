import SwiftUI

/// The app's own menu-bar commands that have a keyboard shortcut. `MainCommands` takes each shortcut from here and
/// the keyboard shortcuts sheet lists them, so the two cannot drift apart; `ShortcutCatalogTests` checks the real menu
/// bar against the sheet.
enum MenuCommand: CaseIterable {
  /// File › Open.
  case open
  /// File › Reveal in Finder.
  case revealInFinder
  /// File › Open Destination in Finder.
  case openDestinationInFinder
  /// File › Move.
  case move
  /// File › Revert Name.
  case revertName
  /// File › Move to Trash.
  case moveToTrash
  /// File › Move Back to Inbox, or Put Back for a trashed file.
  case returnToInbox
  /// View › Refresh.
  case refresh
  /// View › Show or Hide Filing Panel.
  case toggleFilingPanel
  /// View › Zoom In.
  case zoomIn
  /// View › Zoom Out.
  case zoomOut
  /// View › Zoom to Fit.
  case zoomToFit
  /// Go › Previous File.
  case previousFile
  /// Go › Next File.
  case nextFile
  /// Window › History.
  case history
  /// Help › Keyboard Shortcuts.
  case keyboardShortcuts

  /// The command's shortcut.
  var keys: KeyCombination {
    switch self {
    case .open: KeyCombination("o", modifiers: .command)
    case .revealInFinder: KeyCombination("r", modifiers: [.option, .command])
    // ⇧ marks the folder variant of Open, as in ⇧⌘N (New Folder).
    case .openDestinationInFinder: KeyCombination("o", modifiers: [.shift, .command])
    case .move: KeyCombination(.return, modifiers: .command)
    case .revertName: KeyCombination("r", modifiers: [.shift, .command])
    case .moveToTrash: KeyCombination(.delete, modifiers: .command)
    case .returnToInbox: KeyCombination("z", modifiers: [.option, .command])
    case .refresh: KeyCombination("r", modifiers: .command)
    case .toggleFilingPanel: KeyCombination("i", modifiers: [.option, .command])
    case .zoomIn: KeyCombination("+", modifiers: .command)
    case .zoomOut: KeyCombination("-", modifiers: .command)
    case .zoomToFit: KeyCombination("0", modifiers: .command)
    case .previousFile: KeyCombination(.upArrow, modifiers: [.option, .command])
    case .nextFile: KeyCombination(.downArrow, modifiers: [.option, .command])
    case .history: KeyCombination("y", modifiers: .command)
    case .keyboardShortcuts: KeyCombination("/", modifiers: .command)
    }
  }
}

extension View {
  /// Gives the view `command`'s keyboard shortcut.
  func keyboardShortcut(for command: MenuCommand) -> some View {
    keyboardShortcut(command.keys.keyboardShortcut)
  }
}
