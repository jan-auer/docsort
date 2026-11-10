import SwiftUI

/// The divider between the preview and the filing panel: a hairline with a few points of grab area on each side;
/// dragging it left widens the panel, right narrows it, within `range`.
///
/// Accessibility: `filing-panel-divider`, adjustable in steps of 20 pt.
struct PaneDivider: View {
  /// The width of the pane trailing the divider.
  @Binding var width: Double
  /// The widths the pane can take.
  let range: ClosedRange<Double>

  /// The width the divider takes in the layout: the hairline. Its grab area overlaps the panes beside it.
  static let width = 1.0

  /// The width when the drag started.
  @State private var dragStartWidth: Double?

  var body: some View {
    Divider()
      .frame(width: Self.width)
      .frame(maxHeight: .infinity)
      .overlay {
        Color.clear
          .frame(width: 9)
          .contentShape(Rectangle())
          .pointerStyle(.columnResize)
          .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
              .onChanged { drag in
                let start = dragStartWidth ?? width.clamped(to: range)
                dragStartWidth = start
                width = (start - drag.translation.width).clamped(to: range)
              }
              .onEnded { _ in dragStartWidth = nil }
          )
      }
      .accessibilityElement()
      .accessibilityLabel("Filing panel width")
      .accessibilityValue("\(Int(width.clamped(to: range))) points")
      .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: width = (width + 20).clamped(to: range)
        case .decrement: width = (width - 20).clamped(to: range)
        @unknown default: break
        }
      }
      .accessibilityIdentifier("filing-panel-divider")
  }
}
