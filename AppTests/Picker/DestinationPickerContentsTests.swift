import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("Destination picker folder contents")
@MainActor
struct DestinationPickerContentsTests {
  static let invoices = "Kommunikation/Ilmnet Internet/Rechnungen"

  let archive: PickerArchiveFixture
  let events = PickerEventLog()

  init() throws {
    archive = try PickerArchiveFixture()
  }

  func makeModel(listing: FakeFolderFileListing = FakeFolderFileListing(), recents: [String] = [])
    throws -> DestinationPickerModel
  {
    let model = DestinationPickerModel(
      folderFiles: listing, index: try archive.index(), recents: RecentDestinations(paths: recents))
    events.record(model)
    return model
  }

  /// The names of the listed files, or `nil` unless `contents` lists `folder`.
  func fileNames(_ contents: FolderContents, in folder: String) -> Set<String>? {
    guard case .files(let listed, let files) = contents, listed == folder else { return nil }
    return Set(files.map(\.name))
  }

  @Test("Contents follow the highlighted folder")
  func followHighlight() async throws {
    let model = try makeModel(recents: [Self.invoices])
    #expect(model.contents == .loading(folder: Self.invoices))
    await model.contentsTask?.value
    #expect(
      fileNames(model.contents, in: Self.invoices) == [
        "2033-03-04 Rechnung März.pdf", "2033-07-19 Gutschrift Störung.pdf",
        "2033-10-04 Rechnung Oktober.pdf",
      ])

    model.highlightFolder("Mobilität")
    await model.contentsTask?.value
    #expect(fileNames(model.contents, in: "Mobilität") == [])
  }

  @Test("Contents follow the chosen destination rather than the highlight")
  func followDestination() async throws {
    let model = try makeModel()
    model.reset(choosing: .folder("Mobilität/Jahreskarte Regio Plus"))
    await model.contentsTask?.value

    #expect(model.highlightedPath == "Gesundheit")
    #expect(
      fileNames(model.contents, in: "Mobilität/Jahreskarte Regio Plus") == [
        "2031-10-18 Jahreskarte Konrad.pdf"
      ])
  }

  @Test("A new folder is not on disk, and without a folder there are no contents")
  func notOnDiskAndNone() throws {
    let model = try makeModel()
    model.reset(choosing: .newFolder("Reisen/2033-11 Besuch Westerholm"))
    #expect(model.contents == .notOnDisk)

    let indexing = DestinationPickerModel(folderFiles: FakeFolderFileListing())
    indexing.filterText = "reisen"
    #expect(indexing.contents == FolderContents.none)
  }

  @Test("A failed listing shows why")
  func failure() async throws {
    let model = try makeModel(listing: FakeFolderFileListing(unreadableFolders: ["Mobilität"]))
    model.highlightFolder("Mobilität")
    await model.contentsTask?.value

    guard case .failed(let folder, let message) = model.contents else {
      Issue.record("Contents did not fail: \(model.contents)")
      return
    }
    #expect(folder == "Mobilität")
    #expect(message.contains(FakeFolderFileListing.unreadableReason))
  }

  @Test("A result for a folder that is no longer shown is ignored")
  func staleResult() async throws {
    let gate = FolderListingGate()
    let model = try makeModel(listing: FakeFolderFileListing(gate: gate))
    let first = model.contentsTask
    #expect(model.contents == .loading(folder: "Gesundheit"))

    model.highlightFolder("Mobilität/Jahreskarte Regio Plus")
    let second = model.contentsTask
    model.highlightFolder("Reisen")
    let third = model.contentsTask

    await gate.open("Gesundheit")
    await first?.value
    await gate.open("Mobilität/Jahreskarte Regio Plus")
    await second?.value
    #expect(model.contents == .loading(folder: "Reisen"))

    await gate.open("Reisen")
    await third?.value
    #expect(fileNames(model.contents, in: "Reisen") == [])
  }

  @Test("Clicking a file takes its name")
  func takeFileName() async throws {
    let model = try makeModel(recents: ["Mobilität/Jahreskarte Regio Plus"])
    await model.contentsTask?.value
    guard case .files(_, let files) = model.contents, let file = files.first else {
      Issue.record("No files listed: \(model.contents)")
      return
    }

    model.takeFileName(file)
    #expect(events.events == [.tookFileName("2031-10-18 Jahreskarte Konrad.pdf")])
  }
}
