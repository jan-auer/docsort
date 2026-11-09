import Foundation
import SwiftUI

/// Where a shortcut works.
enum ShortcutContext: Hashable, Sendable {
  /// Anywhere in the main window: the menu-bar commands.
  case anywhere
  /// While the inbox sidebar has focus.
  case sidebar
  /// While the destination picker's filter has focus.
  case destinationPicker
  /// While a new folder's name is being typed in the destination picker.
  case newFolderName
  /// While the filing panel's name field has focus.
  case nameField
  /// While the filing panel's Folder contents list has focus.
  case folderContents
  /// While the Quick Look panel is open, from the sidebar or Folder contents.
  case quickLookPanel
  /// In the History window.
  case history

  /// The context's heading in the sheet.
  var title: String {
    switch self {
    case .anywhere: "Anywhere"
    case .sidebar: "Sidebar"
    case .destinationPicker: "Destination Picker"
    case .newFolderName: "New Folder Name"
    case .nameField: "Name Field"
    case .folderContents: "Folder Contents"
    case .quickLookPanel: "Quick Look Panel"
    case .history: "History Window"
    }
  }
}

/// What the user presses for a shortcut.
enum ShortcutTrigger: Hashable, Sendable {
  /// Any one of these keys.
  case keys([KeyCombination])
  /// Two keys for the two halves of a title such as "Previous / Next File" (↑ / ↓).
  case pair(KeyCombination, KeyCombination)
  /// Typing text.
  case typing

  /// Every key combination the trigger names.
  var combinations: [KeyCombination] {
    switch self {
    case .keys(let keys): keys
    case .pair(let first, let second): [first, second]
    case .typing: []
    }
  }
}

/// One row of the keyboard shortcuts sheet.
struct ShortcutEntry: Hashable, Identifiable, Sendable {
  /// What the shortcut does, in menu-title style ("Move to Trash").
  let title: String
  /// When it applies, if not always ("Outside text fields").
  let note: String?
  /// What to press.
  let trigger: ShortcutTrigger

  init(_ title: String, note: String? = nil, _ trigger: ShortcutTrigger) {
    self.title = title
    self.note = note
    self.trigger = trigger
  }

  /// A menu command's row.
  init(_ title: String, note: String? = nil, _ command: MenuCommand) {
    self.init(title, note: note, .keys([command.keys]))
  }

  /// Titles are unique within a section.
  var id: String { title }
}

/// The shortcuts of one context.
struct ShortcutSection: Hashable, Identifiable, Sendable {
  let context: ShortcutContext
  let entries: [ShortcutEntry]

  var id: ShortcutContext { context }
  var title: String { context.title }
}

/// Every keyboard shortcut of the app, grouped by where it works, as the keyboard shortcuts sheet lists it.
///
/// The Anywhere section lists the menu bar: `MainCommands` takes its shortcuts from ``MenuCommand``, and a hosted test
/// compares the real menu bar with this section. The other sections list keys that views handle themselves; their
/// combinations come from the picker's ``PickerKey``, the Quick Look panel's ``QuickLookPanelKey`` and the name
/// field's ``TextFieldKeyCommand`` where those exist, and the tests check that every such key is listed. The sidebar's
/// and Folder contents' keys come from `onKeyPress` handlers and are written out by hand.
struct ShortcutCatalog: Sendable {
  let sections: [ShortcutSection]

  /// The sections and rows that match `query`: every word of the query must start a word of the row's title, note,
  /// section title or key names ("cmd", "esc", "⌘Y"), ignoring case and diacritics. A blank query matches everything.
  func sections(matching query: String) -> [ShortcutSection] {
    let queryWords = Self.fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
    guard !queryWords.isEmpty else { return sections }
    return sections.compactMap { section in
      let entries = section.entries.filter { entry in
        let words = Self.searchWords(of: entry, in: section)
        return queryWords.allSatisfy { queryWord in words.contains { $0.hasPrefix(queryWord) } }
      }
      return entries.isEmpty ? nil : ShortcutSection(context: section.context, entries: entries)
    }
  }

  /// The words a search matches against for `entry`.
  private static func searchWords(of entry: ShortcutEntry, in section: ShortcutSection) -> [String]
  {
    let text = [entry.title, entry.note ?? "", section.title].joined(separator: " ")
    let textWords = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
    var keyWords = entry.trigger.combinations.flatMap(\.searchWords)
    if entry.trigger == .typing { keyWords.append("type") }
    return (textWords + keyWords).filter { !$0.isEmpty }.map(fold)
  }

  private static func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }
}

