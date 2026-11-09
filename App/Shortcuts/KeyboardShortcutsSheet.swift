import SwiftUI

/// The read-only list of every keyboard shortcut (`docs/design/keyboard-shortcuts-sheet.md`): a sheet over the main
/// window with a search field, the catalog's sections in two balanced columns, each row's title on the left and its
/// keys as keycaps on the right. Esc clears the search first, as in History, then closes the sheet; ⌘/ and Done close
/// it at once.
struct KeyboardShortcutsSheet: View {
  let catalog: ShortcutCatalog

  @State private var query: String
  @FocusState private var isSearchFocused: Bool
  @Environment(\.dismiss) private var dismiss

  init(catalog: ShortcutCatalog = .main, query: String = "") {
    self.catalog = catalog
    _query = State(initialValue: query)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      footer
    }
    .frame(width: 760, height: 640)
    // Esc reaches the sheet as `cancelOperation(_:)` from the search field's editor. ⌘/ closes the sheet through
    // Help › Keyboard Shortcuts, which stays on while the sheet is attached.
    .onExitCommand(perform: escape)
    .defaultFocus($isSearchFocused, true)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("keyboard-shortcuts-sheet")
  }

  private var header: some View {
    HStack(spacing: 16) {
      Text("Keyboard Shortcuts")
        .font(.title2.weight(.semibold))
      Spacer()
      ShortcutSearchField(query: $query, isFocused: $isSearchFocused)
        .frame(width: 240)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  @ViewBuilder private var content: some View {
    let sections = catalog.sections(matching: query)
    if sections.isEmpty {
      ContentUnavailableView.search(text: query)
        .accessibilityIdentifier("keyboard-shortcuts-no-results")
    } else {
      ScrollView {
        HStack(alignment: .top, spacing: 36) {
          ForEach(Array(ShortcutColumns.balance(sections, into: 2).enumerated()), id: \.offset) {
            _, column in
            VStack(alignment: .leading, spacing: 24) {
              ForEach(column) { section in
                ShortcutSectionView(section: section)
              }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
      }
    }
  }

  private var footer: some View {
    HStack {
      Text("The commands under Anywhere are also in the menu bar.")
        .font(.callout)
        .foregroundStyle(.secondary)
      Spacer()
      Button("Done") { dismiss() }
        .accessibilityIdentifier("keyboard-shortcuts-done")
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
  }
}

extension KeyboardShortcutsSheet {
  /// Esc: clears a search, else closes the sheet.
  private func escape() {
    if query.isEmpty {
      dismiss()
    } else {
      query = ""
    }
  }
}

/// Splits sections into columns of about equal height, keeping their order within each column.
enum ShortcutColumns {
  /// Puts each section, in order, into the column that is shortest so far (a heading counts as two rows).
  static func balance(_ sections: [ShortcutSection], into count: Int) -> [[ShortcutSection]] {
    var columns = Array(repeating: [ShortcutSection](), count: max(count, 1))
    var heights = Array(repeating: 0, count: columns.count)
    for section in sections {
      guard let shortest = heights.indices.min(by: { heights[$0] < heights[$1] }) else { break }
      columns[shortest].append(section)
      heights[shortest] += section.entries.count + 2
    }
    return columns.filter { !$0.isEmpty }
  }
}

/// The sheet's search field, styled as a macOS search field: a magnifying glass, the text and a clear button.
private struct ShortcutSearchField: View {
  @Binding var query: String
  var isFocused: FocusState<Bool>.Binding

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField("Search", text: $query, prompt: Text("Search shortcuts"))
        .textFieldStyle(.plain)
        .focused(isFocused)
        .accessibilityIdentifier("keyboard-shortcuts-search")
      if !query.isEmpty {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Clear Search")
        .accessibilityIdentifier("keyboard-shortcuts-clear-search")
      }
    }
    .padding(.horizontal, 8)
    .frame(height: 28)
    .background(.fill.tertiary, in: Capsule())
  }
}

/// A section: its context as a small heading, then its rows.
private struct ShortcutSectionView: View {
  let section: ShortcutSection

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(section.title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.bottom, 2)
        .accessibilityAddTraits(.isHeader)
      ForEach(section.entries) { entry in
        ShortcutRow(entry: entry)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("keyboard-shortcuts-section-\(section.context.identifier)")
  }
}

/// One shortcut: what it does (with when it applies, if not always) on the left, its keys on the right.
private struct ShortcutRow: View {
  let entry: ShortcutEntry

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      VStack(alignment: .leading, spacing: 1) {
        Text(entry.title)
        if let note = entry.note {
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      ShortcutTriggerView(trigger: entry.trigger)
        .fixedSize()
    }
    .padding(.vertical, 3)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(entry.title)
    .accessibilityValue(entry.trigger.spokenName)
    .accessibilityHint(entry.note ?? "")
    .accessibilityAddTraits(.isStaticText)
    .accessibilityIdentifier("keyboard-shortcuts-row")
  }
}

/// A trigger's keycaps: alternatives joined by "or", a pair by "/", typing as a dashed "Type" cap.
private struct ShortcutTriggerView: View {
  let trigger: ShortcutTrigger

  var body: some View {
    HStack(spacing: 5) {
      switch trigger {
      case .keys(let keys):
        ForEach(Array(keys.enumerated()), id: \.offset) { index, combination in
          if index > 0 {
            Separator(text: "or")
          }
          Keycap(keys: combination)
        }
      case .pair(let first, let second):
        Keycap(keys: first)
        Separator(text: "/")
        Keycap(keys: second)
      case .typing:
        Keycap(text: "Type", style: .typing)
      }
    }
  }

  private struct Separator: View {
    let text: String

    var body: some View {
      Text(text)
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
  }
}

/// A key combination drawn as a keyboard key: its glyphs on a soft rounded key with a hairline edge.
private struct Keycap: View {
  enum Style {
    /// A key.
    case key
    /// Typing text rather than a key: secondary text on a dashed outline.
    case typing
  }

  let text: String
  var style: Style = .key

  /// The cap for `keys`: its keycaps with a hair space between them, so the glyphs don't crowd but a word such as
  /// "Space" keeps its own spacing.
  init(keys: KeyCombination) {
    self.init(text: keys.keycaps.joined(separator: "\u{200A}"))
  }

  init(text: String, style: Style = .key) {
    self.text = text
    self.style = style
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
    Text(text)
      .font(.system(.callout, design: .rounded).weight(.medium))
      .foregroundStyle(style == .key ? .primary : .secondary)
      .padding(.horizontal, 6)
      .frame(minWidth: 26, minHeight: 22)
      .background {
        if style == .key {
          shape.fill(.fill.tertiary)
        }
      }
      .overlay {
        switch style {
        case .key:
          shape.strokeBorder(.separator, lineWidth: 0.5)
        case .typing:
          shape.strokeBorder(.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
      }
  }
}

#if DEBUG
  #Preview("Light") {
    KeyboardShortcutsSheet()
      .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    KeyboardShortcutsSheet()
      .preferredColorScheme(.dark)
  }

  #Preview("Search") {
    KeyboardShortcutsSheet(query: "folder")
  }

  #Preview("No results") {
    KeyboardShortcutsSheet(query: "xylophone")
  }
#endif
