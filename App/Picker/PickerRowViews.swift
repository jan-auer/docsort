import DocsortCore
import SwiftUI

/// A folder row: folder icon, the path relative to the scope (parent part secondary, matches bold), a New badge for
/// a pending folder and a chevron when the folder has subfolders.
struct PickerFolderRow: View {
  let folder: PickerFolder
  /// Whether the folder is the chosen destination (a check mark at the trailing end).
  let isChosen: Bool
  let highlight: RowHighlight
  /// Steps into the folder (the chevron's action).
  let stepIn: () -> Void

  var body: some View {
    let tone = highlight.textTone
    HStack(spacing: FilingPanelStyle.rowIconSpacing) {
      FolderIcon(tone: tone)
      Text(FolderRowText.displayPath(of: folder, tone: tone))
        .lineLimit(1)
        .truncationMode(.head)
      if folder.isNew {
        NewBadge(tone: tone)
      }
      Spacer(minLength: 0)
      if isChosen {
        ChosenMark(tone: tone)
      }
      if folder.hasSubfolders {
        Button(action: stepIn) {
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
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
  /// Whether the folder is the chosen destination (a check mark at the trailing end).
  let isChosen: Bool
  let highlight: RowHighlight

  var body: some View {
    let tone = highlight.textTone
    HStack(spacing: FilingPanelStyle.rowIconSpacing) {
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
      if isChosen {
        ChosenMark(tone: tone)
      }
    }
  }
}

/// The check mark on the chosen destination's row.
struct ChosenMark: View {
  let tone: RowTextTone

  var body: some View {
    Image(systemName: "checkmark")
      .font(.body.weight(.semibold))
      .foregroundStyle(tone == .onAccent ? tone.primary : Color.accentColor)
      .accessibilityHidden(true)
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
    HStack(alignment: .firstTextBaseline, spacing: FilingPanelStyle.rowIconSpacing) {
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
            .font(.subheadline)
            .foregroundStyle(tone.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 0)
      Text("⇧⌘N")
        .font(.subheadline)
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
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: FilingPanelStyle.rowHeight, alignment: .leading)
  }
}

/// A section header inside a list ("Recent", "All folders"): Subheadline, semibold, secondary, on the rows' leading
/// guide.
struct PickerSectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, FilingPanelStyle.rowPadding)
      .padding(.top, 6)
      .padding(.bottom, 3)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityAddTraits(.isHeader)
  }
}

/// The shared look and behaviour of a selectable picker row: padding, highlight background, click handling and the
/// accessibility element UI tests find it by (see ``DestinationPickerView`` for the scheme).
struct PickerRowChrome: ViewModifier {
  let identifier: String
  /// The row's text as the user reads it.
  let label: String
  let highlight: RowHighlight
  /// Whether the row is the chosen destination.
  var isChosen = false
  /// A single click.
  let click: () -> Void
  /// A double click.
  let open: () -> Void
  /// Extra accessibility actions (name and action), such as stepping into a folder.
  var namedActions: [(name: String, action: () -> Void)] = []

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, FilingPanelStyle.rowPadding)
      .padding(.vertical, 2)
      .frame(minHeight: FilingPanelStyle.rowHeight)
      .background(
        highlight.background, in: RoundedRectangle(cornerRadius: FilingPanelStyle.rowRadius)
      )
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
      .accessibilityValue(isChosen ? "chosen" : highlight.isHighlighted ? "highlighted" : "")
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
