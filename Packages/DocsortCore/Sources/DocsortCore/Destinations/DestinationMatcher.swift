import Foundation
import FuzzyMatch

/// A destination folder that matches a search query.
public struct DestinationMatch: Hashable, Sendable {
  /// The folder's archive-relative path, exactly as the index (or matcher) holds it: the path to file into.
  public let path: String
  /// The folder's path relative to the search scope, as the picker shows it: ``path`` without the scope's segments.
  /// Equal to ``path`` for a search from the archive root.
  public let pathInScope: String
  /// How well the folder matches; higher is better. Only comparable between matches of the same search.
  public let score: Double
  /// The characters of ``pathInScope`` that the query matched, sorted and coalesced, for bold highlighting.
  public let matchedRanges: [Range<String.Index>]
}

/// Ranks folder paths against a search query within a scope, the way destination search shows them.
///
/// A search runs within a scope: an archive-relative folder path, `""` for the archive root. Only the scope's
/// descendants are candidates, never the scope itself, and matching, bonuses and highlighting all see the path relative
/// to the scope, so the scope's own name never matches query letters.
///
/// Matching is FuzzyMatch's Smith-Waterman mode (fzf-style subsequence matching; every space-separated word must
/// match, in any order; case- and diacritic-insensitive; NFC and NFD paths alike). On top of it:
/// - The query is trimmed, and `ue`/`ae`/`oe`/`ss` typed for `ü`/`ä`/`ö`/`ß` also match (see ``SearchQuery``).
/// - ``SegmentBonus``: a word equal to a whole path segment, a segment starting with a word, and a word occurring in
///   the last segment rank a folder higher, so `fahrrad` finds `Mobilität/Fahrrad` before
///   `Mobilität/Angebote/Fahrradwerkstatt Kettenblatt`.
/// - ``depthPenalty``: each segment a folder lies below the scope's direct children costs a little, so among matches of
///   comparable quality the folder closer to the scope comes first (`hobby` ranks `Hobbys` above
///   `Wohnung/Keller/Hobby`).
/// - ``ScopedRanking``: with ``ScopedRanking/exactNameFirst``, a folder whose own name equals a query word also earns
///   ``SegmentBonus/exactName``, which outweighs one level of ``depthPenalty`` but not two.
/// - Recent destinations that match are boosted, the most recent most; a recent folder that does not match is never
///   added.
/// - Equal scores order fewer path segments first, then the order the paths were given in (Finder order).
/// - Highlighting prefers the occurrence closest to the scope (see ``MatchHighlighter``).
/// - A match whose letters are scattered one by one over the path is dropped (see ``isScattered(_:spelling:)``).
struct DestinationMatcher: Sendable {
  /// The boost for the most recent destination; older ones get proportionally less, down to
  /// `recencyBoost / capacity` for the oldest place in the list.
  static let recencyBoost = 0.15
  /// The score subtracted for each segment a folder lies below the scope's direct children.
  ///
  /// One bonus step is ``SegmentBonus/segmentPrefix``, which is also ``SegmentBonus/wholeSegment`` minus
  /// ``SegmentBonus/segmentPrefix``. More than half a step: two levels down outweigh one step, so inside `Mitgliedschaften`
  /// the direct child `2. Segelclub Seeschwalbe` outranks `…/Chronik/Segelclub Seeschwalbe Archiv` for `segelclub`,
  /// whose last segment starts with the word where the child's name does not, and `hobby` ranks `Hobbys` above
  /// `Wohnung/Keller/Hobby`, which is named exactly like the word. Less than a step: one level down does not outweigh a whole-segment match over a
  /// prefix one at the same FuzzyMatch score, so `glasur` from the root still finds `Töpferei/Werkstoffe/Glasur` before
  /// `Töpferei/Glasurrezepte`. The ranking tests pass from 0.025 to just under 0.05; this sits in the middle.
  ///
  /// The penalty is not what ranks `Rechnungen` above a deeper folder of the same name such as
  /// `Hund/Rechnungen`: FuzzyMatch gives the start of the scope-relative path its strongest boundary bonus,
  /// so the deeper one can at best tie, and ties order fewer segments first.
  static let depthPenalty = 0.035

