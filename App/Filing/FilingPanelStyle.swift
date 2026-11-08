import AppKit
import SwiftUI

/// The filing panel's spacing, shapes and colours in one place (`docs/design/ux.md`, "Filing panel"), so its parts
/// share one rhythm: bars (search, footers, bottom bar) on the window colour with a 12 pt margin, edge-to-edge lists on
/// the content colour, and one 24 pt row style for both lists.
enum FilingPanelStyle {
  /// The margin of the bars above, between and below the edge-to-edge lists.
  static let edgeMargin: CGFloat = 12
  /// The horizontal inset of rows inside an edge-to-edge list.
  static let listInset: CGFloat = 6
  /// The corner radius of a highlighted row.
  static let rowRadius: CGFloat = 5
  /// The height of a row in either list.
  static let rowHeight: CGFloat = 24
  /// The leading and trailing padding inside a row.
  static let rowPadding: CGFloat = 7
  /// The space between a row's icon and its text.
  static let rowIconSpacing: CGFloat = 7

  /// The bars' background: the window colour.
  static let background = Color(nsColor: .windowBackgroundColor)
  /// The background of the edge-to-edge lists and of fields: the content colour, set off from the bars.
  static let listBackground = Color(nsColor: .controlBackgroundColor)
  /// The hairline around fields.
  static let fieldBorder = Color(nsColor: .separatorColor)
}
