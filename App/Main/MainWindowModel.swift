import Observation
import SwiftUI

/// The inbox file selected in the main window's sidebar.
nonisolated struct SelectedFile: Hashable, Sendable {
  /// The file's current location.
  let url: URL
  /// The display name of the inbox the file is listed under, as Settings names it.
  let inboxName: String
  /// Whether the file's content is all on disk yet.
  let completeness: PreviewDocument.Completeness

  /// The file name with its extension.
  var name: String {
    url.lastPathComponent
  }

  /// The file as the preview column shows it.
  var previewDocument: PreviewDocument {
    PreviewDocument(url: url, completeness: completeness)
  }
}

/// Whether the configured archive folder can be filed into.
nonisolated enum ArchiveAvailability: Hashable, Sendable {
  /// The archive folder is there and accessible.
  case available
  /// The archive folder cannot be reached (missing, renamed, drive not mounted, permission denied).
  ///
  /// `displayPath` is the folder's path as the user should read it, for example "~/Archiv".
  case unreachable(displayPath: String)
}

/// How wide the main window is, as far as the sidebar's automatic collapsing cares.
nonisolated enum MainWindowWidthClass: Sendable {
  /// Narrower than `MainWindowModel.sidebarCollapseWidth`: the sidebar gives way to the preview.
  case narrow
  /// Wide enough for all three columns.
  case regular
}

/// The state of one main window: what is selected, which columns are shown, and the edge states it shows.
///
/// The main window's views read it, and the menu commands reach it through the `mainWindowModel` focused value while
/// the main window is key. Later steps drive it: the sidebar sets `selectedFile`, the folder settings set
/// `areFoldersConfigured` and `archiveAvailability`.
@Observable
final class MainWindowModel {
  /// Below this window width the sidebar collapses on its own, so that the preview keeps its room.
  nonisolated static let sidebarCollapseWidth: CGFloat = 1180

  /// The file selected in the sidebar; `nil` while nothing is selected.
  var selectedFile: SelectedFile?
  /// Whether the filing panel (the window's inspector) is shown.
  var isFilingPanelShown = true
  /// Which split-view columns are shown. The sidebar toggle (⌃⌘S) and the automatic collapsing change it.
  var columnVisibility: NavigationSplitViewVisibility = .all
  /// Whether an archive folder and at least one inbox are configured. While not, the window shows the welcome view.
  var areFoldersConfigured: Bool
  /// Whether the archive folder can be filed into.
  var archiveAvailability: ArchiveAvailability = .available
  /// The controller the window's zoom commands go through to the preview.
  let previewController = PreviewController()

  /// Whether the sidebar is hidden because the window became narrow, rather than by the user. Only then does the
  /// sidebar come back by itself when the window is widened again.
  @ObservationIgnored private var isSidebarCollapsedForWidth = false

  /// Creates the state of a main window.
  init(areFoldersConfigured: Bool, selectedFile: SelectedFile? = nil) {
    self.areFoldersConfigured = areFoldersConfigured
    self.selectedFile = selectedFile
  }

  /// Collapses the sidebar when the window becomes narrow, and shows it again when the window is widened if it is
  /// still hidden from that collapse. A sidebar the user hid while the window was wide stays hidden.
  func windowWidthClassChanged(to widthClass: MainWindowWidthClass) {
    switch widthClass {
    case .narrow:
      guard columnVisibility != .detailOnly else { return }
      columnVisibility = .detailOnly
      isSidebarCollapsedForWidth = true
    case .regular:
      guard isSidebarCollapsedForWidth else { return }
      isSidebarCollapsedForWidth = false
      if columnVisibility == .detailOnly {
        columnVisibility = .all
      }
    }
  }
}

extension FocusedValues {
  /// The model of the key main window, for the menu commands; `nil` while another window is key.
  @Entry var mainWindowModel: MainWindowModel?
}
