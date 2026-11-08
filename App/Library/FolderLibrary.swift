import DocsortCore
import Foundation
import OSLog
import Observation

/// One configured inbox and how its folder resolved in this launch, as Settings and the sidebar show it.
nonisolated struct ConfiguredInbox: Identifiable, Equatable, Sendable {
  /// The inbox as stored in the settings: its identity, label and folder reference.
  let inbox: InboxFolder
  /// The outcome of resolving the inbox's folder: its URL (with the security scope active) and availability.
  let folder: ResolvedFolder

  /// An inbox with its resolution outcome.
  init(inbox: InboxFolder, folder: ResolvedFolder) {
    self.inbox = inbox
    self.folder = folder
  }

  /// The inbox's stable identity across launches.
  var id: InboxFolder.ID { inbox.id }
  /// The name shown for the inbox: its label, or the folder name when it has none.
  var displayLabel: String { inbox.displayLabel }
  /// The folder's location with its security scope active; `nil` unless the folder is usable.
  var url: URL? { folder.url }
  /// Whether the inbox's folder can be used in this launch.
  var availability: FolderAvailability { folder.availability }
}

extension ResolvedFolder {
  /// The folder's last known path with the home folder abbreviated, for example `~/Archiv/_Neu/Scanner`.
  nonisolated var displayPath: String {
    DisplayPath.abbreviating(reference.lastKnownPath)
  }

  /// Whether the folder can be used in this launch: it is available, or stale but still accessible.
  nonisolated var isUsable: Bool {
    switch availability {
    case .available, .stale: true
    case .missing, .unreachable: false
    }
  }
}

/// Whether the configured archive folder can be filed into.
nonisolated enum ArchiveAvailability: Hashable, Sendable {
  /// No archive folder has been chosen yet; the main window shows the welcome view.
  case notChosen
  /// The archive folder is there and accessible.
  case available
  /// The archive folder cannot be reached (missing, renamed, drive not mounted, permission denied).
  ///
  /// `displayPath` is the folder's path as the user should read it, for example "~/Archiv".
  case unreachable(displayPath: String)
}

/// An error from a folder edit to show the user in an alert.
nonisolated struct FolderSettingsAlert: Identifiable, Sendable {
  /// Distinguishes one alert from the next, so the same error twice is shown twice.
  let id = UUID()
  /// What failed, as the alert's title.
  let title: String
  /// Why it failed, in the system's words.
  let message: String
}

/// The configured folders, the archive root and the inboxes, with the security scopes that make them accessible.
///
/// One per app. At launch it loads the folder settings from the preferences and resolves them with the environment's
/// `FolderResolver`, keeping the `FolderAccessSession` (and so the folders' security scopes) alive. Renewed bookmarks
/// and moved folders (`settingsChanged`) are saved straight away.
///
/// Every edit saves the changed settings first and then resolves them again. The new session is created before the
/// old one is ended, so a folder in both never loses its scope in between. An edit whose settings cannot be saved is
/// not applied.
///
/// When the stored settings cannot be read, `settingsReadError` says why, nothing is configured, and edits are
/// refused, so the stored value is never overwritten. Only `resetFolderSettings()` removes it.
///
/// Errors from edits (a bookmark that cannot be made, settings that cannot be saved) are logged and set as `alert`.
///
/// The library uses only Foundation, Observation and DocsortCore, so its logic can move into the core later. Folders
/// are picked on the view side (`FolderChooser`), which hands the picked URL to `setArchiveRoot(to:)`,
/// `addInbox(folder:)` or `replaceFolder(ofInbox:with:)`, and views present `alert`.
@Observable
final class FolderLibrary {
  /// The archive root and how it resolved; `nil` until the user chooses one.
  private(set) var archiveRoot: ResolvedFolder?
  /// The inboxes in sidebar order, each with how its folder resolved.
  private(set) var inboxes: [ConfiguredInbox] = []
  /// Why the stored folder settings could not be read; while set, nothing is configured and edits are refused.
  private(set) var settingsReadError: PreferenceError?
  /// The error to show the user, until the alert is dismissed.
  var alert: FolderSettingsAlert?

  @ObservationIgnored private let environment: AppEnvironment
  @ObservationIgnored private let preference: StoredPreference<FolderSettings>
  /// The current resolution; holding it keeps the folders' security scopes active.
  @ObservationIgnored private var session: FolderAccessSession?

