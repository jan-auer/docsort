import Foundation

/// A change to an inbox made outside docsort, between two listings of the inbox.
public enum InboxChange: Hashable, Sendable {
  /// An item that was not in the earlier listing.
  case arrived(InboxItem)
  /// An item of the earlier listing that is gone.
  case removed(InboxItem)
  /// The same document, renamed or moved within the inbox, its content changed, replaced at the same path, or a
  /// download completed.
  case changed(from: InboxItem, to: InboxItem)
}

extension InboxChange {
  /// The changes made outside docsort between `old` and `new`, two listings of the same inbox.
  ///
  /// Each old item matches at most one new item and the other way round, over the flattened items of both listings:
  /// 1. Items of docsort's own changes are left out first: old items at a path in `own.removals`, new items at a
  ///    path in `own.arrivals`. A file docsort moved out, put back, or renamed in place is not reported, while an
  ///    unrelated file appearing at a path docsort just vacated is still an arrival.
  /// 2. Items with the same ``InboxItem/identity`` match; they are a change when any field differs.
  /// 3. Of the rest, items at the same path match (a safe-save, or a scanner finishing a file, gives the item at a
  ///    path a new identity) and are a change.
  /// 4. Of the rest, an old incomplete download matches a new item in the same folder named like it without its last
  ///    extension (`Report.pdf.download` → `Report.pdf`) and is a change.
  /// 5. Every other old item is removed and every other new item arrived.
  ///
  /// Paths compare as ``OwnChanges/path(of:)`` writes them.
  ///
  /// Order: removals in the old listing's display order, then changes and arrivals together in the new listing's
  /// display order (a change at its new item's place).
  static func changes(
    from old: InboxListing, to new: InboxListing, excluding own: OwnChanges
  ) -> [InboxChange] {
    let oldItems = old.items.filter { !own.removals.contains(OwnChanges.path(of: $0.url)) }
    let newItems = new.items.filter { !own.arrivals.contains(OwnChanges.path(of: $0.url)) }
    var matching = ItemMatching(oldItems: oldItems, newItems: newItems)
    matching.matchByIdentity()
    matching.matchByPath()
    matching.matchCompletedDownloads()

    let removals = oldItems.indices
      .filter { !matching.isMatched(oldIndex: $0) }
      .map { InboxChange.removed(oldItems[$0]) }
    let changesAndArrivals = newItems.indices.compactMap { newIndex -> InboxChange? in
      let newItem = newItems[newIndex]
      guard let oldIndex = matching.oldIndex(matching: newIndex) else {
        return .arrived(newItem)
      }
      let oldItem = oldItems[oldIndex]
      return oldItem == newItem ? nil : .changed(from: oldItem, to: newItem)
    }
    return removals + changesAndArrivals
  }
}

/// Pairs old items with new ones, each item in at most one pair. The `match…` steps run in the order of the rules in
/// ``InboxChange/changes(from:to:excluding:)``; each pairs only items that are still unpaired.
private struct ItemMatching {
  private let oldItems: [InboxItem]
  private let oldPaths: [String]
  private let newPaths: [String]
  private let newIndicesByIdentity: [FileIdentity: [Int]]
  private let newIndicesByPath: [String: Int]
  private var newIndexByOldIndex: [Int: Int] = [:]
  private var oldIndexByNewIndex: [Int: Int] = [:]

  init(oldItems: [InboxItem], newItems: [InboxItem]) {
    self.oldItems = oldItems
    oldPaths = oldItems.map { OwnChanges.path(of: $0.url) }
    let newPaths = newItems.map { OwnChanges.path(of: $0.url) }
    self.newPaths = newPaths
    newIndicesByIdentity = Dictionary(grouping: newItems.indices) { newItems[$0].identity }
    newIndicesByPath = Dictionary(
      newPaths.indices.map { (newPaths[$0], $0) }, uniquingKeysWith: { first, _ in first })
  }

  func isMatched(oldIndex: Int) -> Bool { newIndexByOldIndex[oldIndex] != nil }

  /// The old item paired with the new item at `newIndex`, if any.
  func oldIndex(matching newIndex: Int) -> Int? { oldIndexByNewIndex[newIndex] }

  /// Pairs items of the same identity. Hard links share an identity, so items that also share a path are paired
  /// first, then the rest in display order.
  mutating func matchByIdentity() {
    for oldIndex in unmatchedOldIndices {
      let samePath = newIndicesByIdentity[oldItems[oldIndex].identity, default: []].first {
        newPaths[$0] == oldPaths[oldIndex]
      }
      if let samePath { pair(oldIndex, samePath) }
    }
    for oldIndex in unmatchedOldIndices {
      let candidate = newIndicesByIdentity[oldItems[oldIndex].identity, default: []].first {
        oldIndexByNewIndex[$0] == nil
      }
      if let candidate { pair(oldIndex, candidate) }
    }
  }

  /// Pairs items at the same path.
  mutating func matchByPath() {
    for oldIndex in unmatchedOldIndices {
      matchNewItem(at: oldPaths[oldIndex], to: oldIndex)
    }
  }

  /// Pairs each incomplete download with the item in the same folder named like it without its last extension.
  mutating func matchCompletedDownloads() {
    for oldIndex in unmatchedOldIndices where oldItems[oldIndex].isIncompleteDownload {
      let download = oldItems[oldIndex]
      let completedURL = download.url.deletingLastPathComponent()
        .appending(path: (download.name as NSString).deletingPathExtension)
      matchNewItem(at: OwnChanges.path(of: completedURL), to: oldIndex)
    }
  }

  private var unmatchedOldIndices: [Int] {
    oldItems.indices.filter { newIndexByOldIndex[$0] == nil }
  }

  /// Pairs the unpaired new item at `path`, if there is one, with the old item at `oldIndex`.
  private mutating func matchNewItem(at path: String, to oldIndex: Int) {
    guard let newIndex = newIndicesByPath[path], oldIndexByNewIndex[newIndex] == nil else { return }
    pair(oldIndex, newIndex)
  }

  private mutating func pair(_ oldIndex: Int, _ newIndex: Int) {
    newIndexByOldIndex[oldIndex] = newIndex
    oldIndexByNewIndex[newIndex] = oldIndex
  }
}
