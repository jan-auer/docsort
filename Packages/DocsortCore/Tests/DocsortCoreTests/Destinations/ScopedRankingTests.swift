import Foundation
import Testing

@testable import DocsortCore

@Suite("ScopedRanking")
struct ScopedRankingTests {
  @Test("stores as a stable string, so a saved setting survives renaming the cases in code")
  func rawValuesAreStable() {
    #expect(ScopedRanking.directChildFirst.rawValue == "directChildFirst")
    #expect(ScopedRanking.exactNameFirst.rawValue == "exactNameFirst")
    #expect(ScopedRanking(rawValue: "exactNameFirst") == .exactNameFirst)
    #expect(ScopedRanking(rawValue: "unknown") == nil)
  }

  @Test("round-trips through JSON as its raw value", arguments: ScopedRanking.allCases)
  func codableRoundTrip(ranking: ScopedRanking) throws {
    let encoded = try JSONEncoder().encode([ranking])
    #expect(String(decoding: encoded, as: UTF8.self) == "[\"\(ranking.rawValue)\"]")
    #expect(try JSONDecoder().decode([ScopedRanking].self, from: encoded) == [ranking])
  }
}