  /// A path prepared for matching.
  private struct Candidate: Sendable {
    /// The path as given, stored as contiguous UTF-8 so that scoring reads its bytes without converting it.
    let path: String
    /// The path's segments as given, to find the scope's descendants.
    let segments: [String]
    /// The path's segments, case- and diacritic-folded, for the segment bonus.
    let foldedSegments: [String]
  }

  /// A candidate inside the search scope, seen relative to the scope.
  private struct ScopedCandidate: Sendable {
    let candidateIndex: Int
    let pathInScope: String
    let foldedSegmentsInScope: ArraySlice<String>
  }

  /// The best score a scoped candidate reached over all spellings of the query.
  private struct Scored: Sendable {
    let scopedIndex: Int
    var score: Double
    var spellingIndex: Int
  }

  private let candidates: [Candidate]
  private let fuzzyMatcher = FuzzyMatcher(config: .smithWaterman)

  /// A matcher over `paths`, which are given in the order ties should keep (Finder order).
  init(paths: [String]) {
    candidates = paths.map { path in
      // Paths from Foundation (the index's NFC paths) are bridged strings; FuzzyMatch reads UTF-8 bytes, which a
      // bridged string would have to convert on every keystroke.
      var contiguousPath = path
      contiguousPath.makeContiguousUTF8()
      return Candidate(
        path: contiguousPath, segments: Self.segments(of: path),
        foldedSegments: SegmentBonus.foldedSegments(of: path))
    }
  }

  /// The descendants of `scope` matching `query`, best first, at most `limit` of them.
  ///
  /// `scope` is an archive-relative folder path in any Unicode normalisation, `""` for the archive root. With
  /// `excludedFolder` (in any normalisation), that folder and everything inside it are left out, whole segments
  /// compared; the other matches keep their scores and order. `""` stands for the root, so nothing is left to find. `ranking` decides whether a folder named exactly like a query word outweighs one level of depth. An empty
  /// or whitespace-only query matches nothing.
  func matches(
    for query: String, in scope: String = "", outside excludedFolder: String? = nil,
    ranking: ScopedRanking = .directChildFirst, recents: RecentDestinations = RecentDestinations(),
    limit: Int = 50
  ) -> [DestinationMatch] {
    guard limit > 0, let searchQuery = SearchQuery(query) else { return [] }

    let scoped = scopedCandidates(in: scope, outside: excludedFolder)
    // Each candidate is scored on its own, so chunks of them are scored concurrently. Each chunk prepares the query
    // itself: shared prepared queries would have their reference counts updated from every core at once, which costs
    // more than preparing them a few dozen times.
    var ranked = ParallelChunks.flatMap(
      scoped.indices, chunkSize: ParallelChunks.chunkSize(for: scoped.count, minimum: 1024)
    ) { chunk -> [Scored] in
      let spellings = PreparedSpellings(searchQuery, fuzzyMatcher: fuzzyMatcher)
      var buffer = fuzzyMatcher.makeBuffer()
      return chunk.compactMap { scopedIndex in
        let candidate = scoped[scopedIndex]
        guard
          let best = bestSpelling(
            for: candidate.pathInScope, segments: candidate.foldedSegmentsInScope,
            among: spellings, ranking: ranking, buffer: &buffer)
        else { return nil }
        return Scored(
          scopedIndex: scopedIndex, score: best.score, spellingIndex: best.spellingIndex)
      }
    }
    for index in ranked.indices {
      let levelsBelowChildren = scoped[ranked[index].scopedIndex].foldedSegmentsInScope.count - 1
      ranked[index].score -= Self.depthPenalty * Double(levelsBelowChildren)
    }
    applyRecencyBoost(recents, to: &ranked, scoped: scoped)
    ranked.sort { lhs, rhs in
      if lhs.score != rhs.score { return lhs.score > rhs.score }
      let lhsDepth = scoped[lhs.scopedIndex].foldedSegmentsInScope.count
      let rhsDepth = scoped[rhs.scopedIndex].foldedSegmentsInScope.count
      if lhsDepth != rhsDepth { return lhsDepth < rhsDepth }
      return lhs.scopedIndex < rhs.scopedIndex
    }

    // Highlighting tells scattered matches apart, so the best `limit` matches that are not scattered are found by
    // highlighting the ranked matches window by window (each window concurrently), until enough are found.
    let rankedMatches = ranked
    var matches: [DestinationMatch] = []
    var windowStart = 0
    var windowSize = limit
    while matches.count < limit, windowStart < ranked.count {
      let window = windowStart..<windowStart + min(windowSize, ranked.count - windowStart)
      let highlighted = ParallelChunks.flatMap(
        window, chunkSize: ParallelChunks.chunkSize(for: window.count, minimum: 8)
      ) { chunk in
        let highlighters = searchQuery.spellings.map { spelling in
          MatchHighlighter(spelling: spelling, fuzzyMatcher: fuzzyMatcher)
        }
        return chunk.map { rankedIndex -> DestinationMatch? in
          let best = rankedMatches[rankedIndex]
          let candidate = scoped[best.scopedIndex]
          guard
            let matchedRanges = Self.unscatteredRanges(
              in: candidate.pathInScope, highlighter: highlighters[best.spellingIndex],
              spelling: searchQuery.spellings[best.spellingIndex])
          else { return nil }
          return DestinationMatch(
            path: candidates[candidate.candidateIndex].path, pathInScope: candidate.pathInScope,
            score: best.score, matchedRanges: matchedRanges)
        }
      }
      matches += highlighted.compactMap(\.self).prefix(limit - matches.count)
      windowStart = window.upperBound
      windowSize = min(windowSize, ranked.count) * 2
    }
    return matches
  }

