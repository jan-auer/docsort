import OSLog
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// A file for the preview column to show, and whether its content is all on disk yet.
nonisolated struct PreviewDocument: Hashable, Sendable {
  /// Whether a file's content is fully on disk.
  enum Completeness: Hashable, Sendable {
    /// The file is complete and can be shown.
    case complete
    /// The file is still downloading or syncing (for example a `.crdownload` file or a cloud placeholder).
    case downloading
  }

  /// The file's location.
  let url: URL
  /// Whether the file can be shown yet.
  let completeness: Completeness
}

/// The preview column of the main window: the selected file shown large, with a footer of its facts.
///
/// PDFs (by type conformance to `.pdf`) render with PDFKit, everything Quick Look can show renders in a Quick Look
/// view, and other files get a "no preview" view with an "Open with" button. Incomplete files show "Downloading…",
/// missing files a short message. While a new file loads, the previous content stays in place (so the PDF view is
/// reused) and a spinner covers it once loading takes longer than 200 ms.
///
/// The view does not watch the file: to reload the same file after its content changed, give it a new identity, for
/// example with `.id(_:)`.
struct PreviewView: View {
  /// The file to show.
  let document: PreviewDocument
  /// The controller the window's zoom and scroll commands go through.
  let controller: PreviewController
  /// The width of the trailing part covered by the filing panel, which a PDF runs on under; none outside the main
  /// window.
  var trailingInset: CGFloat = 0

  /// What the preview shows for a complete file, after loading.
  private enum Content {
    /// A parsed PDF.
    case pdf(PDFDocument, PreviewFileInfo)
    /// A file Quick Look can show.
    case quickLook(PreviewFileInfo)
    /// A file neither PDFKit nor Quick Look can show.
    case unavailable(PreviewFileInfo)
    /// The file no longer exists.
    case missing(fileName: String)
    /// The file exists but its facts could not be read, for example for lack of permission.
    case unreadable(fileName: String, reason: String)
  }

  /// The content shown; `nil` before the first load and while the file is downloading.
  @State private var content: Content?
  /// Whether a load for the current `document` is under way.
  @State private var isLoading = false

  var body: some View {
    Group {
      switch document.completeness {
      case .downloading:
        DownloadingView(fileName: document.url.lastPathComponent)
      case .complete:
        ZStack {
          if let content {
            contentView(content)
          }
          if isLoading {
            DelayedLoadingIndicator()
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("preview")
    .task(id: document) {
      await load(document)
    }
  }

  @ViewBuilder private func contentView(_ content: Content) -> some View {
    switch content {
    case .pdf(let pdfDocument, let info):
      VStack(spacing: 0) {
        // The pages scroll under the window's translucent toolbar, as in Preview. The PDF view's scroll view insets
        // its content below the toolbar by itself (AppKit's automatic content insets) and AppKit draws the scroll
        // edge effect. It also runs on under the filing panel (the trailing safe area), as Keynote's canvas runs
        // under its inspector, so the edge effect spans the whole toolbar; the PDF view keeps its pages left of the
        // panel. Quick Look stays below the toolbar: it has no inset that would keep a file's top visible.
        PDFPreview(document: pdfDocument, controller: controller, trailingInset: trailingInset)
          .ignoresSafeArea(.container, edges: [.top, .trailing])
          .accessibilityIdentifier("preview-pdf")
        PreviewFooter(
          info: info,
          pagePosition: controller.pagePosition
            ?? PDFPagePosition(pageNumber: 1, pageCount: pdfDocument.pageCount)
        )
      }
    case .quickLook(let info):
      VStack(spacing: 0) {
        QuickLookPreview(url: info.url)
          .accessibilityIdentifier("preview-quicklook")
        PreviewFooter(info: info, pagePosition: nil)
      }
    case .unavailable(let info):
      NoPreviewView(info: info)
    case .missing(let fileName):
      PreviewMessageView(
        systemImage: "questionmark.folder",
        title: String(localized: "“\(fileName)” is no longer here"),
        detail: String(localized: "It was moved or deleted outside docsort.")
      )
      .accessibilityIdentifier("preview-missing")
    case .unreadable(let fileName, let reason):
      PreviewMessageView(
        systemImage: "exclamationmark.triangle",
        title: String(localized: "“\(fileName)” can’t be read"),
        detail: reason
      )
      .accessibilityIdentifier("preview-unreadable")
    }
  }

  /// Loads what to show for `document` and shows it, unless a newer document replaced it meanwhile.
  private func load(_ document: PreviewDocument) async {
    guard document.completeness == .complete else {
      content = nil
      isLoading = false
      return
    }
    isLoading = true
    let loadedContent = await Self.loadContent(for: document.url)
    // A cancelled load belongs to a document that was replaced; the newer load sets the state.
    guard !Task.isCancelled else { return }
    content = loadedContent
    isLoading = false
  }

  /// Reads the file's facts, decides how to show it and, for a PDF, parses it. File access runs off the main actor.
  private static func loadContent(for url: URL) async -> Content {
    let fileName = url.lastPathComponent
    let info: PreviewFileInfo
    do {
      info = try await PreviewFileInfo.load(from: url)
    } catch  where error.isFileMissing {
      return .missing(fileName: fileName)
    } catch {
      Logger.preview.error(
        "Reading facts of \(url.path(percentEncoded: false), privacy: .private) failed: \(error.localizedDescription)"
      )
      return .unreadable(fileName: fileName, reason: error.localizedDescription)
    }

    if info.contentType.conforms(to: .pdf) {
      do {
        return .pdf(try await PDFPreview.loadDocument(at: url), info)
      } catch  where error.isFileMissing {
        return .missing(fileName: fileName)
      } catch {
        Logger.preview.error(
          "Loading PDF \(url.path(percentEncoded: false), privacy: .private) failed: \(error.localizedDescription)"
        )
        return .unavailable(info)
      }
    }
    return QuickLookPreview.canPreview(info.contentType) ? .quickLook(info) : .unavailable(info)
  }
}

#if DEBUG
  #Preview("PDF") {
    @Previewable @State var controller = PreviewController()
    PreviewView(
      document: PreviewDocument(url: PreviewSampleFiles.invoicePDF(), completeness: .complete),
      controller: controller
    )
    .frame(width: 620, height: 720)
  }

  #Preview("Text file") {
    @Previewable @State var controller = PreviewController()
    PreviewView(
      document: PreviewDocument(url: PreviewSampleFiles.textNote(), completeness: .complete),
      controller: controller
    )
    .frame(width: 620, height: 520)
  }

  #Preview("No preview") {
    @Previewable @State var controller = PreviewController()
    PreviewView(
      document: PreviewDocument(url: PreviewSampleFiles.unknownData(), completeness: .complete),
      controller: controller
    )
    .frame(width: 620, height: 520)
  }

  #Preview("Downloading") {
    @Previewable @State var controller = PreviewController()
    PreviewView(
      document: PreviewDocument(url: PreviewSampleFiles.invoicePDF(), completeness: .downloading),
      controller: controller
    )
    .frame(width: 620, height: 520)
  }

  #Preview("Missing file") {
    @Previewable @State var controller = PreviewController()
    PreviewView(
      document: PreviewDocument(url: PreviewSampleFiles.missingFile(), completeness: .complete),
      controller: controller
    )
    .frame(width: 620, height: 520)
  }
#endif
