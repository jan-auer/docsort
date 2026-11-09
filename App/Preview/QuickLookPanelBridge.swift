import AppKit
import Quartz
import SwiftUI

/// The system Quick Look panel (`QLPreviewPanel`, shared by the whole app) as ``QuickLookPanelController`` drives it.
final class SystemQuickLookPanel: QuickLookPanelPresenting {
  var isVisible: Bool {
    QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
  }

  func open() {
    // The panel looks for its controller in the key window's responder chain, where `QuickLookPanelBridge` is.
    QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
  }

  func close() {
    guard QLPreviewPanel.sharedPreviewPanelExists() else { return }
    QLPreviewPanel.shared().orderOut(nil)
  }

  func reload() {
    guard QLPreviewPanel.sharedPreviewPanelExists() else { return }
    QLPreviewPanel.shared().reloadData()
  }
}

/// Connects `QLPreviewPanel` to a ``QuickLookPanelController``: a responder placed right after the main window in its
/// responder chain, so the panel finds it whatever has focus in the window, and the panel's data source (the
/// controller's one file) and delegate (its ↑ ↓ Space Esc keys).
final class QuickLookPanelBridge: NSResponder, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
  private let controller: QuickLookPanelController

  init(controller: QuickLookPanelController) {
    self.controller = controller
    super.init()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  /// Places the bridge after `window` in its responder chain, once.
  func install(in window: NSWindow) {
    var responder: NSResponder? = window
    while let current = responder {
      if current === self { return }
      responder = current.nextResponder
    }
    nextResponder = window.nextResponder
    window.nextResponder = self
  }

  // MARK: Panel control

  // The panel calls these on the main thread; they are declared nonisolated on NSObject.
  nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
    true
  }

  nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
    MainActor.assumeIsolated {
      panel.dataSource = self
      panel.delegate = self
    }
  }

  nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
    MainActor.assumeIsolated {
      panel.dataSource = nil
      panel.delegate = nil
      controller.panelDidClose()
    }
  }

  // MARK: QLPreviewPanelDataSource

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    controller.shownURL == nil ? 0 : 1
  }

  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
    controller.shownURL.map { $0 as NSURL }
  }

  // MARK: QLPreviewPanelDelegate

  func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
    guard let event, event.type == .keyDown, let key = Self.key(for: event) else { return false }
    return controller.handle(key)
  }

  /// The panel key `event` stands for, without modifiers; `nil` for any other key.
  private static func key(for event: NSEvent) -> QuickLookPanelKey? {
    guard event.modifierFlags.isDisjoint(with: [.shift, .control, .option, .command]) else {
      return nil
    }
    switch event.specialKey {
    case .upArrow?: return .upArrow
    case .downArrow?: return .downArrow
    default:
      switch event.charactersIgnoringModifiers {
      case " ": return .space
      case "\u{1B}": return .escape
      default: return nil
      }
    }
  }
}

/// Installs a ``QuickLookPanelBridge`` for `controller` in the window it is placed in; it draws nothing. Place it in
/// the main window's view hierarchy, for example as a background.
struct QuickLookPanelHost: NSViewRepresentable {
  let controller: QuickLookPanelController

  func makeNSView(context: Context) -> HostView {
    HostView(bridge: QuickLookPanelBridge(controller: controller))
  }

  func updateNSView(_ view: HostView, context: Context) {}

  /// An empty view that installs its bridge when it joins a window.
  final class HostView: NSView {
    let bridge: QuickLookPanelBridge

    init(bridge: QuickLookPanelBridge) {
      self.bridge = bridge
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) is not supported")
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let window { bridge.install(in: window) }
    }
  }
}

extension EnvironmentValues {
  /// The main window's Quick Look panel controller; `nil` outside the main window (previews, the picker test host).
  @Entry var quickLookPanel: QuickLookPanelController?
}
