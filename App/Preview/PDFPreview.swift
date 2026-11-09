import OSLog
import PDFKit
import SwiftUI

/// A PDF shown with PDFKit: continuous vertical scroll, fit-to-width with a margin around each page, visible page
/// breaks.
///
/// The view is reused when `document` changes, which resets the zoom to fit-to-width and scrolls to the first page.
/// While on screen, the `PDFView` is attached to `controller`, so the window's zoom and scroll commands reach it.
/// The view may run on under a pane laid over its trailing edge (the filing panel); it keeps its pages in the part
/// left of `coveredWidth`. Use `PartlyCoveredPDFPreview` to have the pages follow an animated change of it.
struct PDFPreview: NSViewRepresentable {
  /// The margin around each page, in page units, so it scales with the zoom. At fit-to-width in a typical preview
  /// column it comes to about 16–25 points beside the page.
  static let pageMargins = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

  /// The document to show, loaded with `loadDocument(at:)`.
  let document: PDFDocument
  /// The controller the PDF view is attached to while it is on screen.
  let controller: PreviewController
  /// The width of the trailing part covered by a pane laid over the view.
  let coveredWidth: CGFloat

  /// Keeps the controller the current view is attached to, so that `dismantleNSView` can detach it.
  final class Coordinator {
    /// The controller the view is attached to.
    var controller: PreviewController

    init(controller: PreviewController) {
      self.controller = controller
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(controller: controller)
  }

  func makeNSView(context: Context) -> PartlyCoveredPDFView {
    let view = PartlyCoveredPDFView()
    view.displayMode = .singlePageContinuous
    view.displayDirection = .vertical
    view.displaysPageBreaks = true
    view.pageMargins = Self.pageMargins
    view.autoScales = true
    view.document = document
    view.coveredWidth = coveredWidth
    controller.attach(view)
    return view
  }

  func updateNSView(_ view: PartlyCoveredPDFView, context: Context) {
    view.coveredWidth = coveredWidth
    if view.document !== document {
      view.document = document
      view.autoScales = true
    }
    if context.coordinator.controller !== controller {
      context.coordinator.controller.detach(view)
      context.coordinator.controller = controller
    }
    controller.attach(view)
  }

  static func dismantleNSView(_ view: PartlyCoveredPDFView, coordinator: Coordinator) {
    coordinator.controller.detach(view)
  }
}

/// A `PDFPreview` whose covered width animates: while the filing panel slides in or out, the width
/// reaches the PDF view frame by frame, so the pages refit along with the slide, as they did when the preview itself
/// resized. (A representable that adopts `Animatable` itself gets only the final value; a view with a body gets every
/// frame's.)
struct PartlyCoveredPDFPreview: View, Animatable {
  /// The document to show.
  let document: PDFDocument
  /// The controller the PDF view is attached to while it is on screen.
  let controller: PreviewController
  /// The width of the trailing part covered by the panel.
  var coveredWidth: CGFloat

  /// The covered width, interpolated while it animates.
  var animatableData: CGFloat {
    get { coveredWidth }
    set { coveredWidth = newValue }
  }

  var body: some View {
    PDFPreview(document: document, controller: controller, coveredWidth: coveredWidth)
  }
}

extension PDFPreview {
  /// Why a file could not be shown as a PDF.
  nonisolated enum LoadError: LocalizedError {
    /// The file was read but PDFKit could not parse it.
    case unparsablePDF(fileName: String)

    var errorDescription: String? {
      switch self {
      case .unparsablePDF(let fileName):
        String(localized: "“\(fileName)” is not a readable PDF.")
      }
    }
  }

  /// Reads and parses the PDF at `url` off the main actor, so that a large file never stalls the UI.
  ///
  /// `PDFDocument` is not `Sendable`. It is safe to create on one thread and use on another as long as only one
  /// thread uses it at a time. This function creates the document, does not keep any reference to it, and returns it
  /// as `sending`, so the compiler checks that ownership passes to the caller whole and nothing here can touch it
  /// afterwards. Parsing therefore happens off the main actor too, not only the file read.
  @concurrent static func loadDocument(at url: URL) async throws -> sending PDFDocument {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard let document = PDFDocument(data: data) else {
      throw LoadError.unparsablePDF(fileName: url.lastPathComponent)
    }
    return document
  }
}

#if DEBUG
  #Preview("Two-page invoice") {
    @Previewable @State var controller = PreviewController()
    @Previewable @State var document: PDFDocument?
    Group {
      if let document {
        PDFPreview(document: document, controller: controller, coveredWidth: 0)
      } else {
        ProgressView()
      }
    }
    .frame(width: 520, height: 640)
    .task {
      do {
        document = try await PDFPreview.loadDocument(at: PreviewSampleFiles.invoicePDF())
      } catch {
        Logger.preview.error("Sample PDF failed to load: \(error.localizedDescription)")
      }
    }
  }
#endif
