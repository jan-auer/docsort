import SwiftUI

/// When a file was handled, as the status strip words it: "today 09:41", "yesterday 17:02", or the date.
nonisolated enum HandledTimeText {
  /// The wording for `date`, relative to `now` in `calendar`.
  static func text(for date: Date, relativeTo now: Date, calendar: Calendar = .current) -> String {
    var style = Date.FormatStyle(date: .omitted, time: .shortened)
    style.timeZone = calendar.timeZone
    style.calendar = calendar
    if calendar.isDate(date, inSameDayAs: now) {
      return "today \(date.formatted(style))"
    }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
      calendar.isDate(date, inSameDayAs: yesterday)
    {
      return "yesterday \(date.formatted(style))"
    }
    var dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)
    dateStyle.timeZone = calendar.timeZone
    dateStyle.calendar = calendar
    return date.formatted(dateStyle)
  }
}

/// The status banner across the top of the filing panel for a handled file: what happened to it and when, with the
/// action that returns it to its inbox at the trailing end.
///
/// A filed file shows a green check, "Filed to <destination>" (the destination middle-truncated) with the time
/// below it, and **Move Back**; a trashed file a trash icon, "Moved to Trash" with the time, and **Put Back**.
struct FilingStatusStrip: View {
  /// What the strip shows.
  enum Status {
    /// Filed to the archive-relative `destinationPath` at `date`.
    case filed(destinationPath: String, date: Date)
    /// Moved to the Trash at `date`.
    case trashed(date: Date)
  }

  /// What happened to the file.
  let status: Status
  /// The display name of the file's inbox, for the button's tooltip.
  let inboxName: String
  /// Whether the button can be used now.
  let canReturnToInbox: Bool
  /// Returns the file to its inbox.
  let returnToInbox: () -> Void
  /// The moment "today" and "yesterday" are relative to.
  var now: Date = .now

  var body: some View {
    HStack(spacing: 10) {
      icon
        .font(.title3)
      description
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("filing-strip-text")
      Spacer(minLength: 4)
      Button(buttonTitle, action: returnToInbox)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canReturnToInbox)
        .help(buttonHelp)
        .accessibilityIdentifier(buttonIdentifier)
    }
    .padding(.horizontal, FilingPanelStyle.edgeMargin)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    // Not under the window's toolbar, which spans the preview and the panel.
    .background(background, ignoresSafeAreaEdges: [])
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("filing-strip")
  }

  /// A green tint for a filed file, the list colour for a trashed one; both neutral next to the orange failures.
  private var background: Color {
    switch status {
    case .filed: Color.green.opacity(0.1)
    case .trashed: FilingPanelStyle.listBackground
    }
  }

  @ViewBuilder private var icon: some View {
    switch status {
    case .filed:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .accessibilityHidden(true)
    case .trashed:
      Image(systemName: "trash")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
  }

  /// What happened on the first line (a filed file's destination middle-truncated to the room it has), and when on a
  /// second, smaller line, so the destination isn't squeezed by the time and the button at the panel's width.
  private var description: some View {
    VStack(alignment: .leading, spacing: 1) {
      switch status {
      case .filed(let destinationPath, _):
        HStack(spacing: 4) {
          Text("Filed to")
            .fixedSize()
          Text(destinationPath)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(destinationPath)
        }
      case .trashed:
        Text("Moved to Trash")
          .lineLimit(1)
      }
      Text(HandledTimeText.text(for: date, relativeTo: now))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private var date: Date {
    switch status {
    case .filed(_, let date), .trashed(let date): date
    }
  }

  private var buttonTitle: String {
    switch status {
    case .filed: "Move Back"
    case .trashed: "Put Back"
    }
  }

  private var buttonHelp: String {
    switch status {
    case .filed: "Move back to \(inboxName) (\(MenuCommand.returnToInbox.keys.notation))"
    case .trashed: "Put back in \(inboxName) (\(MenuCommand.returnToInbox.keys.notation))"
    }
  }

  private var buttonIdentifier: String {
    switch status {
    case .filed: "filing-strip-move-back"
    case .trashed: "filing-strip-put-back"
    }
  }
}

#if DEBUG
  #Preview("Filed and trashed") {
    let now = PreviewDates.october2033(13, hour: 16)
    VStack(spacing: 0) {
      FilingStatusStrip(
        status: .filed(
          destinationPath: "Mobilität/Jahreskarte Regio Plus",
          date: PreviewDates.october2033(13, hour: 9)),
        inboxName: "Web-Downloads", canReturnToInbox: true, returnToInbox: {}, now: now)
      FilingStatusStrip(
        status: .filed(
          destinationPath: "Kommunikation/Ilmnet Internet/Rechnungen",
          date: PreviewDates.october2033(12, hour: 17)),
        inboxName: "Web-Downloads", canReturnToInbox: true, returnToInbox: {}, now: now)
      FilingStatusStrip(
        status: .trashed(date: PreviewDates.october2033(4, hour: 11)), inboxName: "Scanner",
        canReturnToInbox: true, returnToInbox: {}, now: now)
    }
    .frame(width: 340)
  }

  /// Fixed dates for the previews, inside the sample household's years.
  private enum PreviewDates {
    static func october2033(_ day: Int, hour: Int) -> Date {
      Calendar.current.date(from: DateComponents(year: 2033, month: 10, day: day, hour: hour))
        ?? .distantPast
    }
  }
#endif
