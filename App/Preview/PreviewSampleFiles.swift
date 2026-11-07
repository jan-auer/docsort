#if DEBUG
  import AppKit
  import OSLog

  /// Invented sample files for the preview views' `#Preview`s, written to a temporary folder on first use.
  ///
  /// All content is made up (fictional parties such as "Beispiel GmbH" and "Musterfirma"). A sample that cannot be
  /// written is logged and its URL returned anyway, so the preview shows the "missing file" state instead of failing.
  enum PreviewSampleFiles {
    /// The folder the samples are written to.
    private static let folder = FileManager.default.temporaryDirectory.appending(
      path: "DocsortPreviewSamples", directoryHint: .isDirectory)

    /// A two-page invoice PDF.
    static func invoicePDF() -> URL {
      write(named: "2026-03-02 Rechnung Beispiel GmbH.pdf") { url in
        try drawPDF(to: url, pages: invoicePages)
      }
    }

    /// A short plain-text note, which Quick Look can show.
    static func textNote() -> URL {
      write(named: "2026-04-14 Notiz Musterfirma.txt") { url in
        try textNoteContent.write(to: url, atomically: true, encoding: .utf8)
      }
    }

    /// A file of an unknown type, which gets the "no preview" view.
    static func unknownData() -> URL {
      write(named: "2026-04-20 Messwerte Musterfirma.dat") { url in
        try Data((0..<3072).map { UInt8(truncatingIfNeeded: $0 &* 37) }).write(to: url)
      }
    }

    /// A URL in the sample folder that no file exists at.
    static func missingFile() -> URL {
      folder.appending(path: "2026-05-11 Angebot Musterfirma.pdf")
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
        "Beispiel GmbH · Musterweg 1 · 12345 Musterstadt",
        "",
        "Musterfirma",
        "Probestraße 7",
        "54321 Beispielhausen",
        "",
        "Rechnung Nr. 1001",
        "Rechnungsdatum: 02.03.2026",
        "",
        "Pos.  Leistung                         Betrag",
        "1     Beratung, 4 Stunden              400,00 €",
        "2     Reisekosten (pauschal)            50,00 €",
        "",
        "Fortsetzung auf Seite 2",
      ],
      [
        "Rechnung Nr. 1001 · Seite 2",
        "",
        "Zwischensumme                          450,00 €",
        "zzgl. 19 % USt.                         85,50 €",
        "Gesamtbetrag                           535,50 €",
        "",
        "Zahlbar innerhalb von 14 Tagen ohne Abzug.",
        "Vielen Dank für Ihren Auftrag.",
      ],
    ]

    private static let textNoteContent = """
      Notiz zum Termin mit der Musterfirma

      - Angebot bis Ende April anfordern
      - Ansprechpartnerin: Erika Beispiel
      - Rückfragen per Post an Probestraße 7
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
