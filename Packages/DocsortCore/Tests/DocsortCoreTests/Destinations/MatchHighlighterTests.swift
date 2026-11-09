import Foundation
import Testing

@testable import DocsortCore

@Suite("MatchHighlighter")
struct MatchHighlighterTests {
  @Test("folds every ASCII character the way Foundation's case and diacritic folding does")
  func foldsASCIILikeFoundation() throws {
    for value in UInt8(0)...UInt8(127) {
      let character = Character(Unicode.Scalar(value))
      #expect(
        MatchHighlighter.folded(character)
          == Array(String(character).foldedForSearch().unicodeScalars), "\(value)")
    }
  }

  @Test("folds other characters through Foundation, in either normalisation")
  func foldsOtherCharacters() {
    #expect(MatchHighlighter.folded("Ü") == ["u"])
    #expect(MatchHighlighter.folded("U\u{0308}") == ["u"])
    #expect(MatchHighlighter.folded("ß") == Array("ß".foldedForSearch().unicodeScalars))
    #expect(MatchHighlighter.folded("\r\n") == Array("\r\n".foldedForSearch().unicodeScalars))
  }
}
