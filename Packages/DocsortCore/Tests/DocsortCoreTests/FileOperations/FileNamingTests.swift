import Testing

@testable import DocsortCore

@Suite("FileNaming")
struct FileNamingTests {
  @Test(
    "finalName builds the name from the entered text and the original extension",
    arguments: [
      ("", "scan.pdf", "scan.pdf"),
      ("   ", "scan.pdf", "scan.pdf"),
      ("Rechnung", "scan.pdf", "Rechnung.pdf"),
      ("  Rechnung  ", "scan.pdf", "Rechnung.pdf"),
      ("Rechnung.pdf", "scan.pdf", "Rechnung.pdf"),
      ("Rechnung.PDF", "scan.pdf", "Rechnung.pdf"),
      ("Rechnung.pdf", "scan.PDF", "Rechnung.PDF"),
      ("Rechnung", "README", "Rechnung"),
      ("Rechnung.pdf", "README", "Rechnung.pdf"),
      ("v1.2 Rechnung", "scan.pdf", "v1.2 Rechnung.pdf"),
      ("2026-11-07 Rechnung v1.2", "scan.pdf", "2026-11-07 Rechnung v1.2.pdf"),
      ("Rechnung", "v1.2 Rechnung", "Rechnung"),
      ("Rechnung", "archive.tar.gz", "Rechnung.gz"),
      ("Rechnung", ".hidden", "Rechnung"),
      ("Rechnung", "trailing.", "Rechnung"),
    ])
  func finalName(entered: String, original: String, expected: String) {
    #expect(FileNaming.finalName(entered: entered, originalName: original) == expected)
  }

  @Test(
    "validationProblem refuses names the file system or the archive cannot take",
    arguments: [
      ("", NameProblem.empty),
      ("   ", .empty),
      (".", .reservedName),
      ("..", .reservedName),
      (".hidden.pdf", .leadingDot),
      ("Rechnung: Mai.pdf", .forbiddenCharacter(":")),
      ("Rechnung/Mai.pdf", .forbiddenCharacter("/")),
      ("Rechnung\u{0}.pdf", .forbiddenCharacter("\u{0}")),
      (String(repeating: "ä", count: 128), .tooLong(byteCount: 256)),
    ])
  func validationProblem(name: String, expected: NameProblem) {
    #expect(FileNaming.validationProblem(for: name) == expected)
  }

  @Test(
    "validationProblem accepts ordinary names",
    arguments: [
      "2026-11-07 Rechnung.pdf", "v1.2 Rechnung", "Kündigung.pdf", "Name.", "a",
      String(repeating: "a", count: 255),
    ])
  func validName(name: String) {
    #expect(FileNaming.validationProblem(for: name) == nil)
  }

  @Test("keepBothName numbers before the extension, Finder style")
  func keepBothNameSequence() {
    var taken: Set<String> = ["Rechnung.pdf"]
    let second = FileNaming.keepBothName(for: "Rechnung.pdf") { taken.contains($0) }
    #expect(second == "Rechnung 2.pdf")
    taken.insert(second)
    let third = FileNaming.keepBothName(for: "Rechnung.pdf") { taken.contains($0) }
    #expect(third == "Rechnung 3.pdf")
  }

  @Test("keepBothName handles names without an extension")
  func keepBothNameWithoutExtension() {
    let name = FileNaming.keepBothName(for: "README") { $0 == "README" }
    #expect(name == "README 2")
  }

  @Test("keepBothName keeps dots that are not an extension separator")
  func keepBothNameDottedStem() {
    let name = FileNaming.keepBothName(for: "v1.2 Rechnung.pdf") { $0 == "v1.2 Rechnung.pdf" }
    #expect(name == "v1.2 Rechnung 2.pdf")
  }
}
