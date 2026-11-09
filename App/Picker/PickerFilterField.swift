import SwiftUI

/// The chrome of the picker's filter field, shaped like the system search field: a Liquid Glass capsule with a
/// magnifier, the text field itself (`field`, built by ``DestinationPickerView`` so its focus binding stays there), a
/// clear button while there is text, and a focus ring drawn outside the capsule.
///
/// The system's own glass search field (`searchable(placement: .sidebar)`, as in System Settings) exists only at the
/// top of a navigation split view's sidebar, attached to the toolbar; anywhere else SwiftUI places it automatically,
/// outside the picker, where the picker's keys would not reach it. So the field stays the picker's own and takes the
/// glass the way Apple documents for custom controls: `glassEffect(_:in:)` in a capsule, interactive.
///
/// It holds only the query: the chosen folder is marked in the list and named on the panel's destination line.
struct PickerFilterField<Field: View>: View {
  /// Whether the text field has focus, for the focus ring.
  let focusState: FieldFocusState
  /// Whether the field holds text, for the clear button.
  let hasText: Bool
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
        .accessibilityIdentifier("picker-filter-clear")
      }
    }
    .padding(.leading, 9)
    .padding(.trailing, 7)
    .frame(height: 28)
    .glassEffect(.regular.interactive(), in: Capsule())
    .overlay {
      if focusState == .focused {
        Capsule().strokeBorder(Color.accentColor, lineWidth: 0.5)
      }
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
