import Testing

@testable import Docsort

@Suite("DisplayPath")
struct DisplayPathTests {
  @Test("The home folder is abbreviated to ~")
  func abbreviatesHome() {
    #expect(
      DisplayPath.abbreviating("/Users/margit/Archiv/_Neu/Scanner", home: "/Users/margit")
        == "~/Archiv/_Neu/Scanner")
    #expect(DisplayPath.abbreviating("/Users/margit", home: "/Users/margit/") == "~")
  }

  @Test("Paths outside the home folder stay as they are")
  func keepsOtherPaths() {
    #expect(
      DisplayPath.abbreviating("/Users/margitta/Archiv", home: "/Users/margit")
        == "/Users/margitta/Archiv")
    #expect(DisplayPath.abbreviating("/Volumes/Archiv", home: "/Users/margit") == "/Volumes/Archiv")
    #expect(DisplayPath.abbreviating("/Archiv", home: "/") == "/Archiv")
  }

  @Test("The real home folder is not the sandbox container")
  func realHomeIsNotTheContainer() {
    #expect(!DisplayPath.userHome.contains("/Library/Containers/"))
  }
}