  /// Loads the folder settings from `environment`'s preferences and resolves them.
  init(environment: AppEnvironment) {
    self.environment = environment
    preference = FolderSettings.preference(in: environment.defaults)
    let stored: FolderSettings?
    do {
      stored = try preference.load()
    } catch {
      Logger.folders.error(
        "The folder settings could not be read; they are left untouched until reset: \(error.description, privacy: .public)"
      )
      settingsReadError = error
      return
    }
    if stored == nil {
      Logger.folders.notice("No folder settings stored yet (first launch)")
    }
    resolve(stored ?? .empty, cause: "launch")
  }

  /// Whether an archive root and at least one inbox are configured; until then the main window shows the welcome view.
  var areFoldersConfigured: Bool {
    archiveRoot != nil && !inboxes.isEmpty
  }

  /// Whether the archive root can be filed into, as the filing panel shows it.
  var archiveAvailability: ArchiveAvailability {
    guard let archiveRoot else { return .notChosen }
    return archiveRoot.isUsable ? .available : .unreachable(displayPath: archiveRoot.displayPath)
  }

  /// Whether the folders can be edited: false while the stored settings cannot be read.
  var isEditable: Bool {
    settingsReadError == nil
  }

  // MARK: Where folder pickers start

  /// The folder a picker for the archive root starts in: the current archive root, or the parent of its last known
  /// path when it cannot be used; `nil` when none is chosen.
  var archiveRootPickerStart: URL? {
    Self.pickerStart(forReplacing: archiveRoot)
  }

  /// The folder a picker for a new inbox starts in: the folder holding the last inbox, else the archive root.
  var newInboxPickerStart: URL? {
    let lastInboxParent = inboxes.last.map { inbox in
      URL(filePath: inbox.folder.reference.lastKnownPath, directoryHint: .isDirectory)
        .deletingLastPathComponent()
    }
    return lastInboxParent ?? archiveRoot?.url
  }

  /// The folder a picker for re-choosing the folder of the inbox with `id` starts in, as for the archive root.
  func pickerStart(forInbox id: InboxFolder.ID) -> URL? {
    Self.pickerStart(forReplacing: inboxes.first(where: { $0.id == id })?.folder)
  }

  // MARK: Edits

  /// Makes the folder at `url`, which the app can access (it came from the open panel), the archive root.
  func setArchiveRoot(to url: URL) {
    guard let reference = makeReference(for: url) else { return }
    applyEdit("setting the archive folder") { settings in
      settings.archiveRoot = reference
    }
  }

  /// Adds the folder at `url`, which the app can access (it came from the open panel), as an inbox at the end.
  func addInbox(folder url: URL) {
    guard let reference = makeReference(for: url) else { return }
    applyEdit("adding an inbox") { settings in
      settings.addInbox(reference)
    }
  }

  /// Points the inbox with `id` at the folder at `url`, keeping its identity, label and position.
  func replaceFolder(ofInbox id: InboxFolder.ID, with url: URL) {
    guard let reference = makeReference(for: url) else { return }
    applyEdit("replacing an inbox's folder") { settings in
      guard let index = settings.inboxes.firstIndex(where: { $0.id == id }) else { return }
      settings.inboxes[index].folder = reference
    }
  }

  /// Removes the inbox with `id`; its folder and files are untouched.
  func removeInbox(id: InboxFolder.ID) {
    applyEdit("removing an inbox") { settings in
      settings.removeInbox(id: id)
    }
  }

  /// Sets the label of the inbox with `id`; a blank label shows the folder name.
  func relabelInbox(id: InboxFolder.ID, to label: String) {
    guard let inbox = inboxes.first(where: { $0.id == id }), (inbox.inbox.label ?? "") != label
    else {
      return
    }
    applyEdit("renaming an inbox") { settings in
      settings.relabelInbox(id: id, to: label)
    }
  }

  /// Moves the inboxes at `offsets` before the inbox at `destination`, as a list's `onMove` does.
  func moveInboxes(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    applyEdit("reordering inboxes") { settings in
      settings.moveInboxes(fromOffsets: offsets, toOffset: destination)
    }
  }

  /// Removes the stored folder settings, including unreadable ones, and starts again with nothing configured.
  func resetFolderSettings() {
    Logger.folders.notice("Resetting the folder settings at the user's request")
    preference.remove()
    settingsReadError = nil
    resolve(.empty, cause: "reset")
  }

  // MARK: Resolution

  /// A bookmark reference for the folder at `url`; on failure the error is logged and shown, and the result is `nil`.
  private func makeReference(for url: URL) -> FolderReference? {
    guard isEditable else {
      Logger.folders.error("Refusing a folder edit: the stored folder settings could not be read")
      return nil
    }
    do {
      return try environment.folderResolver.makeReference(for: url)
    } catch {
      Logger.folders.error(
        "Could not create a bookmark: \(String(describing: error.underlying), privacy: .public) for \(url.path(percentEncoded: false), privacy: .private)"
      )
      alert = FolderSettingsAlert(
        title: "Docsort could not remember the folder “\(url.lastPathComponent)”",
        message: error.underlying.localizedDescription)
      return nil
    }
  }

