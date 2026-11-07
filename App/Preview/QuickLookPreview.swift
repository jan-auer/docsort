import Quartz
import SwiftUI
import UniformTypeIdentifiers

/// A file shown in an embedded Quick Look preview (`QLPreviewView`, normal style).
///
/// The view is reused when `url` changes and closed when it leaves the screen.
struct QuickLookPreview: NSViewRepresentable {
  /// The file to show.
  let url: URL

  func makeNSView(context: Context) -> QLPreviewView {
    // The initializer is imported as implicitly unwrapped because its header returns `id`. It returns nil only if
    // Quick Look's UI framework cannot set up the view, which leaves nothing to show and no way to recover.
    guard let view = QLPreviewView(frame: .zero, style: .normal) else {
      preconditionFailure("QLPreviewView(frame:style:) returned nil")
    }
    view.previewItem = url as NSURL
    return view
  }

  func updateNSView(_ view: QLPreviewView, context: Context) {
    if view.previewItem?.previewItemURL != url {
      view.previewItem = url as NSURL
    }
  }

  static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) {
    view.close()
  }
}

extension QuickLookPreview {
  /// Whether Quick Look shows real content for files of `type`, rather than just their icon.
  ///
  /// `QLPreviewView` gives no signal when it falls back to a generic icon, and asking it would mean rendering first.
  /// So the decision is made up front from the type: the families macOS's built-in Quick Look extensions cover
  /// (images, text and source code, audio and video, PDF, RTF(D), HTML and web archives, Office and iWork documents,
  /// 3D scenes, fonts, contacts, calendar events and mail messages). Everything else gets the "no preview" view
  /// with its "Open with" button. Types only a third-party Quick Look extension can show are not detected; those
  /// files still open with one click.
  static func canPreview(_ type: UTType) -> Bool {
    previewableTypes.contains { type.conforms(to: $0) }
  }

  /// The type families `canPreview(_:)` accepts. Office and iWork identifiers are looked up by name because
  /// `UniformTypeIdentifiers` has no constants for them; unknown identifiers on a system are skipped.
  private static let previewableTypes: [UTType] =
    [
      .image, .text, .audiovisualContent, .pdf, .rtfd, .flatRTFD, .webArchive, .spreadsheet,
      .presentation,
      .threeDContent, .font, .vCard, .calendarEvent, .emailMessage,
    ]
    + [
      "com.microsoft.word.doc", "org.openxmlformats.wordprocessingml.document",
      "com.microsoft.excel.xls", "org.openxmlformats.spreadsheetml.sheet",
      "com.microsoft.powerpoint.ppt", "org.openxmlformats.presentationml.presentation",
      "org.oasis-open.opendocument.text", "com.apple.iwork.pages.sffpages",
      "com.apple.iwork.numbers.sffnumbers",
      "com.apple.iwork.keynote.sffkey",
    ].compactMap { UTType($0) }
}

#if DEBUG
  #Preview("Text note") {
    QuickLookPreview(url: PreviewSampleFiles.textNote())
      .frame(width: 520, height: 400)
  }
#endif
