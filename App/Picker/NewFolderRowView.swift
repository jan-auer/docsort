import DocsortCore
import SwiftUI

/// The inline row in which the user names a new folder (`docs/design/ux.md`, "New folder"): a folder icon, the name
/// field (placeholder "Folder name", focused when the row appears) and a notice line about the typed name.
///
/// Its keys (Tab / Return confirm, Esc / ⇧Tab cancel, ⌘Return confirm and move) are handled by
/// ``DestinationPickerView``.
struct NewFolderRowView<FocusValue: Hashable>: View {
  @Bindable var model: DestinationPickerModel
  let focus: FocusState<FocusValue?>.Binding
  /// The panel's focus value for the row's field.
  let nameField: FocusValue

  /// Focuses the name field once the row has appeared.
  ///
  /// SwiftUI can focus the field only after the list (a lazy stack that scrolls to the new row) has laid it out;
  /// asked earlier, it moves focus to the first focusable view instead. So it asks, checks a moment later, and asks
  /// again while focus went elsewhere.
  private func takeFocus() async {
    for _ in 0..<5 {
      focus.wrappedValue = nameField
      do {
        try await Task.sleep(for: .milliseconds(50))
      } catch {
        // The row went away (the draft ended); nothing left to focus.
        return
      }
      if focus.wrappedValue == nameField { return }
    }
  }

  var body: some View {
    let draft = model.newFolderDraft
    HStack(alignment: .firstTextBaseline, spacing: 7) {
      FolderIcon(tone: .standard)
      VStack(alignment: .leading, spacing: 3) {
        TextField(
          "New folder name in \(ArchivePath.title(of: draft?.parent ?? ""))",
          text: $model.newFolderName, prompt: Text("Folder name")
        )
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .focused(focus, equals: nameField)
        .accessibilityIdentifier("picker-new-folder-name")
        NewFolderNoticeView(notice: draft?.notice)
      }
    }
    .padding(.horizontal, 6)
    .padding(.top, 3)
    .padding(.bottom, 4)
    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    .accessibilityElement(children: .contain)
    .task { await takeFocus() }
  }
}

/// The line under the new-folder name field: how to confirm, what nesting creates, an existing folder of that name,
/// or why the name cannot be used.
struct NewFolderNoticeView: View {
  let notice: NewFolderNotice?

  /// The hint shown with every notice that does not stop the user.
  static let keyHint = "Return or Tab confirms · Esc cancels"

  var body: some View {
    Text(text)
      .font(.system(size: 10.5))
      .foregroundStyle(isWarning ? Color(nsColor: .systemOrange) : .secondary)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier("picker-new-folder-notice")
  }

  /// The notice's text.
  var text: String {
    switch notice {
    case nil:
      Self.keyHint
    case .nested(let components):
      "Creates \(components.joined(separator: " › ")) · \(Self.keyHint)"
    case .existing(let parentTitle, let existingName):
      "“\(parentTitle)” already contains a folder named “\(existingName)”. Return selects it."
    case .invalid(let problem):
      problem.folderNameExplanation
    }
  }

  /// Whether the notice warns (an existing folder, an unusable name) rather than hints.
  private var isWarning: Bool {
    switch notice {
    case .existing, .invalid: true
    case nil, .nested: false
    }
  }
}
