#if DEBUG
  import DocsortCore
  import OSLog
  import SwiftUI

  /// A debug-only window that hosts the destination picker on its own, for UI tests of the picker before (and
  /// independently of) the filing panel. Launch the app with `AppLaunchMode.pickerTestHostArgument` to show it; the
  /// app then runs in the inert environment (`AppLaunchMode.pickerTestHost`).
  enum PickerTestHost {
    /// The window's scene identifier.
    static let sceneID = "picker-test-host"

    /// Whether the app was launched to show the test host.
    static var isRequested: Bool {
      AppLaunchMode.current() == .pickerTestHost
    }
  }

  /// Opens the picker test host's window when the app was launched for it. The main window applies this: a second
  /// `Window` scene marked `.presented` is not shown at launch on its own.
  struct PickerTestHostLauncher: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
      content.onAppear {
        if PickerTestHost.isRequested { openWindow(id: PickerTestHost.sceneID) }
      }
    }
  }

  /// The test host's window; presented at launch only when ``PickerTestHost/isRequested``.
  struct PickerTestHostScene: Scene {
    var body: some Scene {
      Window("Picker Test Host", id: PickerTestHost.sceneID) {
        PickerTestHostView()
      }
      .windowResizability(.contentSize)
      .defaultLaunchBehavior(PickerTestHost.isRequested ? .presented : .suppressed)
    }
  }

  /// The picker and Folder contents on a ``PickerSampleArchive``, between stand-ins for the filing panel's
  /// neighbours: a "sidebar" button and a "name" field. It wires the picker's events as the panel will: `.chose`
  /// focuses the name field, `.steppedBack` the sidebar, `.tookFileName` puts the name (without extension) into the
  /// name field.
  ///
  /// Accessibility identifiers: `picker-test-host`, `picker-test-sidebar`, `picker-test-name`,
  /// `picker-test-last-event` (the last event as text: `chose Gesundheit/Konrad`, `chose new Reisen/Bahn`,
  /// `moveRequested Gesundheit/Konrad`, `steppedBack`, `tookFileName 2033-10-04 Rechnung Oktober.pdf`; empty before
  /// the first) and `picker-test-error` (shown only if the sample archive could not be built). Typing a letter or
  /// pressing Tab or Return in the sidebar enters the picker, as in the main window.
  struct PickerTestHostView: View {
    /// Where focus is in the test host.
    enum HostFocus: Hashable {
      case sidebar
      case picker(PickerField)
      case name
    }

    @State private var model = DestinationPickerModel(
      folderFiles: ArchiveFolderFileListing(), recents: PickerSampleArchive.recents)
    @State private var archive: PickerSampleArchive?
    @State private var setupFailure: String?
    @State private var name = ""
    @State private var lastEvent = ""
    @FocusState private var focus: HostFocus?

    var body: some View {
      HStack(alignment: .top, spacing: 16) {
        sidebar
        VStack(alignment: .leading, spacing: 8) {
          if let setupFailure {
            Text(setupFailure)
              .foregroundStyle(.red)
              .accessibilityIdentifier("picker-test-error")
          }
          DestinationPickerView(model: model, focus: $focus) { .picker($0) }
            .frame(height: 300)
          FolderContentsView(
            model: model, conflictingName: name.isEmpty ? nil : "\(name).pdf",
            listHeight: .constant(110), isCollapsed: .constant(false), maxListHeight: 110)
          TextField("Name", text: $name)
            .focused($focus, equals: .name)
            .accessibilityIdentifier("picker-test-name")
          Text(lastEvent)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("picker-test-last-event")
        }
        .frame(width: 340)
      }
      .padding()
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("picker-test-host")
      .task { await setUp() }
      .onDisappear { archive?.remove() }
    }

    private var sidebar: some View {
      VStack {
        Button("Sidebar") { focus = .picker(.filter) }
          .focusable()
          .focused($focus, equals: .sidebar)
          .onKeyPress(phases: .down) { press in enterPicker(from: press) }
          .accessibilityIdentifier("picker-test-sidebar")
        Spacer()
      }
      .frame(width: 120)
    }

    /// The sidebar's keys that enter the picker: Tab and Return focus it, a typed character starts the filter.
    private func enterPicker(from press: KeyPress) -> KeyPress.Result {
      if press.key == .tab || press.key == .return {
        focus = .picker(.filter)
        return .handled
      }
      guard press.modifiers.subtracting(.shift).isEmpty,
        press.characters.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }),
        !press.characters.isEmpty
      else { return .ignored }
      model.enter(typing: press.characters)
      focus = .picker(.filter)
      return .handled
    }

    /// Wires the events, builds and indexes the sample archive off the main actor and hands the index to the picker.
    private func setUp() async {
      model.onEvent = { event in receive(event) }
      do {
        let (archive, index) = try await PickerSampleArchive.createIndexed()
        self.archive = archive
        model.index = index
      } catch {
        Logger.picker.error("Could not build the picker test host's sample archive: \(error)")
        setupFailure = "The sample archive could not be built: \(error.localizedDescription)"
      }
    }

    /// Does what the filing panel does with `event` and shows it.
    private func receive(_ event: PickerEvent) {
      lastEvent = Self.description(of: event)
      switch event {
      case .chose:
        focus = .name
      case .moveRequested, .renameFileRequested, .trashFileRequested:
        break
      case .steppedBack:
        focus = .sidebar
      case .tookFileName(let fileName):
        name = (fileName as NSString).deletingPathExtension
        focus = .name
      case .refreshRequested:
        break
      }
    }

    /// `event` as the last-event line shows it.
    static func description(of event: PickerEvent) -> String {
      switch event {
      case .chose(let destination): "chose \(description(of: destination))"
      case .moveRequested(let destination): "moveRequested \(description(of: destination))"
      case .steppedBack: "steppedBack"
      case .tookFileName(let fileName): "tookFileName \(fileName)"
      case .refreshRequested: "refreshRequested"
      case .renameFileRequested(let file, let name): "renameFileRequested \(file.name) to \(name)"
      case .trashFileRequested(let file): "trashFileRequested \(file.name)"
      }
    }

    private static func description(of destination: PickerDestination) -> String {
      switch destination {
      case .folder(let path): path
      case .newFolder(let path): "new \(path)"
      }
    }
  }

  #Preview {
    PickerTestHostView()
  }
#endif
