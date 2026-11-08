import Foundation
import Testing

@testable import DocsortCore

@Suite("FileOperations.createFolders")
struct CreateFoldersTests {
  @Test("creates every missing folder of a nested path, outermost first")
  func createsNestedFolders() throws {
    let fixture = try FileOperationsFixture()

    let created = try fixture.operations.createFolders(
      "2033-11 Monitor/Lieferschein", in: fixture.archive)

    #expect(created.map(\.lastPathComponent) == ["2033-11 Monitor", "Lieferschein"])
    #expect(fixture.exists(fixture.archive.appending(path: "2033-11 Monitor/Lieferschein")))
  }

  @Test("returns only the folders it created, matching existing ones case-insensitively")
  func reusesExistingFolders() throws {
    let fixture = try FileOperationsFixture()
    try fixture.directory.createFolder("Archiv/2033-11 Monitor")

    let created = try fixture.operations.createFolders(
      "2033-11 monitor/Lieferschein", in: fixture.archive)

    #expect(created.map(\.lastPathComponent) == ["Lieferschein"])
    #expect(try fixture.names(in: fixture.archive) == ["2033-11 Monitor"])
  }

  @Test("creates nothing when all folders exist")
  func allExisting() throws {
    let fixture = try FileOperationsFixture()
    try fixture.directory.createFolder("Archiv/a/b")

    #expect(try fixture.operations.createFolders("a/b", in: fixture.archive) == [])
  }

  @Test(
    "refuses an invalid component before creating anything",
    arguments: [
      ("Neu/a:b", "a:b", NameProblem.forbiddenCharacter(":")),
      ("Neu//b", "", .empty),
      ("Neu/..", "..", .reservedName),
      ("Neu/.versteckt", ".versteckt", .leadingDot),
    ])
  func invalidComponent(path: String, component: String, problem: NameProblem) throws {
    let fixture = try FileOperationsFixture()

    #expect(throws: FileOperationError.invalidName(component, problem)) {
      try fixture.operations.createFolders(path, in: fixture.archive)
    }
    #expect(try fixture.names(in: fixture.archive) == [])
  }

  @Test("fails when a file stands where a folder should be")
  func fileInTheWay() throws {
    let fixture = try FileOperationsFixture()
    try fixture.directory.createFile("Archiv/a")

    #expect(throws: FileOperationError.self) {
      try fixture.operations.createFolders("a/b", in: fixture.archive)
    }
    #expect(try fixture.names(in: fixture.archive) == ["a"])
  }
}
