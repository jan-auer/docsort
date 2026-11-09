import AppKit
import DocsortCore
import Observation
import SwiftUI

/// The inbox file selected in the main window's sidebar.
nonisolated struct SelectedFile: Hashable, Sendable {
  /// The file's identity.
  let id: InboxItemID
  /// The file's current location: in the inbox, or in the archive once filed.
  let url: URL
  /// The name the file had in the inbox, with its extension.
  let originalName: String
  /// The display name of the inbox the file is listed under, as Settings names it.
  let inboxName: String
  /// Whether the file's content is all on disk yet.
  let completeness: PreviewDocument.Completeness
  /// What happened to the file in this session; `nil` while it is unhandled.
  let mark: InboxItemMark?

  /// The file's current name with its extension: its inbox name until it is filed, then its name in the archive.
  var name: String {
    url.lastPathComponent
  }

  /// Whether the file was moved to the Trash in this session.
  var isTrashed: Bool {
    mark?.isTrashed == true
  }

  /// The file as the preview column shows it.
  var previewDocument: PreviewDocument {
    PreviewDocument(url: url, completeness: completeness)
  }
}

/// A row of the sidebar list: a file, or a subfolder group's disclosure row.
nonisolated enum SidebarRowID: Hashable, Sendable {
  /// A file row.
  case item(InboxItemID)
  /// The disclosure row of the subfolder at this URL.
  case group(URL)
}

/// The main window's three focus stops.
nonisolated enum MainWindowFocus: Hashable, Sendable {
  /// The inbox list.
  case sidebar
  /// The destination filter field.
  case destinationFilter
  /// The name field.
  case nameField
}

/// A request to move keyboard focus, new each time so the same target can be requested twice.
nonisolated struct FocusRequest: Hashable, Sendable {
  /// Distinguishes this request from the previous one.
  let id = UUID()
  /// Where focus should go.
  let target: MainWindowFocus
}

/// A short confirmation in the window's bottom bar, shown for a few seconds.
nonisolated struct WindowStatusMessage: Hashable, Sendable, Identifiable {
  /// Distinguishes this message from the previous one, so the same text twice is shown twice.
  let id = UUID()
  /// The message.
  let text: String
}

/// An alert about a failed filing action.
nonisolated struct FilingAlert: Identifiable, Sendable {
  /// Distinguishes this alert from the previous one.
  let id = UUID()
  /// What failed.
  let title: String
  /// Why it failed.
  let message: String
}

/// How the main window's width compares with the width below which the sidebar gives way.
nonisolated enum MainWindowWidthClass: Sendable {
  /// Narrower than `MainWindowModel.sidebarCollapseWidth`: the sidebar gives way to the preview.
  case narrow
  /// Wide enough for all three columns.
  case regular
}

/// The state of one main window: what is selected, which columns are shown, where focus goes, what the filing panel
/// holds and the messages it shows.
///
/// The main window's views read it, and the menu commands reach it through the `mainWindowModel` focused value while
/// the main window is key. The rows come from the app's `InboxLibrary`, the destinations from its `ArchiveLibrary`,
/// and moves, trashes and undos go through its `FilingModel` (see `MainWindowModel+Filing.swift`).
@Observable
final class MainWindowModel {
  /// Below this window width the sidebar collapses on its own, so that the preview keeps its room.
  nonisolated static let sidebarCollapseWidth: CGFloat = 1180

  /// The selected sidebar row; `nil` while nothing is selected.
  var sidebarSelection: SidebarRowID? {
    didSet {
      guard sidebarSelection != oldValue else { return }
      if case .item(let id) = sidebarSelection { inboxes.markSeen(id) }
      guard !isFollowingReplacement else { return }
      resetPanel()
    }
  }
  /// Subfolder groups the user collapsed; groups are expanded otherwise.
  var collapsedGroups: Set<URL> = []
  /// Whether the filing panel is shown: the pane that sits beside the preview, laid over the PDF view's trailing edge.
  var isFilingPanelShown = true
  /// Which split-view columns are shown. The sidebar toggle (⌃⌘S) and the automatic collapsing change it.
  var columnVisibility: NavigationSplitViewVisibility = .all
  /// Where keyboard focus is, as the views report it.
  var focus: MainWindowFocus?
  /// Whether a sheet or alert is attached to the main window (see `AttachedSheetTracker`). The window's menu commands
  /// are off meanwhile, so keys typed into the sheet stay there.
  var isSheetAttached = false
  /// The latest request to move focus, which the views carry out.
  private(set) var focusRequest: FocusRequest?
  /// The confirmation shown in the bottom bar.
  var statusMessage: WindowStatusMessage?
  /// A name conflict waiting for the user's choice.
  var conflict: FilingConflict?
  /// A Move Back blocked by a taken inbox name, waiting for the user's choice between Keep Both and Cancel.
  var moveBackConflict: MoveBackConflict?
  /// A failed action to tell the user about.
  var alert: FilingAlert?
  /// Whether a move, trash, Move Back or Put Back is under way; further ones wait for it.
  var isFilingInProgress = false

