import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("Destination picker model")
@MainActor
struct DestinationPickerModelTests {
  let archive: PickerArchiveFixture
  let events = PickerEventLog()

  init() throws {
    archive = try PickerArchiveFixture()
  }

  /// A model over the fixture archive (or without an index when `index` is `nil`), recording its events.
  func makeModel(recents: [String] = [], index: DestinationIndex?) -> DestinationPickerModel {
    let model = DestinationPickerModel(
      folderFiles: ArchiveFolderFileListing(), index: index,
      recents: RecentDestinations(paths: recents))
    events.record(model)
    return model
  }

  func makeModel(recents: [String] = []) throws -> DestinationPickerModel {
    makeModel(recents: recents, index: try archive.index())
  }

  // MARK: Rows

  @Test("The root lists indexed recents, then the top-level folders")
  func rootRows() throws {
    let model = try makeModel(recents: [
      "Kommunikation/Ilmnet Internet/Rechnungen", "Hund Fritzi/Tierarzt", "Reisen",
    ])

    #expect(model.sections.map(\.title) == ["Recent", "All folders"])
    #expect(
      model.rowSummaries == [
        "Kommunikation/Ilmnet Internet/Rechnungen", "Reisen",
        "Gesundheit", "Kommunikation", "Mobilität", "Reisen",
      ])
    #expect(model.highlightedPath == "Kommunikation/Ilmnet Internet/Rechnungen")
    #expect(model.pathBarSegments.isEmpty)
    #expect(model.filterPlaceholder == "Search archive")
  }

  @Test("While indexing, Recent is listed unfiltered and filtering shows the indexing row")
  func rowsWhileIndexing() {
    let model = makeModel(recents: ["Reisen", "Hund Fritzi/Tierarzt"], index: nil)

    #expect(model.rowSummaries == ["Reisen", "Hund Fritzi/Tierarzt"])
    #expect(model.isIndexing)
    #expect(model.filterPlaceholder == "Indexing archive…")

    model.filterText = "rech"
    #expect(model.rowSummaries == ["indexing"])
    #expect(model.highlightedRowID == nil)
  }

  @Test("Inside a folder, \"this folder\" comes first, then the subfolders by name")
  func scopedBrowsing() throws {
    let model = try makeModel()
    model.highlightFolder("Gesundheit")
    model.stepIn()

    #expect(model.scope == "Gesundheit")
    #expect(
      model.rowSummaries == [
        "this:Gesundheit", "Impfpässe", "Konrad", "Margit", "Patientenverfügung",
      ])
    #expect(model.highlightedRow?.kind == .currentFolder(path: "Gesundheit"))
    #expect(model.pathBarSegments.map(\.title) == ["Archive", "Gesundheit"])
    #expect(model.scopeTitle == "Gesundheit")
    #expect(model.filterPlaceholder == "Search in Gesundheit")
  }

  @Test("Search lists matches inside the scope with paths relative to it and matched ranges")
  func searchRows() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    model.filterText = "physio"

    #expect(model.rowSummaries == ["Konrad/Physiotherapie", "Margit/Physiotherapie"])
    guard case .folder(let first) = model.rows.first?.kind else {
      Issue.record("The first row is not a folder")
      return
    }
    #expect(first.path == "Gesundheit/Konrad/Physiotherapie")
    let matched = first.matchedRanges.map { first.displayPath[$0] }.joined()
    #expect(matched.lowercased() == "physio")
    #expect(model.highlightedPath == "Gesundheit/Konrad/Physiotherapie")
  }

  // MARK: Highlight

  @Test("The highlight stays on its row when rows recompute and stops at the ends")
  func highlightKeepingAndClamping() throws {
    let model = try makeModel()
    model.highlightFolder("Mobilität")
    model.recents = RecentDestinations(paths: ["Reisen"])
    #expect(model.highlightedRowID == "all:Mobilität")

    model.moveHighlight(by: 100)
    #expect(model.highlightedRowID == "all:Reisen")
    model.moveHighlight(by: -100)
    #expect(model.highlightedRowID == "recent:Reisen")
  }

  // MARK: Choosing

  @Test("Choosing clears the field, shows a token, and moving the highlight restores the filter")
  func chooseAndUnchoose() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    model.filterText = "physio"
    model.moveHighlight(by: 1)
    model.chooseHighlighted()

    #expect(events.events == [.chose(.folder("Gesundheit/Margit/Physiotherapie"))])
    #expect(model.destination == .folder("Gesundheit/Margit/Physiotherapie"))
    #expect(model.filterText == "")
    #expect(
      model.chosenToken == ChosenToken(text: "Gesundheit › Margit › Physiotherapie", isNew: false))

    model.moveHighlight(by: -1)
    #expect(model.destination == nil)
    #expect(model.filterText == "physio")
    #expect(model.highlightedPath == "Gesundheit/Konrad/Physiotherapie")
  }

  @Test("\"This folder\" chooses the scope; ⌫ un-chooses it again")
  func chooseCurrentFolder() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    model.chooseHighlighted()
    #expect(events.events == [.chose(.folder("Gesundheit"))])

    model.deleteBackward()
    #expect(model.destination == nil)
    #expect(model.scope == "Gesundheit")
    #expect(model.highlightedRow?.kind == .currentFolder(path: "Gesundheit"))
  }

  @Test("Typing while chosen drops the destination and filters with the new text")
  func typingWhileChosen() throws {
    let model = try makeModel()
    model.filterText = "physio"
    model.chooseHighlighted()

    model.filterText = ""
    #expect(model.destination != nil)

    model.filterText = "z"
    #expect(model.destination == nil)
    #expect(model.filterText == "z")
    #expect(model.highlightedPath == "Gesundheit/Konrad/Zahnarzt")
  }

  @Test("⌘Return moves to the chosen destination, else chooses the highlighted row silently")
  func requestMove() throws {
    let model = try makeModel()
    model.highlightFolder("Mobilität")
    model.requestMove()
    #expect(events.events == [.moveRequested(.folder("Mobilität"))])
    #expect(model.destination == .folder("Mobilität"))

    model.requestMove()
    #expect(events.events.last == .moveRequested(.folder("Mobilität")))
    #expect(events.events.count == 2)
  }

  @Test("⌘Return with nothing highlighted does nothing")
  func requestMoveWithoutHighlight() {
    let model = makeModel(index: nil)
    model.filterText = "reisen"
    model.requestMove()
    #expect(events.events.isEmpty)
    #expect(model.destination == nil)
  }

  @Test("Esc clears scope and filter first, then steps back; ⇧Tab steps back at once")
  func escapeAndStepBack() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.filterText = "hoch"

    model.escape()
    #expect(model.scope == "")
    #expect(model.filterText == "")
    #expect(events.events.isEmpty)

    model.escape()
    #expect(events.events == [.steppedBack])

    model.jump(to: "Reisen")
    model.stepBack()
    #expect(events.events == [.steppedBack, .steppedBack])
    #expect(model.scope == "Reisen")
  }

  // MARK: Stepping

  @Test("Stepping out highlights the folder the picker came from")
  func stepOutOfFolder() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit/Konrad")
    model.stepOut()

    #expect(model.scope == "Gesundheit")
    #expect(model.highlightedRowID == "browse:Gesundheit/Konrad")
  }

  @Test("At the root, stepping out of a nested recent opens its parent")
  func stepOutOfNestedRecent() throws {
    let model = try makeModel(recents: ["Kommunikation/Ilmnet Internet/Rechnungen"])
    model.stepOut()

    #expect(model.scope == "Kommunikation/Ilmnet Internet")
    #expect(model.highlightedPath == "Kommunikation/Ilmnet Internet/Rechnungen")

    model.jumpToRoot()
    model.highlightFolder("Reisen")
    model.stepOut()
    #expect(model.scope == "")
  }

  @Test("Jumping highlights the folder the picker came from where it is listed")
  func jumping() throws {
    let model = try makeModel()
    model.jump(to: "Reisen/2033-06 Wanderwoche Hochalm/Anreise")
    model.jump(to: "Reisen")
    #expect(model.highlightedPath == "Reisen/2033-06 Wanderwoche Hochalm")

    model.filterText = "ideen"
    model.jumpToRoot()
    #expect(model.scope == "")
    #expect(model.filterText == "")
    #expect(model.highlightedRowID == "all:Reisen")
  }

  @Test("Double-click steps into a folder with subfolders and chooses one without")
  func activate() throws {
    let model = try makeModel()
    model.activate("all:Gesundheit")
    #expect(model.scope == "Gesundheit")

    model.activate("browse:Gesundheit/Impfpässe")
    #expect(events.events == [.chose(.folder("Gesundheit/Impfpässe"))])
  }

  // MARK: Entry and reset

  @Test("Reset returns to the root with the given destination chosen")
  func reset() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    model.filterText = "zahn"

    model.reset(choosing: .folder("Reisen"))
    #expect(model.scope == "")
    #expect(model.filterText == "")
    #expect(model.destination == .folder("Reisen"))
    #expect(model.pendingFolders.isEmpty)
    #expect(model.highlightedPath == "Reisen")
  }

  @Test("Entering by typing drops the destination and appends to the empty field")
  func enterTyping() throws {
    let model = try makeModel()
    model.filterText = "physio"
    model.chooseHighlighted()

    model.enter(typing: "wander")
    #expect(model.destination == nil)
    #expect(model.filterText == "wander")
    #expect(model.highlightedPath == "Reisen/2033-06 Wanderwoche Hochalm")

    model.enter(typing: "woche")
    #expect(model.filterText == "wanderwoche")
  }

  // MARK: Index changes

  @Test("A new index keeps the highlight and moves a vanished scope to its nearest ancestor")
  func indexReplacement() throws {
    let model = try makeModel()
    model.highlightFolder("Mobilität")
    try archive.createFolder("Matthias")
    model.index = try archive.index()
    #expect(model.rowSummaries.contains("Matthias"))
    #expect(model.highlightedRowID == "all:Mobilität")

    model.jump(to: "Reisen/2033-06 Wanderwoche Hochalm/Anreise")
    try archive.removeFolder("Reisen/2033-06 Wanderwoche Hochalm")
    model.index = try archive.index()
    #expect(model.scope == "Reisen")
  }
}
