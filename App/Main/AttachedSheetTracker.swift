import AppKit
import SwiftUI

/// Reports whether a sheet (the keyboard shortcuts sheet, an alert, the Rename dialog) is attached to a window, from
/// AppKit's sheet notifications.
///
/// While one is, the main window's menu commands are off: the menu bar sees ⌘ keys before the sheet's text field
/// does, so ⌘⌫ (delete to the start of the line) would otherwise move the selected file to the Trash.
@MainActor
final class AttachedSheetTracker {
  /// The window whose sheets are tracked; changing it from one window to another (or none) reports `false`.
  weak var window: NSWindow? {
    didSet {
      guard window !== oldValue else { return }
      observe(window)
      if oldValue != nil { onChange(false) }
    }
  }

  /// Called with `true` when a sheet begins on the window and `false` when it ends.
  private let onChange: @MainActor (Bool) -> Void
  private var observers: [any NSObjectProtocol] = []

  init(onChange: @escaping @MainActor (Bool) -> Void) {
    self.onChange = onChange
  }

  isolated deinit {
    stopObserving()
  }

  private func observe(_ window: NSWindow?) {
    stopObserving()
    guard let window else { return }
    let center = NotificationCenter.default
    let changes: [(Notification.Name, Bool)] = [
      (NSWindow.willBeginSheetNotification, true), (NSWindow.didEndSheetNotification, false),
    ]
    observers = changes.map { name, isAttached in
      center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.onChange(isAttached) }
      }
    }
  }

  private func stopObserving() {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers = []
  }
}

/// An invisible view that keeps `MainWindowModel.isSheetAttached` up to date for the window it is placed in.
struct AttachedSheetObserver: NSViewRepresentable {
  let model: MainWindowModel

  func makeNSView(context: Context) -> TrackingView {
    TrackingView(tracker: AttachedSheetTracker { [weak model] in model?.isSheetAttached = $0 })
  }

  func updateNSView(_ view: TrackingView, context: Context) {}

  /// Hands its window to the tracker whenever it moves into one.
  final class TrackingView: NSView {
    let tracker: AttachedSheetTracker

    init(tracker: AttachedSheetTracker) {
      self.tracker = tracker
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("TrackingView is only created in code")
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      tracker.window = window
    }
  }
}
