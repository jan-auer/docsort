import AppKit
import SwiftUI

/// Sets the titlebar separators of the hosting window's split view items: the system line
/// (`NSTitlebarSeparatorStyle.line`, the hairline AppKit draws between the toolbar and the content, as Finder shows it)
/// over the content, and none over the inspector, whose edge-to-edge glass runs from the window's top to its bottom
/// without a seam. SwiftUI has no modifier for either, and `scrollEdgeEffectStyle(.hard, for:)` reaches only SwiftUI
/// scroll views, not the AppKit PDF view under the toolbar.
///
/// The window's own `titlebarSeparatorStyle` stays automatic: a window style overrides the items' preferences. An item's
/// style applies only where it has a titlebar section of its own (`NSTrackingSeparatorToolbarItem`); SwiftUI adds one
/// for the inspector once the inspector declares a toolbar item.
///
/// Place it in the window's view hierarchy, for example as a background; it draws nothing itself.
struct TitlebarSeparatorLine: NSViewRepresentable {
  func makeNSView(context: Context) -> SeparatorSettingView {
    SeparatorSettingView()
  }

  func updateNSView(_ view: SeparatorSettingView, context: Context) {
    view.applySeparatorStyles()
  }

  /// An empty view that sets its window's split view items' separator styles when it joins a window and on updates.
  final class SeparatorSettingView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      applySeparatorStyles()
      // SwiftUI builds the split view items around this view; set them again once they exist.
      DispatchQueue.main.async { [weak self] in self?.applySeparatorStyles() }
    }

    func applySeparatorStyles() {
      guard let contentView = window?.contentView else { return }
      for item in Self.splitViewItems(in: contentView) {
        let style: NSTitlebarSeparatorStyle =
          switch item.behavior {
          case .inspector: .none
          case .sidebar: .automatic
          default: .line
          }
        if item.titlebarSeparatorStyle != style { item.titlebarSeparatorStyle = style }
      }
    }

    /// The items of every split view controller in `view`'s hierarchy (SwiftUI nests the navigation split view inside
    /// the split view that holds the inspector).
    private static func splitViewItems(in view: NSView) -> [NSSplitViewItem] {
      let own = ((view as? NSSplitView)?.delegate as? NSSplitViewController)?.splitViewItems ?? []
      return own + view.subviews.flatMap { splitViewItems(in: $0) }
    }
  }
}