extension ShortcutCatalog {
  /// The app's shortcuts.
  static let main = ShortcutCatalog(sections: [
    ShortcutSection(
      context: .anywhere,
      entries: [
        ShortcutEntry("Move", note: "To the chosen folder, with the entered name", .move),
        ShortcutEntry("Revert Name", .revertName),
        ShortcutEntry("Move to Trash", note: "Outside text fields", .moveToTrash),
        ShortcutEntry(
          "Move Back to Inbox", note: "Put Back for a file in the Trash", .returnToInbox),
        ShortcutEntry("Undo / Redo", .pair(undo, redo)),
        ShortcutEntry("Open", .open),
        ShortcutEntry("Reveal in Finder", .revealInFinder),
        ShortcutEntry("Open Destination in Finder", .openDestinationInFinder),
        ShortcutEntry(
          "Previous / Next File", .pair(MenuCommand.previousFile.keys, MenuCommand.nextFile.keys)),
        ShortcutEntry("Show or Hide Sidebar", .keys([toggleSidebar])),
        ShortcutEntry("Show or Hide Filing Panel", .toggleFilingPanel),
        ShortcutEntry("Refresh", note: "Rescans the inboxes and the archive", .refresh),
        ShortcutEntry("Zoom In", .zoomIn),
        ShortcutEntry("Zoom Out", .zoomOut),
        ShortcutEntry("Zoom to Fit", .zoomToFit),
        ShortcutEntry("History", .history),
        ShortcutEntry("Settings", .keys([settings])),
        ShortcutEntry("Keyboard Shortcuts", .keyboardShortcuts),
      ]),
    ShortcutSection(
      context: .sidebar,
      entries: [
        ShortcutEntry(
          "Previous / Next File", .pair(KeyCombination(.upArrow), KeyCombination(.downArrow))),
        ShortcutEntry(
          "Expand / Collapse Group", .pair(KeyCombination(.rightArrow), KeyCombination(.leftArrow))),
        ShortcutEntry(
          "Go to Destination Picker", .keys([KeyCombination(.tab), KeyCombination(.return)])),
        ShortcutEntry("Quick Look", .keys([KeyCombination(.space)])),
        ShortcutEntry(
          "Search Destinations", note: "Starts the folder filter with what you type", .typing),
      ]),
    ShortcutSection(
      context: .destinationPicker,
      entries: [
        ShortcutEntry("Filter Folders", note: "An empty filter shows Recent first", .typing),
        ShortcutEntry(
          "Move Highlight Up / Down", .pair(KeyCombination(.upArrow), KeyCombination(.downArrow))),
        ShortcutEntry("Into Highlighted Folder", .keys([KeyCombination(.rightArrow)])),
        ShortcutEntry(
          "Out to Parent Folder", note: "With an empty filter",
          .keys([KeyCombination(.leftArrow), KeyCombination(pickerKey: .delete)])),
        ShortcutEntry("Archive Root", .keys([KeyCombination(pickerKey: .commandUpArrow)])),
        ShortcutEntry(
          "Choose Folder", note: "And go on to the name",
          .keys([KeyCombination(pickerKey: .tab), KeyCombination(pickerKey: .returnKey)])),
        ShortcutEntry("Back to Sidebar", .keys([KeyCombination(pickerKey: .shiftTab)])),
        ShortcutEntry(
          "Clear Filter", note: "When there is nothing to clear, back to the sidebar",
          .keys([KeyCombination(pickerKey: .escape)])),
        ShortcutEntry(
          "New Folder", note: "Inside the highlighted folder",
          .keys([KeyCombination(pickerKey: .shiftCommandN)])),
        ShortcutEntry(
          "Move Now", note: "With the highlighted folder",
          .keys([KeyCombination(pickerKey: .commandReturn)])),
      ]),
    ShortcutSection(
      context: .newFolderName,
      entries: [
        ShortcutEntry(
          "Create Folder",
          .keys([KeyCombination(pickerKey: .returnKey), KeyCombination(pickerKey: .tab)])),
        ShortcutEntry(
          "Create Folder and Move", .keys([KeyCombination(pickerKey: .commandReturn)])),
        ShortcutEntry(
          "Cancel New Folder",
          .keys([KeyCombination(pickerKey: .escape), KeyCombination(pickerKey: .shiftTab)])),
      ]),
    ShortcutSection(
      context: .nameField,
      entries: [
        ShortcutEntry("Move", note: "Return alone doesn’t move", .move),
        ShortcutEntry("Revert Name", .revertName),
        ShortcutEntry(
          "Back to Destination Picker",
          .keys([
            KeyCombination(textFieldCommand: .backTab), KeyCombination(textFieldCommand: .cancel),
          ])),
        ShortcutEntry("Back to Sidebar", .keys([KeyCombination(textFieldCommand: .tab)])),
      ]),
    ShortcutSection(
      context: .folderContents,
      entries: [
        ShortcutEntry(
          "Previous / Next File", .pair(KeyCombination(.upArrow), KeyCombination(.downArrow))),
        ShortcutEntry("Quick Look", .keys([KeyCombination(.space)])),
        ShortcutEntry(
          "Use Name", note: "Or double-click",
          .keys([KeyCombination(.return)])),
      ]),
    ShortcutSection(
      context: .quickLookPanel,
      entries: [
        ShortcutEntry(
          "Previous / Next File", note: "In the list it was opened from",
          .pair(
            KeyCombination(quickLookPanelKey: .upArrow),
            KeyCombination(quickLookPanelKey: .downArrow))),
        ShortcutEntry(
          "Close Quick Look",
          .keys([
            KeyCombination(quickLookPanelKey: .space), KeyCombination(quickLookPanelKey: .escape),
          ])),
      ]),
    ShortcutSection(
      context: .history,
      entries: [
        ShortcutEntry("Open", .open),
        ShortcutEntry("Reveal in Finder", .revealInFinder),
        ShortcutEntry(
          "Move Back to Inbox", note: "Put Back for a file in the Trash", .returnToInbox),
        ShortcutEntry(
          "Clear Search", note: "With an empty search, closes the window",
          .keys([KeyCombination(.escape)])),
      ]),
  ])

