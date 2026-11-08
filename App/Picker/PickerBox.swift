import AppKit
import SwiftUI

/// The outlined, rounded box around the picker's folder list and around Folder contents, as in the mockup: the
/// control background with a hairline border that stays visible on the panel's plain content background.
struct PickerBox: ViewModifier {
  private let shape = RoundedRectangle(cornerRadius: 7)

  func body(content: Content) -> some View {
    content
      .background(Color(nsColor: .controlBackgroundColor), in: shape)
      .clipShape(shape)
      .overlay {
        shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
      }
  }
}

extension View {
  /// Puts the view in the picker's outlined box (``PickerBox``).
  func pickerBox() -> some View {
    modifier(PickerBox())
  }
}
