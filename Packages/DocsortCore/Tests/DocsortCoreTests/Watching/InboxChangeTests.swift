import Foundation
import Testing

@testable import DocsortCore

@Suite("InboxChange")
struct InboxChangeTests {
  let scanner = InboxScanner()

  @Test("reports nothing when the inbox did not change")
  func noChange() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("scan-1.pdf", modified: testDate(10))
    try inbox.createFile("Ordner/Invoice.pdf", modified: testDate(20))

    let before = try scanner.scan(inbox.url)
    let after = try scanner.scan(inbox.url)

    #expect(InboxChange.changes(from: before, to: after, excluding: .none) == [])
  }

  @Test("reports a new file as arrived and a deleted one as removed")
  func arrivedAndRemoved() throws {
    let inbox = try TemporaryDirectory()
    let deleted = try inbox.createFile("scan-1.pdf", modified: testDate(10))
    try inbox.createFile("scan-2.pdf", modified: testDate(20))
    let before = try scanner.scan(inbox.url)

    try FileManager.default.removeItem(at: deleted)
    try inbox.createFile("Ordner/Invoice.pdf", modified: testDate(30))
    let after = try scanner.scan(inbox.url)

    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .removed(try item("scan-1.pdf", in: before)),
        .arrived(try item("Invoice.pdf", in: after)),
      ])
  }

  @Test("reports a rename as a change of the same item")
  func renameIsChange() throws {
    let inbox = try TemporaryDirectory()
    let original = try inbox.createFile("scan-1.pdf", modified: testDate(10))
    try inbox.createFile("scan-2.pdf", modified: testDate(20))
    let before = try scanner.scan(inbox.url)

    try FileManager.default.moveItem(at: original, to: inbox.url.appending(path: "Invoice.pdf"))
    let after = try scanner.scan(inbox.url)

    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .changed(from: try item("scan-1.pdf", in: before), to: try item("Invoice.pdf", in: after))
      ])
  }

  @Test("reports moves into, out of and between subfolders as changes")
  func subfolderMovesAreChanges() throws {
    let inbox = try TemporaryDirectory()
    let intoFolder = try inbox.createFile("scan-1.pdf", modified: testDate(10))
    let outOfFolder = try inbox.createFile("A/scan-2.pdf", modified: testDate(20))
    let betweenFolders = try inbox.createFile("A/Tief/scan-3.pdf", modified: testDate(30))
    try inbox.createFolder("B")
    let before = try scanner.scan(inbox.url)

    try FileManager.default.moveItem(at: intoFolder, to: inbox.url.appending(path: "B/scan-1.pdf"))
    try FileManager.default.moveItem(at: outOfFolder, to: inbox.url.appending(path: "scan-2.pdf"))
    try FileManager.default.moveItem(
      at: betweenFolders, to: inbox.url.appending(path: "B/scan-3.pdf"))
    let after = try scanner.scan(inbox.url)

    let changes = InboxChange.changes(from: before, to: after, excluding: .none)

    #expect(Set(changes.map(\.summary)) == ["scan-1.pdf → B", "A → scan-2.pdf", "A/Tief → B"])
    #expect(changes.count == 3)
  }

  @Test("reports new content written in place as a change")
  func contentChangeIsChange() throws {
    let inbox = try TemporaryDirectory()
    let file = try inbox.createFile("scan-1.pdf", contents: "short", modified: testDate(10))
    let before = try scanner.scan(inbox.url)

    let handle = try FileHandle(forWritingTo: file)
    try handle.write(contentsOf: Data("longer content".utf8))
    try handle.close()
    try inbox.setModificationDate(testDate(20), of: file)
    let after = try scanner.scan(inbox.url)

    let old = try item("scan-1.pdf", in: before)
    let new = try item("scan-1.pdf", in: after)
    #expect(new.identity == old.identity)
    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .changed(from: old, to: new)
      ])
  }

  @Test("reports a file replaced at the same path by a new one as a change")
  func replacementAtSamePathIsChange() throws {
    let inbox = try TemporaryDirectory()
    let file = try inbox.createFile("Ordner/scan-1.pdf", modified: testDate(10))
    let before = try scanner.scan(inbox.url)

    try FileManager.default.removeItem(at: file)
    try inbox.createFile("Ordner/scan-1.pdf", contents: "new version", modified: testDate(10))
    let after = try scanner.scan(inbox.url)

    let old = try item("scan-1.pdf", in: before)
    let new = try item("scan-1.pdf", in: after)
    #expect(new.identity != old.identity)
    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .changed(from: old, to: new)
      ])
  }

  @Test("reports a completed download as a change of the download")
  func completedDownloadIsChange() throws {
    let inbox = try TemporaryDirectory()
    let safari = try inbox.createFile("Report.pdf.download/Report.pdf", modified: testDate(10))
      .deletingLastPathComponent()
    let chrome = try inbox.createFile("Ordner/a.pdf.crdownload", modified: testDate(20))
    let upperCase = try inbox.createFile("b.pdf.CRDOWNLOAD", modified: testDate(30))
    let before = try scanner.scan(inbox.url)

    // The folder group is dated by the folder's creation (now), after every file here, so its item comes last.
    // Each finished file is a new item, not the download renamed, so only the name rule can match it.
    for download in [safari, chrome, upperCase] {
      try FileManager.default.removeItem(at: download)
    }
    try inbox.createFile("Report.pdf", modified: testDate(40))
    try inbox.createFile("Ordner/a.pdf", modified: testDate(50))
    try inbox.createFile("b.pdf", modified: testDate(60))
    let after = try scanner.scan(inbox.url)

    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .changed(
          from: try item("Report.pdf.download", in: before), to: try item("Report.pdf", in: after)),
        .changed(from: try item("b.pdf.CRDOWNLOAD", in: before), to: try item("b.pdf", in: after)),
        .changed(from: try item("a.pdf.crdownload", in: before), to: try item("a.pdf", in: after)),
      ])
  }

  @Test(
    "does not match a download to a file in another folder, nor a finished file to a same-stem arrival"
  )
  func nameRuleNeedsDownloadInSameFolder() throws {
    let inbox = try TemporaryDirectory()
    let download = try inbox.createFile("a.pdf.part", modified: testDate(10))
    let backup = try inbox.createFile("b.pdf.bak", modified: testDate(20))
    let before = try scanner.scan(inbox.url)

    try FileManager.default.removeItem(at: download)
    try FileManager.default.removeItem(at: backup)
    try inbox.createFile("Ordner/a.pdf", modified: testDate(30))
    try inbox.createFile("b.pdf", modified: testDate(40))
    let after = try scanner.scan(inbox.url)

    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .removed(try item("a.pdf.part", in: before)),
        .removed(try item("b.pdf.bak", in: before)),
        .arrived(try item("b.pdf", in: after)),
        .arrived(try item("a.pdf", in: after)),
      ])
  }

  @Test("pairs hard links of one file by path, reporting only the link that went")
  func hardLinksPairByPath() throws {
    let inbox = try TemporaryDirectory()
    let first = try inbox.createFile("a-scan.pdf", modified: testDate(10))
    let second = inbox.url.appending(path: "b-scan.pdf")
    try FileManager.default.linkItem(at: first, to: second)
    let before = try scanner.scan(inbox.url)

    try FileManager.default.removeItem(at: first)
    let after = try scanner.scan(inbox.url)

    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .removed(try item("a-scan.pdf", in: before))
      ])
  }

  @Test("leaves out an item docsort moved out or trashed")
  func excludesOwnRemoval() throws {
    let inbox = try TemporaryDirectory()
    let archive = try TemporaryDirectory()
    let filed = try inbox.createFile("scan-1.pdf", modified: testDate(10))
    let before = try scanner.scan(inbox.url)

    try FileManager.default.moveItem(at: filed, to: archive.url.appending(path: "scan-1.pdf"))
    let after = try scanner.scan(inbox.url)

    let own = OwnChanges(removals: [OwnChanges.path(of: filed)], arrivals: [])
    #expect(InboxChange.changes(from: before, to: after, excluding: own) == [])
    // The filing service names the listed item's URL, which the scan spells with `/private`.
    let listedURL = try item("scan-1.pdf", in: before).url
    let ownByListedURL = OwnChanges(removals: [OwnChanges.path(of: listedURL)], arrivals: [])
    #expect(InboxChange.changes(from: before, to: after, excluding: ownByListedURL) == [])
  }

  @Test("leaves out an item docsort put back")
  func excludesOwnArrival() throws {
    let inbox = try TemporaryDirectory()
    let archive = try TemporaryDirectory()
    let filed = try archive.createFile("scan-1.pdf", modified: testDate(10))
    let before = try scanner.scan(inbox.url)

    let restored = inbox.url.appending(path: "Ordner/scan-1.pdf")
    try inbox.createFolder("Ordner")
    try FileManager.default.moveItem(at: filed, to: restored)
    let after = try scanner.scan(inbox.url)

    let own = OwnChanges(removals: [], arrivals: [OwnChanges.path(of: restored)])
    #expect(InboxChange.changes(from: before, to: after, excluding: own) == [])
  }

  @Test("leaves out a rename docsort made in place")
  func excludesOwnRename() throws {
    let inbox = try TemporaryDirectory()
    let original = try inbox.createFile("scan-1.pdf", modified: testDate(10))
    let before = try scanner.scan(inbox.url)

    let renamed = inbox.url.appending(path: "Invoice.pdf")
    try FileManager.default.moveItem(at: original, to: renamed)
    let after = try scanner.scan(inbox.url)

    let own = OwnChanges(
      removals: [OwnChanges.path(of: original)], arrivals: [OwnChanges.path(of: renamed)])
    #expect(InboxChange.changes(from: before, to: after, excluding: own) == [])
  }

  @Test("reports an unrelated file at a path docsort just vacated as arrived")
  func reportsArrivalAtVacatedPath() throws {
    let inbox = try TemporaryDirectory()
    let archive = try TemporaryDirectory()
    let filed = try inbox.createFile("scan-1.pdf", modified: testDate(10))
    let before = try scanner.scan(inbox.url)

    try FileManager.default.moveItem(at: filed, to: archive.url.appending(path: "scan-1.pdf"))
    try inbox.createFile("scan-1.pdf", contents: "another document", modified: testDate(20))
    let after = try scanner.scan(inbox.url)

    let own = OwnChanges(removals: [OwnChanges.path(of: filed)], arrivals: [])
    #expect(
      InboxChange.changes(from: before, to: after, excluding: own) == [
        .arrived(try item("scan-1.pdf", in: after))
      ])
  }

  @Test("lists removals in old display order, then changes and arrivals in new display order")
  func deterministicOrder() throws {
    let inbox = try TemporaryDirectory()
    let removedLate = try inbox.createFile("z-removed.pdf", modified: testDate(10))
    let removedEarly = try inbox.createFile("a-removed.pdf", modified: testDate(5))
    let renamed = try inbox.createFile("scan-1.pdf", modified: testDate(20))
    try inbox.createFile("unchanged.pdf", modified: testDate(25))
    let before = try scanner.scan(inbox.url)

    for removed in [removedLate, removedEarly] {
      try FileManager.default.removeItem(at: removed)
    }
    try FileManager.default.moveItem(at: renamed, to: inbox.url.appending(path: "Invoice.pdf"))
    try inbox.createFile("new-late.pdf", modified: testDate(40))
    try inbox.createFile("new-early.pdf", modified: testDate(15))
    let after = try scanner.scan(inbox.url)

    #expect(
      InboxChange.changes(from: before, to: after, excluding: .none) == [
        .removed(try item("a-removed.pdf", in: before)),
        .removed(try item("z-removed.pdf", in: before)),
        .arrived(try item("new-early.pdf", in: after)),
        .changed(from: try item("scan-1.pdf", in: before), to: try item("Invoice.pdf", in: after)),
        .arrived(try item("new-late.pdf", in: after)),
      ])
  }
}

/// The only item named `name` in `listing`.
private func item(_ name: String, in listing: InboxListing) throws -> InboxItem {
  let matches = listing.items.filter { $0.name == name }
  return try #require(matches.count == 1 ? matches.first : nil, "one item named \(name)")
}

extension InboxChange {
  /// A change as `"<old place> → <new place>"`, where a place is the subfolder path or, at the top level, the name.
  fileprivate var summary: String {
    func place(_ item: InboxItem) -> String { item.subfolderPath ?? item.name }
    switch self {
    case .arrived(let item): return "→ \(place(item))"
    case .removed(let item): return "\(place(item)) →"
    case .changed(let old, let new): return "\(place(old)) → \(place(new))"
    }
  }
}
