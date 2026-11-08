#if DEBUG
  import AppKit
  import OSLog

  /// Invented sample files for the preview views' `#Preview`s, written to a temporary folder on first use.
  ///
  /// All content comes from the fictional household of `docs/design/sample-data` (`no-real-data-in-repo`). A sample that cannot be
  /// written is logged and its URL returned anyway, so the preview shows the "missing file" state instead of failing.
  enum PreviewSampleFiles {
    /// The folder the samples are written to.
    private static let folder = FileManager.default.temporaryDirectory.appending(
      path: "DocsortPreviewSamples", directoryHint: .isDirectory)

    /// A two-page invoice PDF.
    static func invoicePDF() -> URL {
      write(named: "Rechnung_NA-33-08812.pdf") { url in
        try drawPDF(to: url, pages: invoicePages)
      }
    }

    /// A short plain-text note, which Quick Look can show.
    static func textNote() -> URL {
      write(named: "2033-10-16 Notiz Chor Liederkranz.txt") { url in
        try textNoteContent.write(to: url, atomically: true, encoding: .utf8)
      }
    }

    /// A file of an unknown type, which gets the "no preview" view.
    static func unknownData() -> URL {
      write(named: "2033-10-18 Zählerstände Stadtwerke.dat") { url in
        try Data((0..<3072).map { UInt8(truncatingIfNeeded: $0 &* 37) }).write(to: url)
      }
    }

    /// A URL in the sample folder that no file exists at.
    static func missingFile() -> URL {
      folder.appending(path: "2033-10-26_Tierarztpraxis Aschauer Honorarnote.pdf")
    }

    private static func write(named fileName: String, using writeFile: (URL) throws -> Void) -> URL
    {
      let url = folder.appending(path: fileName)
      do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try writeFile(url)
      } catch {
        Logger.preview.error(
          "Writing sample file \(fileName) failed: \(error.localizedDescription)")
      }
      return url
    }

    /// Why a sample PDF could not be drawn.
    private enum SampleError: Error {
      /// Core Graphics could not create a PDF context for the file.
      case pdfContextUnavailable
    }

    private static let invoicePages: [[String]] = [
      [
        "Notenhaus Allegretto · Wettelau",
        "",
        "Margit Weißenbacher",
        "Brunnfeldgasse 14/3",
        "Wettelau",
        "",
        "Rechnung NA-33-08812",
        "Rechnungsdatum: 13.10.2033",
        "",
        "Pos.  Artikel                          Betrag",
        "1     Chorpartitur Adventkantate        24,80 €",
        "2     Klavierauszug, 2 Stück            31,60 €",
        "",
        "Fortsetzung auf Seite 2",
      ],
      [
        "Rechnung NA-33-08812 · Seite 2",
        "",
        "Summe                                  56,40 €",
        "",
        "Zahlbar innerhalb von 14 Tagen.",
        "Vielen Dank für Ihren Einkauf.",
      ],
    ]

    private static let textNoteContent = """
      Notiz Chor Liederkranz

      - Noten für das Adventprogramm bestellen
      - Probenplan an alle schicken
      - Saalmiete für Dezember klären
      """

    /// Draws one A4 page per entry of `pages`, each line of text below the previous one.
    private static func drawPDF(to url: URL, pages: [[String]]) throws {
      var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
      guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
        throw SampleError.pdfContextUnavailable
      }
      let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor.black,
      ]
      for lines in pages {
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for (index, line) in lines.enumerated() {
          let origin = CGPoint(x: 64, y: mediaBox.height - 96 - CGFloat(index) * 20)
          NSAttributedString(string: line, attributes: attributes).draw(at: origin)
        }
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
      }
      context.closePDF()
    }
  }
#endif
