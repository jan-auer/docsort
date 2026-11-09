import AppKit
import SwiftUI

/// The filing panel's spacing, shapes and colours in one place (`docs/design/ux.md`, "Filing panel"), so its parts
/// share one rhythm: bars (search, footers, bottom bar) and lists on the inspector's glass, a 12 pt margin, inset
/// dividers between them, and one 24 pt row style for both lists.
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
  /// The shortest Folder contents' file list gets while expanded.
  static let contentsMinListHeight: Double = 48

  /// The window colour with a faint tint of the label colour, a step darker than the lists in light mode and a step
  /// lighter in dark mode. The panel itself no longer paints it (it sits on the inspector's glass); previews of the
  /// panel's parts use it to stand in for that glass.
  static let background = Color(nsColor: .windowBackgroundColor)
    .mix(with: Color(nsColor: .labelColor), by: 0.05)
  /// A divider inset by the bars' margin, setting the lists on the inspector's glass apart from the bars.
  static var insetDivider: some View {
    Divider().padding(.horizontal, edgeMargin)
  }
}
