import Foundation

/// The folders configured in Settings: the archive root and the inboxes, stored in app preferences.
public struct FolderSettings: Codable, Equatable, Sendable {
  /// The root of the archive folder tree documents are filed into; `nil` until the user picks one.
  public var archiveRoot: FolderReference?
  /// The inbox folders, in sidebar order.
  public var inboxes: [InboxFolder]

  /// Settings with the archive root `archiveRoot` and `inboxes` in sidebar order.
  public init(archiveRoot: FolderReference? = nil, inboxes: [InboxFolder] = []) {
    self.archiveRoot = archiveRoot
    self.inboxes = inboxes
  }

  /// Settings with no archive root and no inboxes, as on first launch.
  public static let empty = FolderSettings()

  /// The preference that stores the settings, under the key `"folderSettings"`.
  public static func preference(in defaults: UserDefaults) -> StoredPreference<FolderSettings> {
    StoredPreference(key: "folderSettings", defaults: defaults)
  }

  /// Appends an inbox for `folder` at the end of the sidebar and returns it.
  ///
  /// A blank `label` is stored as `nil`; any other label is stored trimmed.
  @discardableResult
  public mutating func addInbox(_ folder: FolderReference, label: String? = nil) -> InboxFolder {
    let inbox = InboxFolder(label: InboxFolder.normalisedLabel(label), folder: folder)
    inboxes.append(inbox)
    return inbox
  }

  /// Removes the inbox with `id`; does nothing when no inbox has that id.
  public mutating func removeInbox(id: InboxFolder.ID) {
    inboxes.removeAll { $0.id == id }
  }

  /// Sets the label of the inbox with `id`; a blank label is stored as `nil`, any other label trimmed.
  ///
  /// Does nothing when no inbox has that id.
  public mutating func relabelInbox(id: InboxFolder.ID, to label: String?) {
    guard let index = inboxes.firstIndex(where: { $0.id == id }) else {
      return
    }
    inboxes[index].label = InboxFolder.normalisedLabel(label)
  }

  /// Moves the inboxes at `offsets` so they sit before the inbox that was at `destination`, keeping their order.
  ///
  /// The arguments mean the same as those of a SwiftUI list's `onMove`; `destination` may equal the inbox count to
  /// move to the end. Offsets outside the list are ignored.
  public mutating func moveInboxes(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    let validOffsets = offsets.filteredIndexSet { inboxes.indices.contains($0) }
    let moving = validOffsets.map { inboxes[$0] }
    let clampedDestination = min(max(0, destination), inboxes.count)
    let insertionIndex = clampedDestination - validOffsets.count(in: 0..<clampedDestination)
    for offset in validOffsets.reversed() {
      inboxes.remove(at: offset)
    }
    inboxes.insert(contentsOf: moving, at: insertionIndex)
  }
}
