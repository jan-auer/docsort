import SwiftUI

/// A key with its modifiers: what a menu item or a view's key handler responds to, and what the keyboard shortcuts
/// sheet shows as a keycap such as "⇧⌘O".
struct KeyCombination: Hashable, Sendable {
  /// The key, without modifiers.
  let key: KeyEquivalent
  /// The modifiers held with the key.
  let modifiers: EventModifiers

  init(_ key: KeyEquivalent, modifiers: EventModifiers = []) {
    self.key = key
    self.modifiers = modifiers
  }

  /// The shortcut for SwiftUI's `keyboardShortcut(_:)`.
  var keyboardShortcut: KeyboardShortcut {
    KeyboardShortcut(key, modifiers: modifiers)
  }

  /// One label per key, as printed on the keyboard: the modifiers first in the HIG's order ⌃⌥⇧⌘,
  /// then the key.
  var keycaps: [String] {
    Self.modifierOrder.filter { modifiers.contains($0.modifier) }.map(\.glyph) + [keyGlyph]
  }

  /// The combination as menus write it, for example "⇧⌘O".
  var notation: String {
    keycaps.joined()
  }

  /// The words a search for this combination may use: each glyph, the notation, and the keys' names ("cmd",
  /// "shift", "esc", "up").
  var searchWords: [String] {
    let modifierWords = Self.modifierOrder.filter { modifiers.contains($0.modifier) }
      .flatMap { [$0.glyph] + $0.names }
    return [notation, keyGlyph] + modifierWords + keyNames
  }

  // MARK: Glyphs and names

  /// The modifiers in the order menus list them, with their glyphs and names.
  private static let modifierOrder: [(modifier: EventModifiers, glyph: String, names: [String])] = [
    (.control, "⌃", ["control", "ctrl"]),
    (.option, "⌥", ["option", "opt", "alt"]),
    (.shift, "⇧", ["shift"]),
    (.command, "⌘", ["command", "cmd"]),
  ]

  /// The special keys with their glyphs and names.
  private static let specialKeys: [(key: KeyEquivalent, glyph: String, names: [String])] = [
    (.return, "↩", ["return", "enter"]),
    (.tab, "⇥", ["tab"]),
    (.escape, "⎋", ["escape", "esc"]),
    (.delete, "⌫", ["delete", "backspace"]),
    (.deleteForward, "⌦", ["forward", "delete"]),
    (.space, "Space", ["space"]),
    (.upArrow, "↑", ["up", "arrow"]),
    (.downArrow, "↓", ["down", "arrow"]),
    (.leftArrow, "←", ["left", "arrow"]),
    (.rightArrow, "→", ["right", "arrow"]),
    (.pageUp, "⇞", ["page", "up"]),
    (.pageDown, "⇟", ["page", "down"]),
    (.home, "↖", ["home"]),
    (.end, "↘", ["end"]),
  ]

  /// The names of printable keys that are punctuation.
  private static let punctuationNames: [Character: [String]] = [
    "+": ["plus"], "-": ["minus"], "/": ["slash"], ",": ["comma"], ".": ["period"],
  ]

  /// The key's label: a glyph for special keys, the uppercase letter for letters, a true minus sign for "-".
  private var keyGlyph: String {
    if let special = Self.specialKeys.first(where: { $0.key == key }) {
      return special.glyph
    }
    if key.character == "-" {
      return "−"
    }
    return String(key.character).uppercased()
  }

  /// The key's names for search.
  private var keyNames: [String] {
    if let special = Self.specialKeys.first(where: { $0.key == key }) {
      return special.names
    }
    return [String(key.character)] + (Self.punctuationNames[key.character] ?? [])
  }

  // MARK: Hashable

  // `EventModifiers` is compared by its raw value.
  static func == (lhs: KeyCombination, rhs: KeyCombination) -> Bool {
    lhs.key == rhs.key && lhs.modifiers.rawValue == rhs.modifiers.rawValue
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(key)
    hasher.combine(modifiers.rawValue)
  }
}