  /// The app's configured folders.
  let folders: FolderLibrary
  /// The app's inbox rows.
  let inboxes: InboxLibrary
  /// The app's archive index.
  let archive: ArchiveLibrary
  /// The app's filing service, as the main actor sees it.
  let filing: FilingModel
  /// The destination-search settings.
  let search: SearchSettings
  /// What the filing panel holds for the selected file, beyond the destination picker.
  let panel = FilingPanelModel()
  /// The filing panel's destination picker.
  let picker = DestinationPickerModel(folderFiles: ArchiveFolderFileListing())
  /// The controller the window's zoom commands go through to the preview.
  let previewController = PreviewController()
  /// The window's undo manager, which moves and trashes are registered with; set by the window's view.
  @ObservationIgnored weak var undoManager: UndoManager?

  /// Whether the sidebar is hidden because the window became narrow, rather than by the user. Only then does the
  /// sidebar come back by itself when the window is widened again.
  @ObservationIgnored private var isSidebarCollapsedForWidth = false
  /// Set while the selection moves to the file that replaced the selected one, which keeps the filing panel as it is.
  @ObservationIgnored private var isFollowingReplacement = false
  /// Whether the first file was selected after the first listing of the inboxes (or there was nothing to select), so
  /// later listings leave the selection alone.
  @ObservationIgnored var hasMadeInitialSelection = false
  /// Keeps the picker's index, recents and ranking in step with the app's models.
  @ObservationIgnored private var pickerInputsTask: Task<Void, Never>?
  /// The observers telling the archive library when the app becomes or resigns active, so it picks up folders
  /// created in Finder meanwhile.
  @ObservationIgnored private var activationObservers: [NotificationCenter.ObservationToken] = []

  #if DEBUG
    /// A file shown as selected regardless of the sidebar, for SwiftUI previews.
    @ObservationIgnored private var previewSelectedFile: SelectedFile?
  #endif

  /// Creates the state of a main window showing the app's models.
  init(
    folders: FolderLibrary, inboxes: InboxLibrary, archive: ArchiveLibrary, filing: FilingModel,
    search: SearchSettings
  ) {
    self.folders = folders
    self.inboxes = inboxes
    self.archive = archive
    self.filing = filing
    self.search = search
    picker.onEvent = { [weak self] event in self?.handlePickerEvent(event) }
    inboxes.onExternalChange = { [weak self] change in self?.follow(change) }
    pickerInputsTask = Task { [weak self, archive, filing, search] in
      for await inputs in Observations({
        PickerInputs(
          index: archive.index, isRebuildingIndex: archive.isRebuilding, recents: filing.recents,
          ranking: search.ranking)
      }) {
        guard let self else { return }
        apply(inputs)
      }
    }
    activationObservers = [
      NotificationCenter.default.addObserver(of: NSApplication.self, for: .didBecomeActive) {
        [archive] _ in archive.appBecameActive()
      },
      NotificationCenter.default.addObserver(of: NSApplication.self, for: .didResignActive) {
        [archive] _ in archive.appResignedActive()
      },
    ]
  }

