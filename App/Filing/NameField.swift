import DocsortCore
import SwiftUI

/// The name field: the file's current name without its extension, all selected when focused, with the extension as
/// a fixed label inside the field's trailing edge, a Revert button (↺) just before it while the name differs from the
/// file's inbox name, and a name problem shown under it.
///
/// An empty field keeps the current name. Return does not move: it shows "Press ⌘Return to move" for two seconds,
/// as a toast that floats below the field without taking layout space.
/// Tab wraps focus to the sidebar; ⇧Tab and Esc return to the destination filter.
struct NameField: View {
  /// The window's state.
  @Bindable var model: MainWindowModel
  /// The file being named.
  let file: SelectedFile

  /// The width of the controls at the field's trailing edge, which the text keeps clear of.
  @State private var accessoryWidth: CGFloat = 0

  var body: some View {
    @Bindable var panel = model.panel
    VStack(alignment: .leading, spacing: 4) {
      KeyCommandTextField(
        text: $panel.nameText,
        placeholder: FileNameParts(file.name).stem,
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
        onCommand: handle,
        trailingInset: accessoryWidth
      )
      .overlay(alignment: .trailing) {
        trailingAccessories
          .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
          } action: { width in
            accessoryWidth = width
          }
      }
      // The hint floats just below the field over whatever is there, so nothing shifts when it appears. It hangs from
      // a zero-height anchor on the field's bottom edge: a custom bottom alignment guide on the toast was ignored
      // here and centred the toast on the field.
      .overlay(alignment: .bottom) {
        Color.clear
          .frame(height: 0)
          .overlay(alignment: .top) {
            if let hint = model.panel.hint {
              HintToast(hint: hint) { model.panel.hint = nil }
                .padding(.top, 7)
            }
          }
      }
      .zIndex(1)
      if let problem = nameProblem {
        Text("This name can’t be used: \(FilingMessages.text(for: problem))")
          .font(.callout)
          .foregroundStyle(.orange)
          .accessibilityIdentifier("name-problem")
      }
    }
  }

  /// The Revert button (↺) and the extension, inside the field's trailing edge as in the mockup. The button's slot
  /// is kept while it is hidden, so the room the text keeps free doesn't change as the name is edited.
  private var trailingAccessories: some View {
    HStack(spacing: 3) {
      if model.canRevertName {
        Button {
          model.revertName()
        } label: {
          Image(systemName: "arrow.uturn.backward")
            .font(.callout)
            .frame(width: Self.revertSize, height: Self.revertSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Revert to “\(file.originalName)” (⇧⌘R)")
        .accessibilityLabel("Revert Name")
        .accessibilityIdentifier("name-revert")
      } else {
        Color.clear
          .frame(width: Self.revertSize, height: Self.revertSize)
          .allowsHitTesting(false)
      }
      if let fileExtension = FileNameParts(file.name).fileExtension {
        Text(".\(fileExtension)")
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .fixedSize()
          // Clicks go through to the field, as on its text.
          .allowsHitTesting(false)
          .accessibilityIdentifier("name-extension")
      }
    }
    .padding(.trailing, 7)
  }

  /// The side of the Revert button and of its slot.
  private static let revertSize: CGFloat = 18

  /// The name field's focus request, when the latest request targets it.
  private var focusRequestID: UUID? {
    guard let request = model.focusRequest, request.target == .nameField else { return nil }
    return request.id
  }

  /// Why the entered name can't be used, or `nil`. An empty field keeps the current name, which is fine.
  private var nameProblem: NameProblem? {
    let name = FileNaming.finalName(entered: model.panel.nameText, originalName: file.name)
    return FileNaming.validationProblem(for: name)
  }

  private func handle(_ command: TextFieldKeyCommand) -> Bool {
    switch command {
    case .submit:
      model.panel.hint = .pressCommandReturnToMove
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

/// A short hint in a small floating capsule that hides itself after two seconds.
private struct HintToast: View {
  let hint: FilingHint
  /// Called when the two seconds are up.
  let expire: () -> Void

  var body: some View {
    Text(hint.text)
      .font(.callout)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(.regularMaterial, in: Capsule())
      .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
      .shadow(radius: 3, y: 1)
      .fixedSize()
      .accessibilityIdentifier("filing-hint")
      .task(id: hint) {
        do {
          try await Task.sleep(for: .seconds(2))
        } catch {
          // Cancelled: the hint was replaced or went away earlier, and the newer one sets its own timer.
          return
        }
        expire()
      }
  }
}

#if DEBUG
  #Preview("Filed, renamed") {
    NameField(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
        selectedFile: SampleInboxes.filedInvoice()),
      file: SampleInboxes.filedInvoice()
    )
    .padding()
    .frame(width: 340)
  }

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
