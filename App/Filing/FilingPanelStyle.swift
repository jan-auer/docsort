import AppKit
import SwiftUI

/// The filing panel's spacing, shapes and colours in one place (`docs/design/ux.md`, "Filing panel look"), so its
/// parts share one rhythm: 20 pt margins and 20 pt between sections, 8 pt between a title and what it titles, and
/// concentric corners derived from one outer radius.
enum FilingPanelStyle {
  /// The panel's leading and trailing margin.
  static let margin: CGFloat = 20
  /// The space between two sections (Destination, Files in …, Name).
  static let sectionSpacing: CGFloat = 20
  /// The space between a section's title and its control.
  static let titleSpacing: CGFloat = 8

  /// The corner radius of a well (the folder list, Folder contents, the status strip).
  static let wellRadius: CGFloat = 10
  /// The inset of rows inside a well.
  static let wellInset: CGFloat = 5
  /// The corner radius of a highlighted row, concentric with its well.
  static let rowRadius: CGFloat = wellRadius - wellInset
  /// The height of a row in either list.
  static let rowHeight: CGFloat = 24
  /// The leading and trailing padding inside a row.
  static let rowPadding: CGFloat = 7
  /// The space between a row's icon and its text.
  static let rowIconSpacing: CGFloat = 7

  /// The panel's own background: the window colour, so the white (in dark mode: darker) wells stand out from it.
  static let background = Color(nsColor: .windowBackgroundColor)
  /// The background of wells and fields.
  static let wellBackground = Color(nsColor: .controlBackgroundColor)
  /// The hairline around wells and fields.
  static let wellBorder = Color(nsColor: .separatorColor)
}

/// A rounded well on the panel's background, holding a list or a notice (``FilingPanelStyle``).
struct PanelWell: ViewModifier {
  private let shape = RoundedRectangle(cornerRadius: FilingPanelStyle.wellRadius)

  func body(content: Content) -> some View {
    content
      .background(FilingPanelStyle.wellBackground, in: shape)
      .clipShape(shape)
      .overlay {
        shape.strokeBorder(FilingPanelStyle.wellBorder, lineWidth: 0.5)
      }
  }
}

extension View {
  /// Puts the view in a rounded well on the panel's background (``PanelWell``).
  func panelWell() -> some View {
    modifier(PanelWell())
  }

  /// The panel's section title: Headline, primary.
  func panelSectionTitle() -> some View {
    font(.headline)
      .foregroundStyle(.primary)
      .accessibilityAddTraits(.isHeader)
  }
}
