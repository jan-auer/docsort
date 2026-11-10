import AppKit

extension NSWindow {
  /// The window's field editor while it is first responder and edits a text field whose centre lies inside `view`'s
  /// frame; `nil` otherwise.
  ///
  /// The field editor gets its field (its delegate) only after it became first responder, so right at that change
  /// this is still `nil`.
  func fieldEditor(editingFieldInside view: NSView) -> NSTextView? {
    guard view.window === self, let editor = firstResponder as? NSTextView, editor.isFieldEditor,
      let field = editor.delegate as? NSView, field.window === self
    else { return nil }
    let frame = view.convert(view.bounds, to: nil)
    let fieldFrame = field.convert(field.bounds, to: nil)
    return frame.contains(CGPoint(x: fieldFrame.midX, y: fieldFrame.midY)) ? editor : nil
  }
}
