import Foundation
import Observation

/// What the user has entered in the filing panel for the selected file, beyond the destination picker's own state:
/// the name, the panel's notice and hint.
///
/// One per main window. `MainWindowModel` resets it whenever the selection changes and after each move.
@Observable
final class FilingPanelModel {
  /// The name field's text: the name without its extension. Empty keeps the file's current name.
  var nameText = ""
  /// An error to show in the panel, for example why the last move failed.
  var notice: String?
  /// The short hint floating under the name field, if any; it hides itself after two seconds.
  var hint: FilingHint?

  /// Clears everything entered and pre-fills the name with `currentName` without its extension.
  func reset(currentName: String?) {
    notice = nil
    hint = nil
    nameText = currentName.map { FileNameParts($0).stem } ?? ""
  }
}

/// A short hint the filing panel shows for two seconds as a toast under the name field, taking no layout space.
enum FilingHint: Hashable, Sendable {
  /// Return in the name field: only ⌘Return files.
  case pressCommandReturnToMove
  /// ⌘Return with no destination chosen outside the picker: nothing moved, focus went to the picker.
  case chooseDestinationFirst

  /// The hint's text.
  var text: String {
    switch self {
    case .pressCommandReturnToMove: "Press ⌘Return to move"
    case .chooseDestinationFirst: "Choose a destination first"
    }
  }
}
