import Foundation

/// A document waiting in an inbox: a file or a package, at any depth below the inbox folder.
public struct InboxItem: Hashable, Sendable, Identifiable {
  /// The item's location, which identifies it.
  public var id: URL { url }
  /// The item's location.
  public let url: URL
  /// Which item on disk this is, independent of its path: a rename or a move within the volume keeps it, a copy or a
  /// replacement at the same path gets a new one. The same value `FileIdentity.ofItem(at:)` reports.
  public let identity: FileIdentity
  /// The item's file name, including its extension.
  public let name: String
  /// The item's own content modification date.
  public let modificationDate: Date
  /// The item's creation date, when the file system reports one.
  public let creationDate: Date?
  /// The size of a file's contents in bytes. `nil` for packages.
  public let byteCount: Int64?
  /// Whether the item is a regular file or a package.
  public let kind: ItemKind
  /// The path of the item's parent folder relative to the inbox (`"A/B/C"`, no trailing slash). `nil` for items
  /// directly in the inbox folder.
  public let subfolderPath: String?
  /// Whether the extension marks a download still in progress or abandoned (`download`, `crdownload`, `part`,
  /// `partial`, in any letter case).
  public let isIncompleteDownload: Bool
}

/// A folder directly inside an inbox, holding every visible item below it, at any depth.
public struct InboxSubfolder: Hashable, Sendable, Identifiable {
  /// The folder's location, which identifies it.
  public var id: URL { url }
  /// The folder's location.
  public let url: URL
  /// The folder's name.
  public let name: String
  /// The date that orders the group among its siblings: the folder's creation date, falling back to its oldest
  /// item's date. Filing files out of the folder does not change it.
  public let date: Date
  /// Every visible item below the folder, oldest first by modification date, ties by name. Never empty.
  public let items: [InboxItem]
}

/// One row at the top level of an inbox listing: an item directly in the inbox, or a folder with items below it.
public enum InboxEntry: Hashable, Sendable, Identifiable {
  /// An item directly in the inbox folder.
  case item(InboxItem)
  /// A folder directly in the inbox folder, with its items.
  case subfolder(InboxSubfolder)

  /// The URL of the item or folder, which identifies the entry.
  public var id: URL {
    switch self {
    case .item(let item): item.url
    case .subfolder(let subfolder): subfolder.url
    }
  }
}

/// The visible contents of one inbox folder, in display order.
public struct InboxListing: Equatable, Sendable {
  /// The scanned inbox folder, as passed to the scanner.
  public let folder: URL
  /// Top-level items and folders, oldest first: an item by its modification date, a folder by its own ``InboxSubfolder/date``;
  /// ties by name. Folders without visible items are left out.
  public let entries: [InboxEntry]
  /// Paths below the inbox that could not be read, with reasons. Everything readable is still listed.
  public let problems: [ScanProblem]

  /// Every item, flattened in display order: each folder's items in place of the folder.
  public var items: [InboxItem] {
    entries.flatMap { entry in
      switch entry {
      case .item(let item): [item]
      case .subfolder(let subfolder): subfolder.items
      }
    }
  }
}
