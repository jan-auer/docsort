#if DEBUG
  import AppKit
  import OSLog
  import SwiftUI

  /// Spike tool (`inspector-glass`), debug builds only: logs how AppKit actually laid out the main window (its split
  /// views and split view items with their behaviours, frames and separator styles, the glass behind the inspector,
  /// and the toolbar's items with their frames), so the inspector's layout can be checked from the log without
  /// looking at the screen (`agent-tooling`). Frames are in window coordinates (origin bottom left).
  ///
  /// Debug messages aren't persisted; read them live with
  /// `/usr/bin/log stream --level debug --predicate 'subsystem == "org.jauer.Docsort" AND category == "window-layout"'`.
  struct WindowLayoutProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> ProbeView {
      ProbeView()
    }

    func updateNSView(_ view: ProbeView, context: Context) {}

    /// An empty view that logs its window's layout a moment after it joins the window, once laid out.
    final class ProbeView: NSView {
      override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        for delay in [1.0, 4.0] {
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.logLayout(after: delay)
          }
        }
      }

      private func logLayout(after delay: Double) {
        guard let window, let contentView = window.contentView else { return }
        func emit(_ line: String) {
          Logger.windowLayout.debug("[\(delay, privacy: .public)s] \(line, privacy: .public)")
        }
        emit(
          "window \(frame(of: contentView)), minSize \(window.minSize), contentMinSize \(window.contentMinSize), "
            + "contentLayoutRect \(window.contentLayoutRect), "
            + "titlebarSeparatorStyle \(window.titlebarSeparatorStyle.rawValue) (0 automatic, 1 none, 2 line, 3 shadow)"
        )
        let splitViews = splitViews(in: contentView)
        for splitView in splitViews {
          let panes = splitView.arrangedSubviews.map { frame(of: $0) }.joined(separator: " | ")
          emit(
            "split view \(type(of: splitView)) vertical \(splitView.isVertical) frame \(frame(of: splitView)) "
              + "panes \(panes) delegate \(splitView.delegate.map { "\(type(of: $0))" } ?? "none")")
        }
        for controller in splitViews.compactMap({ $0.delegate as? NSSplitViewController }) {
          for (index, item) in controller.splitViewItems.enumerated() {
            let view = item.viewController.view
            emit(
              "  item \(index): behavior \(item.behavior.rawValue) (0 default, 1 sidebar, 2 contentList, "
                + "3 inspector), collapsed \(item.isCollapsed), frame \(frame(of: view)), safeAreaInsets "
                + "\(view.safeAreaInsets), titlebarSeparatorStyle \(item.titlebarSeparatorStyle.rawValue), "
                + "adjustsSafeArea \(item.automaticallyAdjustsSafeAreaInsets), "
                + "thickness \(item.minimumThickness)…\(item.maximumThickness)")
            if item.behavior == .inspector {
              emit(
                "  inspector backgrounds: \(backgroundViews(around: view).joined(separator: "; "))")
            }
          }
        }
        for item in window.toolbar?.items ?? [] {
          let tracking = (item as? NSTrackingSeparatorToolbarItem).map {
            " tracking divider \($0.dividerIndex)"
          }
          emit(
            "toolbar item \(item.itemIdentifier.rawValue) (\(type(of: item)))\(tracking ?? "") label '\(item.label)' "
              + "frame \(item.view.map { frame(of: $0) } ?? "no view")")
        }
      }

      private func frame(of view: NSView) -> String {
        let rect = view.convert(view.bounds, to: nil)
        return "x \(Int(rect.minX))…\(Int(rect.maxX)) y \(Int(rect.minY))…\(Int(rect.maxY))"
      }

      /// The glass, visual-effect and background views in the inspector's pane, a few levels up and down.
      private func backgroundViews(around view: NSView) -> [String] {
        var root = view
        for _ in 0..<3 { root = root.superview ?? root }
        var found: [String] = []
        func visit(_ candidate: NSView, depth: Int) {
          let name = "\(type(of: candidate))"
          if candidate is NSVisualEffectView || candidate is NSGlassEffectView
            || name.contains("Glass")
            || name.contains("Background") || name.contains("Effect")
          {
            found.append("\(name)@\(depth) \(frame(of: candidate))")
          }
          guard depth < 8 else { return }
          for subview in candidate.subviews { visit(subview, depth: depth + 1) }
        }
        visit(root, depth: 0)
        return found
      }

      private func splitViews(in view: NSView) -> [NSSplitView] {
        let own = (view as? NSSplitView).map { [$0] } ?? []
        return own + view.subviews.flatMap { splitViews(in: $0) }
      }
    }
  }
#endif