  /// Whether the folder at `path` (archive-relative, in any Unicode normalisation) matches `query` from the archive
  /// root: a search from the root without a limit would list it. `false` for a path that is not a candidate.
  func matches(_ query: String, folder path: String, ranking: ScopedRanking = .directChildFirst)
    -> Bool
  {
    let segments = Self.segments(of: path)
    guard !segments.isEmpty, let searchQuery = SearchQuery(query),
      let candidate = candidates.first(where: { $0.segments == segments })
    else { return false }
    var buffer = fuzzyMatcher.makeBuffer()
    guard
      let best = bestSpelling(
        for: candidate.path, segments: candidate.foldedSegments[...],
        among: PreparedSpellings(searchQuery, fuzzyMatcher: fuzzyMatcher), ranking: ranking,
        buffer: &buffer)
    else { return false }
    let spelling = searchQuery.spellings[best.spellingIndex]
    return Self.unscatteredRanges(
      in: candidate.path,
      highlighter: MatchHighlighter(spelling: spelling, fuzzyMatcher: fuzzyMatcher),
      spelling: spelling) != nil
  }

  /// The ranges of `path` to show bold for `spelling` (the spelling it matched best, highlighted by `highlighter`),
  /// or `nil` when the match is scattered and so no match at all (see ``isScattered(_:spelling:)``).
  private static func unscatteredRanges(
    in path: String, highlighter: MatchHighlighter, spelling: String
  ) -> [Range<String.Index>]? {
    let matchedRanges = highlighter.ranges(in: path)
    return isScattered(matchedRanges, spelling: spelling) ? nil : matchedRanges
  }

  /// A query's spellings prepared for scoring.
  private struct PreparedSpellings {
    /// Each spelling prepared for FuzzyMatch, in ``SearchQuery/spellings`` order.
    let queries: [FuzzyQuery]
    /// Each spelling's folded words, for the segment bonus.
    let words: [[String]]

    init(_ searchQuery: SearchQuery, fuzzyMatcher: FuzzyMatcher) {
      queries = searchQuery.spellings.map(fuzzyMatcher.prepare)
      words = searchQuery.spellings.map(SegmentBonus.foldedWords(of:))
    }
  }

