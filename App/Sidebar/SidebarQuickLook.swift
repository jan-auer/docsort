import Foundation

/// The inbox sidebar as a list the Quick Look panel follows: the selected file, moved by ↑ ↓ in the panel through
/// the sidebar's files as its own arrow keys do (Previous File / Next File). A trashed file shows nothing.
extension MainWindowModel: QuickLookSource {
  var quickLookURL: URL? {
    guard let selectedFile, !selectedFile.isTrashed else { return nil }
    return selectedFile.url
  }

  func moveQuickLookSelection(by offset: Int) {
    let step: SidebarStep = offset < 0 ? .previous : .next
    for _ in 0..<abs(offset) { selectFile(step) }
  }
}
