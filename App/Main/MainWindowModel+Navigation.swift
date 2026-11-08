import DocsortCore
import Observation

/// A step through the sidebar's files.
nonisolated enum SidebarStep: Sendable {
  /// To the file above the selection.
  case previous
  /// To the file below the selection.
  case next
}

/// Moving the selection through the sidebar's files: Previous File and Next File (toolbar and View menu), and the
/// first file selected at launch.
extension MainWindowModel {
  /// The file a step from the selection lands on, in the sidebar's order: the file rows as the list shows them,
  /// skipping the files of collapsed groups, as ↑ and ↓ do. From a group's disclosure row, a step goes to the nearest
  /// file in that direction; with nothing selected, Next File goes to the first file. `nil` at the list's start or end.
  func file(_ step: SidebarStep) -> InboxItemID? {
    let rows = visibleSidebarRows
    let selectedIndex = sidebarSelection.flatMap { rows.firstIndex(of: $0) }
    let candidates: [SidebarRowID]
    switch (step, selectedIndex) {
    case (.next, let index?): candidates = Array(rows[(index + 1)...])
    case (.next, nil): candidates = rows
    case (.previous, let index?): candidates = rows[..<index].reversed()
    case (.previous, nil): candidates = []
    }
    for candidate in candidates {
      if case .item(let id) = candidate { return id }
    }
    return nil
  }

  /// Selects the file a step from the selection lands on, if there is one.
  func selectFile(_ step: SidebarStep) {
    guard let id = file(step) else { return }
    select(id)
  }

  /// The sidebar's selectable rows in display order: file rows and group disclosure rows, without the files of
  /// collapsed groups (except the selected file, so a step from it still knows where it is).
  private var visibleSidebarRows: [SidebarRowID] {
    var rows: [SidebarRowID] = []
    for section in inboxes.sections {
      guard case .listing(let entries, _) = section.content else { continue }
      for entry in entries {
        switch entry {
        case .row(let row):
          rows.append(.item(row.id))
        case .group(let group):
          rows.append(.group(group.url))
          let isCollapsed = collapsedGroups.contains(group.url)
          for row in group.rows where !isCollapsed || sidebarSelection == .item(row.id) {
            rows.append(.item(row.id))
          }
        }
      }
    }
    return rows
  }

  /// Selects the sidebar's first file once every inbox has been listed for the first time, so the preview and the
  /// filing panel show it right away. Does nothing when the user selected something first or no inbox has files, and
  /// acts once per model: later listings (live watching, Refresh) never move the selection.
  func selectFirstFileAfterInitialScan() async {
    guard !hasMadeInitialSelection else { return }
    let inboxes = inboxes
    for await isEveryInboxListed in Observations({ Self.isEveryInboxListed(inboxes.sections) }) {
      if isEveryInboxListed { break }
    }
    guard !Task.isCancelled, !hasMadeInitialSelection else { return }
    hasMadeInitialSelection = true
    guard sidebarSelection == nil, let first = inboxes.orderedRows.first else { return }
    select(first.id)
  }

  /// Whether `sections` lists every configured inbox (or says why it can't): at least one inbox, none still being
  /// scanned for the first time.
  private static func isEveryInboxListed(_ sections: [InboxSection]) -> Bool {
    !sections.isEmpty
      && sections.allSatisfy { section in
        if case .scanning = section.content { false } else { true }
      }
  }
}
