import DocsortCore
import SwiftUI

/// The bar at the bottom of the main window's detail column: a persistent warning while the filing history could not
/// be saved (with **Try Again**), and the latest confirmation, which disappears after a few seconds.
struct WindowBottomBar: View {
  /// The window's state.
  @Bindable var model: MainWindowModel

  /// How long a confirmation stays.
  private static let messageDuration: Duration = .seconds(5)

  var body: some View {
    VStack(spacing: 0) {
      if let saveError = model.filing.pendingSaveError {
        Divider()
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.multicolor)
          Text("Filing history not saved: \(saveError.description)")
            .lineLimit(2)
          Spacer(minLength: 8)
          Button("Try Again") { model.retryHistorySave() }
            .accessibilityIdentifier("history-save-retry")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.yellow.opacity(0.15))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-save-warning")
      }
      if let message = model.statusMessage {
        Divider()
        Text(message.text)
          .font(.callout)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .accessibilityIdentifier("status-message")
          .task(id: message.id) {
            do {
              try await Task.sleep(for: Self.messageDuration)
            } catch {
              // Cancelled because a newer message replaced this one; that message manages itself.
              return
            }
            if model.statusMessage?.id == message.id { model.statusMessage = nil }
          }
      }
    }
  }
}

#if DEBUG
  #Preview {
    let model = MainWindowModel.preview(
      folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes))
    model.statusMessage = WindowStatusMessage(
      text:
        "Moved to Musik Margit/Noten & Bücher as 2033-10-13 Notenhaus Allegretto.pdf · Undo ⌘Z")
    return WindowBottomBar(model: model)
      .frame(width: 700)
  }
#endif
