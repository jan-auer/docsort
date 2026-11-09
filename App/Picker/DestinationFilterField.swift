import SwiftUI

/// What the destination picker shares with its search field when the field is drawn outside the picker (the filing
/// panel puts it in the window's toolbar, over the panel): the key monitor, which hands the picker's keys over while
/// either has focus, and the field's text selection, which the picker reads (→ steps in only with the caret at the
/// end) and sets (the caret goes to the end when the field takes focus).
@MainActor @Observable
final class PickerFilterLink {
  /// The search field's selection.
  var selection: TextSelection?
  /// Hands the picker's keys to the picker while one of its fields has focus.
  @ObservationIgnored let keyMonitor = PickerKeyMonitor()
}

/// Where the destination picker's search field is drawn.
enum PickerFilterPlacement {
  /// At the top of the picker.
  case inline
  /// Elsewhere, by a ``DestinationFilterField`` sharing `link` with the picker.
  case elsewhere(PickerFilterLink)
}

/// The destination picker's search field: the filter text field in its capsule chrome (``PickerFilterField``),
/// focused through the panel's focus binding, with an anchor that tells the picker's key monitor its keys belong to
/// the picker.
///
/// Accessibility: `picker-filter` (the text field), `picker-filter-clear`.
struct DestinationFilterField<FocusValue: Hashable>: View {
  @Bindable var model: DestinationPickerModel
  let focus: FocusState<FocusValue?>.Binding
  /// Maps the picker's fields into the panel's focus values.
  let field: (PickerField) -> FocusValue
  @Bindable var link: PickerFilterLink

  var body: some View {
    PickerFilterField(
      focusState: focus.wrappedValue == field(.filter) ? .focused : .unfocused,
      hasText: !model.filterText.isEmpty,
      clear: {
        model.filterText = ""
        focus.wrappedValue = field(.filter)
      }
    ) {
      TextField(
        "Destination filter", text: $model.filterText, selection: $link.selection,
        prompt: Text(model.filterPlaceholder)
      )
      .labelsHidden()
      .focused(focus, equals: field(.filter))
      .accessibilityIdentifier("picker-filter")
    }
    .background(PickerKeyMonitorAnchor(monitor: link.keyMonitor))
  }
}