  /// Applies `edit` to the current settings, saves them and resolves them again; logs as `description`.
  private func applyEdit(_ description: String, _ edit: (inout FolderSettings) -> Void) {
    guard isEditable else {
      Logger.folders.error(
        "Refusing \(description, privacy: .public): the stored folder settings could not be read")
      return
    }
    var settings = session?.settings ?? .empty
    edit(&settings)
    do {
      try preference.save(settings)
    } catch {
      Logger.folders.error(
        "Could not save the folder settings after \(description, privacy: .public): \(error.description, privacy: .public)"
      )
      alert = FolderSettingsAlert(
        title: "The folder settings could not be saved", message: error.description)
      return
    }
    resolve(settings, cause: description)
  }

  /// Resolves `settings` into a new session, then ends the previous one, and saves renewed bookmarks.
  private func resolve(_ settings: FolderSettings, cause: String) {
    let newSession = environment.folderResolver.resolve(settings)
    let previousSession = session
    session = newSession
    previousSession?.end()

    archiveRoot = newSession.archiveRoot
    inboxes = newSession.inboxes.map { ConfiguredInbox(inbox: $0.inbox, folder: $0.folder) }
    Self.log(newSession, cause: cause)

    guard newSession.settingsChanged else { return }
    do {
      try preference.save(newSession.settings)
      Logger.folders.notice("Saved the folder settings with renewed bookmarks or updated paths")
    } catch {
      // The session works for this launch; the next launch resolves the old bookmarks and tries again.
      Logger.folders.error(
        "Could not save renewed bookmarks or updated paths: \(error.description, privacy: .public)")
    }
  }

  /// Logs each folder's position and availability (public) and path (private), for checking bookmarks in the
  /// sandboxed app with `log stream`.
  private static func log(_ session: FolderAccessSession, cause: String) {
    let inboxCount = session.inboxes.count
    Logger.folders.notice(
      "Resolved folders (\(cause, privacy: .public)): archive root \(session.archiveRoot == nil ? "not chosen" : "configured", privacy: .public), \(inboxCount, privacy: .public) inbox(es), settings changed: \(session.settingsChanged, privacy: .public)"
    )
    if let archiveRoot = session.archiveRoot {
      Logger.folders.notice(
        "Archive root: \(logDescription(of: archiveRoot.availability), privacy: .public), scope \(archiveRoot.url == nil ? "not started" : "active", privacy: .public), path \(archiveRoot.reference.lastKnownPath, privacy: .private)\(logReason(of: archiveRoot.availability), privacy: .private)"
      )
    }
    for (index, inbox) in session.inboxes.enumerated() {
      Logger.folders.notice(
        "Inbox \(index + 1, privacy: .public) of \(inboxCount, privacy: .public): \(logDescription(of: inbox.folder.availability), privacy: .public), scope \(inbox.folder.url == nil ? "not started" : "active", privacy: .public), path \(inbox.folder.reference.lastKnownPath, privacy: .private)\(logReason(of: inbox.folder.availability), privacy: .private)"
      )
    }
  }

  /// The availability's name, without the reason (which may name the folder).
  private static func logDescription(of availability: FolderAvailability) -> String {
    switch availability {
    case .available: "available"
    case .stale: "stale (bookmark could not be renewed)"
    case .missing: "missing"
    case .unreachable: "unreachable"
    }
  }

  /// The unreachable reason as a log suffix, or nothing for the other availabilities.
  private static func logReason(of availability: FolderAvailability) -> String {
    guard case .unreachable(let reason) = availability else { return "" }
    return ", reason: \(reason)"
  }

  /// Where a picker starts when re-choosing `folder`: the folder itself, or the parent of its last known path when it
  /// cannot be used.
  private static func pickerStart(forReplacing folder: ResolvedFolder?) -> URL? {
    guard let folder else { return nil }
    if let url = folder.url { return url }
    return URL(filePath: folder.reference.lastKnownPath, directoryHint: .isDirectory)
      .deletingLastPathComponent()
  }

  #if DEBUG
    /// A library showing `archiveRoot` and `inboxes` as given, for SwiftUI previews; nothing is resolved or stored.
    static func preview(archiveRoot: ResolvedFolder?, inboxes: [ConfiguredInbox]) -> FolderLibrary {
      let library = FolderLibrary(environment: .inert(named: "previews"))
      library.archiveRoot = archiveRoot
      library.inboxes = inboxes
      return library
    }
  #endif
}
