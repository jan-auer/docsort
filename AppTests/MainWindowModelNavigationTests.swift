import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("MainWindowModel: Previous File, Next File and the first file at launch")
struct MainWindowModelNavigationTests {
  let environment: TestFolderEnvironment
  let folders: FolderLibrary
  let inboxes: InboxLibrary
  let model: MainWindowModel

  /// Three files in Web-Downloads, one of them in the subfolder `Kurs`, and one in Scanner; nothing listed yet.
  init() throws {
    environment = try TestFolderEnvironment()
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(10))
    _ = try writeInboxFile(
      named: "Anmeldung Kurs.pdf", in: environment.webDownloads.appending(path: "Kurs"),
      date: october2033(11))
    _ = try writeInboxFile(
      named: "2033-10-12 Jahreskarte.pdf", in: environment.webDownloads, date: october2033(12))
    _ = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    folders = FolderLibrary(environment: environment.appEnvironment)
    folders.setArchiveRoot(to: environment.archive)
    folders.addInbox(folder: environment.webDownloads)
    folders.addInbox(folder: environment.scanner)
    let expectedChanges = ExpectedChanges()
    inboxes = InboxLibrary(watcher: InboxWatcher(expectedChanges: expectedChanges))
    let historyURL = environment.root.appending(path: "FilingHistory.json")
    model = MainWindowModel(
      folders: folders, inboxes: inboxes, archive: ArchiveLibrary(),
      filing: FilingStatusModel(
        service: FilingService(
          historyURL: historyURL,
          recentsPreference: RecentDestinations.preference(in: environment.defaults),
          fileOperations: FileOperations(), expectedChanges: expectedChanges),
        historyFileURL: historyURL),
      search: SearchSettings(defaults: environment.defaults))
  }

  private func listInboxes() async {
    inboxes.update(inboxes: folders.inboxes)
    await inboxes.waitForScan()
  }

  /// The subfolder group of Web-Downloads.
  private func kursGroup() throws -> InboxGroup {
    let entries = try #require(
      inboxes.sections.lazy.compactMap { section -> [InboxSectionEntry]? in
        if case .listing(let entries, _) = section.content { entries } else { nil }
      }.first)
    return try #require(
      entries.lazy.compactMap { entry -> InboxGroup? in
        if case .group(let group) = entry { group } else { nil }
      }.first)
  }

  @Test(
    "Next File steps through every file in sidebar order and stops at the end; Previous File steps back"
  )
  func stepsThroughFiles() async throws {
    defer { environment.remove() }
    await listInboxes()
    let order = inboxes.orderedRows.map(\.id)
    #expect(order.count == 4)

    #expect(model.file(.previous) == nil)
    var visited: [InboxItemID] = []
    while let next = model.file(.next) {
      model.selectFile(.next)
      #expect(model.sidebarSelection == .item(next))
      visited.append(next)
    }
    #expect(visited == order)
    #expect(model.file(.next) == nil)

    model.selectFile(.previous)
    #expect(model.sidebarSelection == .item(order[2]))
  }

  @Test(
    "A collapsed group's files are skipped, and a step from the group's row goes to the nearest file"
  )
  func skipsCollapsedGroups() async throws {
    defer { environment.remove() }
    await listInboxes()
    let group = try kursGroup()
    let groupFile = try #require(group.rows.first?.id)
    let order = inboxes.orderedRows.map(\.id)
    let groupFileIndex = try #require(order.firstIndex(of: groupFile))

    model.sidebarSelection = .group(group.url)
    #expect(model.file(.next) == groupFile)

    model.collapsedGroups.insert(group.url)
    let after = order.indices.contains(groupFileIndex + 1) ? order[groupFileIndex + 1] : nil
    let before = groupFileIndex > 0 ? order[groupFileIndex - 1] : nil
    #expect(model.file(.next) == after)
    #expect(model.file(.previous) == before)
    if let before {
      model.select(before)
      #expect(model.file(.next) == after)
    }
  }

  @Test("The first file is selected once the inboxes are first listed, and only once")
  func selectsFirstFileAfterInitialScan() async throws {
    defer { environment.remove() }
    let initialSelection = Task { await model.selectFirstFileAfterInitialScan() }
    await listInboxes()
    await initialSelection.value
    let first = try #require(inboxes.orderedRows.first?.id)
    #expect(model.sidebarSelection == .item(first))
    #expect(model.selectedFile?.id == first)

    let other = inboxes.orderedRows[2].id
    model.select(other)
    inboxes.refresh()
    await inboxes.waitForScan()
    await model.selectFirstFileAfterInitialScan()
    #expect(model.sidebarSelection == .item(other))
  }

  @Test("A selection made before the first listing finishes is kept")
  func keepsEarlierSelection() async throws {
    defer { environment.remove() }
    let initialSelection = Task { await model.selectFirstFileAfterInitialScan() }
    inboxes.update(inboxes: folders.inboxes)
    let earlySelection = SidebarRowID.group(environment.webDownloads.appending(path: "Kurs"))
    model.sidebarSelection = earlySelection
    await inboxes.waitForScan()
    await initialSelection.value
    #expect(model.sidebarSelection == earlySelection)
  }

  @Test("With no files in the inboxes, nothing is selected")
  func emptyInboxesSelectNothing() async throws {
    defer { environment.remove() }
    try FileManager.default.removeItem(at: environment.webDownloads)
    try FileManager.default.removeItem(at: environment.scanner)
    for folder in [environment.webDownloads, environment.scanner] {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    let initialSelection = Task { await model.selectFirstFileAfterInitialScan() }
    await listInboxes()
    await initialSelection.value
    #expect(model.sidebarSelection == nil)
    #expect(model.file(.next) == nil)
  }
}
