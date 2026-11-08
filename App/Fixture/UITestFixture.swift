#if DEBUG
  import CoreGraphics
  import CoreText
  import DocsortCore
  import Foundation
  import OSLog

  /// The environment of a UI-test launch (`-docsort-ui-test-fixture`): an invented archive and two inboxes built
  /// fresh in the app's temporary directory on every launch, with names from the fictional sample archive
  /// (`docs/design/sample-data/`, decision `no-real-data-in-repo`).
  ///
  /// The folders are configured through the real `FolderResolver` (security-scoped bookmarks) in an emptied
  /// `UserDefaults` suite of its own, the history file lives in the fixture folder, and Move to Trash moves files into
  /// the fixture's own `Trash` folder, so a UI test never touches the user's settings, history or Trash.
  ///
  /// Layout below `<tmp>/Docsort-ui-test-fixture`:
  /// - `Archiv` with a dozen folders, among them `Musik Margit/Noten & Bücher` and
  ///   `Kommunikation/Ilmnet Internet/Rechnungen` (holding `2033-09-04 Rechnung September.pdf`);
  /// - inbox `Archiv/_Neu/Web-Downloads`: the group `Uni Westerholm` (dated 7 Oct 2033) with two files, then
  ///   `Rechnung_NA-33-08812.pdf` (13 Oct) and `2033-10-20 Verlängerung Jahreskarte Konrad.pdf` (20 Oct);
  /// - inbox `Archiv/_Neu/Scanner`: `2033-10-11_Optik Klarblick.pdf`.
  enum UITestFixture {
    /// The fixture's folder in the app's temporary directory.
    static let root = URL.temporaryDirectory.appending(
      path: "Docsort-ui-test-fixture", directoryHint: .isDirectory)

    /// The archive folders created, archive-relative.
    static let archiveFolders = [
      "Ahnenforschung/Stammbaum",
      "Arbeit Margit/Gehaltszettel/2033",
      "Gesundheit/Konrad/Augenarzt & Brillen",
      "Gesundheit/Konrad/Zahnarzt",
      "Kommunikation/Ilmnet Internet/Rechnungen",
      "Kommunikation/Ilmnet Internet/Vertrag",
      "Matthias/Studium Westerholm/2. Studienjahr/Collegegeld",
      "Mobilität/Bahntickets/2033",
      "Mobilität/Jahreskarte Regio Plus",
      "Musik Margit/Noten & Bücher",
    ]

    /// Builds the fixture and returns the environment using it. A fixture that cannot be built stops the app: the UI
    /// tests cannot run without it, and running them against anything else must never happen.
    static func makeEnvironment() -> AppEnvironment {
      let suiteName = "org.jauer.Docsort.ui-test-fixture"
      guard let defaults = UserDefaults(suiteName: suiteName) else {
        preconditionFailure("Could not create the user defaults suite \(suiteName)")
      }
      defaults.removePersistentDomain(forName: suiteName)
      let resolver = FolderResolver()
      do {
        try buildFolders()
        var settings = FolderSettings()
        settings.archiveRoot = try resolver.makeReference(for: archive)
        settings.addInbox(try resolver.makeReference(for: webDownloads))
        settings.addInbox(try resolver.makeReference(for: scanner))
        try FolderSettings.preference(in: defaults).save(settings)
      } catch {
        Logger.fixture.fault(
          "Could not build the UI-test fixture: \(String(describing: error), privacy: .public)")
        preconditionFailure("Could not build the UI-test fixture: \(error)")
      }
      Logger.fixture.notice(
        "Built the UI-test fixture at \(root.path(percentEncoded: false), privacy: .public)")
      return AppEnvironment(
        defaults: defaults,
        folderResolver: resolver,
        filingHistoryURL: root.appending(path: "FilingHistory.json", directoryHint: .notDirectory),
        fileTrash: FixtureTrash(folder: root.appending(path: "Trash", directoryHint: .isDirectory)))
    }

    private static var archive: URL { root.appending(path: "Archiv", directoryHint: .isDirectory) }
    private static var webDownloads: URL {
      archive.appending(path: "_Neu/Web-Downloads", directoryHint: .isDirectory)
    }
    private static var scanner: URL {
      archive.appending(path: "_Neu/Scanner", directoryHint: .isDirectory)
    }

    private static func buildFolders() throws {
      let fileManager = FileManager.default
      if fileManager.fileExists(atPath: root.path(percentEncoded: false)) {
        try fileManager.removeItem(at: root)
      }
      for folder in archiveFolders {
        try fileManager.createDirectory(
          at: archive.appending(path: folder, directoryHint: .isDirectory),
          withIntermediateDirectories: true)
      }
      try writePDF(
        at: archive.appending(path: "Kommunikation/Ilmnet Internet/Rechnungen"),
        named: "2033-09-04 Rechnung September.pdf", lines: ["Ilmnet", "Rechnung September 2033"],
        date: date(2033, 9, 4, 8, 0))

      let group = webDownloads.appending(path: "Uni Westerholm", directoryHint: .isDirectory)
      try fileManager.createDirectory(at: group, withIntermediateDirectories: true)
      try writePDF(
        at: group, named: "Rechnung_Collegegeld_1e-termijn.pdf",
        lines: ["Universiteit Westerholm", "Collegegeld 1e termijn 2033"],
        date: date(2033, 10, 7, 21, 12))
      try writePDF(
        at: group, named: "Inschrijvingsbewijs_ST-000-58213.pdf",
        lines: ["Universiteit Westerholm", "Inschrijvingsbewijs 2033-34"],
        date: date(2033, 10, 7, 21, 13))
      try fileManager.setAttributes(
        [.creationDate: date(2033, 10, 7, 21, 10), .modificationDate: date(2033, 10, 7, 21, 13)],
        ofItemAtPath: group.path(percentEncoded: false))
      try writePDF(
        at: webDownloads, named: "Rechnung_NA-33-08812.pdf",
        lines: ["Notenhaus Allegretto", "Rechnung NA-33-08812", "13.10.2033"],
        date: date(2033, 10, 13, 11, 20))
      try writePDF(
        at: webDownloads, named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
        lines: ["Verlängerung Ihrer Jahreskarte", "Jahreskarte Regio Plus", "20.10.2033"],
        date: date(2033, 10, 20, 19, 12))

      try fileManager.createDirectory(at: scanner, withIntermediateDirectories: true)
      try writePDF(
        at: scanner, named: "2033-10-11_Optik Klarblick.pdf",
        lines: ["Optik Klarblick", "Rathausgasse 7 · 4999 Wettelau", "11.10.2033"],
        date: date(2033, 10, 11, 19, 30))
    }

    /// Writes a one-page PDF showing `lines` as `name` in `folder`, dated `date`.
    private static func writePDF(at folder: URL, named name: String, lines: [String], date: Date)
      throws
    {
      let url = folder.appending(path: name, directoryHint: .notDirectory)
      var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
      guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
        throw CocoaError(.fileWriteUnknown, userInfo: [NSURLErrorKey: url])
      }
      context.beginPDFPage(nil)
      let font = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
      for (index, line) in lines.enumerated() {
        let text = NSAttributedString(
          string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        context.textPosition = CGPoint(x: 60, y: 760 - CGFloat(index) * 30)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
      }
      context.endPDFPage()
      context.closePDF()
      try FileManager.default.setAttributes(
        [.creationDate: date, .modificationDate: date],
        ofItemAtPath: url.path(percentEncoded: false))
    }

    /// The date `year`-`month`-`day` `hour`:`minute` in the current time zone.
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int)
      -> Date
    {
      let components = DateComponents(
        calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day,
        hour: hour, minute: minute)
      guard let date = components.date else {
        preconditionFailure("Invalid fixture date \(components)")
      }
      return date
    }
  }

  /// A stand-in for the Trash: moves items into a folder of the fixture, so UI tests leave the user's Trash alone.
  nonisolated struct FixtureTrash: FileTrash {
    /// The folder trashed items are moved into.
    let folder: URL

    func moveToTrash(_ url: URL) throws -> URL {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      var target = folder.appending(path: url.lastPathComponent)
      if FileManager.default.fileExists(atPath: target.path(percentEncoded: false)) {
        target = folder.appending(path: "\(UUID().uuidString) \(url.lastPathComponent)")
      }
      try FileManager.default.moveItem(at: url, to: target)
      return target
    }
  }
#endif
