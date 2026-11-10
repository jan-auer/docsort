import DocsortCore
import Foundation

/// What happened to an inbox file in this session, with what the filing panel's status strip shows about it.
nonisolated enum InboxItemMark: Hashable, Sendable {
  /// The file was filed (or later renamed or moved on) to `destinationPath` (archive-relative) at `date` and now lies
  /// at `newURL`, as the filing history's document `documentID`. Moving it again requires that document to still be
  /// the one at `newURL`, so the row never acts on a file that took its place.
  case filed(newURL: URL, destinationPath: String, date: Date, documentID: UUID)
  /// The file was moved to the Trash at `date` and lies at `trashedURL` there.
  case trashed(trashedURL: URL, date: Date)

  /// Whether the file was moved to the Trash.
  var isTrashed: Bool {
    if case .trashed = self { true } else { false }
  }

  /// The filing history's document of a filed file; `nil` for a trashed one.
  var filedDocumentID: UUID? {
    if case .filed(_, _, _, let documentID) = self { documentID } else { nil }
  }
}

/// One file row of an inbox section: the file as it was listed and what happened to it in this session.
nonisolated struct InboxRow: Hashable, Sendable, Identifiable {
  /// The file as the inbox scan listed it.
  let item: InboxItem
  /// What happened to the file in this session; `nil` while it is unhandled.
  let mark: InboxItemMark?
  /// Whether the file arrived from outside docsort while the inbox was watched and has not been selected since: the
  /// row shows the "new" dot.
  var isNewArrival = false

  /// The file's identity.
  var id: InboxItemID { InboxItemID(item) }

  /// Where the file is now: its archive location once filed, otherwise its inbox location.
  var currentURL: URL {
    if case .filed(let newURL, _, _, _) = mark { return newURL }
    return item.url
  }

  /// Whether the file is still waiting to be filed.
  var isUnhandled: Bool { mark == nil }
}

/// A subfolder of an inbox with the file rows below it, shown as a disclosure row.
nonisolated struct InboxGroup: Hashable, Sendable, Identifiable {
  /// The subfolder's location, which identifies the group.
  let url: URL
  /// The subfolder's name.
  let name: String
  /// The date that places the group among its siblings.
  let date: Date
  /// The files below the subfolder, in display order.
  var rows: [InboxRow]

  var id: URL { url }
}

/// One top-level entry of an inbox section.
nonisolated enum InboxSectionEntry: Hashable, Sendable, Identifiable {
  /// A file directly in the inbox.
  case row(InboxRow)
  /// A subfolder with its files.
  case group(InboxGroup)

  /// The entry's identity: the file's for a row, the folder's URL for a group.
  var id: String {
    switch self {
    case .row(let row): "row:\(row.id)"
    case .group(let group): "group:\(group.url.path(percentEncoded: false))"
    }
  }

  /// The entry's rows: the file itself, or the group's files.
  var rows: [InboxRow] {
    switch self {
    case .row(let row): [row]
    case .group(let group): group.rows
    }
  }
}

/// Why an inbox cannot be listed.
nonisolated enum InboxProblem: Hashable, Sendable {
  /// Nothing is at the inbox's folder path.
  case folderNotFound(path: String)
  /// The inbox's path names something that is not a folder.
  case notAFolder(path: String)
  /// The folder exists but cannot be read; `reason` is the system's explanation.
  case unreadable(path: String, reason: String)
}

/// What an inbox section shows.
nonisolated enum InboxSectionContent: Hashable, Sendable {
  /// The first scan of the inbox has not finished yet.
  case scanning
  /// The inbox's entries in display order; `problems` lists what the scan could not read.
  case listing([InboxSectionEntry], problems: [ScanProblem])
  /// The inbox cannot be listed.
  case unreachable(InboxProblem)
}

/// A change made outside docsort that the main window follows.
nonisolated enum InboxExternalChange: Hashable, Sendable {
  /// The file `id`, named `name`, was removed from the inbox labelled `inboxLabel`; `next` is the next unhandled row
  /// after it in display order as it was listed, for a selection that has to move.
  case removed(InboxItemID, name: String, inboxLabel: String, next: InboxItemID?)
  /// The file `id` became the file `replacement`: a download completed into a file of its own.
  case replaced(InboxItemID, by: InboxItemID)
}

/// One configured inbox as the sidebar shows it.
nonisolated struct InboxSection: Hashable, Sendable, Identifiable {
  /// The inbox's identity in the folder settings.
  let id: InboxFolder.ID
  /// The inbox's display label.
  let label: String
  /// What the section shows.
  let content: InboxSectionContent

  /// The section's file rows, flattened in display order.
  var rows: [InboxRow] {
    guard case .listing(let entries, _) = content else { return [] }
    return entries.flatMap(\.rows)
  }
}
