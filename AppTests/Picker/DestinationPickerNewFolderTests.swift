import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("Destination picker new folders")
@MainActor
struct DestinationPickerNewFolderTests {
  static let visit = "Reisen/2033-11 Besuch Westerholm"

  let archive: PickerArchiveFixture
  let events = PickerEventLog()

  init() throws {
    archive = try PickerArchiveFixture()
  }

  func makeModel() throws -> DestinationPickerModel {
    let model = DestinationPickerModel(
      folderFiles: FakeFolderFileListing(), index: try archive.index())
    events.record(model)
    return model
  }

  // MARK: Create row

  @Test("A filter that finds nothing offers a new folder in the scope, with the name tidied")
  func createRow() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.filterText = " Besuch Westerholm // Bahn/ "
    #expect(model.rowSummaries == ["create:Besuch Westerholm/Bahn in Reisen"])

    model.chooseHighlighted()
    let created = PickerDestination.newFolder("Reisen/Besuch Westerholm/Bahn")
    #expect(events.events == [.chose(created)])
    #expect(model.pendingFolders == [created.path])
    #expect(
      model.chosenToken == ChosenToken(text: "Reisen › Besuch Westerholm › Bahn", isNew: true))
    #expect(model.contents == .notOnDisk)
  }

  @Test("An invalid name in the create row cannot be chosen")
  func invalidCreateRow() throws {
    let model = try makeModel()
    model.jump(to: "Mobilität")
    model.filterText = ".Bahn"
    #expect(
      model.rows.map(\.kind) == [
        .createFolder(name: ".Bahn", parent: "Mobilität", problem: .leadingDot)
      ])

    model.chooseHighlighted()
    model.requestMove()
    #expect(events.events.isEmpty)
    #expect(model.destination == nil)
  }

  @Test("New Folder with the create row highlighted creates it at once")
  func beginNewFolderFromCreateRow() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.filterText = "Besuch Westerholm"
    model.beginNewFolder()

    #expect(model.newFolderDraft == nil)
    #expect(events.events == [.chose(.newFolder("Reisen/Besuch Westerholm"))])
  }

  // MARK: New-folder row

  @Test("A new folder is named inside the highlighted folder, among its siblings")
  func draftInHighlightedFolder() throws {
    let model = try makeModel()
    model.highlightFolder("Reisen")
    #expect(model.newFolderParentTitle == "Reisen")

    model.beginNewFolder()
    #expect(model.newFolderDraft?.parent == "Reisen")
    #expect(model.scope == "Reisen")
    #expect(model.contents == .notOnDisk)
    #expect(
      model.rowSummaries == [
        "this:Reisen", "2032-05 Pfingsten Hochalm", "2033-06 Wanderwoche Hochalm",
        "Reiseplanung Ideen", "draft",
      ])

    model.newFolderName = "2033-11 Besuch Westerholm"
    #expect(model.newFolderDraft?.notice == nil)
    #expect(
      model.rowSummaries == [
        "this:Reisen", "2032-05 Pfingsten Hochalm", "2033-06 Wanderwoche Hochalm", "draft",
        "Reiseplanung Ideen",
      ])

    #expect(model.confirmNewFolder())
    #expect(events.events == [.chose(.newFolder(Self.visit))])
    #expect(model.newFolderDraft == nil)
    #expect(model.pendingFolders == [Self.visit])
    #expect(model.scope == "Reisen")
    #expect(model.rowSummaries.contains("new:2033-11 Besuch Westerholm"))
    #expect(model.highlightedPath == Self.visit)
  }

  @Test("A name that exists, ignoring case, selects the existing folder")
  func existingName() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.beginNewFolder()
    model.newFolderName = "reiseplanung ideen"
    #expect(
      model.newFolderDraft?.notice
        == .existing(parentTitle: "Reisen", existingName: "Reiseplanung Ideen"))

    #expect(model.confirmNewFolder())
    #expect(events.events == [.chose(.folder("Reisen/Reiseplanung Ideen"))])
    #expect(model.pendingFolders.isEmpty)
  }

  @Test("A slash creates nested folders below existing ones in their spelling")
  func nestedName() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.beginNewFolder()
    model.newFolderName = "2033-06 wanderwoche hochalm / Bahn"
    #expect(model.newFolderDraft?.notice == .nested(["2033-06 Wanderwoche Hochalm", "Bahn"]))

    #expect(model.confirmNewFolderAndMove())
    #expect(
      events.events == [.moveRequested(.newFolder("Reisen/2033-06 Wanderwoche Hochalm/Bahn"))])
  }

  @Test("An invalid name keeps the row; an empty one cancels it")
  func invalidAndEmptyNames() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.beginNewFolder()
    model.newFolderName = "Bahn: Hotel"
    #expect(model.newFolderDraft?.notice == .invalid(.forbiddenCharacter(":")))
    #expect(!model.confirmNewFolder())
    #expect(model.newFolderDraft != nil)

    model.newFolderName = "  "
    #expect(model.confirmNewFolder())
    #expect(model.newFolderDraft == nil)
    #expect(events.events.isEmpty)
  }

  @Test("Cancelling restores the filter, highlight and destination from before")
  func cancelRestores() throws {
    let model = try makeModel()
    model.filterText = "hoch"
    model.moveHighlight(by: 1)
    let highlighted = model.highlightedRowID
    let parent = try #require(model.highlightedPath)
    model.beginNewFolder()
    #expect(model.newFolderDraft?.parent == parent)

    model.cancelNewFolder()
    #expect(model.filterText == "hoch")
    #expect(model.scope == "")
    #expect(model.highlightedRowID == highlighted)

    model.jumpToRoot()
    model.highlightFolder("Mobilität")
    model.chooseHighlighted()
    model.beginNewFolder()
    #expect(model.newFolderDraft?.parent == "Mobilität")
    model.escape()
    #expect(model.newFolderDraft == nil)
    #expect(model.destination == .folder("Mobilität"))
  }

  @Test("⌘Return and ⇧Tab in the new-folder row confirm and cancel it")
  func requestMoveAndStepBackWithDraft() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.beginNewFolder()
    model.stepBack()
    #expect(model.newFolderDraft == nil)
    #expect(events.events.isEmpty)

    model.beginNewFolder()
    model.newFolderName = "2033-11 Besuch Westerholm"
    model.requestMove()
    #expect(events.events == [.moveRequested(.newFolder(Self.visit))])
  }

  // MARK: Pending folders

  @Test("Pending folders are listed in Recent and inside their parent, until the index has them")
  func pendingFolders() throws {
    let model = try makeModel()
    model.reset(choosing: .newFolder(Self.visit))
    #expect(model.pendingFolders == [Self.visit])
    #expect(model.rowSummaries.prefix(2) == ["new:\(Self.visit)", "Gesundheit"])

    model.jump(to: "Reisen")
    #expect(model.rowSummaries.contains("new:2033-11 Besuch Westerholm"))

    model.reset(choosing: .newFolder(Self.visit))
    try archive.createFolder(Self.visit)
    model.index = try archive.index()
    #expect(model.pendingFolders.isEmpty)
    #expect(model.destination == .folder(Self.visit))
    #expect(model.rowSummaries == ["Gesundheit", "Kommunikation", "Mobilität", "Reisen"])

    model.reset()
    #expect(model.destination == nil)
  }
}
