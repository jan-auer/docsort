import AppKit
import DocsortCore
import SwiftUI
import UniformTypeIdentifiers

/// Folder contents (`docs/design/ux.md`, "Folder contents"): the files already in the chosen or highlighted folder,
/// alphabetically, scrolled to the bottom (the newest of the archive's date-named files) whenever the folder changes.
/// Clicking a file takes its name for the name field (``PickerEvent/tookFileName(_:)``).
///
/// Accessibility: the view is `folder-contents`; each file is a button `folder-contents-file` labelled with its
/// name, with the value `conflict` when it is the conflicting file.
struct FolderContentsView: View {
  let model: DestinationPickerModel
  /// The name the name field would give the file; a file with this name (ignoring case) is highlighted in the
  /// warning colour and scrolled into view.
  var conflictingName: String? = nil

  var body: some View {
    FolderContentsListing(contents: model.contents, conflictingName: conflictingName) { file in
      model.takeFileName(file)
    }
  }
}

/// Folder contents for one ``FolderContents`` value; ``FolderContentsView`` feeds it from the picker model.
struct FolderContentsListing: View {
  let contents: FolderContents
  let conflictingName: String?
  /// A click on a file.
  let takeFileName: (FolderFile) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: FilingPanelStyle.titleSpacing) {
      header
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panelWell()
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Folder contents")
    .accessibilityIdentifier("folder-contents")
  }

  // MARK: Header

  /// "Files in Rechnungen" as a section title, the file count trailing; the folder's full path is in its tooltip.
  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(headerTitle)
        .panelSectionTitle()
        .lineLimit(1)
        .truncationMode(.middle)
        .help(contents.folder.map(Self.title(of:)) ?? "")
      Spacer(minLength: 4)
      if let fileCount {
        Text(fileCount == 1 ? "1 file" : "\(fileCount) files")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize()
      }
    }
    .accessibilityElement(children: .combine)
  }

  /// "Files in <folder name>", "Files in new folder", or "Folder contents" without a folder.
  private var headerTitle: String {
    switch contents {
    case .none: "Folder contents"
    case .notOnDisk: "Files in new folder"
    case .loading(let folder), .files(let folder, _), .failed(let folder, _):
      "Files in \(ArchivePath.title(of: folder))"
    }
  }

  private var fileCount: Int? {
    if case .files(_, let files) = contents { return files.count }
    return nil
  }

  /// A folder's path as the header shows it: `Gesundheit › Konrad`, or ``ArchivePath/rootTitle``.
  static func title(of folder: String) -> String {
    folder.isEmpty
      ? ArchivePath.rootTitle : ArchivePath.segments(of: folder).joined(separator: " › ")
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    switch contents {
    case .none:
      note("Highlight a folder to see its files.")
    case .notOnDisk:
      note(
        "docsort creates the new folder when you move the file, so cancelling leaves nothing behind."
      )
    case .loading:
      // Listing a folder takes a moment at most; an empty area avoids a spinner flashing up.
      Color.clear
    case .files(_, let files) where files.isEmpty:
      note("No files")
    case .files(_, let files):
      fileList(files)
    case .failed(_, let message):
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.secondary)
        .padding(.horizontal, FilingPanelStyle.rowPadding + FilingPanelStyle.wellInset)
        .padding(.vertical, 8)
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, FilingPanelStyle.rowPadding + FilingPanelStyle.wellInset)
      .padding(.vertical, 8)
  }

  private func fileList(_ files: [FolderFile]) -> some View {
    let conflict = conflictingFile(in: files)
    return ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(files, id: \.url) { file in
            FolderContentsFileRow(file: file, isConflict: file.url == conflict?.url) {
              takeFileName(file)
            }
            .id(file.url)
          }
        }
        .padding(FilingPanelStyle.wellInset)
      }
      .defaultScrollAnchor(.bottom)
      .onChange(of: files.map(\.url), initial: true) { _, urls in
        // A new folder (or new files in it): show the conflict if there is one, else the newest files.
        if let conflict {
          proxy.scrollTo(conflict.url, anchor: .center)
        } else if let last = urls.last {
          proxy.scrollTo(last, anchor: .bottom)
        }
      }
      .onChange(of: conflict?.url) { _, url in
        guard let url else { return }
        proxy.scrollTo(url, anchor: .center)
      }
    }
  }

  /// The file named ``conflictingName``, ignoring case and Unicode normalisation.
  private func conflictingFile(in files: [FolderFile]) -> FolderFile? {
    guard let conflictingName else { return nil }
    let folded = conflictingName.precomposedStringWithCanonicalMapping
    return files.first { file in
      file.name.precomposedStringWithCanonicalMapping.caseInsensitiveCompare(folded) == .orderedSame
    }
  }
}

