import DocsortCore
import SwiftUI

/// The content of the History window: every move and trash in chronological order, newest at the bottom, grouped by
/// day, with a search field filtering all columns, the selected entry's file and actions in an inspector, and
/// a footer under the table counting the entries.
///
/// The list is read when the window appears or becomes active again, and after each action.
struct HistoryWindowView: View {
  @Bindable var model: HistoryModel

  @Environment(\.appearsActive) private var appearsActive
  @Environment(\.dismissWindow) private var dismissWindow

  var body: some View {
    VStack(spacing: 0) {
      table
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      footer
    }
    .inspector(isPresented: .constant(true)) {
      HistoryDetailPane(model: model)
        .inspectorColumnWidth(min: 260, ideal: 300, max: 440)
    }
    .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search")
    .frame(minWidth: 820, minHeight: 360)
    .task(id: appearsActive) {
      if appearsActive { await model.refresh() }
    }
    .alert(
      moveBackConflictTitle, isPresented: isMoveBackConflictPresented,
      presenting: model.moveBackConflict
    ) { conflict in
      Button("Keep Both") { Task { await model.resolve(conflict) } }
        .keyboardShortcut(.defaultAction)
      Button("Cancel", role: .cancel) {}
    } message: { conflict in
      Text(
        "Something else is now at \(DisplayPath.abbreviating(conflict.blockingURL.path(percentEncoded: false))). Keep Both moves the file back under a numbered name."
      )
    }
    .alert(
      model.alert?.title ?? "", isPresented: isAlertPresented, presenting: model.alert
    ) { _ in
      Button("OK", role: .cancel) {}
    } message: { alert in
      Text(alert.message)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("history-window")
  }

  private var table: some View {
    Table(of: HistoryEntry.self, selection: $model.selection) {
      TableColumn("Filed") { entry in
        Text(entry.date, format: .dateTime.hour().minute())
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      .width(min: 44, ideal: 52, max: 80)
      TableColumn("Original name") { entry in
        Text(entry.originalName)
          .foregroundStyle(entry.isCurrent ? .primary : .secondary)
          .help(entry.originalName)
          .accessibilityIdentifier("history-original-name")
      }
      .width(min: 120, ideal: 220)
      TableColumn("Inbox") { entry in
        Text(entry.inboxName ?? "—")
          .foregroundStyle(entry.isCurrent ? .primary : .secondary)
      }
      .width(min: 60, ideal: 100)
      TableColumn("New name") { entry in
        HStack(spacing: 5) {
          if let tag = HistoryModel.tag(for: entry) {
            HistoryTag(text: tag)
          }
          Text(entry.newName ?? "—")
            .foregroundStyle(entry.isCurrent ? .primary : .secondary)
            .help(entry.newName ?? "")
        }
      }
      .width(min: 120, ideal: 220)
      TableColumn("Destination") { entry in
        HStack(spacing: 6) {
          Text(entry.destination)
            .help(entry.destination)
          if entry.place == .movedOrDeleted {
            Text("Moved or deleted since")
              .font(.caption)
              .foregroundStyle(.orange)
              .fixedSize()
          }
        }
      }
      .width(min: 120, ideal: 220)
    } rows: {
      ForEach(model.days) { day in
        Section {
          ForEach(day.entries) { entry in
            TableRow(entry)
          }
        } header: {
          Text(day.title(now: .now, calendar: model.calendar))
        }
      }
    }
    .contextMenu(forSelectionType: HistoryEntry.ID.self) { ids in
      if ids.count == 1, let id = ids.first, let entry = model.entry(id: id) {
        HistoryEntryMenu(model: model, entry: entry)
      }
    } primaryAction: { ids in
      guard let id = ids.first, let entry = model.entry(id: id), model.canOpen(entry)
      else { return }
      FileActions.open(entry.url)
    }
    .onExitCommand {
      if model.searchText.isEmpty {
        dismissWindow(id: SceneID.history)
      } else {
        model.searchText = ""
      }
    }
    .overlay {
      emptyState
    }
    .accessibilityIdentifier("history-table")
  }

  @ViewBuilder private var emptyState: some View {
    if case .unreadable = model.historyAvailability {
      ContentUnavailableView(
        "The filing history can’t be read", systemImage: "exclamationmark.triangle",
        description: Text("Start a new history from the main window to file again."))
    } else if model.isLoaded && model.entries.isEmpty {
      ContentUnavailableView("No files filed yet", systemImage: "clock")
        .accessibilityIdentifier("history-empty")
    } else if model.isLoaded && model.filteredEntries.isEmpty {
      ContentUnavailableView.search(text: model.searchText)
    }
  }

  private var footer: some View {
    HStack(spacing: 12) {
      Text(model.countText)
        .accessibilityIdentifier("history-count")
      if let statusMessage = model.statusMessage {
        Text(statusMessage)
          .foregroundStyle(.primary)
          .lineLimit(1)
          .truncationMode(.middle)
          .accessibilityIdentifier("history-status")
      }
      Spacer(minLength: 0)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .frame(height: 24)
  }

  private var moveBackConflictTitle: String {
    guard let conflict = model.moveBackConflict else { return "" }
    let inbox = conflict.entry.inboxName ?? "its inbox"
    return "“\(conflict.entry.currentName)” can’t be moved back to \(inbox)"
  }

  private var isMoveBackConflictPresented: Binding<Bool> {
    Binding {
      model.moveBackConflict != nil
    } set: {
      if !$0 { model.moveBackConflict = nil }
    }
  }

  private var isAlertPresented: Binding<Bool> {
    Binding {
      model.alert != nil
    } set: {
      if !$0 { model.alert = nil }
    }
  }
}

/// A small bordered label before an entry's new name, such as "Renamed" or "Undone".
private struct HistoryTag: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 3)
      .overlay {
        RoundedRectangle(cornerRadius: 3)
          .strokeBorder(.separator, lineWidth: 0.5)
      }
      .fixedSize()
  }
}

#if DEBUG
  #Preview("Sample history") {
    HistoryWindowView(model: .preview(entries: HistorySampleEntries.entries))
      .frame(width: 1000, height: 520)
  }

  #Preview("Empty history") {
    HistoryWindowView(model: .preview(entries: []))
      .frame(width: 1000, height: 520)
  }
#endif
