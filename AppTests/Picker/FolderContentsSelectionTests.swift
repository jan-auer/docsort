import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("Folder contents selection")
@MainActor
struct FolderContentsSelectionTests {
  static let invoices = "Kommunikation/Ilmnet Internet/Rechnungen"
  static let march = "2033-03-04 Rechnung März.pdf"
  static let credit = "2033-07-19 Gutschrift Störung.pdf"
  static let october = "2033-10-04 Rechnung Oktober.pdf"

  let archive: PickerArchiveFixture
  let events = PickerEventLog()

  init() throws {
    archive = try PickerArchiveFixture()
  }

  /// A picker with the invoices folder chosen and its files listed alphabetically.
  func makeModel() async throws -> DestinationPickerModel {
    let model = DestinationPickerModel(
      folderFiles: ArchiveFolderFileListing(), index: try archive.index())
    events.record(model)
    model.reset(choosing: .folder(Self.invoices))
    await model.contentsTask?.value
    return model
  }

  func file(named name: String, in model: DestinationPickerModel) throws -> FolderFile {
    guard case .files(_, let files) = model.contents else {
      Issue.record("No files listed: \(model.contents)")
      throw CancellationError()
    }
    return try #require(files.first { $0.name.precomposedStringWithCanonicalMapping == name })
  }

  func selectedName(_ model: DestinationPickerModel) -> String? {
    model.selectedContentsFile?.name.precomposedStringWithCanonicalMapping
  }

  @Test("A click selects a file without using its name")
  func clickSelects() async throws {
    let model = try await makeModel()
    #expect(model.selectedContentsFile == nil)

    model.selectContentsFile(try file(named: Self.credit, in: model))
    #expect(selectedName(model) == Self.credit)
    #expect(events.events.isEmpty)
  }

  @Test("↓ starts at the first file, ↑ at the last, and both stop at the ends")
  func arrowsMoveTheSelection() async throws {
    let model = try await makeModel()
    model.moveContentsSelection(by: 1)
    #expect(selectedName(model) == Self.march)
    model.moveContentsSelection(by: 1)
    #expect(selectedName(model) == Self.credit)
    model.moveContentsSelection(by: 1)
    model.moveContentsSelection(by: 1)
    #expect(selectedName(model) == Self.october)

    let fresh = try await makeModel()
    fresh.moveContentsSelection(by: -1)
    #expect(selectedName(fresh) == Self.october)
    fresh.moveContentsSelection(by: -5)
    #expect(selectedName(fresh) == Self.march)
  }

  @Test("Return and a double-click use the file's name")
  func primaryActionUsesTheName() async throws {
    let model = try await makeModel()
    model.useSelectedContentsFileName()
    #expect(events.events.isEmpty)

    model.selectContentsFile(try file(named: Self.march, in: model))
    model.useSelectedContentsFileName()
    model.takeFileName(try file(named: Self.october, in: model))

    let names = events.events.map { event -> String in
      guard case .tookFileName(let name) = event else { return "\(event)" }
      return name.precomposedStringWithCanonicalMapping
    }
    #expect(names == [Self.march, Self.october])
    #expect(selectedName(model) == Self.october)
  }

  @Test("Another folder clears the selection")
  func otherFolderClears() async throws {
    let model = try await makeModel()
    model.selectContentsFile(try file(named: Self.march, in: model))

    model.reset(choosing: .folder("Mobilität/Jahreskarte Regio Plus"))
    await model.contentsTask?.value
    #expect(model.selectedContentsFile == nil)
  }

  @Test("Reloading the folder selects the requested file, and drops a selection that is gone")
  func reloadSelects() async throws {
    let model = try await makeModel()
    let october = try file(named: Self.october, in: model)
    let renamed = october.url.deletingLastPathComponent().appending(
      path: "2033-09-04 Rechnung September.pdf")
    try FileManager.default.moveItem(at: october.url, to: renamed)

    model.reloadContents(selecting: renamed)
    // The files stay listed while the folder is read again, so the list doesn't flash empty.
    guard case .files = model.contents else {
      Issue.record("The reload hid the files: \(model.contents)")
      return
    }
    await model.contentsTask?.value
    #expect(selectedName(model) == "2033-09-04 Rechnung September.pdf")

    model.reloadContents(selecting: october.url)
    await model.contentsTask?.value
    #expect(model.selectedContentsFile == nil)
  }

  @Test("Rename and Move to Trash are asked of the window")
  func fileActionsAreEvents() async throws {
    let model = try await makeModel()
    let march = try file(named: Self.march, in: model)

    model.requestRename(of: march, to: "2033-07-04 Rechnung Juli")
    model.requestTrash(of: march)
    #expect(
      events.events == [
        .renameFileRequested(march, to: "2033-07-04 Rechnung Juli"),
        .trashFileRequested(march),
      ])
  }
}
