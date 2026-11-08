import DocsortCore
import Foundation
import OSLog
import Observation

/// The History entries of one day, in the order they happened.
nonisolated struct HistoryDay: Identifiable, Hashable, Sendable {
  /// The start of the day, which identifies it.
  let id: Date
  /// The day's entries, oldest first.
  let entries: [HistoryEntry]

  /// The day as its section header names it: "Today · Sunday, 13 October 2033", "Yesterday · …", or the date alone.
  func title(now: Date, calendar: Calendar) -> String {
    let date = id.formatted(
      Date.FormatStyle(
        date: .complete, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))
    if calendar.isDate(id, inSameDayAs: now) { return "Today · \(date)" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
      calendar.isDate(id, inSameDayAs: yesterday)
    {
      return "Yesterday · \(date)"
    }
    return date
  }
}

/// A Move Back from History whose inbox name is taken, waiting for the user's choice between Keep Both and Cancel.
nonisolated struct HistoryMoveBackConflict: Identifiable, Sendable {
  /// Distinguishes this conflict from the previous one.
  let id = UUID()
  /// The entry whose file was to move back.
  let entry: HistoryEntry
  /// The item in the way, at the file's inbox path.
  let blockingURL: URL
}

/// The state of the History window: every move and trash of the filing history grouped by day, the search, the
/// selection, and the actions on the selected entry.
///
/// It reads the history through the app's `FilingModel` (`refresh()`, when the window appears and after each action;
/// there are no live updates) and moves files back through it. After Move Back or Put Back it updates the main
/// window's inbox rows the way the filing panel does, through `InboxLibrary.setMark`.
@Observable
final class HistoryModel {
  /// Every entry, oldest first.
  private(set) var entries: [HistoryEntry] = []
  /// Whether the history has been read at least once.
  private(set) var isLoaded = false
  /// The search text; every word must appear in one of the entry's columns.
  var searchText = "" {
    didSet {
      guard searchText != oldValue else { return }
      statusMessage = nil
      keepSelectionVisible()
    }
  }
  /// The selected entry.
  var selection: HistoryEntry.ID? {
    didSet {
      if selection != oldValue { statusMessage = nil }
    }
  }
  /// What the last action did, for the window's footer.
  private(set) var statusMessage: String?
  /// A Move Back blocked by a taken inbox name, waiting for the user's choice.
  var moveBackConflict: HistoryMoveBackConflict?
  /// A failed action to tell the user about.
  var alert: FilingAlert?
  /// Whether a Move Back or Put Back is under way; further ones wait for it.
  private(set) var isActionInProgress = false

  /// The main window's model, for its inbox rows, folders and filing service.
  @ObservationIgnored let mainWindow: MainWindowModel
  /// The calendar the entries are grouped into days with.
  @ObservationIgnored let calendar: Calendar

  #if DEBUG
    /// Whether the entries were given for a SwiftUI preview, so `refresh()` keeps them.
    @ObservationIgnored private var isShowingPreviewEntries = false
  #endif

  /// The History of the app whose main window `mainWindow` shows, grouping days in `calendar`.
  init(mainWindow: MainWindowModel, calendar: Calendar = .current) {
    self.mainWindow = mainWindow
    self.calendar = calendar
  }

  private var filing: FilingModel { mainWindow.filing }
  private var inboxes: InboxLibrary { mainWindow.inboxes }

  // MARK: Listing

  /// Whether the filing history could be read.
  var historyAvailability: FilingHistoryAvailability {
    filing.historyAvailability
  }

  /// Reads the history again. Keeps the selection while its entry is still listed, and otherwise selects the newest
  /// entry the search shows.
  func refresh() async {
    #if DEBUG
      if isShowingPreviewEntries { return }
    #endif
    let events = await filing.events()
    entries = await HistoryListing.entries(from: events, folders: currentFolders())
    isLoaded = true
    keepSelectionVisible()
  }

  /// The entries the search shows, oldest first.
  var filteredEntries: [HistoryEntry] {
    Self.entries(entries, matching: searchText)
  }

  /// The entries the search shows, grouped by day, oldest first.
  var days: [HistoryDay] {
    Self.days(grouping: filteredEntries, in: calendar)
  }

  /// The entries of `entries` that `searchText` matches: every word of it appears, ignoring case and diacritics, in
  /// one of the columns the table shows or in the entry's tag.
  static func entries(_ entries: [HistoryEntry], matching searchText: String) -> [HistoryEntry] {
    let words = searchText.split(whereSeparator: \.isWhitespace).map(String.init)
    guard !words.isEmpty else { return entries }
    return entries.filter { entry in
      let text = searchableText(of: entry)
      return words.allSatisfy {
        text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
      }
    }
  }

  /// `entries` (oldest first) grouped into the days of `calendar` they happened on, oldest first.
  static func days(grouping entries: [HistoryEntry], in calendar: Calendar) -> [HistoryDay] {
    var days: [HistoryDay] = []
    var dayStart: Date?
    var dayEntries: [HistoryEntry] = []
    for entry in entries {
      let start = calendar.startOfDay(for: entry.date)
      if let dayStart, start != dayStart {
        days.append(HistoryDay(id: dayStart, entries: dayEntries))
        dayEntries = []
      }
      dayStart = start
      dayEntries.append(entry)
    }
    if let dayStart { days.append(HistoryDay(id: dayStart, entries: dayEntries)) }
    return days
  }

  /// How many entries the search shows: "3 entries", or "1 of 3 entries" while searching.
  var countText: String {
    let total = entries.count
    let shown = filteredEntries.count
    let unit = total == 1 ? "entry" : "entries"
    return shown == total ? "\(total) \(unit)" : "\(shown) of \(total) \(unit)"
  }

  /// The entry with `id`, shown or not.
  func entry(id: HistoryEntry.ID) -> HistoryEntry? {
    entries.first { $0.id == id }
  }

  /// The selected entry, while the search shows it.
  var selectedEntry: HistoryEntry? {
    guard let selection else { return nil }
    return filteredEntries.first { $0.id == selection }
  }

  /// Selects the newest shown entry when the selection is not shown.
  private func keepSelectionVisible() {
    let shown = filteredEntries
    if let selection, shown.contains(where: { $0.id == selection }) { return }
    selection = shown.last?.id
  }

  /// The text the search looks in: every column the table shows, and the entry's tag.
  private static func searchableText(of entry: HistoryEntry) -> String {
    [
      entry.date.formatted(date: .omitted, time: .shortened), entry.originalName,
      entry.inboxName ?? "", entry.newName ?? "", entry.destination, tag(for: entry) ?? "",
    ].joined(separator: "\n")
  }

  /// The tag the table shows before an entry's new name: what it did beyond filing, or that it was undone.
  static func tag(for entry: HistoryEntry) -> String? {
    if case .undone = entry.place { return "Undone" }
    return switch entry.kind {
    case .filed: nil
    case .renamed: "Renamed"
    case .movedOn: "Moved"
    case .movedBack: "Moved back"
    case .trashed: "Trashed"
    case .replaced: "Replaced"
    }
  }

  /// The archive folder and inboxes as configured now.
  private func currentFolders() -> HistoryFolders {
    let folders = mainWindow.folders
    return HistoryFolders(
      archiveRoot: folders.archiveRoot.map(Self.location(of:)),
      inboxes: folders.inboxes.map {
        HistoryFolders.Inbox(label: $0.displayLabel, url: Self.location(of: $0.folder))
      })
  }

  /// Where `folder` is: its resolved URL, or its last known path when it could not be resolved.
  private static func location(of folder: ResolvedFolder) -> URL {
    folder.url ?? URL(filePath: folder.reference.lastKnownPath, directoryHint: .isDirectory)
  }

  // MARK: Actions

  /// Whether `entry`'s file can be opened or revealed: it is still where the entry put it.
  func canOpen(_ entry: HistoryEntry) -> Bool {
    entry.isCurrent
  }

  /// What returns `entry`'s file to its inbox: Move Back for a filed, renamed or moved file, Put Back for a trashed
  /// one; `nil` for other entries and for files no longer where the entry put them.
  func returnAction(for entry: HistoryEntry) -> ReturnToInboxAction? {
    guard entry.isCurrent else { return nil }
    return switch entry.kind {
    case .filed, .renamed, .movedOn: .moveBack
    case .trashed: .putBack
    case .movedBack, .replaced: nil
    }
  }

  /// Whether `entry`'s file can be returned to its inbox now: the entry allows it, the history is writable and no
  /// other action is under way.
  func canReturnToInbox(_ entry: HistoryEntry) -> Bool {
    returnAction(for: entry) != nil && filing.isHistoryWritable && !isActionInProgress
  }

  /// The main window's row of `entry`'s file, while the file is still where the entry put it and this session's
  /// inbox list shows it.
  func inboxRowID(for entry: HistoryEntry) -> InboxItemID? {
    guard entry.isCurrent else { return nil }
    return inboxRowID(of: entry)
  }

  /// Moves `entry`'s file back to its inbox, or puts it back from the Trash; see `returnAction(for:)`.
  func returnToInbox(_ entry: HistoryEntry) async {
    await returnToInbox(entry, resolution: .refuse)
  }

  /// Keep Both in the Move Back conflict alert: moves the file back under a numbered name beside the item in the way.
  func resolve(_ conflict: HistoryMoveBackConflict) async {
    await returnToInbox(conflict.entry, resolution: .keepBoth)
  }

  private func returnToInbox(_ entry: HistoryEntry, resolution: ConflictResolution) async {
    guard canReturnToInbox(entry), let action = returnAction(for: entry) else { return }
    isActionInProgress = true
    defer { isActionInProgress = false }
    let rowID = inboxRowID(of: entry)
    let inbox = entry.inboxName ?? "its inbox"
    switch action {
    case .moveBack:
      do {
        let outcome = try await filing.moveBack(
          document: entry.documentID, at: entry.url, resolution: resolution)
        returned(rowID)
        await refresh()
        selection = outcome.event.id
        statusMessage =
          "Moved “\(entry.currentName)” back to \(inbox) as \(outcome.movedURL.lastPathComponent)"
      } catch .fileOperation(.nameConflict(let existing)) {
        moveBackConflict = HistoryMoveBackConflict(entry: entry, blockingURL: existing)
      } catch .fileChangedSinceFiling(let url) {
        Logger.filing.error(
          "Refused to move \(url.lastPathComponent, privacy: .private) back from History: another file is there since it was filed"
        )
        alert = FilingAlert(
          title: "“\(entry.currentName)” can’t be moved back to \(inbox)",
          message: FilingMessages.text(for: .fileChangedSinceFiling(url)))
        await refresh()
      } catch {
        Logger.filing.error(
          "Moving \(entry.currentName, privacy: .private) back from History failed: \(String(describing: error), privacy: .private)"
        )
        alert = FilingAlert(
          title: "“\(entry.currentName)” can’t be moved back to \(inbox)",
          message: FilingMessages.text(for: error))
        await refresh()
      }
    case .putBack:
      do {
        _ = try await filing.putBack(entry.url)
        returned(rowID)
        await refresh()
        statusMessage = "Put “\(entry.originalName)” back in \(inbox)"
      } catch {
        Logger.filing.error(
          "Putting \(entry.originalName, privacy: .private) back from History failed: \(String(describing: error), privacy: .private)"
        )
        alert = FilingAlert(
          title: "“\(entry.originalName)” can’t be put back",
          message: FilingMessages.text(for: error))
        await refresh()
      }
    }
  }

  /// After a file came back to its inbox: unmarks its row (`rowID`), as the filing panel does. A file without a row (filed
  /// in an earlier session) gets one, and a row shows the file under a numbered name, once the watcher lists it.
  private func returned(_ rowID: InboxItemID?) {
    guard let rowID else { return }
    inboxes.setMark(rowID, nil)
    if mainWindow.selectedFile?.id == rowID { mainWindow.resetPanel() }
  }

  /// The main window's row of `entry`'s file. A file in the archive is found by its filing history document, the way
  /// the filing panel acts on it, so a file that took its place is never taken for it; a trashed file by its place in
  /// the Trash, and a file back in its inbox by its unhandled row there.
  private func inboxRowID(of entry: HistoryEntry) -> InboxItemID? {
    switch entry.kind {
    case .filed, .renamed, .movedOn:
      return inboxes.rowIDs(filedAs: entry.documentID).first
    case .trashed, .replaced, .movedBack:
      return inboxes.orderedRows.first { row in
        switch row.mark {
        case .filed: false
        case .trashed(let trashedURL, _): Self.isSameLocation(trashedURL, entry.url)
        case nil: Self.isSameLocation(row.item.url, entry.url)
        }
      }?.id
    }
  }

  private static func isSameLocation(_ url: URL, _ other: URL) -> Bool {
    url.standardizedFileURL.path(percentEncoded: false)
      == other.standardizedFileURL.path(percentEncoded: false)
  }

  #if DEBUG
    /// A History showing `entries` as given, for SwiftUI previews; nothing is read from a history.
    static func preview(entries: [HistoryEntry]) -> HistoryModel {
      let environment = AppEnvironment.inert(named: "previews")
      let model = HistoryModel(
        mainWindow: .preview(folders: FolderLibrary(environment: environment)))
      model.entries = entries
      model.isLoaded = true
      model.isShowingPreviewEntries = true
      model.selection = entries.last?.id
      return model
    }
  #endif
}
