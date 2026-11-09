import Foundation
import Observation

/// A list whose selected file the Quick Look panel shows: the inbox sidebar or Folder contents.
///
/// `quickLookURL` must be observable (an `@Observable` property or one derived from them), so the panel follows a
/// selection changed by a click or by the list's own keys.
@MainActor
protocol QuickLookSource: AnyObject {
  /// The selected file, `nil` when nothing is selected.
  var quickLookURL: URL? { get }
  /// Moves the selection by `offset` files (↑ is `-1`, ↓ is `1`), as the list's own arrow keys do.
  func moveQuickLookSelection(by offset: Int)
}

/// The system Quick Look panel, as ``QuickLookPanelController`` drives it; a fake stands in for it in tests.
@MainActor
protocol QuickLookPanelPresenting: AnyObject {
  /// Whether the panel is on screen.
  var isVisible: Bool { get }
  /// Shows the panel; it asks the controller for its file.
  func open()
  /// Closes the panel.
  func close()
  /// Makes the panel ask the controller for its file again.
  func reload()
}

/// A key pressed while the Quick Look panel is the key window.
enum QuickLookPanelKey: Hashable, Sendable {
  case upArrow
  case downArrow
  case space
  case escape
}

/// The one Quick Look panel of the main window, shared by the inbox sidebar and Folder contents
/// (`docs/design/ux.md`, "Quick Look").
///
/// Space in a list calls ``toggle(for:)``: the panel opens on the list's selected file, or closes when it is open.
/// While it is open, ↑ and ↓ move the list's selection and the panel follows, as in Finder; Space or Esc closes it.
/// The panel shows one file, the selection, and follows it until it closes. ``QuickLookPanelBridge`` connects it to
/// `QLPreviewPanel`.
@MainActor
final class QuickLookPanelController {
  /// The file the panel shows; `nil` while it is closed.
  private(set) var shownURL: URL?

  private let panel: any QuickLookPanelPresenting
  /// The list the panel follows while it is open.
  private var source: (any QuickLookSource)?
  /// Counts the lists followed, so an observation of an earlier one is dropped.
  private var sourceNumber = 0

  /// A controller showing files in `panel`.
  init(panel: any QuickLookPanelPresenting) {
    self.panel = panel
  }

  /// Space in `source`: opens the panel on its selected file, or closes the panel when it is open (from either list).
  /// Nothing happens while nothing is selected.
  func toggle(for source: any QuickLookSource) {
    if panel.isVisible {
      close()
    } else {
      show(for: source)
    }
  }

  /// Quick Look in a file's menu: shows `source`'s selected file, opening the panel or moving it to that list.
  func show(for source: any QuickLookSource) {
    guard let url = source.quickLookURL else { return }
    self.source = source
    sourceNumber += 1
    shownURL = url
    observe(source, number: sourceNumber)
    if panel.isVisible {
      panel.reload()
    } else {
      panel.open()
    }
  }

  /// A key pressed in the panel; returns whether it was handled (the panel handles the others itself).
  @discardableResult
  func handle(_ key: QuickLookPanelKey) -> Bool {
    switch key {
    case .upArrow, .downArrow:
      guard let source else { return false }
      source.moveQuickLookSelection(by: key == .upArrow ? -1 : 1)
      follow(source)
      return true
    case .space, .escape:
      close()
      return true
    }
  }

  /// The panel closed (on its own, for example with its close button): stops following the list.
  func panelDidClose() {
    source = nil
    shownURL = nil
  }

  private func close() {
    panelDidClose()
    if panel.isVisible { panel.close() }
  }

  /// Shows `source`'s selection, or closes the panel when it has none.
  private func follow(_ source: any QuickLookSource) {
    guard let url = source.quickLookURL else {
      close()
      return
    }
    guard url != shownURL else { return }
    shownURL = url
    panel.reload()
  }

  /// Follows `source`'s selection until the panel closes or follows another list.
  private func observe(_ source: any QuickLookSource, number: Int) {
    withObservationTracking {
      _ = source.quickLookURL
    } onChange: { [weak self] in
      // Called before the change is stored, so the new selection is read on a later turn.
      Task { @MainActor [weak self] in
        guard let self, number == self.sourceNumber, let source = self.source else { return }
        self.follow(source)
        if let source = self.source { self.observe(source, number: number) }
      }
    }
  }
}
