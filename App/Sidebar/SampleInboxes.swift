#if DEBUG
  import DocsortCore
  import Foundation
  import OSLog

  /// Inbox rows for SwiftUI previews: the preview sample files (`PreviewSampleFiles`), scanned as the inbox
  /// "Web-Downloads", with one file shown as filed and one as trashed.
  enum SampleInboxes {
    /// A library listing the sample files.
    static func library() -> InboxLibrary {
      let items = sampleItems()
      let rows = items.enumerated().map { position, item in
        let mark: InboxItemMark? =
          switch position {
          case 1:
            .filed(
              newURL: item.url.deletingLastPathComponent().appending(path: item.name),
              destinationPath: "Musik Margit/Noten & Bücher", date: handledDate, documentID: UUID())
          case 2:
            .trashed(
              trashedURL: item.url.deletingLastPathComponent().appending(
                path: ".Trash/\(item.name)"),
              date: handledDate)
          default: nil
          }
        return InboxRow(item: item, mark: mark)
      }
      return InboxLibrary.preview(sections: [
        InboxSection(
          id: UUID(), label: "Web-Downloads",
          content: .listing(rows.map(InboxSectionEntry.row), problems: [])),
        InboxSection(
          id: UUID(), label: "Scanner",
          content: .unreachable(.folderNotFound(path: "~/Archiv/_Neu/Scanner"))),
      ])
    }

    /// The sample invoice, as a selected unhandled file.
    static func selectedInvoice() -> SelectedFile {
      let invoice = PreviewSampleFiles.invoicePDF()
      guard
        let item = sampleItems().first(where: {
          $0.url.lastPathComponent == invoice.lastPathComponent
        })
      else {
        preconditionFailure("The sample invoice was not written")
      }
      return SelectedFile(
        id: InboxItemID(item), url: item.url, originalName: item.name, inboxName: "Web-Downloads",
        completeness: .complete, mark: nil)
    }

    /// The sample invoice, filed to "Musik Margit/Noten & Bücher" as "2033-10-13 Notenhaus Allegretto.pdf".
    static func filedInvoice() -> SelectedFile {
      let invoice = selectedInvoice()
      let newURL = invoice.url.deletingLastPathComponent().appending(
        path: "2033-10-13 Notenhaus Allegretto.pdf")
      return SelectedFile(
        id: invoice.id, url: newURL, originalName: invoice.originalName,
        inboxName: invoice.inboxName, completeness: .complete,
        mark: .filed(
          newURL: newURL, destinationPath: "Musik Margit/Noten & Bücher", date: handledDate,
          documentID: UUID()))
    }

    /// The sample invoice, moved to the Trash.
    static func trashedInvoice() -> SelectedFile {
      let invoice = selectedInvoice()
      return SelectedFile(
        id: invoice.id, url: invoice.url, originalName: invoice.originalName,
        inboxName: invoice.inboxName, completeness: .complete,
        mark: .trashed(
          trashedURL: invoice.url.deletingLastPathComponent().appending(
            path: ".Trash/\(invoice.originalName)"),
          date: handledDate))
    }

    /// When the sample files were filed or trashed: 13 October 2033, 09:41.
    private static var handledDate: Date {
      Calendar.current.date(
        from: DateComponents(year: 2033, month: 10, day: 13, hour: 9, minute: 41))
        ?? .distantPast
    }

    /// The sample files as the inbox scanner lists them.
    private static func sampleItems() -> [InboxItem] {
      let folder = PreviewSampleFiles.invoicePDF().deletingLastPathComponent()
      _ = PreviewSampleFiles.textNote()
      _ = PreviewSampleFiles.unknownData()
      do {
        return try InboxScanner().scan(folder).items
      } catch {
        Logger.preview.error("Scanning the preview samples failed: \(String(describing: error))")
        return []
      }
    }
  }
#endif
