import Foundation
import Observation

/// What the user has entered in the filing panel for the selected file, beyond the destination picker's own state:
/// the name, the panel's notice and hint.
///
/// One per main window. `MainWindowModel` resets it whenever the selection changes and after each move.
@Observable
final class FilingPanelModel {
  /// The name field's text: the name without its extension. Empty keeps the original name.
  var nameText = ""
  /// An error to show in the panel, for example why the last move failed.
  var notice: String?
  /// Whether the "Press ⌘Return to move" hint is shown under the name field.
  var isMoveHintShown = false
  /// Whether a key typed in the sidebar asked for the filter's focus, which it has not reported yet. Keys typed
  /// meanwhile still reach the sidebar and are appended to the filter instead of starting it again.
  var isFilterFocusPending = false

  /// Clears everything entered and pre-fills the name with `originalName` without its extension.
  func reset(originalName: String?) {
    notice = nil
    isMoveHintShown = false
    nameText = originalName.map { FileNameParts($0).stem } ?? ""
  }
}
