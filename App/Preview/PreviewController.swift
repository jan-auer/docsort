import AppKit
import Observation
import PDFKit

/// Where the reader is in a PDF: the page shown most prominently and how many pages there are.
nonisolated struct PDFPagePosition: Equatable, Sendable {
  /// The current page, counted from 1.
  let pageNumber: Int
  /// The number of pages in the document.
  let pageCount: Int
}

/// The commands the window offers on the preview (zoom, scroll by page) and whether each is available now.
///
/// The window owns one controller and hands it to `PreviewView`. The commands act on the PDF view while a PDF is
/// shown; for Quick Look and the other states they do nothing, and the `can…` properties are `false` so menu items
/// can be disabled.
@Observable
final class PreviewController {
  /// The direction of a page-sized scroll step.
  private enum ScrollDirection {
    case down
    case up
  }

  /// The page position in the shown PDF; `nil` while no PDF is shown.
  private(set) var pagePosition: PDFPagePosition?
  /// Whether zooming applies to what is shown, which is the case for PDFs only.
  private(set) var isZoomAvailable = false
  /// Whether `zoomIn()` would enlarge the page.
  private(set) var canZoomIn = false
  /// Whether `zoomOut()` would shrink the page.
  private(set) var canZoomOut = false
  /// Whether `zoomToFit()` would change the scale, that is the page is zoomed away from fit-to-width.
  private(set) var canZoomToFit = false
  /// Whether `scrollPageDown()` and `scrollPageUp()` apply to what is shown.
  private(set) var canScrollByPage = false

  /// The PDF view of the shown PDF, set by `PDFPreview` while it is on screen.
  @ObservationIgnored private weak var pdfView: PDFView?
  /// Notification observers on `pdfView`, removed when it detaches.
  @ObservationIgnored private var pdfViewObservers: [any NSObjectProtocol] = []
  /// The clip view of `pdfView`'s scroll view, whose scrolling `clipViewObserver` follows.
  @ObservationIgnored private weak var observedClipView: NSClipView?
  /// The observer of `observedClipView`'s bounds changes.
  @ObservationIgnored private var clipViewObserver: (any NSObjectProtocol)?

  /// Enlarges the PDF by one step and leaves fit-to-width.
  func zoomIn() {
    pdfView?.zoomIn(nil)
  }

  /// Shrinks the PDF by one step and leaves fit-to-width.
  func zoomOut() {
    pdfView?.zoomOut(nil)
  }

  /// Returns the PDF to fit-to-width, which then follows the column's width again.
  func zoomToFit() {
    pdfView?.autoScales = true
  }

  /// Scrolls the PDF down by one screenful, keeping a small overlap like Page Down in other apps.
  func scrollPageDown() {
    scrollByPage(.down)
  }

  /// Scrolls the PDF up by one screenful, keeping a small overlap like Page Up in other apps.
  func scrollPageUp() {
    scrollByPage(.up)
  }

  /// Makes `view` the PDF view the commands act on. `PDFPreview` calls this when it creates or updates its view;
  /// attaching the already attached view does nothing.
  func attach(_ view: PDFView) {
    guard view !== pdfView else { return }
    removeObservers()
    pdfView = view
    let names: [Notification.Name] = [
      .PDFViewDocumentChanged, .PDFViewPageChanged, .PDFViewScaleChanged,
    ]
    pdfViewObservers = names.map { name in
      observeOnMain(name, of: view)
    }
    // Deferred, so that attaching from inside a SwiftUI view update does not change observed state during it.
    Task { refreshState() }
  }

  /// Stops acting on `view`. `PDFPreview` calls this when its view leaves the screen. A view that was already
  /// replaced by a newer one is ignored, so the order in which SwiftUI creates and dismantles views does not matter.
  func detach(_ view: PDFView) {
    guard view === pdfView else { return }
    removeObservers()
    pdfView = nil
    refreshState()
  }

