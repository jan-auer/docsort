import Testing

@testable import DocsortCore

@Suite("SearchQuery")
struct SearchQueryTests {
  @Test("a query of only whitespace does not exist")
  func whitespaceIsNoQuery() {
    #expect(SearchQuery("") == nil)
    #expect(SearchQuery(" \t\n") == nil)
  }

  @Test("tries the typed spelling first, then all digraphs replaced")
  func typedSpellingFirst() throws {
    let query = try #require(SearchQuery("  Toepferei Fusspflege "))

    #expect(query.spellings.first == "toepferei fusspflege")
    #expect(query.spellings.dropFirst().first == "töpferei fußpflege")
    #expect(Set(query.spellings).count == query.spellings.count)
  }

  @Test("varies each digraph of a word on its own")
  func variesDigraphsSeparately() {
    #expect(
      SearchQuery.forms(of: "feuerloescher") == [
        "feuerloescher", "feürlöscher", "feürloescher", "feuerlöscher",
      ])
    #expect(SearchQuery.forms(of: "imkerei") == ["imkerei"])
  }

  @Test("caps the number of spellings")
  func capsSpellings() throws {
    let query = try #require(SearchQuery("aeoeue ssaess uessoe aeae"))

    #expect(query.spellings.count == SearchQuery.maximumSpellingCount)
    #expect(query.spellings.first == "aeoeue ssaess uessoe aeae")
  }
}
