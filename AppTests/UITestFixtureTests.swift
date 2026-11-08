import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("UITestFixture")
struct UITestFixtureTests {
  @Test("The launch argument selects the fixture")
  func launchArgumentSelectsTheFixture() {
    #expect(
      AppLaunchMode.current(
        processEnvironment: [:], arguments: ["Docsort", "-docsort-ui-test-fixture"])
        == .uiTestFixture)
    #expect(AppLaunchMode.current(processEnvironment: [:], arguments: ["Docsort"]) == .standard)
  }

  @Test(
    "The fixture configures its folders through real bookmarks and lists the inboxes in a fixed order"
  )
  func fixtureIsUsable() async throws {
    let environment = UITestFixture.makeEnvironment()
    let folders = FolderLibrary(environment: environment)
    #expect(folders.areFoldersConfigured)
    #expect(folders.archiveAvailability == .available)
    #expect(folders.inboxes.map(\.displayLabel) == ["Web-Downloads", "Scanner"])
    #expect(folders.inboxes.allSatisfy { $0.availability == .available })

    let inboxes = InboxLibrary()
    inboxes.update(inboxes: folders.inboxes)
    await inboxes.waitForScan()
    #expect(
      inboxes.orderedRows.map(\.item.name) == [
        "Rechnung_Collegegeld_1e-termijn.pdf", "Inschrijvingsbewijs_ST-000-58213.pdf",
        "Rechnung_NA-33-08812.pdf", "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
        "2033-10-11_Optik Klarblick.pdf",
      ])

    let archive = ArchiveLibrary()
    archive.update(to: ArchiveIndexRequest(folders: folders))
    await archive.waitForIndexing()
    let index = try #require(archive.index)
    #expect(index.search("noten").first?.path == "Musik Margit/Noten & Bücher")
  }
}