extension FolderContents {
  /// The archive-relative folder the contents are about, if a folder on disk.
  fileprivate var folder: String? {
    switch self {
    case .none, .notOnDisk: nil
    case .loading(let folder), .files(let folder, _), .failed(let folder, _): folder
    }
  }
}

/// One file in Folder contents: its icon and name, in the same row style as the folder list; a click takes the name.
struct FolderContentsFileRow: View {
  let file: FolderFile
  /// Whether the file's name conflicts with the name field's (highlighted in the warning colour).
  let isConflict: Bool
  let take: () -> Void

  var body: some View {
    HStack(spacing: FilingPanelStyle.rowIconSpacing) {
      Image(nsImage: Self.icon(for: file.name))
        .resizable()
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
      Text(file.name)
        .fontWeight(isConflict ? .semibold : .regular)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, FilingPanelStyle.rowPadding)
    .frame(height: FilingPanelStyle.rowHeight)
    .background(
      isConflict ? Color(nsColor: .systemOrange).opacity(0.3) : .clear,
      in: RoundedRectangle(cornerRadius: FilingPanelStyle.rowRadius)
    )
    .contentShape(Rectangle())
    .onTapGesture(perform: take)
    .help("Click to use this name")
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(file.name)
    .accessibilityValue(isConflict ? "conflict" : "")
    .accessibilityHint("Uses this name for the file")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(.default, take)
    .accessibilityIdentifier("folder-contents-file")
  }

  /// The Finder icon for files named like `name`, from its extension alone (the file itself is not read).
  private static func icon(for name: String) -> NSImage {
    let fileExtension = (name as NSString).pathExtension
    let type = UTType(filenameExtension: fileExtension) ?? .data
    return NSWorkspace.shared.icon(for: type)
  }
}

#if DEBUG
  /// The files of one folder of the sample archive, read synchronously, which a preview can afford.
  @MainActor
  private func sampleContents(of folder: String) -> FolderContents {
    do {
      let index = try PickerSampleArchive.create().index()
      return .files(folder: folder, try index.files(in: folder))
    } catch {
      return .failed(folder: folder, message: "The sample archive could not be built: \(error)")
    }
  }

  #Preview("Files") {
    FolderContentsListing(
      contents: sampleContents(of: "Kommunikation/Ilmnet Internet/Rechnungen"), conflictingName: nil
    ) { _ in }
    .padding()
    .frame(width: 340, height: 160)
  }

  #Preview("Conflict") {
    FolderContentsListing(
      contents: sampleContents(of: "Kommunikation/Ilmnet Internet/Rechnungen"),
      conflictingName: "2033-07-19 gutschrift störung.pdf"
    ) { _ in }
    .padding()
    .frame(width: 340, height: 100)
  }

  #Preview("New folder") {
    FolderContentsListing(contents: .notOnDisk, conflictingName: nil) { _ in }
      .padding()
      .frame(width: 340, height: 100)
  }

  #Preview("Failed") {
    FolderContentsListing(
      contents: .failed(
        folder: "Reisen/Reiseplanung Ideen", message: "The folder no longer exists."),
      conflictingName: nil
    ) { _ in }
    .padding()
    .frame(width: 340, height: 100)
  }

  #Preview("From the picker") {
    FolderContentsView(model: .sample { $0.filterText = "rechnungen" })
      .padding()
      .frame(width: 340, height: 160)
  }
#endif