  /// The best score `path` (seen relative to the scope, with folded `segments`) reaches over `spellings`, FuzzyMatch's
  /// score plus the segment bonus, and the first spelling reaching it; `nil` when no spelling matches.
  private func bestSpelling(
    for path: String, segments: ArraySlice<String>, among spellings: PreparedSpellings,
    ranking: ScopedRanking, buffer: inout ScoringBuffer
  ) -> (score: Double, spellingIndex: Int)? {
    var best: (score: Double, spellingIndex: Int)?
    for (spellingIndex, prepared) in spellings.queries.enumerated() {
      guard let match = score(path, against: prepared, buffer: &buffer) else { continue }
      let score =
        match.score
        + SegmentBonus.value(
          words: spellings.words[spellingIndex], segments: segments, ranking: ranking)
      if score > best?.score ?? -.infinity {
        best = (score, spellingIndex)
      }
    }
    return best
  }

  /// FuzzyMatch's match of `path` against `prepared`, read from the path's UTF-8 bytes where they are contiguous.
  private func score(_ path: String, against prepared: FuzzyQuery, buffer: inout ScoringBuffer)
    -> ScoredMatch?
  {
    let contiguousMatch = path.utf8.withContiguousStorageIfAvailable { bytes in
      fuzzyMatcher.score(utf8: bytes, against: prepared, buffer: &buffer)
    }
    if let contiguousMatch { return contiguousMatch }
    return fuzzyMatcher.score(path, against: prepared, buffer: &buffer)
  }

  /// Whether a match is noise: the query's letters land on the path in more separate runs than half the query's
  /// length (rounded up), so most of them stand alone. FuzzyMatch's score alone doesn't tell this apart: `asdf` scores
  /// 0.76 against `…/Ableger Stand Föhrenhang` (one letter per word), more than the intended `radwerk` against
  /// `…/Fahrradwerkstatt Kettenblatt` (0.71). Initials and fragments the user means come in few runs: `fpfl` finds
  /// `Fußpflege` in two (`F`, `pfl`), `ba37` finds `Bad 2037` in two, `rchng` finds `Rechnungen` in three.
  static func isScattered(_ matchedRanges: [Range<String.Index>], spelling: String) -> Bool {
    let queryLength = spelling.count { !$0.isWhitespace && $0 != "/" }
    return matchedRanges.count > (queryLength + 1) / 2
  }

  /// The candidates strictly inside `scope` and not in or inside `excludedFolder`, in the given order, with their
  /// paths relative to the scope.
  private func scopedCandidates(in scope: String, outside excludedFolder: String?)
    -> [ScopedCandidate]
  {
    let scopeSegments = Self.segments(of: scope)
    let excludedSegments = excludedFolder.map(Self.segments(of:))
    // String equality is canonical-equivalence aware, so a scope in either normalisation finds NFC and NFD paths.
    // Every path starts with the root's empty segments, so excluding the root excludes everything.
    func isExcluded(_ candidate: Candidate) -> Bool {
      excludedSegments.map(candidate.segments.starts(with:)) ?? false
    }
    guard !scopeSegments.isEmpty else {
      return candidates.enumerated().compactMap { index, candidate in
        guard !isExcluded(candidate) else { return nil }
        return ScopedCandidate(
          candidateIndex: index, pathInScope: candidate.path,
          foldedSegmentsInScope: candidate.foldedSegments[...])
      }
    }
    return candidates.enumerated().compactMap { index, candidate in
      guard
        candidate.segments.count > scopeSegments.count,
        candidate.segments.starts(with: scopeSegments),
        !isExcluded(candidate)
      else { return nil }
      return ScopedCandidate(
        candidateIndex: index,
        pathInScope: candidate.segments.dropFirst(scopeSegments.count).joined(separator: "/"),
        foldedSegmentsInScope: candidate.foldedSegments.dropFirst(scopeSegments.count))
    }
  }

