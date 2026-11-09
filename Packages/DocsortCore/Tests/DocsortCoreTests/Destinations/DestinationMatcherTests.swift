import Foundation
import Testing

@testable import DocsortCore

@Suite("DestinationMatcher")
struct DestinationMatcherTests {
  @Test("an empty or whitespace query matches nothing")
  func emptyQueryMatchesNothing() {
    let matcher = DestinationMatcher(paths: ["Rechnungen", "Hund"])

    #expect(matcher.matches(for: "").isEmpty)
    #expect(matcher.matches(for: "  \t ").isEmpty)
  }

  @Test("matches case- and diacritic-insensitively, as a subsequence")
  func matchesFuzzily() {
    let matcher = DestinationMatcher(paths: ["Kündigungen", "Rechnungen", "Auto"])

    #expect(paths(matcher.matches(for: "KUNDIG")) == ["Kündigungen"])
    #expect(paths(matcher.matches(for: "rchng")) == ["Rechnungen"])
  }

  @Test("a trailing or leading space does not change the result")
  func trimsTheQuery() {
    let matcher = DestinationMatcher(paths: [
      "Rechnungen", "Hund/Rechnungen", "Wohnung/Rechnungen/2033-09 Hängematte Faulpelz",
    ])

    #expect(matcher.matches(for: "rechnungen ") == matcher.matches(for: "rechnungen"))
    #expect(matcher.matches(for: " rechnungen") == matcher.matches(for: "rechnungen"))
    #expect(matcher.matches(for: "rechnungen ").first?.path == "Rechnungen")
  }

  @Test("query words match in any order and all must match")
  func multiWordAnyOrder() {
    let matcher = DestinationMatcher(paths: ["Hund/Rechnungen", "Hund/Rassestandard", "Rechnungen"])

    #expect(matcher.matches(for: "rechnungen hund").first?.path == "Hund/Rechnungen")
    #expect(matcher.matches(for: "hund rech").first?.path == "Hund/Rechnungen")
    #expect(!paths(matcher.matches(for: "hund rech")).contains("Hund/Rassestandard"))
  }

  @Test("a word matching a whole segment ranks that folder above longer names containing it")
  func wholeSegmentRanksFirst() {
    let matcher = DestinationMatcher(paths: [
      "Hobbys/Bienen",
      "Rechnungen/2035-04-09 Bienenhaus Summer",
      "Hobbys/Imkerei/Völker/2036 Ableger/Bienenwachs Tausch Wabenhof",
    ])

    #expect(matcher.matches(for: "bienen").first?.path == "Hobbys/Bienen")
  }

  @Test("a segment that starts with the word ranks above a word start inside a dated name")
  func segmentPrefixRanksFirst() {
    let matcher = DestinationMatcher(paths: [
      "Wohnung/Umbauten/Rechnungen/2032-03-08 Glaserei Splitterfrei Spiegel",
      "Töpferei/Glasurrezepte",
      "Wohnung/Umbauten/Flur/Glasbausteine",
    ])

    #expect(matcher.matches(for: "glas").first?.path == "Töpferei/Glasurrezepte")
  }

  @Test("a match in the last segment ranks above the same match in a parent")
  func lastSegmentRanksAboveParentMatch() {
    let matcher = DestinationMatcher(paths: ["Imkerei/Angebote", "Hobbys/Imkerei"])

    #expect(matcher.matches(for: "imkerei").first?.path == "Hobbys/Imkerei")
  }

