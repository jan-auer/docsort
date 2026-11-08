import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("Destination picker folders in Finder")
@MainActor
struct DestinationPickerFinderTests {
  static let visit = "Reisen/2033-11 Besuch Westerholm"

  let archive: PickerArchiveFixture

  init() throws {
    archive = try PickerArchiveFixture()
  }

  func makeModel(recents: [String] = [], index: DestinationIndex?) -> DestinationPickerModel {
    DestinationPickerModel(
      folderFiles: FakeFolderFileListing(), index: index,
      recents: RecentDestinations(paths: recents))
  }

  func makeModel(recents: [String] = []) throws -> DestinationPickerModel {
    makeModel(recents: recents, index: try archive.index())
  }

  /// Where the folder at the archive-relative `path` is on disk, as the model's index locates it.
  func location(of path: String, in model: DestinationPickerModel) -> URL? {
    model.index?.url(for: path)
  }

  @Test("The destination folder is the highlighted folder, then the chosen one")
  func destinationFolder() throws {
    let model = try makeModel()
    model.highlightFolder("Mobilität")
    #expect(model.destinationFolderURL == location(of: "Mobilität", in: model))

    model.reset(choosing: .folder("Kommunikation/Ilmnet Internet/Rechnungen"))
    #expect(
      model.destinationFolderURL
        == location(of: "Kommunikation/Ilmnet Internet/Rechnungen", in: model))
  }

  @Test("Folder rows and the \"this folder\" row locate their folders; the create row has none")
  func rowFolders() throws {
    let model = try makeModel()
    model.jump(to: "Gesundheit")
    let thisFolder = try #require(model.rows.first)
    #expect(model.folderURL(of: thisFolder) == location(of: "Gesundheit", in: model))
    let konrad = try #require(model.rows.first { $0.folderPath == "Gesundheit/Konrad" })
    #expect(model.folderURL(of: konrad) == location(of: "Gesundheit/Konrad", in: model))

    model.filterText = "Kleingarten Am Weidenbach"
    let createRow = try #require(model.highlightedRow)
    guard case .createFolder = createRow.kind else {
      Issue.record("Expected the create row, got \(createRow.kind)")
      return
    }
    #expect(model.folderURL(of: createRow) == nil)
    #expect(model.destinationFolderURL == nil)
  }

  @Test("A pending new folder is not on disk, so it has no folder to open")
  func pendingFolder() throws {
    let model = try makeModel()
    model.reset(choosing: .newFolder(Self.visit))
    #expect(model.destinationFolderURL == nil)
    let pendingRow = try #require(model.rows.first { $0.folderPath == Self.visit })
    #expect(model.folderURL(of: pendingRow) == nil)

    model.jump(to: Self.visit)
    let thisFolder = try #require(model.rows.first)
    #expect(thisFolder.kind == .currentFolder(path: Self.visit))
    #expect(model.folderURL(of: thisFolder) == nil)

    try archive.createFolder(Self.visit)
    model.index = try archive.index()
    #expect(model.folderURL(of: thisFolder) == location(of: Self.visit, in: model))
  }

  @Test("While the archive is being indexed, no folder can be located")
  func indexing() throws {
    let model = makeModel(recents: ["Reisen"], index: nil)
    let recent = try #require(model.highlightedRow)
    #expect(recent.folderPath == "Reisen")
    #expect(model.folderURL(of: recent) == nil)
    #expect(model.destinationFolderURL == nil)
  }
}
