import Foundation
import Testing

@testable import DocsortCore

/// Ranking regression over an invented archive (`Fixtures/destination-corpus.txt`).
///
/// The archive belongs to an invented couple renting a flat in an invented town, with a pottery workshop on the side,
/// a sailing club, bees, a dog and a godchild: about 500 folders up to seven levels deep, German names, dated, year and
/// quarter folders, numbered places, `! Inaktiv`. Every name and date in it is made up. The query shapes are
/// docsort-cli's: the intended folder of each regression query must stay first; short prefixes and fragments, where
/// fuzzy matching alone is weakest, must reach the top 3. Some fixture paths are stored decomposed (NFD).
@Suite("Destination ranking")
struct DestinationRankingTests {
  static let matcher = DestinationMatcher(paths: fixtureCorpus())

  @Test(
    "the intended folder ranks first",
    arguments: [
      // A category folder starting with the word above a dated folder with a word starting with it.
      ("imk", "Hobbys/Imkerei"),
      ("imker", "Hobbys/Imkerei"),
      // A folder named exactly like the word above folders whose names add a suffix.
      ("fahrrad", "Mobilität/Fahrrad"),
      ("tierhalter", "Versicherungen/Tierhalter"),
      // The last segment's prefix.
      ("elek", "Rechnungen/Elektronik"),
      ("jahresnetz", "Mobilität/Jahresnetzkarte"),
      ("tierarztp", "Hund/Tierarztpraxis Moosleitner"),
      ("laufz", "Abos/Zeitschrift Drehscheibe/Laufzeit"),
      // Two words, in either order.
      ("hund rech", "Hund/Rechnungen"),
      ("rech hund", "Hund/Rechnungen"),
      ("auto insp", "Auto/Kleinwagen Grünspecht/Inspektionen"),
      ("insp auto", "Auto/Kleinwagen Grünspecht/Inspektionen"),
      ("rechnungen geschenke", "Rechnungen/Geschenke"),
      // A parent's and a child's initials.
      ("imk volk", "Hobbys/Imkerei/Völker"),
      ("mara fortb", "Beruf/Mara/Fortbildungen"),
      ("segeln torn", "Hobbys/Segeln/Törns"),
      ("wohn hald", "Wohnung/Haldenbrück"),
      ("hald kaution", "Wohnung/Haldenbrück/Kaution"),
      ("fichtenzell kaution", "Wohnung/! Inaktiv/Fichtenzell/Kaution"),
      ("seeschwalbe liege", "Mitgliedschaften/2. Segelclub Seeschwalbe/Liegeplatz"),
      (
        "hutte skarv",
        "Reisen/2037/2037-09-22 Zugreise Polarlicht-Express/Unterkünfte/Hütte Skarvlia"
      ),
      // A topic-and-year folder and its child.
      ("bad 2037", "Wohnung/Umbauten/Bad 2037"),
      ("bad angeb", "Wohnung/Umbauten/Bad 2037/Angebote"),
      // Years and digits.
      ("honig 2036", "Hobbys/Imkerei/Honigernte/2036"),
      ("kontoausz 2036", "Finanzen/Bank/Kontoauszüge/2036"),
      ("vorschr 2037", "Wohnung/Haldenbrück/Vorschreibungen/2037"),
      ("monatsabr 2035", "Beruf/Tobias/Dienstgeber Kranwerk Ostler/Monatsabrechnungen/2035"),
      ("gehaltsz 2038", "Beruf/Mara/Dienstgeber Übersetzungsbüro Wortbrücke/Gehaltszettel/2038"),
      ("1. imkerverein", "Mitgliedschaften/1. Imkerverein Haldenbrück"),
      ("32q2", "Finanzen/Bank/Kontoauszüge/2032/2032-Q2"),
      ("36q2", "Finanzen/Bank/Kontoauszüge/2036/2036-Q2"),
      ("2034q3", "Finanzen/Bank/Kontoauszüge/2034/2034-Q3"),
      ("ba37", "Wohnung/Umbauten/Bad 2037"),
      // A fragment from the middle of a word, and scattered letters.
      ("radwerk", "Mobilität/Angebote/Fahrradwerkstatt Kettenblatt"),
      ("lichtexp", "Reisen/2037/2037-09-22 Zugreise Polarlicht-Express"),
      ("fpfl", "Gesundheit/Fußpflege"),
      // A separator in the query.
      ("hund/rech", "Hund/Rechnungen"),
      // Umlauts typed plainly, as the letter, or transliterated; some of these paths are decomposed (NFD).
      ("kundigung", "Verträge/Kündigungen"),
      ("kuendigung", "Verträge/Kündigungen"),
      ("aerzte", "Gesundheit/Ärzte"),
      ("toepferei", "Töpferei"),
      ("fusspflege", "Gesundheit/Fußpflege"),
      ("maengel", "Wohnung/Haldenbrück/Mängel"),
      ("uebersiedl", "Wohnung/Übersiedlung 2035"),
      ("kontoauszuge", "Finanzen/Bank/Kontoauszüge"),
      // A word with a real `ue`, and one with a real `ue` and a typed `oe` for `ö`.
      ("feuerl", "Wohnung/Feuerlöscher"),
      ("feuerloescher", "Wohnung/Feuerlöscher"),
      // A trailing space.
      ("hund rech ", "Hund/Rechnungen"),
      ("rechnungen ", "Rechnungen"),
      // A whole name that is also the start of a longer one.
      ("glasur", "Töpferei/Werkstoffe/Glasur"),
    ])
  func ranksFirst(query: String, expected: String) {
    #expect(paths(Self.matcher.matches(for: query, limit: 3)).first == expected)
  }

