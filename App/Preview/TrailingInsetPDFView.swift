import OSLog
import PDFKit

/// A PDF view whose trailing part is covered by a pane laid over it (the filing panel), and which keeps its pages in
/// the uncovered part: fit-to-width fits the uncovered width, pages centre in it, and scrolling never leaves a page
/// edge under the pane.
///
/// Set the covered width with `trailingInset`. It becomes the view's trailing safe-area inset, which PDFView passes
/// on to its scroll view's content insets (as it does with the toolbar's inset at the top, automatically), so the
/// scroll view, its scroller and its centring keep to the uncovered part. PDFView doesn't refit to fit-to-width
/// when only its insets change, so this view does it after each layout that follows a change. Measured on macOS 27
/// (Apple DTS calls centring a PDFView in an inset area "a real framework gap" in developer forums thread 821091;
/// they tried the scroll view's insets directly, which PDFView resets).
final class TrailingInsetPDFView: PDFView {
  /// The width of the trailing part covered by another pane.
  var trailingInset: CGFloat = 0 {
    didSet {
      guard trailingInset != oldValue else { return }
      var insets = additionalSafeAreaInsets
      insets.right = trailingInset
      additionalSafeAreaInsets = insets
      // A change of the additional safe-area insets alone doesn't lay the view out again.
      needsLayout = true
    }
  }

  /// The trailing inset the page scale was last fitted to.
  private var fittedTrailingInset: CGFloat?

  override func layout() {
    super.layout()
    guard trailingInset != fittedTrailingInset else { return }
    fittedTrailingInset = trailingInset
    // The scroll view takes the new content insets in its own layout, which AppKit runs after this one; fitting
    // before it would fit the previous width.
    documentView?.enclosingScrollView?.layoutSubtreeIfNeeded()
    if autoScales {
      // Re-enabling fit-to-width refits to the scroll view's inset width; setting it while on does nothing.
      autoScales = false
      autoScales = true
    }
    if let scrollView = documentView?.enclosingScrollView {
      Logger.preview.debug(
        "PDF view fitted to trailing inset \(self.trailingInset): content insets top \(scrollView.contentInsets.top), right \(scrollView.contentInsets.right), width \(self.bounds.width), scale \(self.scaleFactor)"
      )
    }
  }
}
