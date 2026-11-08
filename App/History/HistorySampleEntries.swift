#if DEBUG
  import Foundation

  /// Invented History entries for SwiftUI previews, with names from the fictional sample archive
  /// (`docs/design/sample-data/`, decision `no-real-data-in-repo`). Their files do not exist, so the preview pane shows
  /// the "missing" state for current entries.
  enum HistorySampleEntries {
    /// `day` October 2033 at `hour`:`minute` in the current time zone.
    private static func october2033(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
      Calendar.current.date(
        from: DateComponents(year: 2033, month: 10, day: day, hour: hour, minute: minute)) ?? .now
    }

    private static let archive = URL(filePath: "/Users/margit/Archiv", directoryHint: .isDirectory)

    /// Six entries over two days: filed, renamed, moved back, trashed, undone and moved or deleted since.
    static let entries: [HistoryEntry] = [
      HistoryEntry(
        id: UUID(), documentID: UUID(), date: october2033(13, 9, 41), kind: .filed,
        originalName: "Rechnung_NA-33-08812.pdf", inboxName: "Web-Downloads",
        newName: "Rechnung_NA-33-08812.pdf", destination: "Musik Margit/Noten & Bücher",
        url: archive.appending(path: "Musik Margit/Noten & Bücher/Rechnung_NA-33-08812.pdf"),
        place: .movedOrDeleted),
      HistoryEntry(
        id: UUID(), documentID: UUID(), date: october2033(13, 9, 43), kind: .renamed,
        originalName: "Rechnung_NA-33-08812.pdf", inboxName: "Web-Downloads",
        newName: "2033-10-13 Notenhaus Allegretto.pdf", destination: "Musik Margit/Noten & Bücher",
        url: archive.appending(
          path: "Musik Margit/Noten & Bücher/2033-10-13 Notenhaus Allegretto.pdf"),
        place: .current),
      HistoryEntry(
        id: UUID(), documentID: UUID(), date: october2033(13, 9, 50), kind: .filed,
        originalName: "2033-10-11_Optik Klarblick.pdf", inboxName: "Scanner",
        newName: "2033-10-11 Optik Klarblick Rechnung.pdf",
        destination: "Gesundheit/Konrad/Augenarzt & Brillen",
        url: archive.appending(
          path: "Gesundheit/Konrad/Augenarzt & Brillen/2033-10-11 Optik Klarblick Rechnung.pdf"),
        place: .movedOrDeleted),
      HistoryEntry(
        id: UUID(), documentID: UUID(), date: october2033(13, 9, 52), kind: .movedBack,
        originalName: "2033-10-11 Optik Klarblick Rechnung.pdf", inboxName: "Scanner",
        newName: "2033-10-11_Optik Klarblick.pdf",
        destination: "Scanner (moved back from Gesundheit/Konrad/Augenarzt & Brillen)",
        url: archive.appending(path: "_Neu/Scanner/2033-10-11_Optik Klarblick.pdf"),
        place: .current),
      HistoryEntry(
        id: UUID(), documentID: UUID(), date: october2033(20, 10, 5), kind: .filed,
        originalName: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf", inboxName: "Web-Downloads",
        newName: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
        destination: "Mobilität/Jahreskarte Regio Plus",
        url: archive.appending(
          path: "Mobilität/Jahreskarte Regio Plus/2033-10-20 Verlängerung Jahreskarte Konrad.pdf"),
        place: .undone(october2033(20, 10, 6))),
      HistoryEntry(
        id: UUID(), documentID: UUID(), date: october2033(20, 10, 8), kind: .trashed,
        originalName: "Inschrijvingsbewijs_ST-000-58213.pdf", inboxName: "Web-Downloads",
        newName: nil, destination: "Trash",
        url: URL(filePath: "/Users/margit/.Trash/Inschrijvingsbewijs_ST-000-58213.pdf"),
        place: .current),
    ]
  }
#endif
