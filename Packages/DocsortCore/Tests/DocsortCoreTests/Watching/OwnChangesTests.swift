import Foundation
import Testing

@testable import DocsortCore

@Suite("OwnChanges")
struct OwnChangesTests {
  @Test("spells a path the same with or without /private, whether or not the item exists")
  func pathIgnoresPrivatePrefix() throws {
    let folder = try TemporaryDirectory()
    // The temporary directory is under /var, a link to /private/var.
    let privateFolder = URL(
      filePath: "/private" + folder.url.path(percentEncoded: false), directoryHint: .isDirectory)
    try #require(folder.url.path(percentEncoded: false).hasPrefix("/var/"))
    try folder.createFile("scan-1.pdf")

    #expect(
      OwnChanges.path(of: privateFolder.appending(path: "scan-1.pdf"))
        == OwnChanges.path(of: folder.url.appending(path: "scan-1.pdf")))
    #expect(
      OwnChanges.path(of: privateFolder.appending(path: "Ordner/gone.pdf"))
        == OwnChanges.path(of: folder.url.appending(path: "Ordner/gone.pdf")))
    #expect(
      OwnChanges.path(of: privateFolder.appending(path: "Ordner/gone.pdf"))
        == FolderReference.path(of: folder.url) + "/Ordner/gone.pdf")
  }

  @Test("standardises the path: no trailing slash, no dot components")
  func pathIsStandardised() throws {
    let folder = try TemporaryDirectory()
    let base = FolderReference.path(of: folder.url)

    #expect(OwnChanges.path(of: folder.url) == base)
    #expect(OwnChanges.path(of: folder.url.appending(path: "A/../B/./c.pdf")) == base + "/B/c.pdf")
    #expect(
      OwnChanges.path(of: folder.url.appending(path: "Brief.rtfd", directoryHint: .isDirectory))
        == base + "/Brief.rtfd")
    #expect(OwnChanges.path(of: URL(filePath: "/")) == "/")
  }
}
