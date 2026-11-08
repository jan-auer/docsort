import AppKit
import SwiftUI

/// How a picker row is highlighted: the accent colour while the picker has focus, a neutral grey while it does not
/// (as in a Finder list whose window or view is inactive).
enum RowHighlight: Hashable {
  /// Not highlighted.
  case none
  /// Highlighted while one of the picker's fields has focus.
  case focused
  /// Highlighted while focus is elsewhere; a chosen destination's row stays marked like this.
  case unfocused

  /// Whether the row is highlighted at all.
  var isHighlighted: Bool { self != .none }

  /// The row's background.
  var background: Color {
    switch self {
    case .none: .clear
    case .focused: .accentColor
    case .unfocused: Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }
  }

  /// How the row's text is coloured on this background.
  var textTone: RowTextTone {
    self == .focused ? .onAccent : .standard
  }
}

/// The colouring of a row's text: secondary parts in secondary colour, or everything in the accent's text colour.
enum RowTextTone: Hashable {
  /// Primary and secondary label colours.
  case standard
  /// On the accent background: all text in the selected-text colour.
  case onAccent

  /// The colour of the row's main text.
  var primary: Color {
    switch self {
    case .standard: .primary
    case .onAccent: Color(nsColor: .alternateSelectedControlTextColor)
    }
  }

  /// The colour of secondary text (the parent part of a path, "this folder", hints).
  var secondary: Color {
    switch self {
    case .standard: .secondary
    case .onAccent: Color(nsColor: .alternateSelectedControlTextColor).opacity(0.8)
    }
  }

  /// The colour of folder icons.
  var folderIcon: Color {
    switch self {
    case .standard: Color(nsColor: .systemBlue).opacity(0.7)
    case .onAccent: Color(nsColor: .alternateSelectedControlTextColor)
    }
  }
}

/// The text of a folder row: the display path with its parent part in secondary colour and the characters the filter
/// matched in bold.
enum FolderRowText {
  /// `folder.displayPath` styled for `tone`.
  static func displayPath(of folder: PickerFolder, tone: RowTextTone) -> AttributedString {
    let path = folder.displayPath
    var text = AttributedString(path)
    text.swiftUI.foregroundColor = tone.primary
    if tone == .standard, let slash = path.lastIndex(of: "/"),
      let nameStart = AttributedString.Index(path.index(after: slash), within: text)
    {
      text[text.startIndex..<nameStart].swiftUI.foregroundColor = tone.secondary
    }
    for range in folder.matchedRanges {
      guard let lower = AttributedString.Index(range.lowerBound, within: text),
        let upper = AttributedString.Index(range.upperBound, within: text)
      else { continue }
      text[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
      text[lower..<upper].swiftUI.foregroundColor = tone.primary
    }
    return text
  }
}

/// The small "New" badge on a pending folder's row and on the chosen token of a new folder.
struct NewBadge: View {
  let tone: RowTextTone

  var body: some View {
    Text("New")
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 5)
      .padding(.vertical, 1)
      .foregroundStyle(tone == .onAccent ? tone.primary : Color.accentColor)
      .background(
        (tone == .onAccent ? tone.primary : Color.accentColor).opacity(0.2),
        in: Capsule()
      )
      .accessibilityLabel("New folder")
  }
}

/// The plain folder icon of folder rows and the new-folder row.
struct FolderIcon: View {
  let tone: RowTextTone

  var body: some View {
    Image(systemName: "folder.fill")
      .foregroundStyle(tone.folderIcon)
      .frame(width: 16)
      .accessibilityHidden(true)
  }
}

/// The "this folder" row's icon: a folder with a downward "file here" arrow, so the row reads as "choose the folder
/// I'm in" rather than as one more child. SF Symbols has no such folder, so the arrow is drawn on the folder.
struct FileHereIcon: View {
  let tone: RowTextTone

  var body: some View {
    Image(systemName: "folder.fill")
      .foregroundStyle(tone.folderIcon)
      .overlay {
        Image(systemName: "arrow.down")
          .font(.system(size: 7, weight: .heavy))
          .foregroundStyle(
            tone == .onAccent ? Color.accentColor : Color(nsColor: .textBackgroundColor)
          )
          .offset(y: 1)
      }
      .frame(width: 16)
      .accessibilityHidden(true)
  }
}
