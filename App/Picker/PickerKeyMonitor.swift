import AppKit
import SwiftUI

/// A key the destination picker handles itself while one of its text fields has focus (`docs/design/ux.md`,
/// "Keyboard map › Destination picker focused"). Named for the key, not for what it does: the picker view maps each
/// to an intent of ``DestinationPickerModel`` depending on which field is focused.
enum PickerKey: Hashable {
  /// ↑ without modifiers.
  case upArrow
  /// ↓ without modifiers.
  case downArrow
  /// → without modifiers.
  case rightArrow
  /// ← without modifiers.
  case leftArrow
  /// ⌫ (Backspace) without modifiers.
  case delete
  /// ⌘↑.
  case commandUpArrow
  /// Tab without modifiers.
  case tab
  /// Return or keypad Enter without modifiers.
  case returnKey
  /// ⇧Tab.
  case shiftTab
  /// Esc without modifiers.
  case escape
  /// ⇧⌘N.
  case shiftCommandN
  /// ⌘Return or ⌘Enter.
  case commandReturn

  /// The picker key `event` stands for, or `nil` for any other key.
  init?(_ event: NSEvent) {
    let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])
    switch (event.specialKey, modifiers) {
    case (.upArrow?, []): self = .upArrow
    case (.downArrow?, []): self = .downArrow
    case (.rightArrow?, []): self = .rightArrow
    case (.leftArrow?, []): self = .leftArrow
    case (.delete?, []): self = .delete
    case (.upArrow?, [.command]): self = .commandUpArrow
    case (.tab?, []): self = .tab
    case (.carriageReturn?, []), (.enter?, []): self = .returnKey
    case (.backTab?, [.shift]), (.tab?, [.shift]): self = .shiftTab
    case (.carriageReturn?, [.command]), (.enter?, [.command]): self = .commandReturn
    default:
      // Esc and letters have no special key; ⇧ turns `charactersIgnoringModifiers` into "N".
      let character = event.charactersIgnoringModifiers?.lowercased()
      if character == "\u{1B}", modifiers.isEmpty {
        self = .escape
      } else if character == "n", modifiers == [.shift, .command] {
        self = .shiftCommandN
      } else {
        return nil
      }
    }
  }
}

/// Delivers ``PickerKey``s to the picker while one of its fields has focus, before the text field, the focus system
/// or the menu see them.
///
/// SwiftUI's `TextField` on macOS hands Tab and ⇧Tab to the focus system, Return to `onSubmit` and arrows and Esc to
/// its field editor, and `onKeyPress` does not reliably see them first. An app-local event monitor does: AppKit calls
/// it for every key-down event before `NSApplication.sendEvent(_:)` dispatches it. The monitor runs only while the
/// picker has focus (the view starts and stops it), acts only on events for the picker's own window, and leaves keys
/// alone while an input method is composing text (marked text), so dead keys and IMEs keep working.
@MainActor
final class PickerKeyMonitor {
  /// The window the picker is in; set by ``PickerKeyMonitorAnchor``.
  weak var window: NSWindow?

  /// The installed monitor, `nil` while stopped.
  private var monitor: Any?

  /// Starts handing picker keys to `handler`, replacing an earlier handler. A key the handler reports as
  /// `.handled` is consumed; any other key, and every key that is not a ``PickerKey``, goes on as usual.
  func start(handler: @escaping @MainActor (PickerKey) -> KeyPress.Result) {
    stop()
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, let window = self.window, event.window === window,
        !Self.isComposingText(in: window), let key = PickerKey(event)
      else { return event }
      return handler(key) == .handled ? nil : event
    }
  }

  /// Stops handing keys to the picker.
  func stop() {
    guard let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
  }

  isolated deinit {
    stop()
  }

  /// Whether the focused text in `window` has marked text, i.e. an input method is composing a character.
  private static func isComposingText(in window: NSWindow) -> Bool {
    (window.firstResponder as? any NSTextInputClient)?.hasMarkedText() == true
  }
}

/// An invisible view that tells a ``PickerKeyMonitor`` which window the picker is in.
struct PickerKeyMonitorAnchor: NSViewRepresentable {
  let monitor: PickerKeyMonitor

  func makeNSView(context: Context) -> AnchorView {
    AnchorView(monitor: monitor)
  }

  func updateNSView(_ view: AnchorView, context: Context) {
    view.monitor = monitor
    monitor.window = view.window
  }

  /// Reports its window to the monitor whenever it moves into one.
  final class AnchorView: NSView {
    var monitor: PickerKeyMonitor

    init(monitor: PickerKeyMonitor) {
      self.monitor = monitor
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("AnchorView is only created in code")
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      monitor.window = window
    }
  }
}
