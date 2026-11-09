import DocsortCore
import Foundation

/// Folder contents as a list the Quick Look panel follows: its selected file, moved by ↑ ↓ in the panel.
extension DestinationPickerModel: QuickLookSource {
  var quickLookURL: URL? { selectedContentsFile?.url }

  func moveQuickLookSelection(by offset: Int) {
    moveContentsSelection(by: offset)
  }
}
