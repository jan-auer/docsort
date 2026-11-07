import SwiftUI
import UniformTypeIdentifiers

/// The thin line under a preview: page position (PDFs only), size, kind and dates.
struct PreviewFooter: View {
  /// The shown file's facts.
  let info: PreviewFileInfo
  /// The page position for a PDF; `nil` for other files.
  let pagePosition: PDFPagePosition?

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      Text(parts.joined(separator: "  ·  "))
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("preview-footer")
  }

  /// The footer's entries, in reading order; facts the file system did not report are left out.
  private var parts: [String] {
    var parts: [String] = []
    if let pagePosition {
      parts.append(
        String(localized: "Page \(pagePosition.pageNumber) of \(pagePosition.pageCount)")
      )
    }
    if let byteCount = info.byteCount {
      parts.append(byteCount.formatted(.byteCount(style: .file)))
    }
    parts.append(info.kindDescription)
    if let creationDate = info.creationDate {
      parts.append(
        String(localized: "Created \(creationDate.formatted(date: .abbreviated, time: .shortened))")
      )
    }
    if let modificationDate = info.modificationDate {
      parts.append(
        String(
          localized: "Modified \(modificationDate.formatted(date: .abbreviated, time: .shortened))")
      )
    }
    return parts
  }
}

#if DEBUG
  #Preview("PDF footer") {
    PreviewFooter(
      info: PreviewFileInfo(
        url: URL(filePath: "/tmp/2026-03-02 Rechnung Beispiel GmbH.pdf"),
        name: "2026-03-02 Rechnung Beispiel GmbH.pdf",
        contentType: .pdf,
        byteCount: 48_213,
        creationDate: Date(timeIntervalSince1970: 1_772_445_600),
        modificationDate: Date(timeIntervalSince1970: 1_772_449_200)
      ),
      pagePosition: PDFPagePosition(pageNumber: 1, pageCount: 2)
    )
    .frame(width: 600)
  }
#endif
