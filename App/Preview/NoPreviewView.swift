import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Shown for a file that neither PDFKit nor Quick Look can show: its icon and facts, and a button that opens it in
/// its default app.
struct NoPreviewView: View {
  /// The file's facts.
  let info: PreviewFileInfo

  /// The app that opens the file by default; `nil` while unknown or when no app claims the type.
  @State private var defaultApplication: DefaultApplication?

  var body: some View {
    VStack(spacing: 14) {
      Image(nsImage: NSWorkspace.shared.icon(forFile: info.url.path(percentEncoded: false)))
        .resizable()
        .frame(width: 128, height: 128)
        .accessibilityHidden(true)
      VStack(spacing: 4) {
        Text(info.name)
          .font(.title3)
          .multilineTextAlignment(.center)
          .textSelection(.enabled)
        Text(info.kindDescription)
          .foregroundStyle(.secondary)
      }
      Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
        if let byteCount = info.byteCount {
          factRow(label: "Size", value: byteCount.formatted(.byteCount(style: .file)))
        }
        if let creationDate = info.creationDate {
          factRow(
            label: "Created", value: creationDate.formatted(date: .abbreviated, time: .shortened))
        }
        if let modificationDate = info.modificationDate {
          factRow(
            label: "Modified",
            value: modificationDate.formatted(date: .abbreviated, time: .shortened))
        }
      }
      .font(.callout)
      if let defaultApplication {
        Button("Open with \(defaultApplication.name)") {
          open(with: defaultApplication)
        }
        .accessibilityIdentifier("preview-open-with")
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("preview-unavailable")
    .task(id: info.url) {
      defaultApplication = DefaultApplication(toOpen: info.url)
    }
  }

  private func factRow(label: LocalizedStringKey, value: String) -> some View {
    GridRow {
      Text(label)
        .foregroundStyle(.secondary)
        .gridColumnAlignment(.trailing)
      Text(value)
    }
  }

  private func open(with application: DefaultApplication) {
    let fileURL = info.url
    Task {
      do {
        _ = try await NSWorkspace.shared.open(
          [fileURL], withApplicationAt: application.url,
          configuration: NSWorkspace.OpenConfiguration())
      } catch {
        Logger.preview.error(
          "Opening \(fileURL.path(percentEncoded: false), privacy: .private) with \(application.name) failed: \(error.localizedDescription)"
        )
      }
    }
  }
}

/// The app Launch Services opens a file with by default.
struct DefaultApplication: Equatable {
  /// The app bundle's location.
  let url: URL
  /// The app's name as Finder shows it, without ".app".
  let name: String

  /// Looks up the default app for `fileURL`; `nil` when no app claims the file's type.
  init?(toOpen fileURL: URL) {
    guard let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: fileURL) else {
      return nil
    }
    let displayName = FileManager.default.displayName(
      atPath: applicationURL.path(percentEncoded: false))
    url = applicationURL
    name = displayName.hasSuffix(".app") ? String(displayName.dropLast(".app".count)) : displayName
  }
}

#if DEBUG
  #Preview("No preview") {
    NoPreviewView(
      info: PreviewFileInfo(
        url: PreviewSampleFiles.unknownData(),
        name: "2026-04-20 Messwerte Musterfirma.dat",
        contentType: .data,
        byteCount: 3_072,
        creationDate: Date(timeIntervalSince1970: 1_776_675_600),
        modificationDate: Date(timeIntervalSince1970: 1_776_679_200)
      )
    )
    .frame(width: 520, height: 520)
  }
#endif
