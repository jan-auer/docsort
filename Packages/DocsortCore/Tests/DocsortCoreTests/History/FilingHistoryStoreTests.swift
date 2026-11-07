import Foundation
import Testing

@testable import DocsortCore

@Suite("FilingHistoryStore")
struct FilingHistoryStoreTests {
  /// A history with one move, for saving.
  private func sampleHistory() -> FilingHistory {
    var history = FilingHistory()
    history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/Rechnung.pdf"), at: testDate(1))
    return history
  }

  private func contents(of url: URL) throws -> Data {
    try Data(contentsOf: url)
  }

  @Test("loading a missing file gives an empty history")
  func missingFileIsEmpty() throws {
    let directory = try TemporaryDirectory()
    let store = FilingHistoryStore(fileURL: directory.url.appending(path: "FilingHistory.json"))

    #expect(try store.load() == FilingHistory())
  }

  @Test("a saved history loads back unchanged")
  func roundTrip() throws {
    let directory = try TemporaryDirectory()
    let store = FilingHistoryStore(fileURL: directory.url.appending(path: "FilingHistory.json"))
    var history = sampleHistory()
    let undone = history.recordTrash(trashRecord(of: "/Archiv/Rechnung.pdf"), at: testDate(2))
    try history.markUndone(undone.id, at: testDate(3))

    try store.save(history)

    #expect(try store.load() == history)
  }

  @Test("a file that is not a filing history is reported as corrupt and left alone")
  func corruptFile() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("FilingHistory.json", contents: "not json")
    let store = FilingHistoryStore(fileURL: file)

    let error = try #require(throws: FilingHistoryStoreError.self) { try store.load() }

    guard case .corrupt(let url, _) = error else {
      Issue.record("expected .corrupt, got \(error)")
      return
    }
    #expect(url == file)
    #expect(try contents(of: file) == Data("not json".utf8))
  }

  @Test("an empty file is corrupt, not an empty history")
  func emptyFileIsCorrupt() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("FilingHistory.json", contents: "")
    let store = FilingHistoryStore(fileURL: file)

    let error = try #require(throws: FilingHistoryStoreError.self) { try store.load() }

    guard case .corrupt = error else {
      Issue.record("expected .corrupt, got \(error)")
      return
    }
  }

  @Test("a history with events of the wrong shape is reported as corrupt")
  func malformedEvents() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile(
      "FilingHistory.json", contents: #"{"version": 1, "events": [{"id": "nope"}]}"#)
    let store = FilingHistoryStore(fileURL: file)

    let error = try #require(throws: FilingHistoryStoreError.self) { try store.load() }

    guard case .corrupt(let url, _) = error else {
      Issue.record("expected .corrupt, got \(error)")
      return
    }
    #expect(url == file)
  }

  @Test("a history of an unknown format version is reported with its version")
  func unknownVersion() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile(
      "FilingHistory.json", contents: #"{"version": 2, "entries": []}"#)
    let store = FilingHistoryStore(fileURL: file)

    #expect(throws: FilingHistoryStoreError.unsupportedVersion(2, url: file)) {
      try store.load()
    }
  }

  @Test("a path that cannot be read is reported as unreadable, not as empty")
  func unreadablePath() throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("FilingHistory.json")
    let store = FilingHistoryStore(fileURL: folder)

    let error = try #require(throws: FilingHistoryStoreError.self) { try store.load() }

    guard case .readFailed(let url, _) = error else {
      Issue.record("expected .readFailed, got \(error)")
      return
    }
    #expect(url == folder)
  }

  @Test("saving creates the missing folders")
  func saveCreatesFolder() throws {
    let directory = try TemporaryDirectory()
    let file = directory.url.appending(path: "Application Support/Docsort/FilingHistory.json")
    let store = FilingHistoryStore(fileURL: file)
    let history = sampleHistory()

    try store.save(history)

    #expect(try store.load() == history)
  }

  @Test("saving replaces the file instead of writing into it")
  func saveReplacesFile() throws {
    let directory = try TemporaryDirectory()
    let file = directory.url.appending(path: "FilingHistory.json")
    let store = FilingHistoryStore(fileURL: file)
    try store.save(FilingHistory())
    let firstFileNumber = try fileNumber(of: file)

    try store.save(sampleHistory())

    #expect(try fileNumber(of: file) != firstFileNumber)
  }

  @Test("a history that cannot be encoded leaves the saved file intact")
  func failedEncodeKeepsFile() throws {
    let directory = try TemporaryDirectory()
    let file = directory.url.appending(path: "FilingHistory.json")
    let store = FilingHistoryStore(fileURL: file)
    try store.save(sampleHistory())
    let saved = try contents(of: file)
    var unencodable = FilingHistory()
    unencodable.recordMove(
      moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/a.pdf"),
      at: Date(timeIntervalSinceReferenceDate: .nan))

    let error = try #require(throws: FilingHistoryStoreError.self) { try store.save(unencodable) }

    guard case .encodingFailed(let url, _) = error else {
      Issue.record("expected .encodingFailed, got \(error)")
      return
    }
    #expect(url == file)
    #expect(try contents(of: file) == saved)
  }

  @Test("a failed write leaves the saved file intact")
  func failedWriteKeepsFile() throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Docsort")
    let file = folder.appending(path: "FilingHistory.json")
    let store = FilingHistoryStore(fileURL: file)
    try store.save(sampleHistory())
    let saved = try contents(of: file)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
    defer {
      // Restoring write access only lets the temporary directory be removed; a failure here shows up as a leftover
      // folder, not as a wrong test result.
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: folder.path)
    }

    let error = try #require(throws: FilingHistoryStoreError.self) {
      try store.save(FilingHistory())
    }

    guard case .writeFailed(let url, _) = error else {
      Issue.record("expected .writeFailed, got \(error)")
      return
    }
    #expect(url == file)
    #expect(try contents(of: file) == saved)
  }

  @Test("the default file is Docsort/FilingHistory.json in Application Support")
  func defaultFileURL() {
    let url = FilingHistoryStore.defaultFileURL()

    #expect(url.lastPathComponent == "FilingHistory.json")
    #expect(url.deletingLastPathComponent().lastPathComponent == "Docsort")
    #expect(
      url.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL
        == URL.applicationSupportDirectory.standardizedFileURL)
  }

  private func fileNumber(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(
      atPath: url.path(percentEncoded: false))
    return try #require(attributes[.systemFileNumber] as? Int)
  }
}
