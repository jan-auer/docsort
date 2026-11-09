import AppKit
import Foundation
import PDFKit
import Testing

@testable import Docsort

/// A PDF made in code with one blank page per given size, in points.
private func makeDocument(pageSizes: [CGSize]) throws -> PDFDocument {
  let data = NSMutableData()
  var firstBox = CGRect(origin: .zero, size: pageSizes[0])
  let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
  let context = try #require(CGContext(consumer: consumer, mediaBox: &firstBox, nil))
  for size in pageSizes {
    var box = CGRect(origin: .zero, size: size)
    let pageInfo =
      [kCGPDFContextMediaBox as String: NSData(bytes: &box, length: MemoryLayout<CGRect>.size)]
      as CFDictionary
    context.beginPDFPage(pageInfo)
    context.endPDFPage()
  }
  context.closePDF()
  return try #require(PDFDocument(data: data as Data))
}

/// A4 portrait and landscape, in points.
private let portrait = CGSize(width: 595, height: 842)
private let landscape = CGSize(width: 842, height: 595)

@MainActor
@Suite("PDF view under a covering pane")
struct PartlyCoveredPDFViewTests {
  /// The view's width, as a preview column with the filing panel over its trailing part.
  private let viewWidth = 1000.0
  /// The width the panel covers.
  private let coveredWidth = 300.0
  /// The margins around each page, as the app sets them.
  private let pageMargins = PDFPreview.pageMargins

  /// A fit-to-width PDF view in an offscreen window, set up as `PDFPreview` sets up its view.
  private func makeView(document: PDFDocument) -> (view: PartlyCoveredPDFView, window: NSWindow) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: viewWidth, height: 700), styleMask: [.titled],
      backing: .buffered, defer: false)
    // ARC owns the window; released on close as well, it would be released twice and crash the test host.
    window.isReleasedWhenClosed = false
    let view = PartlyCoveredPDFView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: 700))
    view.displayMode = .singlePageContinuous
    view.displaysPageBreaks = true
    view.pageMargins = pageMargins
    view.autoScales = true
    window.contentView = view
    view.document = document
    view.coveredWidth = coveredWidth
    settle(view)
    return (view, window)
  }

  /// Lays the view out until the refit and the scale change it posts have both been handled.
  private func settle(_ view: PDFView) {
    for _ in 0..<4 {
      view.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }
  }

  @Test("the right margin reserves the covered width at the current scale")
  func rightMarginReservesCoveredWidth() throws {
    let (view, window) = makeView(document: try makeDocument(pageSizes: [landscape, portrait]))
    defer { window.close() }

    #expect(
      abs(view.pageBreakMargins.right - (pageMargins.right + coveredWidth / view.scaleFactor)) < 0.5
    )
  }

  @Test("fit-to-width fits the widest page and its margins into the uncovered width")
  func scaleFitsUncoveredWidth() throws {
    let (view, window) = makeView(document: try makeDocument(pageSizes: [landscape, portrait]))
    defer { window.close() }

    let fittedScale =
      (viewWidth - coveredWidth) / (landscape.width + pageMargins.left + pageMargins.right)
    #expect(abs(view.scaleFactor - fittedScale) < 0.005)
  }

  @Test("a document with a different widest page gets new margins")
  func newDocumentRefitsMargins() throws {
    let (view, window) = makeView(document: try makeDocument(pageSizes: [landscape, portrait]))
    defer { window.close() }
    let landscapeMargin = view.pageBreakMargins.right

    view.document = try makeDocument(pageSizes: [portrait, portrait])
    view.autoScales = true
    settle(view)

    let fittedScale =
      (viewWidth - coveredWidth) / (portrait.width + pageMargins.left + pageMargins.right)
    #expect(abs(view.scaleFactor - fittedScale) < 0.005)
    #expect(abs(view.pageBreakMargins.right - landscapeMargin) > 1)
    #expect(
      abs(view.pageBreakMargins.right - (pageMargins.right + coveredWidth / view.scaleFactor)) < 0.5
    )
  }
}
