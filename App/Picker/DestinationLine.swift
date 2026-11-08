import SwiftUI

/// The destination line under the picker's search field, the one place the full destination path is shown:
/// `Archive › Gesundheit › Konrad › Physiotherapie`, the folder's own name in semibold, wrapping onto a second line
/// rather than hiding part of the path. It names the chosen folder (with a filled folder icon), else the highlighted
/// one (outlined), so it always says where ⌘Return would file. Each ancestor is a link that takes the picker there.
///
/// Accessibility: `filing-destination`, labelled "Destination: Archive › …", with an action per ancestor.
struct DestinationLine: View {
  /// What to show; `nil` when no folder is chosen or highlighted.
  let destination: DestinationPath?
  /// Takes the picker to an archive-relative folder (`""` for the root).
  let jump: (String) -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      if let destination {
        Image(systemName: destination.isChosen ? "folder.fill" : "folder")
          .foregroundStyle(destination.isChosen ? Color.accentColor : .secondary)
          .accessibilityHidden(true)
        Text(Self.text(for: destination))
          .lineLimit(2)
          .truncationMode(.head)
          .tint(.secondary)
          .environment(\.openURL, OpenURLAction { url in jump(toSegmentIn: url, of: destination) })
          .help(destination.segments.map(\.title).joined(separator: " › "))
        if destination.isNew {
          NewBadge(tone: .standard)
        }
      } else {
        Text("No folder chosen")
          .foregroundStyle(.tertiary)
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityActions {
      if let destination {
        ForEach(destination.segments.dropLast()) { segment in
          Button("Go to \(segment.title)") { jump(segment.path) }
        }
      }
    }
    .accessibilityIdentifier("filing-destination")
  }

  private var accessibilityLabel: String {
    guard let destination else { return "No folder chosen" }
    let path = destination.segments.map(\.title).joined(separator: " › ")
    return destination.isNew ? "Destination: \(path), new folder" : "Destination: \(path)"
  }

  /// The path as one text: ancestors as links in secondary colour, `›` in tertiary, the folder in semibold primary.
  static func text(for destination: DestinationPath) -> AttributedString {
    let segments = destination.segments
    var text = AttributedString()
    for (position, segment) in segments.enumerated() {
      if position > 0 {
        var separator = AttributedString(" › ")
        separator.foregroundColor = Color(nsColor: .tertiaryLabelColor)
        text += separator
      }
      var part = AttributedString(segment.title)
      if position == segments.count - 1 {
        part.inlinePresentationIntent = .stronglyEmphasized
      } else {
        part.link = URL(string: "\(linkScheme):\(position)")
      }
      text += part
    }
    return text
  }

  /// The scheme of the segment links; their payload is the segment's position.
  private static let linkScheme = "docsort-segment"

  private func jump(toSegmentIn url: URL, of destination: DestinationPath) -> OpenURLAction.Result {
    guard url.scheme == Self.linkScheme,
      let position = Int(url.absoluteString.dropFirst(Self.linkScheme.count + 1)),
      destination.segments.indices.contains(position)
    else { return .discarded }
    jump(destination.segments[position].path)
    return .handled
  }
}

#if DEBUG
  #Preview("Chosen, highlighted, new, none") {
    VStack(alignment: .leading, spacing: 12) {
      DestinationLine(
        destination: DestinationPath(
          path: "Gesundheit/Konrad/Physiotherapie", isChosen: true, isNew: false), jump: { _ in })
      DestinationLine(
        destination: DestinationPath(
          path: "Kommunikation/Ilmnet Internet/Rechnungen", isChosen: false, isNew: false),
        jump: { _ in })
      DestinationLine(
        destination: DestinationPath(
          path: "Reisen/2033-06 Wanderwoche Hochalm/Anreise/Bahn und Bus nach Hochalm",
          isChosen: true,
          isNew: true), jump: { _ in })
      DestinationLine(destination: nil, jump: { _ in })
    }
    .padding()
    .frame(width: 300)
  }
#endif
