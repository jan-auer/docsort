import SwiftUI

/// The filing panel, the main window's inspector: where the selected file gets its destination and name.
///
/// It is inactive and dimmed until a file is selected. With a selection it shows, top to bottom (the spec's order):
/// the suggestions slot (reserved, hidden for now), the destination picker, the folder contents, the name field and
/// the Move button. This step shows the selected file's name only; the filing steps add the sections below it in
/// that order, in `selectedFileSections(for:)`. When the archive folder is unreachable, a notice with **Locate…**
/// sits at the top, whether or not a file is selected.
struct FilingPanel: View {
  /// The file to file; `nil` while nothing is selected.
  let selectedFile: SelectedFile?
  /// Whether the archive folder can be filed into.
  let archiveAvailability: ArchiveAvailability
  /// Lets the user find the unreachable archive folder again.
  let locateArchive: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if case .unreachable(let displayPath) = archiveAvailability {
        archiveUnreachableNotice(displayPath: displayPath)
      }
      if let selectedFile {
        selectedFileSections(for: selectedFile)
      } else {
        inactiveMessage
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("filing-panel")
  }

  /// The panel's content for a selected file.
  @ViewBuilder private func selectedFileSections(for file: SelectedFile) -> some View {
    Text(file.name)
      .font(.headline)
      .lineLimit(2)
      .truncationMode(.middle)
      .textSelection(.enabled)
      .accessibilityIdentifier("filing-panel-file-name")
  }

  private var inactiveMessage: some View {
    Text("Select a file to file it")
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityIdentifier("filing-panel-inactive")
  }

  private func archiveUnreachableNotice(displayPath: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(
        "Archive folder not available: \(displayPath)",
        systemImage: "exclamationmark.triangle.fill"
      )
      .symbolRenderingMode(.multicolor)
      Button("Locate…", action: locateArchive)
        .accessibilityIdentifier("filing-panel-locate-archive")
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("filing-panel-archive-unreachable")
  }
}

#Preview("Nothing selected") {
  FilingPanel(selectedFile: nil, archiveAvailability: .available, locateArchive: {})
    .frame(width: 340, height: 600)
}

#Preview("File selected") {
  FilingPanel(
    selectedFile: SelectedFile(
      url: URL(filePath: "/tmp/Eingangskorb/2026-03-02 Rechnung Beispiel GmbH.pdf"),
      inboxName: "Eingangskorb",
      completeness: .complete
    ),
    archiveAvailability: .available,
    locateArchive: {}
  )
  .frame(width: 340, height: 600)
}

#Preview("Archive unreachable") {
  FilingPanel(
    selectedFile: SelectedFile(
      url: URL(filePath: "/tmp/Scannerablage/Scan 0007.pdf"),
      inboxName: "Scannerablage",
      completeness: .complete
    ),
    archiveAvailability: .unreachable(displayPath: "~/Fantasia-Ablage"),
    locateArchive: {}
  )
  .frame(width: 340, height: 600)
}
