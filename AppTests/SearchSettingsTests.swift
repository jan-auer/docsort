import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("SearchSettings")
struct SearchSettingsTests {
  @Test("Closer folders rank first by default, and a change is stored")
  func rankingIsStored() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }

    let settings = SearchSettings(defaults: environment.defaults)
    #expect(settings.ranking == .directChildFirst)

    settings.ranking = .exactNameFirst
    #expect(
      try SearchSettings.rankingPreference(in: environment.defaults).load() == .exactNameFirst)
    #expect(SearchSettings(defaults: environment.defaults).ranking == .exactNameFirst)
  }

  @Test("An unreadable stored ranking falls back to the default")
  func unreadableRankingFallsBack() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    environment.defaults.set("closest", forKey: "searchRanking")

    #expect(SearchSettings(defaults: environment.defaults).ranking == .directChildFirst)
  }
}
