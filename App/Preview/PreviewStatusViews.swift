import SwiftUI

/// A spinner that appears only once loading has taken longer than `delay`, so fast loads never flash it.
///
/// It covers what is beneath it once visible, so the previous file's content does not linger as if it were the new
/// one.
struct DelayedLoadingIndicator: View {
  /// How long loading may take before the spinner shows.
  static let delay = Duration.milliseconds(200)

  @State private var isVisible = false

  var body: some View {
    ZStack {
      if isVisible {
        Rectangle().fill(.background)
        ProgressView()
          .controlSize(.large)
          .accessibilityLabel(Text("Loading preview"))
          .accessibilityIdentifier("preview-loading")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(isVisible)
    .task {
      // `Task.sleep` throws only on cancellation, which means loading finished first: the spinner stays hidden.
      guard (try? await Task.sleep(for: Self.delay)) != nil else { return }
      isVisible = true
    }
  }
}

/// Shown in place of the content while a file is still downloading or syncing.
struct DownloadingView: View {
  /// The file's name.
  let fileName: String

  var body: some View {
    VStack(spacing: 10) {
      Text("Downloading…")
        .font(.title3)
      ProgressView()
        .progressViewStyle(.linear)
        .frame(maxWidth: 220)
        .accessibilityLabel(Text("Download in progress"))
      Text(fileName)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("preview-downloading")
  }
}

/// A short centred message with a symbol, for files that cannot be shown at all (gone, or not readable).
struct PreviewMessageView: View {
  /// The SF Symbol above the message.
  let systemImage: String
  /// The message's first line.
  let title: String
  /// The explanation under it.
  let detail: String

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
    } description: {
      Text(detail)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#if DEBUG
  #Preview("Downloading") {
    DownloadingView(fileName: "2026-05-11 Angebot Musterfirma.pdf")
      .frame(width: 520, height: 400)
  }

  #Preview("Missing file") {
    PreviewMessageView(
      systemImage: "questionmark.folder",
      title: "“2026-05-11 Angebot Musterfirma.pdf” is no longer here",
      detail: "It was moved or deleted outside docsort."
    )
    .frame(width: 520, height: 400)
  }

  #Preview("Loading") {
    DelayedLoadingIndicator()
      .frame(width: 520, height: 400)
  }
#endif
