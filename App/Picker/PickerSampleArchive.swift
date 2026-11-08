#if DEBUG
  import DocsortCore
  import Foundation
  import OSLog

  /// A small archive on disk for the picker's previews and its test host, built in a fresh temporary directory.
  ///
  /// Debug builds only. Folder and file names come from the fictional sample archive in `docs/design/sample-data/`
  /// (`folders.txt`, `folder-files.txt`). This is the one place outside the core that writes to the disk for the
  /// picker; the views themselves never do.
  nonisolated struct PickerSampleArchive: Sendable {
    /// The archive's folders, parents before children: a dozen across three levels.
    static let folders = [
      "Gesundheit",
      "Gesundheit/Impfpässe",
      "Gesundheit/Konrad",
      "Gesundheit/Konrad/Augenarzt & Brillen",
      "Gesundheit/Konrad/Physiotherapie",
      "Gesundheit/Konrad/Zahnarzt",
      "Gesundheit/Margit",
      "Gesundheit/Margit/Physiotherapie",
      "Kommunikation",
      "Kommunikation/Ilmnet Internet",
      "Kommunikation/Ilmnet Internet/Rechnungen",
      "Mobilität",
      "Mobilität/Jahreskarte Regio Plus",
      "Reisen",
      "Reisen/2032-05 Pfingsten Hochalm",
      "Reisen/2033-06 Wanderwoche Hochalm",
      "Reisen/2033-06 Wanderwoche Hochalm/Anreise",
      "Reisen/Reiseplanung Ideen",
    ]

    /// The archive's files, by archive-relative path.
    static let files = [
      "Gesundheit/Konrad/Augenarzt & Brillen/2031-11-08 Befund Augenarzt Dr. Zöhrer.pdf",
      "Gesundheit/Konrad/Augenarzt & Brillen/2032-01-20 Rechnung Gleitsichtbrille.pdf",
      "Gesundheit/Konrad/Augenarzt & Brillen/2033-09-22 Befund Augenarzt Dr. Zöhrer.pdf",
      "Kommunikation/Ilmnet Internet/Rechnungen/2033-07-04 Rechnung Juli.pdf",
      "Kommunikation/Ilmnet Internet/Rechnungen/2033-07-19 Gutschrift Störung.pdf",
      "Kommunikation/Ilmnet Internet/Rechnungen/2033-08-04 Rechnung August.pdf",
      "Kommunikation/Ilmnet Internet/Rechnungen/2033-09-04 Rechnung September.pdf",
      "Kommunikation/Ilmnet Internet/Rechnungen/2033-10-04 Rechnung Oktober.pdf",
      "Mobilität/Jahreskarte Regio Plus/2031-10-18 Jahreskarte Konrad.pdf",
      "Mobilität/Jahreskarte Regio Plus/2033-10-20 Verlängerung Jahreskarte Margit.pdf",
    ]

    /// The recent destinations, most recent first.
    static let recents = RecentDestinations(paths: [
      "Kommunikation/Ilmnet Internet/Rechnungen",
      "Gesundheit/Konrad/Physiotherapie",
    ])

    /// The archive root, a fresh temporary directory.
    let root: URL

    /// Writes the archive into a new temporary directory.
    ///
    /// - Throws: The file system's error when a folder or file cannot be created.
    static func create() throws -> PickerSampleArchive {
      let root = FileManager.default.temporaryDirectory
        .appending(path: "DocsortPickerSample-\(UUID().uuidString)", directoryHint: .isDirectory)
      for folder in folders {
        try FileManager.default.createDirectory(
          at: root.appending(path: folder, directoryHint: .isDirectory),
          withIntermediateDirectories: true)
      }
      for file in files {
        try Data("sample".utf8).write(to: root.appending(path: file, directoryHint: .notDirectory))
      }
      return PickerSampleArchive(root: root)
    }

    /// Writes the archive and indexes it, off the main actor.
    ///
    /// - Throws: The file system's error, or the index's ``FolderAccessError``.
    @concurrent
    static func createIndexed() async throws -> (
      archive: PickerSampleArchive, index: DestinationIndex
    ) {
      let archive = try create()
      return (archive, try archive.index())
    }

    /// A fresh index of the archive.
    func index() throws(FolderAccessError) -> DestinationIndex {
      try DestinationIndex.build(root: root)
    }

    /// Deletes the archive's directory; a failure is logged, since a leftover temporary folder harms nothing.
    func remove() {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Logger.picker.error(
          "Could not remove the picker's sample archive at \(root.path(percentEncoded: false)): \(error)"
        )
      }
    }
  }

  extension DestinationPickerModel {
    /// A picker on a fresh ``PickerSampleArchive`` with its recents, for previews; `prepare` puts it into the state
    /// the preview shows. Indexes on the main actor, which a preview can afford. The temporary archive is left
    /// behind for the preview process's lifetime, since the listing reads it.
    static func sample(_ prepare: (DestinationPickerModel) -> Void = { _ in })
      -> DestinationPickerModel
    {
      let model = DestinationPickerModel(
        folderFiles: ArchiveFolderFileListing(), recents: PickerSampleArchive.recents)
      do {
        model.index = try PickerSampleArchive.create().index()
      } catch {
        Logger.picker.error("Could not build the picker's sample archive for a preview: \(error)")
      }
      prepare(model)
      return model
    }
  }
#endif
