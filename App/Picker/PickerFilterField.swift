import SwiftUI

/// The chrome of the picker's filter field: magnifier, the scope chip ("in Gesundheit") while inside a folder, the
/// chosen destination's token in place of the text, and the text field itself (`field`, built by
/// ``DestinationPickerView`` so its focus binding stays there).
struct PickerFilterField<Field: View>: View {
  /// The folder the picker is in, for the chip; `nil` at the root.
  let scopeTitle: String?
  /// The chosen destination, shown as a token instead of the query.
  let chosenToken: ChosenToken?
  /// Whether the text field has focus, for the focus ring.
  let focusState: FieldFocusState
  @ViewBuilder let field: () -> Field

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      if let chosenToken {
        ChosenTokenView(token: chosenToken)
      } else if let scopeTitle {
        Text("in \(scopeTitle)")
          .font(.callout)
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(.horizontal, 7)
          .frame(height: 20)
          .background(
            Color(nsColor: .unemphasizedSelectedContentBackgroundColor),
            in: RoundedRectangle(cornerRadius: 5)
          )
          .layoutPriority(-1)
          .accessibilityLabel("Searching in \(scopeTitle)")
      }
      field()
        .textFieldStyle(.plain)
        .frame(minWidth: 40)
    }
    .padding(.leading, 8)
    .padding(.trailing, 6)
    .frame(height: 28)
    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
    .overlay {
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(
          focusState == .focused ? Color.accentColor : Color(nsColor: .separatorColor),
          lineWidth: focusState == .focused ? 2 : 0.5)
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
    .padding(.horizontal, 7)
    .frame(height: 20)
    .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
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
    HStack(spacing: 2) {
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
          .padding(.horizontal, 4)
          .padding(.vertical, 1)
          .accessibilityIdentifier("picker-path-segment-\(position)")
          .accessibilityHint(
            segment.path.isEmpty ? "Goes to the archive root" : "Goes to this folder")
      }
      Spacer(minLength: 0)
    }
    .font(.system(size: 11.5))
    .frame(minHeight: 20)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Path")
    .accessibilityIdentifier("picker-path-bar")
  }
}