  /// Adds the recency boost to every scored candidate that is a recent destination.
  private func applyRecencyBoost(
    _ recents: RecentDestinations, to ranked: inout [Scored], scoped: [ScopedCandidate]
  ) {
    guard !recents.paths.isEmpty else { return }
    // String equality and hashing are canonical-equivalence aware, so NFC and NFD spellings find each other.
    let rankByPath = Dictionary(
      recents.paths.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
    let capacity = Double(max(recents.capacity, recents.paths.count))
    for index in ranked.indices {
      let path = candidates[scoped[ranked[index].scopedIndex].candidateIndex].path
      guard let rank = rankByPath[path] else { continue }
      ranked[index].score += Self.recencyBoost * (capacity - Double(rank)) / capacity
    }
  }

  /// The segments of an archive-relative path, as given.
  private static func segments(of path: String) -> [String] {
    path.split(separator: "/").map(String.init)
  }
}

/// The score added for where in a path the query's words fall, on FuzzyMatch's 0...1 scale.
///
/// FuzzyMatch rewards word starts anywhere in a path about equally; people searching for a folder mean its name. Per
/// query word, a folder earns ``wholeSegment`` when a segment equals the word, else ``segmentPrefix`` when a segment
/// starts with it, and ``lastSegment`` when its last segment contains the word. The total is averaged over the words,
/// so multi-word queries stay on the same scale. With ``ScopedRanking/exactNameFirst``, a folder whose last segment
/// equals one of the words also earns ``exactName``, once and not averaged, so it is worth the same for any number of
/// words. Words are split at spaces and `/`.
enum SegmentBonus {
  /// A word equals a whole segment (`fahrrad` and `Mobilität/Fahrrad`).
  static let wholeSegment = 0.1
  /// A segment starts with the word (`elek` and `Rechnungen/Elektronik`).
  static let segmentPrefix = 0.05
  /// The last segment contains the word: the folder itself is named that, not one of its parents.
  static let lastSegment = 0.05
  /// The folder's own name equals a word, under ``ScopedRanking/exactNameFirst`` only.
  ///
  /// More than one ``DestinationMatcher/depthPenalty`` (0.035) and less than two (0.07): inside `Töpferei`, `glasur`
  /// ranks `Werkstoffe/Glasur` above the direct child `Glasurrezepte`, whose match at the start of the path and one
  /// level less outweigh the whole-segment bonus by about 0.03 under ``ScopedRanking/directChildFirst``; from the root,
  /// `hobby` still ranks `Hobbys` above `Wohnung/Keller/Hobby`, two levels deeper. It is one bonus step,
  /// the same as ``segmentPrefix``.
  static let exactName = 0.05

  /// The bonus for a path with `segments` (from ``foldedSegments(of:)``) and a query with `words` (from
  /// ``foldedWords(of:)``), under `ranking`.
  static func value(words: [String], segments: ArraySlice<String>, ranking: ScopedRanking)
    -> Double
  {
    guard !words.isEmpty, let finalSegment = segments.last else { return 0 }
    var total = 0.0
    for word in words {
      if segments.contains(word) {
        total += wholeSegment
      } else if segments.contains(where: { $0.hasPrefix(word) }) {
        total += segmentPrefix
      }
      if finalSegment.contains(word) {
        total += lastSegment
      }
    }
    let nameBonus: Double
    switch ranking {
    case .directChildFirst:
      nameBonus = 0
    case .exactNameFirst:
      nameBonus = words.contains(finalSegment) ? exactName : 0
    }
    return total / Double(words.count) + nameBonus
  }

  /// The case- and diacritic-folded segments of `path`.
  static func foldedSegments(of path: String) -> [String] {
    path.foldedForSearch().split(separator: "/").map(String.init)
  }

  /// The case- and diacritic-folded words of `query`, split at whitespace and `/`.
  static func foldedWords(of query: String) -> [String] {
    query.foldedForSearch().split { $0.isWhitespace || $0 == "/" }.map(String.init)
  }
}
