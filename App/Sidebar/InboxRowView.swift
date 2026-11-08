import AppKit
import DocsortCore
import SwiftUI

/// One file row of the inbox list: icon, middle-truncated name and relative date.
///
/// A filed file shows a green check and its new name in secondary colour; a trashed file a trash icon and its name
/// struck through; a file still downloading a cloud icon. The row's accessibility value says which ("filed",
/// "trashed", "unfiled"), and its label is always the inbox name. A file that arrived from outside docsort shows a small
/// accent dot on its icon's corner until it is first selected.
struct InboxRowView: View {
  /// The row to show.
  let row: InboxRow

  var body: some View {
    HStack(spacing: 6) {
      icon
        .frame(width: 16, height: 16)
        .overlay(alignment: .topTrailing) {
          if row.isNewArrival && row.mark == nil {
            Circle()
              .fill(.tint)
              .frame(width: 6, height: 6)
              .offset(x: 2, y: -2)
              .accessibilityHidden(true)
          }
        }
      Text(shownName)
        .lineLimit(1)
        .truncationMode(.middle)
        .strikethrough(row.mark?.isTrashed == true)
        .foregroundStyle(row.mark == nil ? .primary : .secondary)
      Spacer(minLength: 4)
      Text(row.item.modificationDate, format: .relative(presentation: .named))
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .help(tooltip)
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isStaticText)
    .accessibilityLabel(row.item.name)
    .accessibilityValue(state)
    .accessibilityHint(row.isNewArrival ? "New" : "")
    .accessibilityIdentifier("sidebar-row")
  }

  @ViewBuilder private var icon: some View {
    switch row.mark {
    case .filed:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .trashed:
      Image(systemName: "trash")
        .foregroundStyle(.secondary)
    case nil:
      if row.item.isIncompleteDownload {
        Image(systemName: "icloud.and.arrow.down")
          .foregroundStyle(.secondary)
      } else {
        Image(nsImage: NSWorkspace.shared.icon(forFile: row.item.url.path(percentEncoded: false)))
          .resizable()
      }
    }
  }

  /// The name shown: the new name once filed, the inbox name otherwise.
  private var shownName: String {
    row.currentURL.lastPathComponent
  }

  private var tooltip: String {
    switch row.mark {
    case .filed(_, let destinationPath, _, _): "→ \(destinationPath)/\(shownName)"
    case .trashed: "\(row.item.name) (moved to the Trash)"
    case nil: row.item.name
    }
  }

  /// The row's state for accessibility and UI tests.
  private var state: String {
    switch row.mark {
    case .filed: "filed"
    case .trashed: "trashed"
    case nil: row.item.isIncompleteDownload ? "downloading" : "unfiled"
    }
  }
}

#if DEBUG
  #Preview {
    List(SampleInboxes.library().orderedRows) { row in
      InboxRowView(row: row)
    }
    .listStyle(.sidebar)
    .frame(width: 260, height: 200)
  }
#endif
