import AppKit
import Testing

@testable import Docsort

/// Text typed in the main window's sidebar starts the destination filter. It reaches the filter field only once the
/// field has focus, so it is never selected (the next key would replace it), and before any key the field gets
/// itself, so keys keep their order; other ways in select as text fields do.
@MainActor
struct TypeAheadReceiverTests {
  /// A window with two text fields side by side, the first with a ``TypeAheadReceiver`` behind it.
  @MainActor private final class Fixture {
    let window: NSWindow
    let receivingField: NSTextField
    let otherField: NSTextField
    let typeAhead = TypeAhead()
    var typedText = ""

    init() {
      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 100), styleMask: [.titled],
        backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      let content = NSView(frame: window.contentLayoutRect)
      window.contentView = content
      receivingField = NSTextField(frame: NSRect(x: 10, y: 40, width: 150, height: 22))
      otherField = NSTextField(frame: NSRect(x: 200, y: 40, width: 150, height: 22))
      typeAhead.takeText = { [unowned self] in
        defer { typedText = "" }
        return typedText
      }
      let receiver = TypeAheadReceiver.MarkerView(typeAhead: typeAhead)
      receiver.frame = receivingField.frame
      content.addSubview(receiver)
      content.addSubview(receivingField)
      content.addSubview(otherField)
    }

    /// Gives `field` keyboard focus, as AppKit does, without running what the focus change queued.
    func focus(_ field: NSTextField) -> NSText? {
      #expect(window.makeFirstResponder(field))
      return field.currentEditor()
    }

    /// Returns once the main queue has run what was queued so far.
    func mainQueueTurn() async {
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }
  }

  @Test func typedTextArrivesUnselectedWithTheCaretAfterIt() async {
    let fixture = Fixture()
    defer { fixture.window.close() }
    fixture.typedText = "no"

    let editor = fixture.focus(fixture.receivingField)
    await fixture.mainQueueTurn()

    #expect(editor?.string == "no")
    #expect(editor?.selectedRange == NSRange(location: 2, length: 0))
  }

  @Test func aKeyQueuedBeforeTheHandOverLandsAfterTheTypedText() async {
    let fixture = Fixture()
    defer { fixture.window.close() }
    fixture.typedText = "n"

    let editor = fixture.focus(fixture.receivingField) as? NSTextView
    // The picker's key monitor delivers before each key, ahead of the receiver's own delivery after focus.
    fixture.typeAhead.deliver()
    editor?.insertText("o", replacementRange: NSRange(location: NSNotFound, length: 0))
    await fixture.mainQueueTurn()

    #expect(editor?.string == "no")
  }

  @Test func fieldSelectsItsWholeTextWhenNothingWasTyped() async {
    let fixture = Fixture()
    defer { fixture.window.close() }
    fixture.receivingField.stringValue = "noten"

    let editor = fixture.focus(fixture.receivingField)
    await fixture.mainQueueTurn()

    #expect(editor?.string == "noten")
    #expect(editor?.selectedRange == NSRange(location: 0, length: 5))
  }

  @Test func otherFieldsDoNotReceiveTheText() async {
    let fixture = Fixture()
    defer { fixture.window.close() }
    fixture.typedText = "no"

    let editor = fixture.focus(fixture.otherField)
    fixture.typeAhead.deliver()
    await fixture.mainQueueTurn()

    #expect(editor?.string == "")
    #expect(fixture.typedText == "no")
  }
}
