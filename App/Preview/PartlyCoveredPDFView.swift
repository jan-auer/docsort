import OSLog
import PDFKit

/// A PDF view whose trailing part is covered by a pane laid over it (the filing panel), and which keeps its pages in
/// the uncovered part: fit-to-width fits the uncovered width, pages centre in it, and scrolling never leaves a page
/// edge under the pane.
///
/// The covered part is reserved with the pages' right margin (`pageBreakMargins`), not with the scroll view's content
/// insets: AppKit draws the scroll edge effect under the toolbar only across the scroll view's inset content area, so a
/// right content inset would end the effect at the pane's edge. The margin is `pageMargins.right` plus the covered
/// width in page units, so it changes with the scale; PDFKit centres every page, also narrower ones in a mixed-width
/// document, between the margins. PDFView doesn't refit to fit-to-width when only its margins change, so this view
/// does it after each layout that follows a change of the covered width, the scale or the document. Measured on
/// macOS 27.
///
/// The refit posts a scale change, which asks for one more layout; that pass computes the same margins and stops at
/// the change guard in `layout()`, so the guard must stay.
final class PartlyCoveredPDFView: PDFView {
  /// The width of the trailing part covered by another pane.
  var coveredWidth: CGFloat = 0 {
    didSet {
      guard coveredWidth != oldValue else { return }
      needsLayout = true
    }
  }

  /// The margins around each page in page units, before the covered width is added on the right.
  var pageMargins = NSEdgeInsets() {
    didSet { needsLayout = true }
  }

  /// The width of the document's widest page, kept until the document changes; `layout()` runs on every frame of the
  /// panel's slide and every step of a divider drag.
  private var cachedWidestPageWidth: CGFloat?

  /// Observers of this view's scale and document changes, after which the margin is recomputed.
  private var observers: [any NSObjectProtocol] = []

  override init(frame: NSRect) {
    super.init(frame: frame)
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: .PDFViewScaleChanged, object: self, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.needsLayout = true }
      },
      center.addObserver(forName: .PDFViewDocumentChanged, object: self, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated {
          self?.cachedWidestPageWidth = nil
          self?.needsLayout = true
        }
      },
    ]
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("PartlyCoveredPDFView is created in code only")
  }

  isolated deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  override func layout() {
    super.layout()
    guard let scrollView = documentView?.enclosingScrollView else { return }
    // The scroller stays beside the covered part rather than under it.
    if scrollView.scrollerInsets.right != coveredWidth {
      var scrollerInsets = scrollView.scrollerInsets
      scrollerInsets.right = coveredWidth
      scrollView.scrollerInsets = scrollerInsets
    }
    if cachedWidestPageWidth == nil { cachedWidestPageWidth = widestPageWidth() }
    guard let widestPage = cachedWidestPageWidth, bounds.width > coveredWidth else { return }
    // At fit-to-width the scale is the one that fits the widest page and its own margins into the uncovered width;
    // otherwise it is the reader's zoom.
    let scale =
      autoScales
      ? (bounds.width - coveredWidth) / (widestPage + pageMargins.left + pageMargins.right)
      : scaleFactor
    guard scale > 0 else { return }
    var margins = pageMargins
    margins.right += coveredWidth / scale
    guard
      abs(margins.right - pageBreakMargins.right) > 0.01 || pageBreakMargins.left != margins.left
        || pageBreakMargins.top != margins.top || pageBreakMargins.bottom != margins.bottom
    else { return }
    pageBreakMargins = margins
    layoutDocumentView()
    if autoScales {
      // Re-enabling fit-to-width refits to the new margins; setting it while on does nothing.
      autoScales = false
      autoScales = true
    }
    Logger.preview.debug(
      "PDF view fitted to covered width \(self.coveredWidth): right margin \(margins.right), width \(self.bounds.width), scale \(self.scaleFactor)"
    )
  }

  /// The width of the document's widest page as displayed (rotation applied), in page units.
  private func widestPageWidth() -> CGFloat? {
    guard let document, document.pageCount > 0 else { return nil }
    return (0..<document.pageCount).compactMap { index in
      document.page(at: index).map { page in
        let box = page.bounds(for: displayBox)
        return page.rotation % 180 == 0 ? box.width : box.height
      }
    }.max()
  }
}
