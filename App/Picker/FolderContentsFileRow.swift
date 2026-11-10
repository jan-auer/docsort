import AppKit
import DocsortCore
import SwiftUI
import UniformTypeIdentifiers

/// One file in Folder contents: its icon and name, in the same row style as the folder list. A click selects it, a
/// double-click uses its name.
struct FolderContentsFileRow: View {
  let file: FolderFile
  /// How the row shows the selection.
  let highlight: RowHighlight
  /// Whether the file's name conflicts with the name field's (highlighted in the warning colour).
  let isConflict: Bool
  let select: () -> Void
  let useName: () -> Void

  var body: some View {
    HStack(spacing: FilingPanelStyle.rowIconSpacing) {
      Image(nsImage: Self.icon(for: file.name))
        .resizable()
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
      Text(file.name)
        .fontWeight(isConflict ? .semibold : .regular)
        .foregroundStyle(highlight.textTone.primary)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, FilingPanelStyle.rowPadding)
    .frame(height: FilingPanelStyle.rowHeight)
    .background(background, in: RoundedRectangle(cornerRadius: FilingPanelStyle.rowRadius))
    .contentShape(Rectangle())
    .onTapGesture {
      // One gesture for both, so a single click selects at once instead of waiting out the double-click interval;
      // the second click of a double click carries a click count of 2.
      if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
        useName()
      } else {
        select()
      }
    }
    .help("Double-click to use this name")
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(file.name)
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Uses this name for the file")
    .accessibilityAddTraits(highlight.isHighlighted ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(.default, useName)
    .accessibilityIdentifier("folder-contents-file")
  }

  /// The selection's background, else the warning colour for the conflicting file.
  private var background: Color {
    if highlight.isHighlighted { return highlight.background }
    return isConflict ? Color(nsColor: .systemOrange).opacity(0.3) : .clear
  }

  private var accessibilityValue: String {
    [highlight.isHighlighted ? "selected" : nil, isConflict ? "conflict" : nil]
      .compactMap { $0 }.joined(separator: ", ")
  }

  /// The Finder icon for files named like `name`, from its extension alone (the file itself is not read).
  private static func icon(for name: String) -> NSImage {
    let fileExtension = (name as NSString).pathExtension
    let type = UTType(filenameExtension: fileExtension) ?? .data
    return NSWorkspace.shared.icon(for: type)
  }
}
