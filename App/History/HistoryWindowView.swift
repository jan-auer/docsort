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

#Preview("Invented history") {
  HistoryWindowView(rows: [
    HistoryRow(
      id: UUID(),
      filedAt: Date(timeIntervalSince1970: 1_768_215_600),
      originalName: "Scan 0007.pdf",
      inboxName: "Scannerablage",
      newName: "2026-01-12 Stegmiete Fantasia Ruderclub.pdf",
      destination: "Bootssteg/Fantasia Ruderclub"
    ),
    HistoryRow(
      id: UUID(),
      filedAt: Date(timeIntervalSince1970: 1_770_112_800),
      originalName: "quittung_8841.pdf",
      inboxName: "Eingangskorb",
      newName: "2026-02-03 Quittung Beispiel GmbH.pdf",
      destination: "Lieferanten/Beispiel GmbH"
    ),
    HistoryRow(
      id: UUID(),
      filedAt: Date(timeIntervalSince1970: 1_771_498_800),
      originalName: "Probeabo Bestaetigung.pdf",
      inboxName: "Eingangskorb",
      newName: "2026-02-19 Probeabo Musterfirma.pdf",
      destination: "Lieferanten/Musterfirma"
    ),
  ])
  .frame(width: 900, height: 420)
}

#Preview("Empty history") {
  HistoryWindowView(rows: [])
    .frame(width: 900, height: 420)
}
