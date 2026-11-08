import Foundation
import Testing

@testable import DocsortCore

@Suite("VisibleContentsWalker")
struct VisibleContentsWalkerTests {
  let walker = VisibleContentsWalker()

  @Test("lists visible descendant folders as root-relative paths")
  func listsVisibleDescendantFolders() throws {
    let root = try TemporaryDirectory()
    try root.createFolder("Finanzen/Steuer/2025")
    try root.createFolder("Wohnung")
    try root.createFolder(".git/objects")
    try root.createFolder("Versteckt")
    try markHidden(root.url.appending(path: "Versteckt"))
    try root.createFolder("Versteckt/Innen")
    try root.createFolder("Brief.rtfd")
    try root.createFolder("Wohnung/Notiz.rtfd")

    let contents = try walker.walk(root.url)

    #expect(
      contents.folderPaths == ["Finanzen", "Finanzen/Steuer", "Finanzen/Steuer/2025", "Wohnung"])
    #expect(contents.problems.isEmpty)
  }

  @Test("lists visible files and packages as items without descending into packages")
  func listsFilesAndPackagesAsItems() throws {
    let root = try TemporaryDirectory()
    try root.createFile("a.pdf", contents: "12345")
    try root.createFile("Ordner/b.pdf")
    try root.createFile("Brief.rtfd/TXT.rtf")
    try root.createFile(".DS_Store")
    try root.createFile("Ordner/.versteckt.pdf")
    let flaggedHidden = try root.createFile("Ordner/flagged.pdf")
    try markHidden(flaggedHidden)

    let contents = try walker.walk(root.url)

    let itemsByPath = Dictionary(uniqueKeysWithValues: contents.items.map { ($0.relativePath, $0) })
    #expect(Set(itemsByPath.keys) == ["a.pdf", "Brief.rtfd", "Ordner/b.pdf"])
    #expect(itemsByPath["a.pdf"]?.kind == .file)
    #expect(itemsByPath["a.pdf"]?.byteCount == 5)
    #expect(itemsByPath["Brief.rtfd"]?.kind == .package)
    #expect(itemsByPath["Ordner/b.pdf"]?.kind == .file)
  }

  @Test("carries modification dates of folders and items")
  func carriesModificationDates() throws {
    let root = try TemporaryDirectory()
    try root.createFile("Ordner/b.pdf", modified: testDate(10))
    try root.setModificationDate(testDate(20), of: root.url.appending(path: "Ordner"))

    let contents = try walker.walk(root.url)

    #expect(contents.folders.map(\.modificationDate) == [testDate(20)])
    #expect(contents.items.map(\.modificationDate) == [testDate(10)])
    #expect(contents.folders.first?.creationDate != nil)
  }

  @Test("carries each item's file identity, the one FileIdentity.ofItem(at:) reports")
  func carriesFileIdentity() throws {
    let root = try TemporaryDirectory()
    let file = try root.createFile("Ordner/scan-1.pdf")
    try root.createFile("Brief.rtfd/TXT.rtf")
    let package = root.url.appending(path: "Brief.rtfd")

    let contents = try walker.walk(root.url)

    let identitiesByPath = Dictionary(
      uniqueKeysWithValues: contents.items.map { ($0.relativePath, $0.identity) })
    #expect(identitiesByPath["Ordner/scan-1.pdf"] == (try FileIdentity.ofItem(at: file)))
    #expect(identitiesByPath["Brief.rtfd"] == (try FileIdentity.ofItem(at: package)))
  }

  @Test("reports an unreadable subfolder and walks the rest")
  func reportsUnreadableSubfolder() throws {
    let root = try TemporaryDirectory()
    try root.createFile("Gesperrt/innen.pdf")
    try root.createFile("Offen/aussen.pdf")
    let locked = root.url.appending(path: "Gesperrt")
    try setPermissions(0o000, of: locked)
    // Restoring lets the temporary directory be removed; a failure there must not mask the result.
    defer { try? setPermissions(0o755, of: locked) }

    let contents = try walker.walk(root.url)

    #expect(contents.items.map(\.relativePath) == ["Offen/aussen.pdf"])
    #expect(contents.folderPaths == ["Gesperrt", "Offen"])
    #expect(contents.problems.map(\.url.lastPathComponent) == ["Gesperrt"])
  }

  @Test("reports a symbolic link instead of following it, and walks the rest")
  func reportsSymbolicLink() throws {
    let root = try TemporaryDirectory()
    let elsewhere = try TemporaryDirectory()
    try elsewhere.createFile("Ziel/innen.pdf")
    try root.createFile("Offen/aussen.pdf")
    try FileManager.default.createSymbolicLink(
      at: root.url.appending(path: "Verknüpfung"),
      withDestinationURL: elsewhere.url.appending(path: "Ziel"))

    let contents = try walker.walk(root.url)

    #expect(contents.items.map(\.relativePath) == ["Offen/aussen.pdf"])
    #expect(contents.folderPaths == ["Offen"])
    #expect(contents.problems.map(\.url.lastPathComponent) == ["Verknüpfung"])
  }

  @Test("throws notFound for a missing root")
  func throwsNotFoundForMissingRoot() throws {
    let root = try TemporaryDirectory()
    let missing = root.url.appending(path: "gibt-es-nicht")

    #expect(throws: FolderAccessError.notFound(missing)) { try walker.walk(missing) }
  }

  @Test("throws notAFolder when the root is a file")
  func throwsNotAFolderForFileRoot() throws {
    let root = try TemporaryDirectory()
    let file = try root.createFile("datei.pdf")

    #expect(throws: FolderAccessError.notAFolder(file)) { try walker.walk(file) }
  }

  @Test("lists only the root's own folders, files and packages when walking its immediate contents")
  func walksImmediateContents() throws {
    let root = try TemporaryDirectory()
    try root.createFile("a.pdf")
    try root.createFile("Brief.rtfd/TXT.rtf")
    try root.createFile(".DS_Store")
    try root.createFile("Ordner/b.pdf")
    try root.createFolder("Ordner/Unter")
    try root.createFolder("Gesperrt/Innen")
    let locked = root.url.appending(path: "Gesperrt")
    try setPermissions(0o000, of: locked)
    // Restoring lets the temporary directory be removed; a failure there must not mask the result.
    defer { try? setPermissions(0o755, of: locked) }

    let contents = try walker.walk(root.url, depth: .immediateContents)

    #expect(contents.folderPaths == ["Gesperrt", "Ordner"])
    #expect(contents.items.map(\.relativePath) == ["a.pdf", "Brief.rtfd"])
    #expect(contents.problems.isEmpty)
  }

  @Test("walks the entire tree by default")
  func walksEntireTreeByDefault() throws {
    let root = try TemporaryDirectory()
    try root.createFile("Ordner/Unter/c.pdf")

    let contents = try walker.walk(root.url)

    #expect(contents.folderPaths == ["Ordner", "Ordner/Unter"])
    #expect(contents.items.map(\.relativePath) == ["Ordner/Unter/c.pdf"])
    #expect(try walker.walk(root.url, depth: .entireTree).folderPaths == contents.folderPaths)
  }
}
