import SwiftUI

/// A search field shaped like the system's: a capsule with a magnifier, the text field itself (`field`, built by the
/// caller so its focus binding stays there), a clear button while there is text, and a focus ring drawn outside the
/// capsule. The destination picker's filter field and the keyboard shortcuts sheet's search field use it, so both look
/// the same.
struct SearchField<Field: View>: View {
  /// Whether the text field has focus, for the focus ring.
  let focusState: FieldFocusState
  /// Whether the field holds text, for the clear button.
  let hasText: Bool
  /// The clear button's accessibility identifier.
  let clearButtonIdentifier: String
  /// Empties the field.
  let clear: () -> Void
  @ViewBuilder let field: () -> Field

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      field()
        .textFieldStyle(.plain)
        .frame(minWidth: 40)
      if hasText {
        Button(action: clear) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.tertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear")
        .accessibilityLabel("Clear")
        .accessibilityIdentifier(clearButtonIdentifier)
      }
    }
    .padding(.leading, 9)
    .padding(.trailing, 7)
    .frame(height: 28)
    .background(FilingPanelStyle.listBackground, in: Capsule())
    .overlay {
      Capsule().strokeBorder(
        focusState == .focused ? Color.accentColor : FilingPanelStyle.fieldBorder, lineWidth: 0.5)
    }
    .overlay {
      if focusState == .focused {
        Capsule()
          .stroke(Color.accentColor.opacity(0.4), lineWidth: 3)
          .padding(-1.5)
          .allowsHitTesting(false)
      }
    }
  }
}

/// Whether a text field has keyboard focus.
enum FieldFocusState: Hashable {
  case focused
  case unfocused
}
