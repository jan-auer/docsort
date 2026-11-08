import Foundation

/// A destination search query as typed, and the spellings of it the matcher tries.
///
/// Guarantees:
/// - Leading and trailing whitespace is dropped; a query of only whitespace does not exist (`init` returns `nil`).
/// - ``spellings`` starts with the query as typed (lowercased) and holds at most ``maximumSpellingCount`` entries.
/// - Every other spelling replaces, in some words, the `ue`/`ae`/`oe`/`ss` people type for `ü`/`ä`/`ö`/`ß`. Each word
///   is varied on its own, so a word that really contains `ue` (`steuer`) keeps its typed form alongside.
struct SearchQuery: Sendable {
  /// The most spellings tried for one query; caps the work for queries full of `ue`/`ss`.
  static let maximumSpellingCount = 8
  /// The most forms tried for one word, including the typed form.
  static let maximumWordFormCount = 4

  /// The digraphs people type for German letters they cannot reach, with the letter each stands for.
  private static let transliterations: [(typed: String, letter: String)] = [
    ("ue", "ü"), ("ae", "ä"), ("oe", "ö"), ("ss", "ß"),
  ]

  /// The query's spellings, typed form first; each is a space-separated list of lowercased words.
  let spellings: [String]

  /// Splits `text` into words and derives its spellings; `nil` when `text` holds nothing but whitespace.
  init?(_ text: String) {
    let words = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
    guard !words.isEmpty else { return nil }

    let formsPerWord = words.map(Self.forms(of:))
    // The typed spelling, then every word in its most replaced form (someone who types `ue` for `ü` usually does
    // it throughout), then the other combinations until the cap.
    var candidates = [words, formsPerWord.map { $0[min(1, $0.count - 1)] }]
    var combinations = [[String]()]
    for forms in formsPerWord {
      combinations = combinations.flatMap { prefix in forms.map { prefix + [$0] } }
        .prefix(Self.maximumSpellingCount).map { $0 }
    }
    candidates += combinations

    var spellings: [String] = []
    for candidate in candidates.map({ $0.joined(separator: " ") })
    where !spellings.contains(candidate) && spellings.count < Self.maximumSpellingCount {
      spellings.append(candidate)
    }
    self.spellings = spellings
  }

  /// `word` as typed, then with every transliterated digraph replaced, then with each one replaced alone.
  static func forms(of word: String) -> [String] {
    let occurrences = digraphOccurrences(in: word)
    guard !occurrences.isEmpty else { return [word] }

    var forms = [word, replacing(occurrences, in: word)]
    if occurrences.count > 1 {
      forms += occurrences.map { replacing([$0], in: word) }
    }
    var unique: [String] = []
    for form in forms where !unique.contains(form) && unique.count < maximumWordFormCount {
      unique.append(form)
    }
    return unique
  }

  /// A transliterated digraph found in a word.
  private struct DigraphOccurrence {
    /// Where the digraph lies in the word.
    let range: Range<String.Index>
    /// The letter the digraph stands for.
    let letter: String
  }

  /// The non-overlapping transliterated digraphs in `word`, left to right.
  private static func digraphOccurrences(in word: String) -> [DigraphOccurrence] {
    var occurrences: [DigraphOccurrence] = []
    var position = word.startIndex
    while position < word.endIndex {
      let rest = word[position...]
      if let match = transliterations.first(where: { rest.hasPrefix($0.typed) }) {
        let end = word.index(position, offsetBy: match.typed.count)
        occurrences.append(DigraphOccurrence(range: position..<end, letter: match.letter))
        position = end
      } else {
        position = word.index(after: position)
      }
    }
    return occurrences
  }

  /// `word` with each of `occurrences` replaced by its letter.
  private static func replacing(_ occurrences: [DigraphOccurrence], in word: String) -> String {
    var result = word
    // Replaces from the end so that the earlier ranges stay valid.
    for occurrence in occurrences.reversed() {
      result.replaceSubrange(occurrence.range, with: occurrence.letter)
    }
    return result
  }
}

extension StringProtocol {
  /// The text case- and diacritic-folded, the form in which search compares query words with path segments. Combining
  /// marks are dropped, so NFC and NFD spellings fold alike.
  func foldedForSearch() -> String {
    folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }
}
