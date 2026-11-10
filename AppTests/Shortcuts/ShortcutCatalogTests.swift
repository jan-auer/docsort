import AppKit
import SwiftUI
import Testing

@testable import Docsort

@Suite("Keyboard shortcut catalog")
@MainActor
struct ShortcutCatalogTests {
  private let catalog = ShortcutCatalog.main

  /// Every key combination listed in `context`.
  private func combinations(in context: ShortcutContext) -> [KeyCombination] {
    catalog.sections.filter { $0.context == context }.flatMap(\.entries).flatMap(
      \.trigger.combinations)
  }

  @Test(
    "The sections follow the contexts in order: Anywhere, Sidebar, Destination picker, New folder name, Name field, Folder contents, Quick Look panel, History"
  )
  func sectionOrder() {
    #expect(
      catalog.sections.map(\.context) == [
        .anywhere, .sidebar, .destinationPicker, .newFolderName, .nameField, .folderContents,
        .quickLookPanel, .history,
      ])
    #expect(catalog.sections.allSatisfy { !$0.entries.isEmpty })
  }

  @Test("Every menu command's shortcut is listed under Anywhere")
  func menuCommandsAreListed() {
    let anywhere = Set(combinations(in: .anywhere))
    for command in MenuCommand.allCases {
      #expect(
        anywhere.contains(command.keys), "\(command) (\(command.keys.notation)) is not listed")
    }
  }

  @Test("No key combination is listed twice in one context")
  func noDuplicatesWithinAContext() {
    for section in catalog.sections {
      let listed = section.entries.flatMap(\.trigger.combinations)
      #expect(listed.count == Set(listed).count, "\(section.title) lists a key twice")
    }
  }

  @Test("Entry titles are unique within a section, since they identify the rows")
  func uniqueTitles() {
    for section in catalog.sections {
      let titles = section.entries.map(\.title)
      #expect(titles.count == Set(titles).count, "\(section.title) repeats a title")
    }
  }

  @Test("No two menu commands share a shortcut")
  func menuCommandsAreDistinct() {
    let keys = MenuCommand.allCases.map(\.keys)
    #expect(keys.count == Set(keys).count)
  }

  @Test("Every key the destination picker handles is listed under Destination picker")
  func pickerKeysAreListed() {
    let listed = Set(combinations(in: .destinationPicker))
    for key in PickerKey.allCases {
      #expect(listed.contains(KeyCombination(pickerKey: key)), "\(key) is not listed")
    }
  }

  @Test("Every key the new-folder row handles is listed under New folder name")
  func newFolderKeysAreListed() {
    let listed = Set(combinations(in: .newFolderName))
    let handled: [PickerKey] = [.tab, .returnKey, .escape, .shiftTab, .commandReturn]
    for key in handled {
      #expect(listed.contains(KeyCombination(pickerKey: key)), "\(key) is not listed")
    }
  }

  @Test("The picker keys' combinations are the keys the picker recognises")
  func pickerKeyCombinationsRoundTrip() throws {
    for key in PickerKey.allCases {
      let event = try #require(KeyEventFactory.keyDown(KeyCombination(pickerKey: key)))
      #expect(PickerKey(event) == key, "\(KeyCombination(pickerKey: key).notation) is not \(key)")
    }
  }

  @Test("Every key the Quick Look panel handles is listed under Quick Look panel")
  func quickLookPanelKeysAreListed() {
    let listed = Set(combinations(in: .quickLookPanel))
    for key in QuickLookPanelKey.allCases {
      #expect(listed.contains(KeyCombination(quickLookPanelKey: key)), "\(key) is not listed")
    }
  }

  @Test("Folder contents lists ↑, ↓, Space and Return; the sidebar lists Space for Quick Look")
  func quickLookListKeysAreListed() {
    let folderContents = Set(combinations(in: .folderContents))
    for keys in [KeyEquivalent.upArrow, .downArrow, .space, .return].map({ KeyCombination($0) }) {
      #expect(folderContents.contains(keys), "\(keys.notation) is not listed")
    }
    #expect(combinations(in: .sidebar).contains(KeyCombination(.space)))
  }

  @Test("Every key the name field handles is listed under Name field")
  func nameFieldKeysAreListed() {
    let listed = Set(combinations(in: .nameField))
    let handled: [TextFieldKeyCommand] = [.tab, .backTab, .cancel]
    for command in handled {
      #expect(
        listed.contains(KeyCombination(textFieldCommand: command)), "\(command) is not listed")
    }
  }

  @Test("Keycaps put the modifiers first, in the order ⌃⌥⇧⌘, then the key")
  func keycapOrder() {
    let keys = KeyCombination("o", modifiers: [.command, .shift, .option, .control])
    #expect(keys.keycaps == ["⌃", "⌥", "⇧", "⌘", "O"])
    #expect(keys.notation == "⌃⌥⇧⌘O")
  }

  @Test("Special keys get their macOS glyphs")
  func specialKeyGlyphs() {
    #expect(KeyCombination(.return, modifiers: .command).notation == "⌘↩")
    #expect(KeyCombination(.delete, modifiers: .command).notation == "⌘⌫")
    #expect(KeyCombination(.upArrow, modifiers: [.option, .command]).notation == "⌥⌘↑")
    #expect(KeyCombination(.tab, modifiers: .shift).notation == "⇧⇥")
    #expect(KeyCombination(.escape).notation == "⎋")
    #expect(KeyCombination("/", modifiers: .command).notation == "⌘/")
  }

  @Test("VoiceOver hears key names, not glyphs")
  func spokenNames() {
    #expect(KeyCombination("o", modifiers: [.shift, .command]).spokenName == "Shift Command O")
    #expect(
      KeyCombination(.upArrow, modifiers: [.option, .command]).spokenName
        == "Option Command Up Arrow")
    #expect(KeyCombination("-", modifiers: .command).spokenName == "Command Minus")
    #expect(
      ShortcutTrigger.keys([KeyCombination(.tab), KeyCombination(.return)]).spokenName
        == "Tab or Return")
    #expect(
      ShortcutTrigger.pair(KeyCombination(.upArrow), KeyCombination(.downArrow)).spokenName
        == "Up Arrow, Down Arrow")
    #expect(ShortcutTrigger.typing.spokenName == "Type")
  }

  @Test("Section identifiers are distinct")
  func sectionIdentifiers() {
    let identifiers = catalog.sections.map(\.context.identifier)
    #expect(identifiers.count == Set(identifiers).count)
  }

  @Test("Search matches titles, section names and key names, ignoring case and order")
  func search() {
    #expect(titles(matching: "trash").first == "Move to Trash")
    #expect(titles(matching: "TRASH to move").first == "Move to Trash")
    #expect(!titles(matching: "trash").contains("Open"))
    #expect(titles(matching: "zoom").count == 3)
    // A section's name finds all of its rows.
    #expect(
      catalog.sections(matching: "name field").map(\.context) == [.nameField])
    // Key names in words and glyphs.
    #expect(titles(matching: "cmd y") == ["History"])
    #expect(titles(matching: "⌘Y") == ["History"])
    #expect(titles(matching: "esc").isEmpty == false)
    #expect(titles(matching: "space").contains("Quick Look"))
  }

  @Test("An empty or blank query lists everything; a query matching nothing lists nothing")
  func searchEdges() {
    #expect(catalog.sections(matching: "") == catalog.sections)
    #expect(catalog.sections(matching: "   ") == catalog.sections)
    #expect(catalog.sections(matching: "xylophone").isEmpty)
  }

  @Test(
    "Every shortcut in the menu bar is listed under Anywhere or is a standard macOS shortcut, and back"
  )
  func menuBarIsInSync() throws {
    let menuBar = try #require(NSApp.mainMenu, "the test host has no menu bar")
    var titles: [KeyCombination: String] = [:]
    // SwiftUI keeps a few hidden items (a second Toggle Sidebar, Dictation) that no one can see or reach by name.
    for item in Self.menuItems(in: menuBar) where !item.isHidden {
      if let keys = KeyCombination(menuItem: item) { titles[keys] = item.title }
    }
    let inMenuBar = Set(titles.keys)
    let anywhere = Set(combinations(in: .anywhere))
    let standard = Set(Self.standardMacShortcuts)

    let unlisted = inMenuBar.subtracting(anywhere).subtracting(standard)
    #expect(
      unlisted.isEmpty,
      "In the menu bar but not listed: \(unlisted.map { "\($0.notation) \(titles[$0] ?? "")" }.sorted())"
    )
    let missing = anywhere.subtracting(inMenuBar)
    #expect(missing.isEmpty, "Listed but not in the menu bar: \(missing.map(\.notation).sorted())")
  }

  @Test("The sheet's columns take every section once, in order, and leave no column empty")
  func columns() {
    let columns = ShortcutColumns.balance(catalog.sections, into: 2)
    #expect(columns.count == 2)
    #expect(Set(columns.flatMap { $0 }.map(\.context)) == Set(catalog.sections.map(\.context)))
    let order = catalog.sections.map(\.context)
    for column in columns {
      let positions = column.compactMap { section in order.firstIndex(of: section.context) }
      #expect(positions == positions.sorted())
    }
    #expect(ShortcutColumns.balance(Array(catalog.sections.prefix(1)), into: 2).count == 1)
  }

  private func titles(matching query: String) -> [String] {
    catalog.sections(matching: query).flatMap(\.entries).map(\.title)
  }

  /// Shortcuts the menu bar has in every Mac app, which the sheet leaves out: quitting, hiding, closing and minimizing
  /// windows, full screen, the text editing commands, Emoji & Symbols and Help.
  private static let standardMacShortcuts: [KeyCombination] = [
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

  /// Every item of `menu` and its submenus.
  private static func menuItems(in menu: NSMenu) -> [NSMenuItem] {
    menu.items.flatMap { item in [item] + (item.submenu.map(menuItems(in:)) ?? []) }
  }
}

