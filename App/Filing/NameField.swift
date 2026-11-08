import DocsortCore
import SwiftUI

/// The name field: the file's name without its extension, all selected when focused, with the extension as a fixed
/// label after it and a name problem shown under it.
///
/// An empty field keeps the original name. Return does not move: it shows "Press ⌘Return to move" for two seconds.
/// Tab wraps focus to the sidebar; ⇧Tab and Esc return to the destination filter.
struct NameField: View {
  /// The window's state.
  @Bindable var model: MainWindowModel
  /// The file being named.
  let file: SelectedFile

  var body: some View {
    @Bindable var panel = model.panel
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 2) {
        KeyCommandTextField(
          text: $panel.nameText,
          placeholder: FileNameParts(file.originalName).stem,
          identifier: "name-field",
          focusSelection: .all,
          focusRequestID: focusRequestID,
          onFocusChange: { isFocused in
            if isFocused {
              model.focus = .nameField
            } else if model.focus == .nameField {
              model.focus = nil
            }
          },
          onCommand: handle
        )
        if let fileExtension = FileNameParts(file.originalName).fileExtension {
          Text(".\(fileExtension)")
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("name-extension")
        }
      }
      if let problem = nameProblem {
        Text("This name can’t be used: \(FilingMessages.text(for: problem))")
          .font(.callout)
          .foregroundStyle(.orange)
          .accessibilityIdentifier("name-problem")
      }
      if model.panel.isMoveHintShown {
        Text("Press ⌘Return to move")
          .font(.callout)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("name-move-hint")
          .task {
            // A cancelled sleep only means the hint went away earlier; hiding it then is right too.
            try? await Task.sleep(for: .seconds(2))
            model.panel.isMoveHintShown = false
          }
      }
    }
  }

  /// The name field's focus request, when the latest request targets it.
  private var focusRequestID: UUID? {
    guard let request = model.focusRequest, request.target == .nameField else { return nil }
    return request.id
  }

  /// Why the entered name can't be used, or `nil`. An empty field keeps the original name, which is fine.
  private var nameProblem: NameProblem? {
    let name = FileNaming.finalName(entered: model.panel.nameText, originalName: file.originalName)
    return FileNaming.validationProblem(for: name)
  }

  private func handle(_ command: TextFieldKeyCommand) -> Bool {
    switch command {
    case .submit:
      model.panel.isMoveHintShown = true
      return true
    case .tab:
      model.requestFocus(.sidebar)
      return true
    case .backTab, .cancel:
      model.requestFocus(.destinationFilter)
      return true
    case .moveUp, .moveDown:
      return false
    }
  }
}

#if DEBUG
  #Preview {
    NameField(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
        selectedFile: SampleInboxes.selectedInvoice()),
      file: SampleInboxes.selectedInvoice()
    )
    .padding()
    .frame(width: 340)
  }
#endif
