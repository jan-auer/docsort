import AppKit
import SwiftUI

/// The editing commands of a text field that the filing panel handles itself.
enum TextFieldKeyCommand {
  /// ↑
  case moveUp
  /// ↓
  case moveDown
  /// Tab
  case tab
  /// ⇧Tab
  case backTab
  /// Return
  case submit
  /// Esc
  case cancel
}

/// Where the caret goes when the field gains focus.
enum TextFieldFocusSelection {
  /// After the last character, so typing continues the text (the destination filter).
  case end
  /// Around all of the text, so typing replaces it (the name field).
  case all
}

/// A single-line `NSTextField` that reports ↑, ↓, Tab, ⇧Tab, Return and Esc to `onCommand` and takes focus when asked.
///
/// SwiftUI's `TextField` selects all of its text whenever it gains focus and gives no reliable hook for these keys
/// on macOS, so the filter could not continue a search started by typing in the sidebar. This field places the
/// caret as `focusSelection` says, and reports focus changes so the window knows where focus is.
struct KeyCommandTextField: NSViewRepresentable {
  /// The field's text.
  @Binding var text: String
  /// The placeholder shown while the field is empty.
  let placeholder: String
  /// The accessibility identifier.
  let identifier: String
  /// Where the caret goes when the field gains focus.
  let focusSelection: TextFieldFocusSelection
  /// A focus request for this field; each new value makes the field first responder once.
  let focusRequestID: UUID?
  /// Called when the field gains (`true`) or loses (`false`) focus.
  let onFocusChange: (Bool) -> Void
  /// Called for each handled key; returns whether it handled the key (otherwise the field does its default).
  let onCommand: (TextFieldKeyCommand) -> Bool
  /// Room kept free at the field's trailing edge for controls drawn over it (the name field's ↺ and extension).
  var trailingInset: CGFloat = 0

  func makeNSView(context: Context) -> NSTextField {
    let field = FocusReportingTextField()
    field.delegate = context.coordinator
    field.placeholderString = placeholder
    field.lineBreakMode = .byTruncatingMiddle
    field.cell?.isScrollable = true
    field.cell?.wraps = false
    field.bezelStyle = .roundedBezel
    field.setAccessibilityIdentifier(identifier)
    field.onBecomeFirstResponder = { [weak coordinator = context.coordinator] in
      coordinator?.didBeginFocus()
    }
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    context.coordinator.parent = self
    if let field = field as? FocusReportingTextField {
      field.setTrailingInset(trailingInset)
    }
    if field.stringValue != text {
      field.stringValue = text
    }
    field.placeholderString = placeholder
    // An AppKit control doesn't follow SwiftUI's `disabled(_:)` on its own.
    if field.isEnabled != context.environment.isEnabled {
      field.isEnabled = context.environment.isEnabled
    }
    guard let focusRequestID, focusRequestID != context.coordinator.handledFocusRequestID else {
      return
    }
    context.coordinator.handledFocusRequestID = focusRequestID
    // The request may arrive before the field is in a window; take focus once SwiftUI has placed it.
    Task { @MainActor in
      guard let window = field.window else { return }
      if window.firstResponder !== field.currentEditor() {
        window.makeFirstResponder(field)
      }
      context.coordinator.placeCaret(in: field)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  /// Relays the field's delegate calls to the representable.
  final class Coordinator: NSObject, NSTextFieldDelegate {
    var parent: KeyCommandTextField
    /// The focus request already carried out.
    var handledFocusRequestID: UUID?

    init(parent: KeyCommandTextField) {
      self.parent = parent
    }

    func didBeginFocus() {
      parent.onFocusChange(true)
    }

    func placeCaret(in field: NSTextField) {
      guard let editor = field.currentEditor() else { return }
      let length = (field.stringValue as NSString).length
      switch parent.focusSelection {
      case .end: editor.selectedRange = NSRange(location: length, length: 0)
      case .all: editor.selectedRange = NSRange(location: 0, length: length)
      }
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSTextField else { return }
      parent.text = field.stringValue
    }

    func controlTextDidEndEditing(_ notification: Notification) {
      parent.onFocusChange(false)
    }

    func control(
      _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
      let command: TextFieldKeyCommand? =
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)): .moveUp
        case #selector(NSResponder.moveDown(_:)): .moveDown
        case #selector(NSResponder.insertTab(_:)): .tab
        case #selector(NSResponder.insertBacktab(_:)): .backTab
        case #selector(NSResponder.insertNewline(_:)): .submit
        case #selector(NSResponder.cancelOperation(_:)): .cancel
        default: nil
        }
      guard let command else { return false }
      return parent.onCommand(command)
    }
  }
}

/// A text field that says when it becomes first responder (by click, Tab or a focus request), which the delegate
/// does not report until the first edit, and keeps room free at its trailing edge.
final class FocusReportingTextField: NSTextField {
  var onBecomeFirstResponder: (() -> Void)?

  override class var cellClass: AnyClass? {
    get { TrailingInsetTextFieldCell.self }
    set {}
  }

  override func becomeFirstResponder() -> Bool {
    let didBecome = super.becomeFirstResponder()
    if didBecome { onBecomeFirstResponder?() }
    return didBecome
  }

  /// Keeps `inset` points free at the trailing edge, for drawing and for editing.
  func setTrailingInset(_ inset: CGFloat) {
    guard let cell = cell as? TrailingInsetTextFieldCell, cell.trailingInset != inset else {
      return
    }
    let growth = cell.trailingInset - inset
    cell.trailingInset = inset
    // While editing, the field editor's clip view was laid out with the old inset; resize it in place, since
    // starting the edit over would select all of the text again and report a focus change.
    if let clipView = currentEditor()?.superview as? NSClipView {
      clipView.frame.size.width = max(0, clipView.frame.width + growth)
    }
    needsDisplay = true
  }
}

/// A text field cell whose text, placeholder and field editor stop `trailingInset` points before the trailing edge.
final class TrailingInsetTextFieldCell: NSTextFieldCell {
  var trailingInset: CGFloat = 0

  override func drawingRect(forBounds rect: NSRect) -> NSRect {
    var bounds = rect
    bounds.size.width = max(0, bounds.width - trailingInset)
    return super.drawingRect(forBounds: bounds)
  }
}

#Preview {
  @Previewable @State var text = "noten"
  KeyCommandTextField(
    text: $text, placeholder: "Search folders", identifier: "preview-field",
    focusSelection: .end, focusRequestID: nil, onFocusChange: { _ in },
    onCommand: { _ in false }
  )
  .padding()
  .frame(width: 300)
}
