import Foundation
import Testing

@testable import DocsortCore

@Suite("FilingHistory coding")
struct FilingHistoryCodingTests {
  @Test("a move record with created folders and a replaced item survives encoding")
  func moveRecordRoundTrip() throws {
    let record = MoveRecord(
      originalURL: location("/Inbox/scan.pdf"),
      destinationURL: location("/Archiv/2026-11 Monitor/Lieferschein/Lieferschein.pdf"),
      createdFolders: [
        location("/Archiv/2026-11 Monitor/"), location("/Archiv/2026-11 Monitor/Lieferschein/"),
      ],
      replaced: trashRecord(of: "/Archiv/2026-11 Monitor/Lieferschein/Lieferschein.pdf"),
      movedItem: FileIdentity(volumeUUID: nil, fileID: 42))

    let decoded = try JSONDecoder().decode(
      MoveRecord.self, from: try JSONEncoder().encode(record))

    #expect(decoded == record)
  }

  @Test("a trash record survives encoding")
  func trashRecordRoundTrip() throws {
    let record = trashRecord(of: "/Inbox/Kündigung ä.pdf")

    let decoded = try JSONDecoder().decode(
      TrashRecord.self, from: try JSONEncoder().encode(record))

    #expect(decoded == record)
  }

  @Test("a history with moves, a trash and an undone event survives encoding")
  func historyRoundTrip() throws {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1.25))
    history.recordMove(moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/b.pdf"), at: testDate(2))
    history.recordTrash(trashRecord(of: "/Inbox/junk.pdf"), at: testDate(3))
    let undone = history.recordMove(
      moveRecord(from: "/Archiv/b.pdf", to: "/Archiv/c.pdf"), at: testDate(4))
    try history.markUndone(undone.id, at: testDate(5.5))

    let decoded = try JSONDecoder().decode(
      FilingHistory.self, from: try JSONEncoder().encode(history))

    #expect(decoded == history)
    #expect(decoded.document(at: location("/Archiv/b.pdf")) == first.documentID)
  }

  @Test("a Replace's trash event keeps the link to its move through encoding")
  func replaceRoundTrip() throws {
    var history = FilingHistory()
    history.recordMove(moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    let replacing = history.recordMove(
      MoveRecord(
        originalURL: location("/Inbox/b.pdf"), destinationURL: location("/Archiv/x.pdf"),
        createdFolders: [], replaced: trashRecord(of: "/Archiv/x.pdf"), movedItem: testIdentity),
      at: testDate(2))

    let decoded = try JSONDecoder().decode(
      FilingHistory.self, from: try JSONEncoder().encode(history))

    #expect(decoded == history)
    #expect(decoded.events.contains { $0.causedBy == replacing.id })
  }

  @Test("the encoded history carries format version 1 at the top level")
  func encodesVersion() throws {
    let data = try JSONEncoder().encode(FilingHistory())

    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["version"] as? Int == 1)
    #expect((object["events"] as? [Any])?.isEmpty == true)
  }

  @Test("decoding an unknown format version fails")
  func rejectsUnknownVersion() {
    let data = Data(#"{"version": 2, "events": []}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(FilingHistory.self, from: data)
    }
  }

  @Test("decoding a history without a format version fails")
  func rejectsMissingVersion() {
    let data = Data(#"{"events": []}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(FilingHistory.self, from: data)
    }
  }

  @Test("decoding an action that is neither a move nor a trash fails")
  func rejectsUnknownAction() {
    let data = Data(#"{"copied": {}}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(FilingAction.self, from: data)
    }
  }
}
