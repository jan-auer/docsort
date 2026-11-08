import SwiftUI

/// One filed file as the History window lists it.
nonisolated struct HistoryRow: Identifiable, Hashable, Sendable {
  /// Identifies the row across updates of the history.
  let id: UUID
  /// When the file was filed.
  let filedAt: Date
  /// The file's name in its inbox, before filing.
  let originalName: String
  /// The display name of the inbox the file came from.
  let inboxName: String
  /// The name the file was filed under.
  let newName: String
  /// The destination folder, as a path relative to the archive folder.
  let destination: String
}

/// The content of the History window: every filed file in chronological order, newest at the bottom.
///
/// The History step feeds `rows` from the persistent filing history.
struct HistoryWindowView: View {
  /// The filed files, oldest first.
  let rows: [HistoryRow]

  var body: some View {
    Table(rows) {
      TableColumn("Filed") { row in
        Text(row.filedAt.formatted(date: .abbreviated, time: .shortened))
      }
      TableColumn("Original name", value: \.originalName)
      TableColumn("Inbox", value: \.inboxName)
      TableColumn("New name", value: \.newName)
      TableColumn("Destination", value: \.destination)
    }
    .overlay {
      if rows.isEmpty {
        ContentUnavailableView("No files filed yet", systemImage: "clock")
          .accessibilityIdentifier("history-empty")
      }
    }
    .frame(minWidth: 720, minHeight: 360)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("history-window")
  }
}

#Preview("Sample history") {
  HistoryWindowView(rows: [
    HistoryRow(
      id: UUID(),
      filedAt: Date(timeIntervalSince1970: 2_012_890_320),
      originalName: "Rechnung_NA-33-08812.pdf",
      inboxName: "Web-Downloads",
      newName: "2033-10-13 Notenhaus Allegretto.pdf",
      destination: "Musik Margit/Noten & Bücher"
    ),
    HistoryRow(
      id: UUID(),
      filedAt: Date(timeIntervalSince1970: 2_012_890_500),
      originalName: "2033-10-11_Optik Klarblick.pdf",
      inboxName: "Scanner",
      newName: "2033-10-11 Optik Klarblick Rechnung.pdf",
      destination: "Gesundheit/Konrad/Augenarzt & Brillen"
    ),
    HistoryRow(
      id: UUID(),
      filedAt: Date(timeIntervalSince1970: 2_013_529_200),
      originalName: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
      inboxName: "Web-Downloads",
      newName: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
      destination: "Mobilität/Jahreskarte Regio Plus"
    ),
  ])
  .frame(width: 900, height: 420)
}

#Preview("Empty history") {
  HistoryWindowView(rows: [])
    .frame(width: 900, height: 420)
}
