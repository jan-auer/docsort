import DocsortCore
import Foundation
import Observation
import Testing

@testable import Docsort

/// Records what the controller does to the Quick Look panel.
@MainActor
private final class FakeQuickLookPanel: QuickLookPanelPresenting {
  private(set) var isVisible = false
  private(set) var reloadCount = 0

  func open() { isVisible = true }
  func close() { isVisible = false }
  func reload() { reloadCount += 1 }
}

/// A list of files with a selection, as Folder contents and the sidebar are.
@MainActor
@Observable
private final class FakeQuickLookSource: QuickLookSource {
  let urls: [URL]
  var selectedIndex: Int?

  init(names: [String], selectedIndex: Int?) {
    urls = names.map { URL(filePath: "/Archiv/Kommunikation/Ilmnet Internet/Rechnungen/\($0)") }
    self.selectedIndex = selectedIndex
  }

  var quickLookURL: URL? { selectedIndex.map { urls[$0] } }

  func moveQuickLookSelection(by offset: Int) {
    guard let selectedIndex else { return }
    self.selectedIndex = min(max(selectedIndex + offset, 0), urls.count - 1)
  }
}

@MainActor
@Suite("Quick Look panel controller")
struct QuickLookPanelControllerTests {
  private let names = [
    "2033-03-04 Rechnung März.pdf", "2033-07-19 Gutschrift Störung.pdf",
    "2033-10-04 Rechnung Oktober.pdf",
  ]

  /// Waits up to five seconds for `condition`, which observation makes true on a later main-actor turn.
  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition() {
      guard ContinuousClock.now < deadline else {
        Issue.record("Timed out waiting for the controller")
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  @Test("Space opens the panel on the selected file and closes it again")
  func toggle() {
    let panel = FakeQuickLookPanel()
    let controller = QuickLookPanelController(panel: panel)
    let source = FakeQuickLookSource(names: names, selectedIndex: 1)

    controller.toggle(for: source)
    #expect(panel.isVisible)
    #expect(controller.shownURL == source.urls[1])

    controller.toggle(for: source)
    #expect(!panel.isVisible)
  }

  @Test("Without a selected file, Space opens nothing")
  func nothingSelected() {
    let panel = FakeQuickLookPanel()
    let controller = QuickLookPanelController(panel: panel)
    controller.toggle(for: FakeQuickLookSource(names: names, selectedIndex: nil))
    #expect(!panel.isVisible)
  }

  @Test("↑ and ↓ in the panel move the list's selection, and the panel follows")
  func arrowsMoveTheSelection() {
    let panel = FakeQuickLookPanel()
    let controller = QuickLookPanelController(panel: panel)
    let source = FakeQuickLookSource(names: names, selectedIndex: 0)
    controller.toggle(for: source)

    #expect(controller.handle(.downArrow))
    #expect(source.selectedIndex == 1)
    #expect(controller.shownURL == source.urls[1])
    #expect(panel.reloadCount == 1)

    #expect(controller.handle(.upArrow))
    #expect(controller.shownURL == source.urls[0])
  }

  @Test("Space and Esc in the panel close it")
  func spaceAndEscapeClose() {
    let panel = FakeQuickLookPanel()
    let controller = QuickLookPanelController(panel: panel)
    let source = FakeQuickLookSource(names: names, selectedIndex: 0)

    controller.toggle(for: source)
    #expect(controller.handle(.space))
    #expect(!panel.isVisible)

    controller.toggle(for: source)
    #expect(controller.handle(.escape))
    #expect(!panel.isVisible)
  }

  @Test("The panel follows a selection changed in the list, and closes when nothing is selected")
  func followsTheList() async throws {
    let panel = FakeQuickLookPanel()
    let controller = QuickLookPanelController(panel: panel)
    let source = FakeQuickLookSource(names: names, selectedIndex: 0)
    controller.toggle(for: source)

    source.selectedIndex = 2
    try await waitUntil { controller.shownURL == source.urls[2] }

    source.selectedIndex = nil
    try await waitUntil { !panel.isVisible }
    #expect(controller.shownURL == nil)
  }

  @Test("In Folder contents, ↓ in the panel moves to the next file")
  func folderContentsSource() async throws {
    let archive = try PickerArchiveFixture()
    let picker = DestinationPickerModel(
      folderFiles: ArchiveFolderFileListing(), index: try archive.index())
    picker.reset(choosing: .folder("Kommunikation/Ilmnet Internet/Rechnungen"))
    await picker.contentsTask?.value
    picker.moveContentsSelection(by: 1)
    let panel = FakeQuickLookPanel()
    let controller = QuickLookPanelController(panel: panel)

    controller.toggle(for: picker)
    let first = try #require(controller.shownURL)
    controller.handle(.downArrow)
    #expect(controller.shownURL != first)
    #expect(controller.shownURL == picker.selectedContentsFile?.url)
  }
}
