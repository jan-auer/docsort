import SwiftUI

/// The destination filter and the folder list below it.
///
/// An empty filter lists the recent destinations, then the top-level folders; typing searches the whole archive and
/// shows each match's path with the matched letters bold. ↑ / ↓ in the filter move the highlight; Tab or Return
/// choose the highlighted folder, as a click on a row does. Esc clears the filter, and with an empty filter returns
/// to the sidebar.
struct DestinationList: View {
  /// The window's state.
  @Bindable var model: MainWindowModel

  var body: some View {
    @Bindable var panel = model.panel
    let candidates = model.destinationCandidates
    VStack(alignment: .leading, spacing: 6) {
      KeyCommandTextField(
        text: $panel.filter,
        placeholder: "Search folders",
        identifier: "destination-filter",
        focusSelection: .end,
        focusRequestID: focusRequestID,
        onFocusChange: { isFocused in
          if isFocused {
            model.focus = .destinationFilter
            model.panel.isFilterFocusPending = false
          } else if model.focus == .destinationFilter {
            model.focus = nil
          }
        },
        onCommand: { command in handle(command, candidateCount: candidates.count) }
      )

      if model.archive.index == nil {
        Text("Indexing archive…")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 80)
          .accessibilityIdentifier("destination-indexing")
      } else if candidates.isEmpty {
        Text("No matching folders")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 80)
          .accessibilityIdentifier("destination-empty")
      } else {
        list(of: candidates)
      }
    }
  }

  /// The filter's focus request, when the latest request targets it.
  private var focusRequestID: UUID? {
    guard let request = model.focusRequest, request.target == .destinationFilter else { return nil }
    return request.id
  }

  private func list(of candidates: [DestinationCandidate]) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(Array(candidates.enumerated()), id: \.element.id) { position, candidate in
            row(for: candidate, isHighlighted: position == model.panel.highlightedIndex)
              .id(candidate.id)
          }
        }
      }
      .frame(minHeight: 120, maxHeight: 320)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
      .onChange(of: model.panel.highlightedIndex) { _, index in
        guard candidates.indices.contains(index) else { return }
        proxy.scrollTo(candidates[index].id)
      }
    }
  }

  private func row(for candidate: DestinationCandidate, isHighlighted: Bool) -> some View {
    Button {
      model.choose(candidate)
    } label: {
      HStack(spacing: 6) {
        Image(systemName: candidate.isRecent ? "clock" : "folder")
          .foregroundStyle(isHighlighted ? .white : .secondary)
          .frame(width: 16)
        Text(Self.highlighted(candidate.shownPath, ranges: candidate.matchedRanges))
          .lineLimit(1)
          .truncationMode(.head)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(isHighlighted ? .white : .primary)
      .background(
        isHighlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 4)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(candidate.path)
    .accessibilityLabel(candidate.path)
    .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    .accessibilityIdentifier("destination-row")
  }

  private func handle(_ command: TextFieldKeyCommand, candidateCount: Int) -> Bool {
    switch command {
    case .moveUp:
      model.panel.moveHighlight(by: -1, count: candidateCount)
      return true
    case .moveDown:
      model.panel.moveHighlight(by: 1, count: candidateCount)
      return true
    case .tab, .submit:
      model.chooseHighlightedDestination()
      return true
    case .backTab:
      model.requestFocus(.sidebar)
      return true
    case .cancel:
      if model.panel.filter.isEmpty {
        model.requestFocus(.sidebar)
      } else {
        model.panel.filter = ""
      }
      return true
    }
  }

  /// `path` with the characters in `ranges` bold.
  static func highlighted(_ path: String, ranges: [Range<String.Index>]) -> AttributedString {
    var result = AttributedString()
    var cursor = path.startIndex
    for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound })
    where range.lowerBound >= cursor && range.upperBound <= path.endIndex {
      result += AttributedString(String(path[cursor..<range.lowerBound]))
      var match = AttributedString(String(path[range]))
      match.inlinePresentationIntent = .stronglyEmphasized
      result += match
      cursor = range.upperBound
    }
    result += AttributedString(String(path[cursor...]))
    return result
  }
}

#if DEBUG
  #Preview {
    DestinationList(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes))
    )
    .padding()
    .frame(width: 340, height: 400)
  }
#endif
