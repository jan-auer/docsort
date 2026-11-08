import Foundation
import Observation

/// One folder the destination list offers: a recent or top-level folder for an empty filter, a search match
/// otherwise.
nonisolated struct DestinationCandidate: Hashable, Sendable, Identifiable {
  /// The folder's archive-relative path, which is filed into.
  let path: String
  /// The path as the list shows it.
  let shownPath: String
  /// The ranges of `shownPath` the filter matched, shown bold.
  let matchedRanges: [Range<String.Index>]
  /// Whether the folder is listed because it is a recent destination.
  let isRecent: Bool

  var id: String { path }
}

/// What the user has entered in the filing panel for the selected file: the destination filter and its highlight,
/// the chosen destination, and the name.
///
/// One per main window. `MainWindowModel` resets it whenever the selection changes and after each move.
@Observable
final class FilingPanelModel {
  /// The destination filter's text.
  var filter = "" {
    didSet {
      if filter != oldValue { highlightedIndex = 0 }
    }
  }
  /// The index of the highlighted folder in the destination list.
  var highlightedIndex = 0
  /// The chosen destination's archive-relative path; `nil` until a folder is chosen.
  var chosenDestination: String?
  /// The name field's text: the name without its extension. Empty keeps the original name.
  var nameText = ""
  /// An error to show in the panel, for example why the last move failed.
  var notice: String?
  /// Whether the "Press ⌘Return to move" hint is shown under the name field.
  var isMoveHintShown = false
  /// Whether a key typed in the sidebar asked for the filter's focus, which it has not reported yet. Keys typed
  /// meanwhile still reach the sidebar and are appended instead of starting the filter again.
  var isFilterFocusPending = false

  /// Clears everything entered and pre-fills the name with `originalName` without its extension.
  func reset(originalName: String?) {
    filter = ""
    highlightedIndex = 0
    chosenDestination = nil
    notice = nil
    isMoveHintShown = false
    nameText = originalName.map { FileNameParts($0).stem } ?? ""
  }

  /// Moves the highlight by `offset` within a list of `count` folders, stopping at either end.
  func moveHighlight(by offset: Int, count: Int) {
    guard count > 0 else { return }
    highlightedIndex = min(max(highlightedIndex + offset, 0), count - 1)
  }
}
