import DocsortCore
import SwiftUI

/// A folder row: folder icon, the path relative to the scope (parent part secondary, matches bold), a New badge for
/// a pending folder and a chevron when the folder has subfolders.
struct PickerFolderRow: View {
  let folder: PickerFolder
  let highlight: RowHighlight
  /// Steps into the folder (the chevron's action).
  let stepIn: () -> Void

  var body: some View {
    let tone = highlight.textTone
    HStack(spacing: 7) {
      FolderIcon(tone: tone)
      Text(FolderRowText.displayPath(of: folder, tone: tone))
        .lineLimit(1)
        .truncationMode(.head)
      if folder.isNew {
        NewBadge(tone: tone)
      }
      Spacer(minLength: 0)
      if folder.hasSubfolders {
        Button(action: stepIn) {
          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tone.secondary)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show its subfolders (→)")
        .accessibilityLabel("Show subfolders")
      }
    }
  }
}

/// The "this folder" row inside a folder: it stands for the scope itself, so Tab chooses the folder the picker is in.
struct PickerCurrentFolderRow: View {
  /// The folder's own name.
  let title: String
  /// Whether the folder is a pending new folder.
  let isNew: Bool
  let highlight: RowHighlight

  var body: some View {
    let tone = highlight.textTone
    HStack(spacing: 7) {
      FileHereIcon(tone: tone)
      Text(title)
        .foregroundStyle(tone.primary)
        .lineLimit(1)
        .truncationMode(.middle)
      Text("this folder")
        .font(.callout)
        .foregroundStyle(tone.secondary)
        .fixedSize()
      if isNew {
        NewBadge(tone: tone)
      }
      Spacer(minLength: 0)
    }
  }
}

/// "New Folder “name” in <parent>", offered when the filter finds nothing; ⇧⌘N or choosing it creates the folder.
struct PickerCreateFolderRow: View {
  /// The tidied filter text, the name the folder gets.
  let name: String
  /// The archive-relative parent, `""` for the root.
  let parent: String
  /// Why the name cannot be used, if it cannot.
  let problem: NameProblem?
  let highlight: RowHighlight

  /// The row's text, also its accessibility label.
  var title: String {
    "New Folder “\(name)” in \(Self.parentTitle(of: parent))"
  }

  var body: some View {
    let tone = highlight.textTone
    let color = tone == .onAccent ? tone.primary : Color.accentColor
    HStack(alignment: .firstTextBaseline, spacing: 7) {
      Image(systemName: "folder.badge.plus")
        .foregroundStyle(color)
        .frame(width: 16)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .foregroundStyle(color)
          .lineLimit(1)
          .truncationMode(.middle)
        if let problem {
          Text(problem.folderNameExplanation)
            .font(.caption)
            .foregroundStyle(tone.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 0)
      Text("⇧⌘N")
        .font(.caption)
        .foregroundStyle(tone.secondary)
        .accessibilityHidden(true)
    }
  }

  /// The parent as the row names it: its path with ` › `, or ``ArchivePath/rootTitle``.
  static func parentTitle(of parent: String) -> String {
    parent.isEmpty
      ? ArchivePath.rootTitle : ArchivePath.segments(of: parent).joined(separator: " › ")
  }
}

/// An informational row that cannot be highlighted, such as "Indexing archive…".
struct PickerInfoRow: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.callout)
      .foregroundStyle(.secondary)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The shared look and behaviour of a selectable picker row: padding, highlight background, click handling and the
/// accessibility element UI tests find it by (see ``DestinationPickerView`` for the scheme).
struct PickerRowChrome: ViewModifier {
  let identifier: String
  /// The row's text as the user reads it.
  let label: String
  let highlight: RowHighlight
  /// A single click.
  let click: () -> Void
  /// A double click.
  let open: () -> Void
  /// Extra accessibility actions (name and action), such as stepping into a folder.
  var namedActions: [(name: String, action: () -> Void)] = []

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .frame(minHeight: 24)
      .background(highlight.background, in: RoundedRectangle(cornerRadius: 5))
      .contentShape(Rectangle())
      .onTapGesture {
        // One gesture for both, so a single click highlights at once instead of waiting out the double-click
        // interval; the second click of a double click carries a click count of 2.
        if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
          open()
        } else {
          click()
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(label)
      .accessibilityValue(highlight.isHighlighted ? "highlighted" : "")
      .accessibilityAddTraits(highlight.isHighlighted ? [.isButton, .isSelected] : .isButton)
      .accessibilityIdentifier(identifier)
      .accessibilityAction(.default, open)
      .accessibilityActions {
        ForEach(namedActions.indices, id: \.self) { position in
          Button(namedActions[position].name, action: namedActions[position].action)
        }
      }
  }
}
