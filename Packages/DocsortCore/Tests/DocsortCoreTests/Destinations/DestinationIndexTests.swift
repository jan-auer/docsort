import Foundation
import Testing

@testable import DocsortCore

@Suite("DestinationIndex")
struct DestinationIndexTests {
  @Test(
    "gives the NFC path of a URL under a root, empty for the root, nil outside it, through symbolic links"
  )
  func archiveRelativePath() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Töpferei")
    let root = archive.url
    // The temporary directory lies under /var, a symbolic link to /private/var.
    let resolvedRoot = root.resolvingSymlinksInPath()
    let decomposed = "Töpferei".decomposedStringWithCanonicalMapping

    #expect(
      DestinationIndex.archiveRelativePath(
        of: resolvedRoot.appending(path: decomposed), under: root)
        == "Töpferei".precomposedStringWithCanonicalMapping)
    #expect(DestinationIndex.archiveRelativePath(of: root, under: resolvedRoot) == "")
    #expect(
      DestinationIndex.archiveRelativePath(
        of: root.deletingLastPathComponent(), under: root) == nil)
  }

  @Test("lists every folder below the root, parents before children, siblings in Finder order")
  func listsFoldersInFinderOrder() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Wohnung/2. Haldenbrück")
    try archive.createFolder("Wohnung/10. Fichtenzell")
    try archive.createFolder("Hund/Hundeschule")
    try archive.createFile("Hund/Impfpass.pdf")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.root == archive.url)
    #expect(
      index.folders == [
        "Hund", "Hund/Hundeschule", "Wohnung", "Wohnung/2. Haldenbrück", "Wohnung/10. Fichtenzell",
      ])
    #expect(index.problems.isEmpty)
  }

  @Test("leaves out hidden folders, packages and everything inside them")
  func leavesOutHiddenFoldersAndPackages() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Töpferei")
    try archive.createFolder(".verborgen/Darunter")
    try archive.createFolder("Getarnt/Darunter")
    try markHidden(archive.url.appending(path: "Getarnt"))
    try archive.createFile("Notiz.rtfd/TXT.rtf")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.folders == ["Töpferei"])
  }

  @Test("leaves out excluded inbox folders and their descendants, however their URL is spelled")
  func leavesOutExcludedFolders() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Posteingang/Geladen/Vorjahr")
    try archive.createFolder("Posteingang/Gescannt")
    try archive.createFolder("Posteingangsfach")
    try archive.createFolder("Rechnungen")
    // The temporary directory lies behind a symbolic link (/var -> /private/var); the target's spelling of the same
    // folder must be excluded too.
    let loadedPath = archive.url.appending(path: "Posteingang/Geladen").path(percentEncoded: false)
    #expect(loadedPath.hasPrefix("/var/"))
    let loaded = URL(filePath: "/private" + loadedPath, directoryHint: .isDirectory)
    let scanned = archive.url.appending(path: "Posteingang/Gescannt/", directoryHint: .isDirectory)

    let index = try DestinationIndex.build(root: archive.url, excluding: [loaded, scanned])

    #expect(index.folders == ["Posteingang", "Posteingangsfach", "Rechnungen"])
  }

  @Test("ignores excluded folders outside the archive")
  func ignoresExclusionsOutsideTheArchive() throws {
    let archive = try TemporaryDirectory()
    let elsewhere = try TemporaryDirectory()
    try archive.createFolder("Rechnungen")

    let index = try DestinationIndex.build(root: archive.url, excluding: [elsewhere.url])

    #expect(index.folders == ["Rechnungen"])
  }

  @Test("holds paths NFC-normalised and finds them in either normalisation")
  func normalisesPaths() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Töpferei/Ma\u{0308}rkte")

    let index = try DestinationIndex.build(root: archive.url)

    let stored = try #require(index.folders.last)
    #expect(stored.unicodeScalars.elementsEqual("T\u{00F6}pferei/M\u{00E4}rkte".unicodeScalars))
    #expect(index.contains("T\u{00F6}pferei/M\u{00E4}rkte"))
    #expect(index.contains("To\u{0308}pferei/Ma\u{0308}rkte"))
    #expect(!index.contains("Töpferei/Markte"))
  }

  @Test("reports unreadable subfolders as problems and still lists the rest")
  func reportsUnreadableSubfolders() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Verschlossen/Darunter")
    try archive.createFolder("Zugänglich")
    let locked = archive.url.appending(path: "Verschlossen")
    try setPermissions(0o000, of: locked)
    // Restoring lets the temporary directory be removed; a failure there must not mask the result.
    defer { try? setPermissions(0o755, of: locked) }

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.folders == ["Verschlossen", "Zugänglich"])
    #expect(index.problems.map(\.url.lastPathComponent) == ["Verschlossen"])
  }

  @Test("throws for a missing archive root")
  func throwsForMissingRoot() throws {
    let archive = try TemporaryDirectory()
    let missing = archive.url.appending(path: "nicht-vorhanden")

    #expect(throws: FolderAccessError.notFound(missing)) {
      try DestinationIndex.build(root: missing)
    }
  }

  @Test("rebuild picks up a new folder and keeps the exclusions")
  func rebuildPicksUpNewFolder() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Posteingang")
    try archive.createFolder("Töpferei")
    var index = try DestinationIndex.build(
      root: archive.url, excluding: [archive.url.appending(path: "Posteingang")])

    try archive.createFolder("Töpferei/Glasuren")
    try archive.createFolder("Posteingang/Frisch")
    try index.rebuild()

    #expect(index.folders == ["Töpferei", "Töpferei/Glasuren"])
    #expect(index.search("glas").map(\.path) == ["Töpferei/Glasuren"])
  }

  @Test("navigates top-level folders, subfolders and parents")
  func navigation() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Wohnung/Haldenbrück/Mängel")
    try archive.createFolder("Wohnung/Umbauten")
    try archive.createFolder("Hund")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.topLevelFolders() == ["Hund", "Wohnung"])
    #expect(index.subfolders(of: "") == ["Hund", "Wohnung"])
    #expect(index.subfolders(of: "Wohnung") == ["Wohnung/Haldenbrück", "Wohnung/Umbauten"])
    #expect(index.subfolders(of: "Wohnung/Haldenbrück/Mängel").isEmpty)
    #expect(index.subfolders(of: "Nicht vorhanden").isEmpty)
    #expect(index.parent(of: "Wohnung/Haldenbrück/Mängel") == "Wohnung/Haldenbrück")
    #expect(index.parent(of: "Wohnung") == "")
    #expect(index.parent(of: "") == nil)
    #expect(index.contains("Wohnung/Haldenbrück"))
    #expect(!index.contains(""))
  }

  @Test("finds subfolders of a parent given in the other Unicode normalisation")
  func subfoldersNormalisationInsensitive() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("M\u{00E4}rkte/Standplätze")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.subfolders(of: "Ma\u{0308}rkte") == ["M\u{00E4}rkte/Standplätze"])
  }

  @Test("gives the URL of a folder and of the root")
  func urls() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Wohnung/Umbauten")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.url(for: "") == archive.url)
    #expect(
      index.url(for: "Wohnung/Umbauten").standardizedFileURL.path(percentEncoded: false)
        == archive.url.appending(path: "Wohnung/Umbauten").standardizedFileURL.path(
          percentEncoded: false))
    #expect(index.url(for: "Wohnung/Umbauten").hasDirectoryPath)
  }

  @Test("searches the indexed folders, with recents")
  func search() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Rechnungen")
    try archive.createFolder("Hund/Rechnungen")
    try archive.createFolder("Auto")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.search("").isEmpty)
    #expect(index.search("   ").isEmpty)
    #expect(index.search("rech").map(\.path) == ["Rechnungen", "Hund/Rechnungen"])
    #expect(
      index.search("rech", recents: RecentDestinations(paths: ["Hund/Rechnungen"])).map(\.path)
        == ["Hund/Rechnungen", "Rechnungen"])
    #expect(index.search("rech", limit: 1).count == 1)
  }

  @Test("searches within a scope, given in either normalisation, with paths relative to it")
  func searchInScope() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("T\u{00F6}pferei/Rechnungen")
    try archive.createFolder("T\u{00F6}pferei/Brennofen/Rechnungen")
    try archive.createFolder("Rechnungen")

    let index = try DestinationIndex.build(root: archive.url)

    for scope in ["T\u{00F6}pferei", "To\u{0308}pferei"] {
      let matches = index.search("rech", in: scope)
      #expect(
        matches.map(\.path) == [
          "T\u{00F6}pferei/Rechnungen", "T\u{00F6}pferei/Brennofen/Rechnungen",
        ])
      #expect(matches.map(\.pathInScope) == ["Rechnungen", "Brennofen/Rechnungen"])
    }
    #expect(index.search("rech", in: "Nicht vorhanden").isEmpty)
    #expect(index.search("rech").map(\.path).first == "Rechnungen")
  }

  @Test("searches with the scoped ranking given, closer folders first by default")
  func searchWithScopedRanking() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Töpferei/Werkstoffe/Glasur")
    try archive.createFolder("Töpferei/Glasurrezepte")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(index.search("glasur", in: "Töpferei").first?.path == "Töpferei/Glasurrezepte")
    #expect(
      index.search("glasur", in: "Töpferei", ranking: .exactNameFirst).first?.path
        == "Töpferei/Werkstoffe/Glasur")
  }

  @Test("lists a folder's files and packages newest first, ties by name")
  func filesNewestFirst() throws {
    let archive = try TemporaryDirectory()
    try archive.createFile("Töpferei/frueh.pdf", modified: testDate(10))
    try archive.createFile("Töpferei/spaet.pdf", modified: testDate(30))
    try archive.createFile("Töpferei/b zugleich.pdf", modified: testDate(20))
    try archive.createFile("Töpferei/a zugleich.pdf", modified: testDate(20))
    let package = try archive.createFile("Töpferei/Skizze.rtfd/TXT.rtf")
    try archive.setModificationDate(testDate(25), of: package.deletingLastPathComponent())
    try archive.createFile("Töpferei/Ablage/darin.pdf", modified: testDate(40))

    let index = try DestinationIndex.build(root: archive.url)
    let files = try index.files(in: "Töpferei")

    #expect(
      files.map(\.name) == [
        "spaet.pdf", "Skizze.rtfd", "a zugleich.pdf", "b zugleich.pdf", "frueh.pdf",
      ])
    #expect(files.first?.modificationDate == testDate(30))
    #expect(files.first?.url.lastPathComponent == "spaet.pdf")
  }

  @Test("lists the root's own files for the empty path")
  func filesInRoot() throws {
    let archive = try TemporaryDirectory()
    try archive.createFile("wurzel.pdf")
    try archive.createFile("Mappe/tiefer.pdf")

    let index = try DestinationIndex.build(root: archive.url)

    #expect(try index.files(in: "").map(\.name) == ["wurzel.pdf"])
  }

  @Test("skips hidden files and the custom-icon file")
  func filesSkipHiddenAndIcon() throws {
    let archive = try TemporaryDirectory()
    try archive.createFile("Mappe/lesbar.pdf")
    try archive.createFile("Mappe/.DS_Store")
    try archive.createFile("Mappe/Icon\r")
    try markHidden(try archive.createFile("Mappe/getarnt.pdf"))

    let index = try DestinationIndex.build(root: archive.url)

    #expect(try index.files(in: "Mappe").map(\.name) == ["lesbar.pdf"])
  }

  @Test("throws when the folder no longer exists")
  func filesInMissingFolder() throws {
    let archive = try TemporaryDirectory()
    try archive.createFolder("Entfernt")
    let index = try DestinationIndex.build(root: archive.url)
    try FileManager.default.removeItem(at: archive.url.appending(path: "Entfernt"))

    #expect(throws: FolderAccessError.self) {
      try index.files(in: "Entfernt")
    }
  }
}