  /// Registers an observer that refreshes the observed state after `name` is posted by `object`.
  private func observeOnMain(_ name: Notification.Name, of object: NSObject) -> any NSObjectProtocol
  {
    NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) {
      [weak self] _ in
      Task { @MainActor in self?.refreshState() }
    }
  }

  /// Observes scrolling of the PDF view's clip view, which `PDFViewPageChanged` does not report for programmatic
  /// scrolling. PDFView may set up its scroll view only once it has a document, so this is checked on every refresh.
  private func observeClipView() {
    let clipView = pdfView?.documentView?.enclosingScrollView?.contentView
    guard clipView !== observedClipView else { return }
    if let clipViewObserver {
      NotificationCenter.default.removeObserver(clipViewObserver)
    }
    observedClipView = clipView
    clipViewObserver = clipView.map { observeOnMain(NSView.boundsDidChangeNotification, of: $0) }
  }

  private func removeObservers() {
    for observer in pdfViewObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    pdfViewObservers = []
    if let clipViewObserver {
      NotificationCenter.default.removeObserver(clipViewObserver)
    }
    clipViewObserver = nil
    observedClipView = nil
  }

  /// The page under the centre of the PDF view, which is the page the reader is looking at. `PDFView.currentPage`
  /// is not used: it does not follow programmatic scrolling such as `scrollPageDown()`.
  private static func visiblePage(in view: PDFView) -> PDFPage? {
    view.page(for: NSPoint(x: view.bounds.midX, y: view.bounds.midY), nearest: true)
      ?? view.currentPage
  }

  /// Copies the PDF view's state into the observed properties, assigning only what changed so that observers are
  /// not woken for nothing.
  private func refreshState() {
    observeClipView()
    let document = pdfView?.document
    let hasDocument = document != nil
    let newPagePosition: PDFPagePosition? =
      if let document, let pdfView, let page = Self.visiblePage(in: pdfView) {
        PDFPagePosition(pageNumber: document.index(for: page) + 1, pageCount: document.pageCount)
      } else {
        nil
      }
    let newCanZoomIn = hasDocument && (pdfView?.canZoomIn ?? false)
    let newCanZoomOut = hasDocument && (pdfView?.canZoomOut ?? false)
    let newCanZoomToFit = hasDocument && !(pdfView?.autoScales ?? true)

    if pagePosition != newPagePosition { pagePosition = newPagePosition }
    if isZoomAvailable != hasDocument { isZoomAvailable = hasDocument }
    if canScrollByPage != hasDocument { canScrollByPage = hasDocument }
    if canZoomIn != newCanZoomIn { canZoomIn = newCanZoomIn }
    if canZoomOut != newCanZoomOut { canZoomOut = newCanZoomOut }
    if canZoomToFit != newCanZoomToFit { canZoomToFit = newCanZoomToFit }
  }

  /// Scrolls the PDF view's scroll view by its visible height minus the scroll view's page overlap.
  ///
  /// PDFView exposes no page-wise scroll call (`goToNextPage(_:)` jumps to page starts, which skips most of a page
  /// that is taller than the view), so this moves the clip view directly.
  private func scrollByPage(_ direction: ScrollDirection) {
    guard let documentView = pdfView?.documentView,
      let scrollView = documentView.enclosingScrollView
    else {
      return
    }
    let clipView = scrollView.contentView
    let step = max(clipView.bounds.height - scrollView.verticalPageScroll, 0)
    // The clip view's bounds use the document view's coordinates, so "down" is +y only in a flipped document view.
    let downward: CGFloat = documentView.isFlipped ? 1 : -1
    let sign: CGFloat =
      switch direction {
      case .down: downward
      case .up: -downward
      }
    var target = clipView.bounds
    target.origin.y += sign * step
    clipView.scroll(to: clipView.constrainBoundsRect(target).origin)
    scrollView.reflectScrolledClipView(clipView)
  }
}
