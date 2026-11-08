import DocsortCore
import Foundation
import Testing

@testable import Docsort

/// Soft scope (`docs/design/ux.md`, "Destination picker"): inside a folder every search covers the whole archive, with
/// the folder's matches first ("In <folder>") and the rest after them ("Elsewhere").
@Suite("Destination picker soft scope")
@MainActor
struct DestinationPickerSoftScopeTests {
  let archive: PickerArchiveFixture
  let events = PickerEventLog()

  init() throws {
    archive = try PickerArchiveFixture()
  }

  func makeModel(recents: [String] = []) throws -> DestinationPickerModel {
    let model = DestinationPickerModel(
      folderFiles: ArchiveFolderFileListing(), index: try archive.index(),
      recents: RecentDestinations(paths: recents))
    events.record(model)
    return model
  }

  @Test("Inside a folder, its matches come first, then the rest of the archive with full paths")
  func inFolderThenElsewhere() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit/Konrad")
    model.filterText = "physio"

    #expect(model.sections.map(\.title) == ["In Konrad", "Elsewhere"])
    #expect(model.rowSummaries == ["Physiotherapie", "Gesundheit/Margit/Physiotherapie"])
    #expect(model.highlightedPath == "Gesundheit/Konrad/Physiotherapie")
    #expect(model.filterPlaceholder == "Search, Konrad first")
  }

  @Test(
    "Elsewhere leaves out the folder's own subtree and keeps the matched ranges of the full path")
  func elsewhereLeavesOutTheSubtree() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    model.filterText = "physio"

    #expect(model.sections.map(\.title) == ["In Gesundheit"])
    #expect(model.rowSummaries == ["Konrad/Physiotherapie", "Margit/Physiotherapie"])

    model.jump(to: "Reisen")
    model.filterText = "physio"
    let elsewhere = try #require(model.sections.last)
    guard case .folder(let first) = elsewhere.rows.first?.kind else {
      Issue.record("Elsewhere doesn't start with a folder")
      return
    }
    #expect(first.displayPath == "Gesundheit/Konrad/Physiotherapie")
    let matched = first.matchedRanges.map { first.displayPath[$0] }.joined()
    #expect(matched.lowercased() == "physio")
  }

  @Test(
    "When nothing in the folder matches, a note says so and the first Elsewhere match is highlighted"
  )
  func firstElsewhereHighlighted() throws {
    let model = try makeModel()
    model.jump(to: "Mobilität")
    model.filterText = "physio"

    #expect(model.sections.map(\.title) == ["In Mobilität", "Elsewhere"])
    #expect(
      model.rowSummaries == [
        "nothing in:Mobilität", "Gesundheit/Konrad/Physiotherapie",
        "Gesundheit/Margit/Physiotherapie",
      ])
    #expect(model.highlightedPath == "Gesundheit/Konrad/Physiotherapie")

    model.moveHighlight(by: -1)
    #expect(model.highlightedPath == "Gesundheit/Konrad/Physiotherapie")
  }

  @Test("When nothing matches anywhere, New Folder is offered in the folder and highlighted")
  func newFolderWhenNothingMatches() throws {
    let model = try makeModel()
    model.jump(to: "Reisen")
    model.filterText = "Kleingarten"

    #expect(model.sections.map(\.title) == [nil])
    #expect(model.rowSummaries == ["create:Kleingarten in Reisen"])
    #expect(
      model.highlightedRow?.kind
        == .createFolder(name: "Kleingarten", parent: "Reisen", problem: nil))
  }

  @Test("A query naming the folder itself offers it as \"this folder\", not a new folder")
  func scopeItselfMatches() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    model.filterText = "gesundheit"

    #expect(model.sections.map(\.title) == ["In Gesundheit"])
    #expect(model.rowSummaries == ["this:Gesundheit"])
    #expect(model.highlightedPath == "Gesundheit")
  }

  @Test("At the root a search is one untitled section, as before")
  func rootSearch() throws {
    let model = try makeModel()
    model.filterText = "physio"

    #expect(model.sections.map(\.title) == [nil])
    #expect(
      model.rowSummaries == [
        "Gesundheit/Konrad/Physiotherapie", "Gesundheit/Margit/Physiotherapie",
      ])
    #expect(model.filterPlaceholder == "Search archive")
  }

  @Test("Choosing keeps the query and the list and marks the chosen row; typing un-chooses")
  func choosingKeepsTheQuery() throws {
    let model = try makeModel()
    model.jump(to: "Mobilität")
    model.filterText = "physio"
    model.moveHighlight(by: 1)
    model.chooseHighlighted()

    #expect(events.events == [.chose(.folder("Gesundheit/Margit/Physiotherapie"))])
    #expect(model.filterText == "physio")
    #expect(model.rowSummaries.count == 3)
    let chosenRow = try #require(model.highlightedRow)
    #expect(model.isChosen(chosenRow))
    #expect(model.rows.filter(model.isChosen).count == 1)

    model.filterText = "physiot"
    #expect(model.destination == nil)
    #expect(!model.rows.contains(where: model.isChosen))
  }

  @Test("The destination path follows the highlight until a folder is chosen")
  func destinationPath() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    #expect(
      model.destinationPath == DestinationPath(path: "Gesundheit", isChosen: false, isNew: false))

    model.moveHighlight(by: 2)
    #expect(model.destinationPath?.path == "Gesundheit/Konrad")
    model.chooseHighlighted()
    #expect(
      model.destinationPath
        == DestinationPath(path: "Gesundheit/Konrad", isChosen: true, isNew: false))
    #expect(
      model.destinationPath?.segments.map(\.title) == ["Archive", "Gesundheit", "Konrad"])

    model.filterText = "Kleingarten"
    #expect(model.destinationPath == nil)
    model.beginNewFolder()
    #expect(
      model.destinationPath
        == DestinationPath(path: "Gesundheit/Kleingarten", isChosen: true, isNew: true))
  }
}