  isolated deinit {
    pickerInputsTask?.cancel()
    for observer in activationObservers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  /// Hands the archive index, the recent destinations and the ranking setting to the picker, changing only what
  /// changed, so the picker keeps its highlight.
  private func apply(_ inputs: PickerInputs) {
    if inputs.index?.root != picker.index?.root || inputs.index?.folders != picker.index?.folders {
      picker.index = inputs.index
    }
    if inputs.isRebuildingIndex != picker.isRebuildingIndex {
      picker.isRebuildingIndex = inputs.isRebuildingIndex
    }
    if inputs.recents != picker.recents { picker.recents = inputs.recents }
    if inputs.ranking != picker.ranking { picker.ranking = inputs.ranking }
  }

  /// Lists the inboxes again and rebuilds the archive's folder index, for folders and files changed outside docsort
  /// (View › Refresh, ⌘R, and the picker's refresh button). The picker keeps the previous index, and with it its
  /// scope, filter and highlight, until the new one is ready.
  func refresh() {
    inboxes.refresh()
    archive.rebuild()
  }

  /// Clears the filing panel for the selected file: the name field holds the file's current name; the picker is at
  /// the archive root, or, for a filed file, has the file's current folder chosen.
  func resetPanel() {
    let file = selectedFile
    panel.reset(currentName: file?.name)
    if case .filed(_, let destinationPath, _, _) = file?.mark {
      picker.reset(choosing: .folder(destinationPath))
    } else {
      picker.reset()
    }
  }

  /// The selected file; `nil` while nothing or a group is selected.
  var selectedFile: SelectedFile? {
    #if DEBUG
      if let previewSelectedFile { return previewSelectedFile }
    #endif
    guard case .item(let id) = sidebarSelection else { return nil }
    return file(id)
  }

  /// The file `id` as the window shows it; `nil` when no section lists it.
  func file(_ id: InboxItemID) -> SelectedFile? {
    guard let row = inboxes.row(for: id) else { return nil }
    return SelectedFile(
      id: id, url: row.currentURL, originalName: row.item.name,
      inboxName: inboxes.sectionLabel(of: id) ?? "",
      completeness: row.item.isIncompleteDownload ? .downloading : .complete, mark: row.mark)
  }

  /// Whether an archive folder and at least one inbox are configured. While not, the window shows the welcome view.
  var areFoldersConfigured: Bool {
    folders.areFoldersConfigured
  }

  /// Whether the archive folder can be filed into.
  var archiveAvailability: ArchiveAvailability {
    folders.archiveAvailability
  }

  /// Whether a text field (the destination filter or the name field) has keyboard focus.
  var isTextFieldFocused: Bool {
    focus == .destinationFilter || focus == .nameField
  }

  /// Asks the views to move keyboard focus to `target`.
  ///
  /// Focus in the filing panel shows the panel first, so typed text never goes into a filter the user can't see.
  func requestFocus(_ target: MainWindowFocus) {
    if target == .destinationFilter || target == .nameField { isFilingPanelShown = true }
    if target == .destinationFilter { panel.isFilterFocusPending = true }
    focusRequest = FocusRequest(target: target)
  }

  /// Selects the file `id`, expanding its group if it is collapsed.
  func select(_ id: InboxItemID) {
    if let row = inboxes.row(for: id), let subfolderPath = row.item.subfolderPath {
      // The group is the item's top-level folder: its parent, once per subfolder level.
      var groupURL = row.item.url.deletingLastPathComponent()
      for _ in subfolderPath.split(separator: "/").dropFirst() {
        groupURL = groupURL.deletingLastPathComponent()
      }
      let groupPath = Self.folderPath(of: groupURL)
      collapsedGroups = collapsedGroups.filter { Self.folderPath(of: $0) != groupPath }
    }
    sidebarSelection = .item(id)
  }

  /// The standardized path of the folder at `url`, without a trailing slash, under which equal folders compare equal.
  /// Follows a change made outside docsort: when the selected file was removed, selects the next unfiled file (the
  /// panel resets, discarding what was typed) and says so in the bottom bar; when the selected download completed into
  /// a file of its own (or a safe-save replaced it), selects that file, keeping what the filing panel holds.
  private func follow(_ change: InboxExternalChange) {
    switch change {
    case .removed(let id, let name, let inboxLabel, let next):
      guard sidebarSelection == .item(id) else { return }
      if let next {
        select(next)
      } else {
        sidebarSelection = nil
      }
      statusMessage = WindowStatusMessage(
        text: "“\(name)” was removed from \(inboxLabel) outside docsort.")
    case .replaced(let id, let replacement):
      guard sidebarSelection == .item(id) else { return }
      isFollowingReplacement = true
      defer { isFollowingReplacement = false }
      select(replacement)
    }
  }

  private static func folderPath(of url: URL) -> String {
    let path = url.standardizedFileURL.path(percentEncoded: false)
    return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
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

  #if DEBUG
    /// A window model for SwiftUI previews, with inert services, showing `folders` and `inboxes` and, when given,
    /// `selectedFile` as selected.
    static func preview(
      folders: FolderLibrary, inboxes: InboxLibrary = InboxLibrary(),
      selectedFile: SelectedFile? = nil
    ) -> MainWindowModel {
      let environment = AppEnvironment.inert(named: "previews")
      let model = MainWindowModel(
        folders: folders, inboxes: inboxes, archive: ArchiveLibrary(),
        filing: FilingModel(
          service: .make(environment: environment, expectedChanges: ExpectedChanges()),
          historyFileURL: environment.filingHistoryURL),
        search: SearchSettings(defaults: environment.defaults))
      model.previewSelectedFile = selectedFile
      // Previews show the selection they are given, not the first file selected at launch.
      model.hasMadeInitialSelection = true
      model.resetPanel()
      return model
    }
  #endif
}

extension FocusedValues {
  /// The model of the key main window, for the menu commands; `nil` while another window is key.
  @Entry var mainWindowModel: MainWindowModel?
}

/// What the destination picker takes from the app's models.
nonisolated private struct PickerInputs: Sendable {
  let index: DestinationIndex?
  let isRebuildingIndex: Bool
  let recents: RecentDestinations
  let ranking: ScopedRanking
}
