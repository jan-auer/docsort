import AppKit
import SwiftUI

/// Types text that was typed elsewhere into a text field once that field has keyboard focus.
///
/// `NSTextField.becomeFirstResponder` selects the field's whole text, so text put into the field before it has focus
/// ends up selected. Instead, ``deliver()`` inserts the waiting text at the end of the field's text, as if typed, and
/// only while the field's editor is first responder. ``TypeAheadReceiver`` calls it right after the field took focus,
/// and the picker's key monitor before each key the field gets, so a key already queued when focus arrived still
/// lands after the waiting text.
@MainActor
final class TypeAhead {
  /// Hands over the waiting text and forgets it; empty when nothing waits.
  var takeText: () -> String = { "" }
  /// The view the field lies in front of; set by ``TypeAheadReceiver``.
  weak var marker: NSView?

  /// Inserts the waiting text into the field if its editor is first responder; does nothing otherwise.
  func deliver() {
    guard let marker, let window = marker.window,
      let editor = window.fieldEditor(editingFieldInside: marker)
    else { return }
    let text = takeText()
    guard !text.isEmpty else { return }
    let end = (editor.string as NSString).length
    editor.insertText(text, replacementRange: NSRange(location: end, length: 0))
  }
}

/// Marks the text field it lies behind for a ``TypeAhead`` and delivers its waiting text when the field takes focus.
///
/// When the field's editor becomes first responder, `selectText(_:)` is still running: it hands the editor its field
/// and selects once more before it returns. So delivery happens on the main queue right after. Put it behind the field
/// with `.background(TypeAheadReceiver(typeAhead: …))`; it acts on whichever text field's centre lies inside its own
/// frame.
struct TypeAheadReceiver: NSViewRepresentable {
  let typeAhead: TypeAhead

  func makeNSView(context: Context) -> MarkerView {
    MarkerView(typeAhead: typeAhead)
  }

  func updateNSView(_ view: MarkerView, context: Context) {
    view.typeAhead = typeAhead
    typeAhead.marker = view
  }

  /// An invisible view that marks where the field is and watches the first responder of the window it is in.
  final class MarkerView: NSView {
    var typeAhead: TypeAhead
    private var firstResponderObservation: NSKeyValueObservation?

    init(typeAhead: TypeAhead) {
      self.typeAhead = typeAhead
      super.init(frame: .zero)
      typeAhead.marker = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("MarkerView is only created in code")
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      firstResponderObservation = window?.observe(\.firstResponder) { [weak self] window, _ in
        MainActor.assumeIsolated {
          guard (window.firstResponder as? NSTextView)?.isFieldEditor == true else { return }
          DispatchQueue.main.async {
            self?.typeAhead.deliver()
          }
        }
      }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil
    }
  }
}
