import AppKit
import Testing

@testable import Docsort

@Suite("Destination picker keys")
@MainActor
struct PickerKeyTests {
  /// A key-down event as AppKit delivers it for `characters` typed with `modifiers`.
  func keyDown(
    _ characters: String, ignoringModifiers: String? = nil,
    modifiers: NSEvent.ModifierFlags = [], keyCode: UInt16 = 0
  ) throws -> NSEvent {
    try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
        context: nil, characters: characters,
        charactersIgnoringModifiers: ignoringModifiers ?? characters, isARepeat: false,
        keyCode: keyCode))
  }

  /// The character AppKit uses for a function key such as an arrow.
  func functionKey(_ code: Int) -> String {
    String(utf16CodeUnits: [unichar(code)], count: 1)
  }

  @Test(
    "Arrows without modifiers, as the keyboard sends them with the function and numeric-pad flags")
  func arrows() throws {
    let arrowFlags: NSEvent.ModifierFlags = [.function, .numericPad]
    #expect(
      PickerKey(try keyDown(functionKey(NSUpArrowFunctionKey), modifiers: arrowFlags)) == .upArrow)
    #expect(
      PickerKey(try keyDown(functionKey(NSDownArrowFunctionKey), modifiers: arrowFlags))
        == .downArrow)
    #expect(
      PickerKey(try keyDown(functionKey(NSRightArrowFunctionKey), modifiers: arrowFlags))
        == .rightArrow)
    #expect(
      PickerKey(try keyDown(functionKey(NSLeftArrowFunctionKey), modifiers: arrowFlags))
        == .leftArrow)
    #expect(
      PickerKey(
        try keyDown(functionKey(NSUpArrowFunctionKey), modifiers: arrowFlags.union(.command)))
        == .commandUpArrow)
  }

  @Test("Arrows with Shift or Option are left to the text field")
  func modifiedArrows() throws {
    #expect(PickerKey(try keyDown(functionKey(NSUpArrowFunctionKey), modifiers: [.shift])) == nil)
    #expect(
      PickerKey(try keyDown(functionKey(NSLeftArrowFunctionKey), modifiers: [.option])) == nil)
  }

  @Test("Tab, Shift-Tab, Return, Enter, Esc and Backspace")
  func editingKeys() throws {
    #expect(PickerKey(try keyDown("\t")) == .tab)
    #expect(PickerKey(try keyDown("\u{19}", modifiers: [.shift])) == .shiftTab)
    #expect(PickerKey(try keyDown("\r")) == .returnKey)
    #expect(PickerKey(try keyDown("\u{3}")) == .returnKey)
    #expect(PickerKey(try keyDown("\u{1B}")) == .escape)
    #expect(PickerKey(try keyDown("\u{7F}")) == .delete)
  }

  @Test("Command-Return and Shift-Command-N")
  func commandKeys() throws {
    #expect(PickerKey(try keyDown("\r", modifiers: [.command])) == .commandReturn)
    #expect(
      PickerKey(try keyDown("n", ignoringModifiers: "N", modifiers: [.shift, .command]))
        == .shiftCommandN)
    #expect(PickerKey(try keyDown("n", modifiers: [.command])) == nil)
  }

  @Test("Typing is left to the text field")
  func typing() throws {
    #expect(PickerKey(try keyDown("p")) == nil)
    #expect(PickerKey(try keyDown("P", modifiers: [.shift])) == nil)
    #expect(PickerKey(try keyDown(" ")) == nil)
  }
}
