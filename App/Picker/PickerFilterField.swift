import SwiftUI

/// The chrome of the picker's filter field, shaped like the system search field: a capsule with a magnifier, the
/// chosen destination's token in place of the text, the text field itself (`field`, built by
/// ``DestinationPickerView`` so its focus binding stays there), a clear button while there is text, and a focus ring
/// drawn outside the capsule. The folder the picker is in is not repeated here: the placeholder and the path bar show
/// it.
struct PickerFilterField<Field: View>: View {
  /// The chosen destination, shown as a token instead of the query.
  let chosenToken: ChosenToken?
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
      if let chosenToken {
        ChosenTokenView(token: chosenToken)
      }
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
    .background(FilingPanelStyle.wellBackground, in: Capsule())
    .overlay {
      Capsule().strokeBorder(
        focusState == .focused ? Color.accentColor : FilingPanelStyle.wellBorder, lineWidth: 0.5)
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

/// The chosen destination as the filter field shows it: `Rechnungen › Elektronik`, with a New badge for a new
/// folder.
struct ChosenTokenView: View {
  let token: ChosenToken

  var body: some View {
    HStack(spacing: 4) {
      Text(token.text)
        .lineLimit(1)
        .truncationMode(.head)
      if token.isNew {
        NewBadge(tone: .standard)
      }
    }
    .font(.callout)
    .padding(.horizontal, 8)
    .frame(height: 20)
    .background(Color.accentColor.opacity(0.18), in: Capsule())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(token.isNew ? "Chosen: \(token.text), new folder" : "Chosen: \(token.text)")
    .accessibilityIdentifier("picker-chosen-token")
  }
}

/// The path bar above the list while the picker is inside a folder: `Archive › Gesundheit › Konrad`, each segment a
/// button that jumps there.
struct PickerPathBar: View {
  let segments: [PathBarSegment]
  /// Jumps to an archive-relative path, `""` for the root.
  let jump: (String) -> Void

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(segments.enumerated()), id: \.element.id) { position, segment in
        if position > 0 {
          Text("›")
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        }
        let isCurrent = position == segments.count - 1
        Button(segment.title) { jump(segment.path) }
          .buttonStyle(.plain)
          .fontWeight(isCurrent ? .semibold : .regular)
          .foregroundStyle(isCurrent ? .primary : .secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .layoutPriority(isCurrent ? 1 : 0)
          .padding(.vertical, 1)
          .accessibilityIdentifier("picker-path-segment-\(position)")
          .accessibilityHint(
            segment.path.isEmpty ? "Goes to the archive root" : "Goes to this folder")
      }
      Spacer(minLength: 0)
    }
    .font(.subheadline)
    .padding(.horizontal, 9)
    .frame(minHeight: 16)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Path")
    .accessibilityIdentifier("picker-path-bar")
  }
}