/// Builds the key-down events AppKit delivers for key combinations.
@MainActor
enum KeyEventFactory {
  static func keyDown(_ keys: KeyCombination) -> NSEvent? {
    let character = String(keys.key.character)
    var flags: NSEvent.ModifierFlags = []
    if keys.modifiers.contains(.control) { flags.insert(.control) }
    if keys.modifiers.contains(.option) { flags.insert(.option) }
    if keys.modifiers.contains(.shift) { flags.insert(.shift) }
    if keys.modifiers.contains(.command) { flags.insert(.command) }
    let ignoringModifiers =
      flags.contains(.shift) && keys.key.character.isLetter ? character.uppercased() : character
    return NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
      context: nil, characters: character, charactersIgnoringModifiers: ignoringModifiers,
      isARepeat: false, keyCode: 0)
  }
}

extension KeyCombination {
  /// The key combination of a menu item, or `nil` when it has none.
  ///
  /// AppKit stores a shifted letter either as the lowercase letter with ⇧ in the mask or as the uppercase letter
  /// alone; both become the lowercase letter with ⇧.
  @MainActor init?(menuItem: NSMenuItem) {
    let equivalent = menuItem.keyEquivalent
    guard let character = equivalent.first, equivalent.count == 1 else { return nil }
    let mask = menuItem.keyEquivalentModifierMask
    var modifiers: EventModifiers = []
    if mask.contains(.control) { modifiers.insert(.control) }
    if mask.contains(.option) { modifiers.insert(.option) }
    if mask.contains(.shift) { modifiers.insert(.shift) }
    if mask.contains(.command) { modifiers.insert(.command) }
    var key = character
    if character.isUppercase {
      modifiers.insert(.shift)
      key = Character(character.lowercased())
    }
    // AppKit's Backspace is the menu bar's Delete key.
    if key == "\u{8}" { key = KeyEquivalent.delete.character }
    self.init(KeyEquivalent(key), modifiers: modifiers)
  }
}
