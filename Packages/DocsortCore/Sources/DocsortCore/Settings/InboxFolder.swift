import Foundation

/// One inbox folder configured in Settings, shown as an entry in the sidebar.
public struct InboxFolder: Codable, Hashable, Sendable, Identifiable {
  /// Stable identity of the inbox across launches, independent of its folder and label.
  public let id: UUID
  /// The label the user gave the inbox; `nil` or blank means the folder name is shown instead.
  public var label: String?
  /// The inbox's folder.
  public var folder: FolderReference

  /// An inbox for `folder`, labelled `label`, with a new identity unless `id` is given.
  public init(id: UUID = UUID(), label: String? = nil, folder: FolderReference) {
    self.id = id
    self.label = label
    self.folder = folder
  }

  /// The name shown for the inbox: the trimmed label, or the folder name when the label is `nil` or blank.
  public var displayLabel: String {
    Self.normalisedLabel(label) ?? folder.folderName
  }

  /// `label` trimmed of surrounding whitespace, or `nil` when nothing remains.
  static func normalisedLabel(_ label: String?) -> String? {
    guard let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else {
      return nil
    }
    return trimmed
  }
}