  @Test("equal scores order fewer segments first, then the given (Finder) order")
  func tiesByDepthThenGivenOrder() {
    let matcher = DestinationMatcher(paths: [
      "Umbauten/Balkon",
      "Umbauten/Balkon/Angebote",
      "Umbauten/Balkon/Bilder",
      "Umbauten/Balkon/Rechnungen",
    ])

    #expect(
      paths(matcher.matches(for: "umbauten balkon")) == [
        "Umbauten/Balkon", "Umbauten/Balkon/Angebote", "Umbauten/Balkon/Bilder",
        "Umbauten/Balkon/Rechnungen",
      ])
  }

  @Test("letters scattered one by one over a path are not a match")
  func scatteredLettersAreNoMatch() {
    let matcher = DestinationMatcher(paths: [
      "Ahnenforschung/Stammbaum/Druckfassung",
      "Hobbys/Imkerei/Völker/2034-09-15 Ableger Stand Föhrenhang",
      "Mobilität/Jahresnetzkarte/2036-10-24 Verlängerung",
    ])

    #expect(matcher.matches(for: "asdf").isEmpty)
    #expect(matcher.matches(for: "jkl").isEmpty)
  }

  @Test("letters in at most half as many runs as the query is long still match")
  func shortRunsStillMatch() {
    let matcher = DestinationMatcher(paths: [
      "Gesundheit/Fußpflege", "Wohnung/Umbauten/Bad 2037",
      "Finanzen/Bank/Kontoauszüge/2032/2032-Q2",
      "Rechnungen",
    ])

    #expect(paths(matcher.matches(for: "fpfl")) == ["Gesundheit/Fußpflege"])
    #expect(paths(matcher.matches(for: "ba37")) == ["Wohnung/Umbauten/Bad 2037"])
    #expect(paths(matcher.matches(for: "32q2")).first == "Finanzen/Bank/Kontoauszüge/2032/2032-Q2")
    #expect(paths(matcher.matches(for: "rchng")) == ["Rechnungen"])
  }

  @Test("returns at most `limit` matches")
  func respectsLimit() {
    let matcher = DestinationMatcher(paths: (1...30).map { "Rechnungen/\($0)" })

    #expect(matcher.matches(for: "rech", limit: 5).count == 5)
    #expect(matcher.matches(for: "rech", limit: 0).isEmpty)
  }

  @Test("matched ranges cover the matched characters")
  func matchedRangesCoverMatchedCharacters() throws {
    let matcher = DestinationMatcher(paths: ["Kündigungen"])

    let match = try #require(matcher.matches(for: "kundig").first)

    #expect(highlighted(match) == ["Kündig"])
  }

  @Test("matched ranges index into a decomposed (NFD) path")
  func matchedRangesInDecomposedPath() throws {
    let decomposed = "Ku\u{0308}ndigungen"
    let matcher = DestinationMatcher(paths: [decomposed])

    let match = try #require(matcher.matches(for: "kundig").first)

    #expect(match.path.unicodeScalars.elementsEqual(decomposed.unicodeScalars))
    #expect(highlighted(match) == ["Kündig"])
  }

  @Test("matched ranges cover every query word")
  func matchedRangesForSeveralWords() throws {
    let matcher = DestinationMatcher(paths: ["Hund/Rechnungen"])

    let match = try #require(matcher.matches(for: "rech hund").first)

    #expect(highlighted(match) == ["Hund", "Rech"])
  }

  @Test(
    "ue, ae, oe and ss typed for ü, ä, ö and ß still match",
    arguments: [
      ("kuendigung", "Kündigungen"),
      ("aerzte", "Gesundheit/Ärzte"),
      ("toepferei", "Töpferei"),
      ("fusspflege", "Gesundheit/Fußpflege"),
      ("grussk", "Rechnungen/Grußkarten"),
    ])
  func transliteratedUmlauts(query: String, expected: String) {
    let matcher = DestinationMatcher(paths: [
      "Gesundheit/Fußpflege", "Gesundheit/Ärzte", "Kündigungen", "Rechnungen/Grußkarten",
      "Töpferei",
      "Wohnung/Feuerlöscher",
    ])

    #expect(matcher.matches(for: query).first?.path == expected)
  }

  @Test("words that really contain ue or ss still match as typed")
  func literalUeStillMatches() {
    let matcher = DestinationMatcher(paths: [
      "Reisen/Abenteuer", "Reisen/Abenteuerspielplätze", "Kündigungen", "Reisen/Reisepässe",
    ])

    #expect(matcher.matches(for: "abenteuer").first?.path == "Reisen/Abenteuer")
    #expect(matcher.matches(for: "abenteuersp").first?.path == "Reisen/Abenteuerspielplätze")
    #expect(matcher.matches(for: "reisepaesse").first?.path == "Reisen/Reisepässe")
  }

  @Test("each word is transliterated on its own")
  func transliterationPerWord() {
    let matcher = DestinationMatcher(paths: [
      "Reisen/Abenteuer/Hütten", "Reisen/Abenteuer", "Rechnungen/Hütten",
    ])

    #expect(matcher.matches(for: "abenteuer huetten").first?.path == "Reisen/Abenteuer/Hütten")
  }

  @Test("matched ranges of a transliterated query cover the umlaut")
  func transliteratedRanges() throws {
    let matcher = DestinationMatcher(paths: ["Kündigungen"])

    let match = try #require(matcher.matches(for: "kuendig").first)

    #expect(highlighted(match) == ["Kündig"])
  }

  @Test("recent destinations move up, the most recent furthest")
  func recentsReorderMatches() {
    let matcher = DestinationMatcher(paths: [
      "Rechnungen", "Hund/Rechnungen", "Töpferei/Rechnungen", "Auto",
    ])
    let recents = RecentDestinations(paths: ["Töpferei/Rechnungen", "Hund/Rechnungen"])

    let withoutRecents = paths(matcher.matches(for: "rechnungen"))
    let withRecents = paths(matcher.matches(for: "rechnungen", recents: recents))

    #expect(withoutRecents.first == "Rechnungen")
    #expect(withRecents.prefix(2) == ["Töpferei/Rechnungen", "Hund/Rechnungen"])
    #expect(Set(withRecents) == Set(withoutRecents))
  }

  @Test("a recent destination that does not match the query is not added")
  func recentsAddNoMatches() {
    let matcher = DestinationMatcher(paths: ["Rechnungen", "Auto", "Hund"])
    let recents = RecentDestinations(paths: ["Auto", "Hund"])

    #expect(paths(matcher.matches(for: "rech", recents: recents)) == ["Rechnungen"])
  }

  @Test("recent destinations are found whatever their Unicode normalisation")
  func recentsAreNormalisationInsensitive() {
    let matcher = DestinationMatcher(paths: ["A/Märkte", "B/Märkte"])
    let recents = RecentDestinations(paths: ["B/Ma\u{0308}rkte"])

    #expect(matcher.matches(for: "markte", recents: recents).first?.path == "B/Märkte")
  }

  // MARK: Scope

  @Test("a scoped search finds only the scope's descendants, not the scope or its name-alikes")
  func scopeLimitsToDescendants() {
    let matcher = DestinationMatcher(paths: [
      "Hund", "Hund/Rechnungen", "Hund/Training/Rechnungen", "Hundehütte/Rechnungen", "Rechnungen",
    ])

    #expect(
      paths(matcher.matches(for: "rech", in: "Hund")) == [
        "Hund/Rechnungen", "Hund/Training/Rechnungen",
      ])
  }

  @Test("the scope's own name never matches query letters")
  func scopeNameDoesNotMatch() {
    let matcher = DestinationMatcher(paths: ["Hund", "Hund/Leinen", "Hund/Hundesitter"])

    #expect(paths(matcher.matches(for: "hund", in: "Hund")) == ["Hund/Hundesitter"])
    #expect(matcher.matches(for: "hund leinen", in: "Hund").isEmpty)
  }

  @Test("a scoped match carries the path relative to the scope, and its ranges index into it")
  func scopedMatchIsRelative() throws {
    let matcher = DestinationMatcher(paths: ["Hund/Training/Rechnungen"])

    let match = try #require(matcher.matches(for: "train rech", in: "Hund").first)

    #expect(match.path == "Hund/Training/Rechnungen")
    #expect(match.pathInScope == "Training/Rechnungen")
    #expect(highlighted(match) == ["Train", "Rech"])
    #expect(highlightedOffsets(match) == [0..<5, 9..<13])
  }

  @Test("the root scope is the default, searches the whole archive and keeps paths whole")
  func rootScopeIsDefault() throws {
    let matcher = DestinationMatcher(paths: ["Rechnungen", "Hund/Rechnungen"])

    #expect(matcher.matches(for: "rech") == matcher.matches(for: "rech", in: ""))
    let match = try #require(matcher.matches(for: "hund rech").first)
    #expect(match.pathInScope == "Hund/Rechnungen")
    #expect(highlighted(match) == ["Hund", "Rech"])
  }

  @Test("a scope over decomposed (NFD) paths, given in either normalisation")
  func scopeOverDecomposedPaths() throws {
    let matcher = DestinationMatcher(paths: [
      "To\u{0308}pferei/Lieferanten", "To\u{0308}pferei/Ku\u{0308}ndigungen",
      "Topferei/Kündigungen",
    ])

    for scope in ["T\u{00F6}pferei", "To\u{0308}pferei"] {
      let matches = matcher.matches(for: "kundig", in: scope)
      let match = try #require(matches.first)
      #expect(matches.count == 1)
      #expect(
        match.path.unicodeScalars.elementsEqual(
          "To\u{0308}pferei/Ku\u{0308}ndigungen".unicodeScalars))
      #expect(match.pathInScope.unicodeScalars.elementsEqual("Ku\u{0308}ndigungen".unicodeScalars))
      #expect(highlighted(match) == ["Kündig"])
    }
  }

  @Test("recent destinations under a scope are boosted by their archive-relative path")
  func recentsUnderScope() {
    let matcher = DestinationMatcher(paths: [
      "Hund/Rechnungen", "Hund/Training/Rechnungen", "Rechnungen",
    ])
    let recents = RecentDestinations(paths: ["Rechnungen", "Hund/Training/Rechnungen"])

    #expect(
      paths(matcher.matches(for: "rech", in: "Hund", recents: recents)) == [
        "Hund/Training/Rechnungen", "Hund/Rechnungen",
      ])
  }

  // MARK: Closer to the scope first

  @Test(
    "a top-level folder starting with the word ranks above a deeper folder named exactly like it")
  func topLevelAboveDeeperExactName() {
    let matcher = DestinationMatcher(paths: [
      "Hobbys", "Wohnung", "Wohnung/Keller", "Wohnung/Keller/Hobby",
    ])

    // Without the depth penalty, the deeper folder's whole-segment bonus would put it first.
    #expect(paths(matcher.matches(for: "hobby")) == ["Hobbys", "Wohnung/Keller/Hobby"])
  }

  @Test(
    "a direct child of the scope ranks above `<child>/Chronik/<name> Archiv`",
    arguments: ["Ruderverein Haubentaucher", "3. Ruderverein Haubentaucher"])
  func directChildAboveDeeperNamesake(child: String) {
    let matcher = DestinationMatcher(paths: [
      "Mitgliedschaften", "Mitgliedschaften/\(child)", "Mitgliedschaften/\(child)/Chronik",
      "Mitgliedschaften/\(child)/Chronik/Ruderverein Haubentaucher Archiv",
    ])

    let matches = matcher.matches(for: "ruderverein", in: "Mitgliedschaften")

    #expect(paths(matches).first == "Mitgliedschaften/\(child)")
    #expect(
      paths(matches).contains(
        "Mitgliedschaften/\(child)/Chronik/Ruderverein Haubentaucher Archiv"))
  }

  // MARK: Scoped ranking

  @Test(
    "by default a direct child starting with the word ranks above a deeper folder named exactly like it"
  )
  func directChildFirstIsTheDefault() {
    let matcher = DestinationMatcher(paths: [
      "Töpferei", "Töpferei/Werkstoffe", "Töpferei/Werkstoffe/Glasur", "Töpferei/Glasurrezepte",
    ])

    let matches = matcher.matches(for: "glasur", in: "Töpferei")

    #expect(paths(matches).first == "Töpferei/Glasurrezepte")
    #expect(matches == matcher.matches(for: "glasur", in: "Töpferei", ranking: .directChildFirst))
  }

  @Test(
    "exact name first ranks a folder named like the word above a closer folder only starting with it"
  )
  func exactNameFirstOutweighsOneLevel() {
    let matcher = DestinationMatcher(paths: [
      "Töpferei", "Töpferei/Werkstoffe", "Töpferei/Werkstoffe/Glasur", "Töpferei/Glasurrezepte",
    ])

    #expect(
      paths(matcher.matches(for: "glasur", in: "Töpferei", ranking: .exactNameFirst)) == [
        "Töpferei/Werkstoffe/Glasur", "Töpferei/Glasurrezepte",
      ])
  }

  @Test("exact name first does not outweigh two levels")
  func exactNameFirstDoesNotOutweighTwoLevels() {
    let matcher = DestinationMatcher(paths: [
      "Hobbys", "Wohnung", "Wohnung/Keller", "Wohnung/Keller/Hobby",
    ])

    #expect(
      paths(matcher.matches(for: "hobby", ranking: .exactNameFirst)) == [
        "Hobbys", "Wohnung/Keller/Hobby",
      ])
  }

  @Test(
    "exact name first adds its bonus once, where the folder's own name, folded, equals a query word"
  )
  func exactNameFirstComparesOwnName() throws {
    let matcher = DestinationMatcher(paths: [
      "Töpferei/Ma\u{0308}rkte", "Töpferei/Ma\u{0308}rkte/2038", "Töpferei/Märktekalender",
    ])
    func extraScore(of path: String) throws -> Double {
      let exactNameFirst = try #require(
        matcher.matches(for: "topf markte", ranking: .exactNameFirst).first { $0.path == path })
      let directChildFirst = try #require(
        matcher.matches(for: "topf markte", ranking: .directChildFirst).first { $0.path == path })
      return exactNameFirst.score - directChildFirst.score
    }

    #expect(abs(try extraScore(of: "Töpferei/Märkte") - SegmentBonus.exactName) < 1e-9)
    #expect(abs(try extraScore(of: "Töpferei/Märkte/2038")) < 1e-9)
    #expect(abs(try extraScore(of: "Töpferei/Märktekalender")) < 1e-9)
  }

  // MARK: Highlight preference

  @Test("a word matching at a segment's start highlights the shallowest such segment")
  func highlightPrefersShallowestSegmentStart() throws {
    let matcher = DestinationMatcher(paths: ["Wohnung/Rechnungen/Glaserei Rechberger"])

    let match = try #require(matcher.matches(for: "rech glas").first)

    #expect(highlightedOffsets(match) == [8..<12, 19..<23])
  }

  @Test("a word matching after a sort number highlights the first such segment")
  func highlightPrefersFirstWordStart() throws {
    let matcher = DestinationMatcher(paths: [
      "Mitgliedschaften/3. Ruderverein Haubentaucher/Chronik/Ruderverein Haubentaucher Archiv"
    ])

    let match = try #require(
      matcher.matches(for: "ruderverein arch", in: "Mitgliedschaften").first)

    #expect(
      match.pathInScope
        == "3. Ruderverein Haubentaucher/Chronik/Ruderverein Haubentaucher Archiv")
    #expect(highlightedOffsets(match) == [3..<14, 63..<67])
  }

  @Test("the preferred highlight compares case- and diacritic-folded, in decomposed paths")
  func highlightPreferenceIsFolded() throws {
    let matcher = DestinationMatcher(paths: [
      "To\u{0308}pferei/U\u{0308}berzu\u{0308}ge/Alte U\u{0308}berzu\u{0308}ge"
    ])

    let match = try #require(matcher.matches(for: "UBERZ", in: "Töpferei").first)

    #expect(highlightedOffsets(match) == [0..<5])
    #expect(highlighted(match) == ["Überz"])
  }

  @Test("a word matching no segment or word start keeps FuzzyMatch's highlight")
  func highlightFallsBackToFuzzyMatch() throws {
    let matcher = DestinationMatcher(paths: ["Rechnungen"])

    let match = try #require(matcher.matches(for: "rchng").first)

    #expect(highlighted(match).joined() == "Rchng")
  }

  // MARK: Outside a folder

  @Test(
    "a search outside a folder leaves out the folder and its subtree and keeps the other matches in order",
    arguments: ["rech", "hund", "imk volk", "kontoauszuege", "s", "2036"])
  func outsideLeavesOutTheSubtree(query: String) {
    let matcher = DestinationRankingTests.matcher
    for excluded in ["Hund", "Hobbys/Imkerei", "Finanzen/Bank/Kontoauszu\u{0308}ge"] {
      let everywhere = matcher.matches(for: query, limit: .max)
      let expected = everywhere.filter { match in
        match.path.precomposedStringWithCanonicalMapping
          != excluded.precomposedStringWithCanonicalMapping
          && !match.path.precomposedStringWithCanonicalMapping.hasPrefix(
            excluded.precomposedStringWithCanonicalMapping + "/")
      }

      #expect(
        matcher.matches(for: query, outside: excluded, limit: 20) == Array(expected.prefix(20)),
        "\(query) outside \(excluded)")
    }
  }

  @Test("a search inside a scope can leave out a folder in it")
  func outsideInsideAScope() {
    let matcher = DestinationMatcher(paths: [
      "Hund", "Hund/Rechnungen", "Hund/Tierarzt", "Hund/Tierarzt/Rechnungen", "Rechnungen",
    ])

    #expect(
      paths(matcher.matches(for: "rech", in: "Hund", outside: "Hund/Tierarzt")) == [
        "Hund/Rechnungen"
      ])
  }

  // MARK: One folder

  @Test(
    "a folder matches a query exactly when a search from the root without a limit lists it",
    arguments: ["rech", "hund", "imk volk", "kontoauszuege", "s", "2036", "asdf", "rchng"])
  func folderMatchesLikeASearch(query: String) {
    let matcher = DestinationRankingTests.matcher
    let listed = Set(paths(matcher.matches(for: query, limit: .max)))
    for folder in fixtureCorpus() {
      #expect(
        matcher.matches(query, folder: folder) == listed.contains(folder), "\(query) in \(folder)")
    }
  }

  @Test("the root and a folder that is not a candidate match nothing")
  func folderMatchOutsideTheCandidates() {
    let matcher = DestinationMatcher(paths: ["Hund", "Hund/Rechnungen"])

    #expect(matcher.matches("hund", folder: "Hund"))
    #expect(!matcher.matches("hund", folder: ""))
    #expect(!matcher.matches("katze", folder: "Katze"))
    #expect(!matcher.matches("  ", folder: "Hund"))
  }
}

/// The paths of `matches`, in order.
func paths(_ matches: [DestinationMatch]) -> [String] {
  matches.map(\.path)
}

/// The substrings of the match's scope-relative path that its ranges cover.
func highlighted(_ match: DestinationMatch) -> [String] {
  match.matchedRanges.map { String(match.pathInScope[$0]) }
}

/// The match's ranges as character offsets into its scope-relative path.
func highlightedOffsets(_ match: DestinationMatch) -> [Range<Int>] {
  let text = match.pathInScope
  return match.matchedRanges.map { range in
    text.distance(
      from: text.startIndex, to: range.lowerBound)..<text.distance(
        from: text.startIndex, to: range.upperBound)
  }
}
