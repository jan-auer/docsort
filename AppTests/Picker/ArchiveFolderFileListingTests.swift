import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("Archive folder file listing")
struct ArchiveFolderFileListingTests {
  @Test("Lists a folder's files alphabetically")
  func alphabeticalOrder() async throws {
    let archive = try PickerArchiveFixture()
    let files = try await ArchiveFolderFileListing().files(
      in: "Kommunikation/Ilmnet Internet/Rechnungen", of: archive.index())

    #expect(
      files.map(\.name) == [
        "2033-03-04 Rechnung März.pdf", "2033-07-19 Gutschrift Störung.pdf",
        "2033-10-04 Rechnung Oktober.pdf",
      ])
  }
}
