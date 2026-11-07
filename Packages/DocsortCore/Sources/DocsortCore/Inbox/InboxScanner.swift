import Foundation

/// Why an inbox folder could not be scanned at all.
public enum InboxScanError: Error, Equatable, Sendable {
  /// Nothing exists at the inbox URL.
  case notFound(URL)
  /// The inbox URL names something that is not a folder.
  case notAFolder(URL)
  /// The inbox folder exists but its contents could not be listed.
  case unreadable(URL, reason: String)

  init(_ accessError: FolderAccessError) {
    switch accessError {
    case .notFound(let url): self = .notFound(url)
    case .notAFolder(let url): self = .notAFolder(url)
    case .unreadable(let url, let reason): self = .unreadable(url, reason: reason)
    }
  }
}

/// Lists the documents waiting in an inbox folder.
///
/// Guarantees: hidden entries are skipped, packages are single items, items in subfolders are grouped under their
/// top-level folder, and the order is deterministic (see ``InboxListing/entries``). Unreadable subfolders are
/// reported in ``InboxListing/problems`` without stopping the scan.
public struct InboxScanner: Sendable {
  private static let incompleteDownloadExtensions: Set<String> = [
    "download", "crdownload", "part", "partial",
  ]

  private let walker = VisibleContentsWalker()

  /// Creates a scanner.
  public init() {}

  /// Scans `folder` and everything visible below it.
  ///
  /// - Throws: ``InboxScanError`` when `folder` is missing, is not a folder, or cannot be listed.
  public func scan(_ folder: URL) throws(InboxScanError) -> InboxListing {
    let contents: VisibleContents
    do {
      contents = try walker.walk(folder)
    } catch {
      throw InboxScanError(error)
    }

    var problems = contents.problems
    var topLevelItems: [InboxItem] = []
    var itemsByTopLevelFolder: [String: [InboxItem]] = [:]
    for visibleItem in contents.items {
      guard let item = inboxItem(visibleItem) else {
        problems.append(
          ScanProblem(url: visibleItem.url, reason: "The file system reports no modification date.")
        )
        continue
      }
      let pathComponents = visibleItem.relativePath.split(separator: "/")
      if pathComponents.count > 1 {
        itemsByTopLevelFolder[String(pathComponents[0]), default: []].append(item)
      } else {
        topLevelItems.append(item)
      }
    }

    var subfolders: [InboxSubfolder] = []
    for folder in contents.folders where !folder.relativePath.contains("/") {
      guard let items = itemsByTopLevelFolder[folder.relativePath] else { continue }
      let date: Date
      if let folderDate = folder.modificationDate ?? folder.creationDate {
        date = folderDate
      } else {
        // The folder's items are still worth showing; without a date the group sorts last.
        problems.append(
          ScanProblem(
            url: folder.url, reason: "The file system reports no modification or creation date."))
        date = .distantPast
      }
      subfolders.append(
        InboxSubfolder(
          url: folder.url, name: folder.url.lastPathComponent, date: date,
          items: items.sorted { DisplayOrder($0) < DisplayOrder($1) }))
    }

    let entries = (topLevelItems.map(InboxEntry.item) + subfolders.map(InboxEntry.subfolder))
      .sorted { DisplayOrder($0) < DisplayOrder($1) }
    return InboxListing(folder: folder, entries: entries, problems: problems)
  }

  /// The inbox item for `visibleItem`, or `nil` when it has no modification date to sort by.
  private func inboxItem(_ visibleItem: VisibleItem) -> InboxItem? {
    guard let modificationDate = visibleItem.modificationDate else { return nil }
    let subfolderPath = visibleItem.relativePath.split(separator: "/").dropLast()
      .joined(separator: "/")
    return InboxItem(
      url: visibleItem.url,
      name: visibleItem.url.lastPathComponent,
      modificationDate: modificationDate,
      creationDate: visibleItem.creationDate,
      byteCount: visibleItem.byteCount,
      kind: visibleItem.kind,
      subfolderPath: subfolderPath.isEmpty ? nil : subfolderPath,
      isIncompleteDownload: Self.incompleteDownloadExtensions.contains(
        visibleItem.url.pathExtension.lowercased()))
  }
}

/// The sort key for inbox rows: newest date first, then Finder name order, then the inbox-relative path so that
/// equal names in different subfolders still sort the same way every time.
private struct DisplayOrder: Comparable {
  let date: Date
  let name: String
  let path: String

  init(date: Date, name: String, path: String) {
    self.date = date
    self.name = name
    self.path = path
  }

  init(_ item: InboxItem) {
    self.init(
      date: item.modificationDate, name: item.name,
      path: item.subfolderPath.map { "\($0)/\(item.name)" } ?? item.name)
  }

  init(_ entry: InboxEntry) {
    switch entry {
    case .item(let item):
      self.init(item)
    case .subfolder(let subfolder):
      self.init(date: subfolder.date, name: subfolder.name, path: subfolder.name)
    }
  }

  static func < (lhs: DisplayOrder, rhs: DisplayOrder) -> Bool {
    if lhs.date != rhs.date { return lhs.date > rhs.date }
    let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
    if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
  }
}