  @Test(
    "the intended folder ranks in the top 3 for short prefixes and fragments",
    arguments: [
      ("pol", "Versicherungen/Polizzen"),
      ("ver", "Verträge"),
      ("imk", "Mitgliedschaften/1. Imkerverein Haldenbrück"),
      ("huette", "Reisen/2037/2037-09-22 Zugreise Polarlicht-Express/Unterkünfte/Hütte Skarvlia"),
      ("schwalbe", "Mitgliedschaften/2. Segelclub Seeschwalbe"),
    ])
  func ranksInTopThree(query: String, expected: String) {
    #expect(paths(Self.matcher.matches(for: query, limit: 3)).contains(expected))
  }

  // Without ``DestinationMatcher/depthPenalty`` the deeper folder of each pair ranks first. A deeper folder with the
  // same name as the closer one never does: FuzzyMatch gives the start of the scope-relative path the strongest
  // boundary bonus, so it can at best tie, and equal scores already order fewer segments first. For the same reason
  // `segeln` inside `Hobbys` does not depend on the penalty (see `directChildAboveDeeperNamesake`); the numbered
  // variant here does.
  @Test(
    "a folder closer to the scope ranks above a deeper one that FuzzyMatch and the segment bonus prefer",
    arguments: [
      // A top-level folder starting with the word above a deeper folder named exactly like it.
      ("", "hobby", "Hobbys"),
      ("", "mitgliedschaft", "Mitgliedschaften"),
      // A numbered direct child of the scope above `<child>/Chronik/<name> Archiv`, whose last segment starts with
      // the word where the child's name does not.
      ("Mitgliedschaften", "segelclub", "Mitgliedschaften/2. Segelclub Seeschwalbe"),
    ])
  func ranksCloserToScopeFirst(scope: String, query: String, expected: String) {
    #expect(paths(Self.matcher.matches(for: query, in: scope, limit: 3)).first == expected)
  }

  @Test("a direct child named like the word ranks above a deeper folder of the same name")
  func directChildAboveDeeperNamesake() {
    let matches = Self.matcher.matches(for: "segeln", in: "Hobbys", limit: 3)

    #expect(paths(matches).first == "Hobbys/Segeln")
    #expect(paths(matches).contains("Hobbys/Segeln/Törns/Segeln Logbuch"))
  }

  @Test(
    "the highlight of a deeper match marks the segment closest to the scope",
    arguments: [
      (
        "Hobbys", "segeln", "Hobbys/Segeln/Törns/Segeln Logbuch", "Segeln/Törns/Segeln Logbuch",
        0..<6
      ),
      (
        "Mitgliedschaften", "segelclub",
        "Mitgliedschaften/2. Segelclub Seeschwalbe/Chronik/Segelclub Seeschwalbe Archiv",
        "2. Segelclub Seeschwalbe/Chronik/Segelclub Seeschwalbe Archiv", 3..<12
      ),
    ])
  func highlightsSegmentClosestToScope(
    scope: String, query: String, path: String, pathInScope: String, highlight: Range<Int>
  ) throws {
    let match = try #require(Self.matcher.matches(for: query, in: scope).first { $0.path == path })

    #expect(match.pathInScope == pathInScope)
    #expect(highlightedOffsets(match) == [highlight])
  }

  @Test(
    "each scoped ranking puts the expected folder first for `glasur`",
    arguments: [
      ("", ScopedRanking.directChildFirst, "Töpferei/Werkstoffe/Glasur"),
      ("", ScopedRanking.exactNameFirst, "Töpferei/Werkstoffe/Glasur"),
      ("Töpferei", ScopedRanking.directChildFirst, "Töpferei/Glasurrezepte"),
      ("Töpferei", ScopedRanking.exactNameFirst, "Töpferei/Werkstoffe/Glasur"),
    ])
  func glasurPerScopedRanking(scope: String, ranking: ScopedRanking, expected: String) {
    let matches = Self.matcher.matches(for: "glasur", in: scope, ranking: ranking, limit: 3)

    #expect(paths(matches).first == expected)
  }

  @Test("a search over the whole fixture archive takes well under 10 ms in a release build")
  func searchIsFast() {
    let queries = ["e", "rech", "hund rech", "bad angeb", "honig 2036", "kuendigung"]
    let matcher = Self.matcher
    let clock = ContinuousClock()

    let elapsed = clock.measure {
      for query in queries {
        _ = matcher.matches(for: query)
      }
    }

    // A release build takes well under 1 ms per query here. Debug builds run the matcher and FuzzyMatch
    // unoptimised, tens of times slower, so their bound only catches an accidental quadratic or a per-query
    // preparation of the whole corpus.
    #if DEBUG
      let bound = Duration.milliseconds(250)
    #else
      let bound = Duration.milliseconds(10)
    #endif
    #expect(elapsed / queries.count < bound)
  }
}

/// The fixture archive's folder paths, in the order the index holds them: parents before children, siblings in
/// Finder name order.
func fixtureCorpus() -> [String] {
  guard
    let url = Bundle.module.url(forResource: "destination-corpus", withExtension: "txt"),
    let text = try? String(contentsOf: url, encoding: .utf8)
  else {
    Issue.record("The fixture destination-corpus.txt is missing from the test bundle.")
    return []
  }
  return text.split(separator: "\n").map(String.init).sorted { lhs, rhs in
    let lhsSegments = lhs.split(separator: "/")
    let rhsSegments = rhs.split(separator: "/")
    for (lhsSegment, rhsSegment) in zip(lhsSegments, rhsSegments) where lhsSegment != rhsSegment {
      return lhsSegment.localizedStandardCompare(rhsSegment) == .orderedAscending
    }
    return lhsSegments.count < rhsSegments.count
  }
}
