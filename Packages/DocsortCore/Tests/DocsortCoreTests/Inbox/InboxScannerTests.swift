import Foundation
import Testing

@testable import DocsortCore

@Suite("InboxScanner")
struct InboxScannerTests {
  let scanner = InboxScanner()

  @Test("lists top-level files newest first")
  func listsTopLevelFilesNewestFirst() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("alt.pdf", modified: testDate(10))
    try inbox.createFile("neu.pdf", modified: testDate(30))
    try inbox.createFile("mittel.pdf", modified: testDate(20))

    let listing = try scanner.scan(inbox.url)

    #expect(outline(listing) == ["neu.pdf", "mittel.pdf", "alt.pdf"])
    #expect(listing.items.map(\.subfolderPath) == [nil, nil, nil])
    #expect(listing.problems.isEmpty)
  }

  @Test("lists folders as groups, never as items, and leaves out folders without files")
  func foldersAreGroupsNotItems() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("datei.pdf", modified: testDate(10))
    try inbox.createFile("Ordner/innen.pdf", modified: testDate(10))
    try inbox.createFolder("Leer/Auch leer")
    try inbox.createFile("Nur versteckt/.DS_Store")
    try inbox.setModificationDate(testDate(5), of: inbox.url.appending(path: "Ordner"))

    let listing = try scanner.scan(inbox.url)

    #expect(outline(listing) == ["datei.pdf", "Ordner/[innen.pdf]"])
    #expect(listing.items.map(\.name) == ["datei.pdf", "innen.pdf"])
  }

  @Test("skips hidden files, hidden folders and their contents")
  func skipsHiddenEntries() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("sichtbar.pdf")
    try inbox.createFile(".DS_Store")
    try inbox.createFile(".versteckt/innen.pdf")
    try inbox.createFile("Markiert/innen.pdf")
    try markHidden(inbox.url.appending(path: "Markiert"))
    try markHidden(try inbox.createFile("markiert.pdf"))

    let listing = try scanner.scan(inbox.url)

    #expect(outline(listing) == ["sichtbar.pdf"])
  }

  @Test("groups a nested file under its top-level folder, dated by that folder")
  func groupsNestedFileUnderTopLevelFolder() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("A/B/C/datei.pdf", modified: testDate(50))
    try inbox.setModificationDate(testDate(40), of: inbox.url.appending(path: "A/B/C"))
    try inbox.setModificationDate(testDate(30), of: inbox.url.appending(path: "A/B"))
    try inbox.setModificationDate(testDate(20), of: inbox.url.appending(path: "A"))

    let listing = try scanner.scan(inbox.url)

    let group = try #require(subfolders(listing).first)
    #expect(group.name == "A")
    #expect(group.date == testDate(20))
    #expect(group.items.map(\.name) == ["datei.pdf"])
    #expect(group.items.first?.subfolderPath == "A/B/C")
    #expect(group.items.first?.modificationDate == testDate(50))
  }

  @Test("interleaves groups with top-level files by the group folder's date")
  func interleavesGroupsWithTopLevelFiles() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("neu.pdf", modified: testDate(30))
    try inbox.createFile("alt.pdf", modified: testDate(10))
    // The file inside is newer than everything, but the group sorts by the folder's own date.
    try inbox.createFile("Ordner/innen.pdf", modified: testDate(99))
    try inbox.setModificationDate(testDate(20), of: inbox.url.appending(path: "Ordner"))

    let listing = try scanner.scan(inbox.url)

    #expect(outline(listing) == ["neu.pdf", "Ordner/[innen.pdf]", "alt.pdf"])
  }

  @Test("keeps a group's files together, newest first")
  func keepsGroupFilesTogetherNewestFirst() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("Gruppe/erste.pdf", modified: testDate(10))
    try inbox.createFile("Gruppe/Tief/zweite.pdf", modified: testDate(30))
    try inbox.createFile("dazwischen.pdf", modified: testDate(20))
    try inbox.setModificationDate(testDate(15), of: inbox.url.appending(path: "Gruppe"))

    let listing = try scanner.scan(inbox.url)

    #expect(outline(listing) == ["dazwischen.pdf", "Gruppe/[zweite.pdf, erste.pdf]"])
    #expect(listing.items.map(\.name) == ["dazwischen.pdf", "zweite.pdf", "erste.pdf"])
  }

  @Test("breaks ties on equal dates by name")
  func breaksTiesByName() throws {
    // The walk visits "Gruppe/b.pdf" before "Gruppe/Tief/a.pdf", and top-level files before groups, so only the
    // tie-break by name produces this order.
    let inbox = try TemporaryDirectory()
    try inbox.createFile("b 10.pdf", modified: testDate(10))
    try inbox.createFile("b 9.pdf", modified: testDate(10))
    try inbox.createFile("Gruppe/b.pdf", modified: testDate(5))
    try inbox.createFile("Gruppe/Tief/a.pdf", modified: testDate(5))
    try inbox.setModificationDate(testDate(10), of: inbox.url.appending(path: "Gruppe"))
    try inbox.createFile("Aaa/x.pdf", modified: testDate(5))
    try inbox.setModificationDate(testDate(10), of: inbox.url.appending(path: "Aaa"))

    let listing = try scanner.scan(inbox.url)

    #expect(
      outline(listing) == ["Aaa/[x.pdf]", "b 9.pdf", "b 10.pdf", "Gruppe/[a.pdf, b.pdf]"])
  }

  @Test("treats a package as one item")
  func treatsPackageAsOneItem() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("Brief.rtfd/TXT.rtf")
    try inbox.createFile("Ordner/Notiz.rtfd/TXT.rtf")

    let listing = try scanner.scan(inbox.url)

    let itemsByName = Dictionary(uniqueKeysWithValues: listing.items.map { ($0.name, $0) })
    #expect(Set(itemsByName.keys) == ["Brief.rtfd", "Notiz.rtfd"])
    #expect(itemsByName["Brief.rtfd"]?.kind == .package)
    #expect(itemsByName["Brief.rtfd"]?.byteCount == nil)
    #expect(itemsByName["Notiz.rtfd"]?.subfolderPath == "Ordner")
  }

  @Test("carries a file's size and creation date")
  func carriesSizeAndCreationDate() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("datei.pdf", contents: "12345")

    let item = try #require(try scanner.scan(inbox.url).items.first)

    #expect(item.kind == .file)
    #expect(item.byteCount == 5)
    #expect(item.creationDate != nil)
    #expect(item.url.lastPathComponent == "datei.pdf")
  }

  @Test("flags incomplete downloads by extension")
  func flagsIncompleteDownloads() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("fertig.pdf")
    try inbox.createFile("chrome.pdf.crdownload")
    try inbox.createFile("firefox.pdf.PART")
    try inbox.createFile("andere.pdf.partial")
    try inbox.createFile("safari.pdf.download/safari.pdf")

    let listing = try scanner.scan(inbox.url)

    let flagsByName = Dictionary(
      uniqueKeysWithValues: listing.items.map { ($0.name, $0.isIncompleteDownload) })
    #expect(
      flagsByName == [
        "fertig.pdf": false, "chrome.pdf.crdownload": true, "firefox.pdf.PART": true,
        "andere.pdf.partial": true, "safari.pdf.download": true,
      ])
  }

  @Test("returns an empty listing for an empty inbox")
  func emptyInbox() throws {
    let inbox = try TemporaryDirectory()

    let listing = try scanner.scan(inbox.url)

    #expect(listing.folder == inbox.url)
    #expect(listing.entries.isEmpty)
    #expect(listing.problems.isEmpty)
  }

  @Test("throws notFound for a missing inbox")
  func throwsNotFoundForMissingInbox() throws {
    let inbox = try TemporaryDirectory()
    let missing = inbox.url.appending(path: "gibt-es-nicht")

    #expect(throws: InboxScanError.notFound(missing)) { try scanner.scan(missing) }
  }

  @Test("throws notAFolder when the inbox is a file")
  func throwsNotAFolderForFileInbox() throws {
    let inbox = try TemporaryDirectory()
    let file = try inbox.createFile("datei.pdf")

    #expect(throws: InboxScanError.notAFolder(file)) { try scanner.scan(file) }
  }

  @Test("reports an unreadable subfolder and lists everything else")
  func reportsUnreadableSubfolder() throws {
    let inbox = try TemporaryDirectory()
    try inbox.createFile("aussen.pdf")
    try inbox.createFile("Offen/innen.pdf")
    try inbox.createFile("Gesperrt/versteckt.pdf")
    let locked = inbox.url.appending(path: "Gesperrt")
    try setPermissions(0o000, of: locked)
    // Restoring lets the temporary directory be removed; a failure there must not mask the result.
    defer { try? setPermissions(0o755, of: locked) }

    let listing = try scanner.scan(inbox.url)

    #expect(Set(listing.items.map(\.name)) == ["aussen.pdf", "innen.pdf"])
    #expect(listing.problems.map(\.url.lastPathComponent) == ["Gesperrt"])
  }
}

/// The listing's entries as short strings: a top-level item by name, a group as `Name/[item, item]`.
private func outline(_ listing: InboxListing) -> [String] {
  listing.entries.map { entry in
    switch entry {
    case .item(let item):
      item.name
    case .subfolder(let subfolder):
      "\(subfolder.name)/[\(subfolder.items.map(\.name).joined(separator: ", "))]"
    }
  }
}

/// The listing's groups, in order.
private func subfolders(_ listing: InboxListing) -> [InboxSubfolder] {
  listing.entries.compactMap { entry in
    if case .subfolder(let subfolder) = entry { subfolder } else { nil }
  }
}
