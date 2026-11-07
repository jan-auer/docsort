import Foundation
import Testing

@testable import DocsortCore

@Suite("FolderSettings")
struct FolderSettingsTests {
  static func reference(_ path: String) -> FolderReference {
    FolderReference(bookmark: Data("bookmark:\(path)".utf8), lastKnownPath: path)
  }

  @Test("the folder name is the last component of the last known path")
  func folderName() {
    #expect(Self.reference("/Users/me/Drive/Inbox/Scans").folderName == "Scans")
    #expect(Self.reference("/Users/me/Drive/Inbox/Scans/").folderName == "Scans")
  }

  @Test("the folder name follows the last known path")
  func folderNameFollowsPath() {
    var reference = Self.reference("/a/Old")

    reference.lastKnownPath = "/a/New"

    #expect(reference.folderName == "New")
  }

  @Test(
    "the display label is the label, or the folder name when the label is nil or blank",
    arguments: [
      (String?.some("Scanner"), "Scanner"),
      (String?.some("  Scanner "), "Scanner"),
      (String?.some(""), "Scans"),
      (String?.some("  \n"), "Scans"),
      (String?.none, "Scans"),
    ])
  func displayLabel(label: String?, expected: String) {
    let inbox = InboxFolder(label: label, folder: Self.reference("/Drive/Inbox/Scans"))

    #expect(inbox.displayLabel == expected)
  }

  @Test("empty settings have no archive root and no inboxes")
  func empty() {
    #expect(FolderSettings.empty.archiveRoot == nil)
    #expect(FolderSettings.empty.inboxes.isEmpty)
  }

  @Test("addInbox appends an inbox for the folder and returns it")
  func addInbox() {
    var settings = FolderSettings.empty

    let first = settings.addInbox(Self.reference("/Inbox/Scans"))
    let second = settings.addInbox(Self.reference("/Inbox/Downloads"), label: "Web")

    #expect(settings.inboxes == [first, second])
    #expect(first.label == nil)
    #expect(first.folder == Self.reference("/Inbox/Scans"))
    #expect(second.displayLabel == "Web")
    #expect(first.id != second.id)
  }

  @Test("removeInbox removes only the inbox with that id")
  func removeInbox() {
    var settings = FolderSettings.empty
    let first = settings.addInbox(Self.reference("/a"))
    let second = settings.addInbox(Self.reference("/b"))

    settings.removeInbox(id: first.id)

    #expect(settings.inboxes == [second])
  }

  @Test("relabelInbox sets a trimmed label, and a blank label clears it")
  func relabelInbox() throws {
    var settings = FolderSettings.empty
    let inbox = settings.addInbox(Self.reference("/Inbox/Scans"), label: "Old")

    settings.relabelInbox(id: inbox.id, to: "  Scanner ")
    #expect(try #require(settings.inboxes.first).label == "Scanner")

    settings.relabelInbox(id: inbox.id, to: " ")
    #expect(try #require(settings.inboxes.first).label == nil)
    #expect(try #require(settings.inboxes.first).displayLabel == "Scans")
  }

  @Test(
    "moveInboxes reorders like a list's onMove",
    arguments: [
      (IndexSet([0]), 3, ["b", "c", "a"]),
      (IndexSet([2]), 0, ["c", "a", "b"]),
      (IndexSet([0, 2]), 2, ["b", "a", "c"]),
      (IndexSet([1]), 1, ["a", "b", "c"]),
      (IndexSet([1]), 2, ["a", "b", "c"]),
      (IndexSet([0, 5]), 9, ["b", "c", "a"]),
    ])
  func moveInboxes(offsets: IndexSet, destination: Int, expected: [String]) {
    var settings = FolderSettings.empty
    for name in ["a", "b", "c"] {
      settings.addInbox(Self.reference("/\(name)"))
    }

    settings.moveInboxes(fromOffsets: offsets, toOffset: destination)

    #expect(settings.inboxes.map(\.folder.folderName) == expected)
  }

  @Test("the preference stores the settings under folderSettings")
  func preferenceRoundTrip() throws {
    let suite = try TemporaryDefaults()
    let preference = FolderSettings.preference(in: suite.defaults)
    var settings = FolderSettings.empty
    settings.archiveRoot = Self.reference("/Drive")
    settings.addInbox(Self.reference("/Drive/Inbox/Scans"), label: "Scanner")

    try preference.save(settings)

    #expect(preference.key == "folderSettings")
    #expect(try preference.load() == settings)
  }
}