  /// Edit › Undo, from the window's undo manager.
  private static let undo = KeyCombination("z", modifiers: .command)
  /// Edit › Redo, from the window's undo manager.
  private static let redo = KeyCombination("z", modifiers: [.shift, .command])
  /// View › Show or Hide Sidebar, from SwiftUI's `SidebarCommands` (⌃⌘S on macOS 27).
  private static let toggleSidebar = KeyCombination("s", modifiers: [.control, .command])
  /// docsort › Settings, from the `Settings` scene.
  private static let settings = KeyCombination(",", modifiers: .command)

  /// Shortcuts the menu bar has in every Mac app, which the sheet leaves out: quitting, hiding, closing and minimizing
  /// windows, full screen, the text editing commands, Emoji & Symbols and Help.
  static let standardMacShortcuts: [KeyCombination] = [
    KeyCombination("q", modifiers: .command),
    KeyCombination("h", modifiers: .command),
    KeyCombination("h", modifiers: [.option, .command]),
    KeyCombination("w", modifiers: .command),
    KeyCombination("w", modifiers: [.option, .command]),
    KeyCombination("m", modifiers: .command),
    KeyCombination("f", modifiers: [.control, .command]),
    KeyCombination("x", modifiers: .command),
    KeyCombination("c", modifiers: .command),
    KeyCombination("v", modifiers: .command),
    KeyCombination("a", modifiers: .command),
    KeyCombination(.space, modifiers: .command),
    KeyCombination("?", modifiers: .command),
  ]
}

extension KeyCombination {
  /// The key `pickerKey` stands for.
  ///
  /// The switch covers every ``PickerKey``: a new picker key fails to compile here until it has a combination, and
  /// `ShortcutCatalogTests` then asks for its row under Destination Picker.
  init(pickerKey: PickerKey) {
    switch pickerKey {
    case .upArrow: self.init(.upArrow)
    case .downArrow: self.init(.downArrow)
    case .rightArrow: self.init(.rightArrow)
    case .leftArrow: self.init(.leftArrow)
    case .delete: self.init(.delete)
    case .commandUpArrow: self.init(.upArrow, modifiers: .command)
    case .tab: self.init(.tab)
    case .returnKey: self.init(.return)
    case .shiftTab: self.init(.tab, modifiers: .shift)
    case .escape: self.init(.escape)
    case .shiftCommandN: self.init("n", modifiers: [.shift, .command])
    case .commandReturn: self.init(.return, modifiers: .command)
    }
  }

  /// The key `quickLookPanelKey` stands for; like ``init(pickerKey:)``, a new panel key fails to compile here.
  init(quickLookPanelKey: QuickLookPanelKey) {
    switch quickLookPanelKey {
    case .upArrow: self.init(.upArrow)
    case .downArrow: self.init(.downArrow)
    case .space: self.init(.space)
    case .escape: self.init(.escape)
    }
  }

  /// The key that sends `command` to a text field.
  init(textFieldCommand command: TextFieldKeyCommand) {
    switch command {
    case .moveUp: self.init(.upArrow)
    case .moveDown: self.init(.downArrow)
    case .tab: self.init(.tab)
    case .backTab: self.init(.tab, modifiers: .shift)
    case .submit: self.init(.return)
    case .cancel: self.init(.escape)
    }
  }
}
