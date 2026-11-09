import Foundation
import FuzzyMatch

/// Works out which characters of a matched path to show bold for a query.
///
/// Guarantees, per query word (words are split at whitespace, as FuzzyMatch splits them):
/// - When the word, case- and diacritic-folded, occurs at the start of a segment or of a word inside one (after a
///   space, `.`, `-` or any other character that is neither letter nor digit), its range is the first such occurrence,
///   which lies in the shallowest segment that has one. So `segelclub` marks `2. Segelclub Seeschwalbe`, not
///   the later `Segelclub Seeschwalbe Archiv`, in `2. Segelclub Seeschwalbe/Chronik/Segelclub Seeschwalbe Archiv`, wherever FuzzyMatch's own alignment fell.
/// - Otherwise its ranges are FuzzyMatch's highlight for that word alone (scattered letters such as `rchng`).
/// - The ranges of all words are sorted and coalesced, and index into the path as given, NFC or NFD.
struct MatchHighlighter: Sendable {
  /// A query word, folded for comparison and prepared for FuzzyMatch.
  private struct Word: Sendable {
    let folded: String
    let fuzzyQuery: FuzzyQuery
  }

  /// A character of a path with its folded form.
  private struct FoldedCharacter {
    let index: String.Index
    let folded: [Unicode.Scalar]
    let startsWord: Bool
  }

  private let words: [Word]
  private let fuzzyMatcher: FuzzyMatcher

  /// A highlighter for the space-separated words of `spelling` (a ``SearchQuery`` spelling), using `fuzzyMatcher` for
  /// words that match no word start.
  init(spelling: String, fuzzyMatcher: FuzzyMatcher) {
    self.fuzzyMatcher = fuzzyMatcher
    words = spelling.split(whereSeparator: \.isWhitespace).map { word in
      Word(folded: word.foldedForSearch(), fuzzyQuery: fuzzyMatcher.prepare(String(word)))
    }
  }

  /// The sorted, coalesced ranges of `path` to show bold.
  func ranges(in path: String) -> [Range<String.Index>] {
    let characters = Self.foldedCharacters(of: path)
    var ranges: [Range<String.Index>] = []
    for word in words {
      if let range = Self.firstWordStartOccurrence(of: word.folded, in: characters, path: path) {
        ranges.append(range)
      } else {
        // The matcher accepted the whole query for this path, so every word matches on its own; an empty result
        // would only mean no bold text for this word.
        ranges += fuzzyMatcher.highlight(path, against: word.fuzzyQuery) ?? []
      }
    }
    return Self.coalesced(ranges)
  }

  /// The characters of `path`, each with its folded form and whether a word starts there.
  private static func foldedCharacters(of path: String) -> [FoldedCharacter] {
    var characters: [FoldedCharacter] = []
    var previous: Character?
    for index in path.indices {
      let character = path[index]
      let startsWord = previous.map { !$0.isLetter && !$0.isNumber } ?? true
      characters.append(
        FoldedCharacter(index: index, folded: folded(character), startsWord: startsWord))
      previous = character
    }
    return characters
  }

  /// `character` case- and diacritic-folded, as scalars. Folds a single ASCII scalar itself, which is what Foundation's
  /// folding does to it (lowercasing), and only hands other characters to Foundation, which is slow per character.
  static func folded(_ character: Character) -> [Unicode.Scalar] {
    let scalars = character.unicodeScalars
    if scalars.count == 1, let scalar = scalars.first, scalar.isASCII {
      let byte = UInt8(scalar.value)
      return [
        Unicode.Scalar((UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte) ? byte + 32 : byte)
      ]
    }
    return Array(String(character).foldedForSearch().unicodeScalars)
  }

  /// The range of the first occurrence of `word` (folded) that begins at a word start, or `nil`.
  private static func firstWordStartOccurrence(
    of word: String, in characters: [FoldedCharacter], path: String
  ) -> Range<String.Index>? {
    let wordScalars = Array(word.unicodeScalars)
    guard !wordScalars.isEmpty else { return nil }
    for start in characters.indices where characters[start].startsWord {
      var matchedCount = 0
      var position = start
      while matchedCount < wordScalars.count, position < characters.count {
        let folded = characters[position].folded
        let remaining = wordScalars[matchedCount...]
        guard folded.count <= remaining.count, remaining.starts(with: folded) else { break }
        matchedCount += folded.count
        position += 1
      }
      if matchedCount == wordScalars.count {
        let end = position < characters.count ? characters[position].index : path.endIndex
        return characters[start].index..<end
      }
    }
    return nil
  }

  /// `ranges` sorted, with overlapping and adjacent ranges merged.
  private static func coalesced(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
    var merged: [Range<String.Index>] = []
    for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
      if let last = merged.last, range.lowerBound <= last.upperBound {
        merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
      } else {
        merged.append(range)
      }
    }
    return merged
  }
}
