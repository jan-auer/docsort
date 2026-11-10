import Foundation
import Testing

@testable import DocsortCore

@Suite("FileLocation")
struct FileLocationTests {
  @Test("spells one location one way: standardised, no trailing slash, the root as /")
  func pathIsStandardised() {
    let packageAsDirectory = URL(filePath: "/Archiv/Scan.bundle/", directoryHint: .isDirectory)
    let packageAsFile = URL(filePath: "/Archiv/Scan.bundle", directoryHint: .notDirectory)
    let detour = URL(filePath: "/Archiv/./Rechnungen/../Scan.bundle")

    #expect(FileLocation.path(of: packageAsDirectory) == "/Archiv/Scan.bundle")
    #expect(FileLocation.path(of: packageAsFile) == "/Archiv/Scan.bundle")
    #expect(FileLocation.path(of: detour) == "/Archiv/Scan.bundle")
    #expect(FileLocation.path(of: URL(filePath: "/")) == "/")
  }

  @Test("trims only trailing slashes from a path, keeping the root as /")
  func trimsTrailingSlashes() {
    #expect(FileLocation.withoutTrailingSlashes("/Eingang/Scan.bundle//") == "/Eingang/Scan.bundle")
    #expect(FileLocation.withoutTrailingSlashes("/Eingang/./Scan.pdf") == "/Eingang/./Scan.pdf")
    #expect(FileLocation.withoutTrailingSlashes("///") == "/")
  }
}
