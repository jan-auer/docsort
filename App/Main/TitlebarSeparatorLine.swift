import AppKit
import SwiftUI

/// Sets the hosting window's titlebar separator to the system line (`NSWindow.titlebarSeparatorStyle = .line`), the
/// hairline AppKit draws between the toolbar and the content, as Finder shows it. SwiftUI has no modifier for it, and
/// `scrollEdgeEffectStyle(.hard, for:)` reaches only SwiftUI scroll views, not the AppKit PDF view under the toolbar.
///
/// Place it in the window's view hierarchy, for example as a background; it draws nothing itself.
struct TitlebarSeparatorLine: NSViewRepresentable {
  func makeNSView(context: Context) -> SeparatorSettingView {
    SeparatorSettingView()
  }

  func updateNSView(_ view: SeparatorSettingView, context: Context) {
    view.applySeparatorStyle()
  }

  /// An empty view that sets its window's separator style when it joins a window.
  final class SeparatorSettingView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      applySeparatorStyle()
    }

    func applySeparatorStyle() {
      guard let window, window.titlebarSeparatorStyle != .line else { return }
      window.titlebarSeparatorStyle = .line
    }
  }
}
