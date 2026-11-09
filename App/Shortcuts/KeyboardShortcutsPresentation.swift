import SwiftUI

extension FocusedValues {
  /// Whether the key main window shows the keyboard shortcuts sheet; Help › Keyboard Shortcuts (⌘/) toggles it.
  @Entry var keyboardShortcutsSheet: Binding<Bool>?
}

/// Presents the keyboard shortcuts sheet over the view's window and lets the menu bar toggle it.
private struct KeyboardShortcutsSheetPresenter: ViewModifier {
  @State private var isPresented = false

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $isPresented) {
        KeyboardShortcutsSheet()
      }
      .focusedSceneValue(\.keyboardShortcutsSheet, $isPresented)
  }
}

extension View {
  /// Gives the view's window the keyboard shortcuts sheet, opened by Help › Keyboard Shortcuts (⌘/).
  func keyboardShortcutsSheet() -> some View {
    modifier(KeyboardShortcutsSheetPresenter())
  }
}
