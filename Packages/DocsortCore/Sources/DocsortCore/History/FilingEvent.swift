import Foundation

/// What a filing event did to an item: moved it (filing, renaming, moving back) or sent it to the Trash.
///
/// Each case carries the record that ``FileOperations`` returned, which is exactly what its `undo` functions need.
/// Encoded as an object with one key, `"moved"` or `"trashed"`, whose value is the record.
public enum FilingAction: Codable, Hashable, Sendable {
  /// The item was moved (and possibly renamed); undo with ``FileOperations/undo(_:resolution:)``.
  case moved(MoveRecord)
  /// The item was moved to the Trash; undo with ``FileOperations/undo(_:)-(TrashRecord)``.
  case trashed(TrashRecord)

  /// Where the item was before the action.
  var sourceURL: URL {
    switch self {
    case .moved(let record): record.originalURL
    case .trashed(let record): record.originalURL
    }
  }

  /// Where the item was after the action: the move's destination or the item's place in the Trash.
  var resultURL: URL {
    switch self {
    case .moved(let record): record.destinationURL
    case .trashed(let record): record.trashedURL
    }
  }

  private enum CodingKeys: String, CodingKey {
    case moved
    case trashed
  }

  /// Decodes an object with exactly one of the keys `"moved"` or `"trashed"`.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    guard container.allKeys.count == 1, let key = container.allKeys.first else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription:
            "A filing action needs exactly one of the keys \"moved\" or \"trashed\"."
        ))
    }
    switch key {
    case .moved: self = .moved(try container.decode(MoveRecord.self, forKey: .moved))
    case .trashed: self = .trashed(try container.decode(TrashRecord.self, forKey: .trashed))
    }
  }

  /// Encodes the record under the key naming the case.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .moved(let record): try container.encode(record, forKey: .moved)
    case .trashed(let record): try container.encode(record, forKey: .trashed)
    }
  }
}

/// One move or trash in the filing history, with when it happened and which document it belongs to.
///
/// Undone events stay in the history with their ``undoneDate`` set, so the History view can show them.
public struct FilingEvent: Codable, Hashable, Sendable, Identifiable {
  /// Identifies this event, for example to mark it undone.
  public let id: UUID
  /// When the action happened.
  public let date: Date
  /// The document this event belongs to; every event in one document's chain of moves shares it.
  public let documentID: UUID
  /// What happened, with the record needed to undo it.
  public let action: FilingAction
  /// When the event was undone, or `nil` while it is active. Set through ``FilingHistory/recordUndo(of:restoredTo:at:)``.
  public internal(set) var undoneDate: Date?
  /// The move whose Replace caused this event, or `nil`. Set on the trash event that records the replaced item; that
  /// event is undone together with its move, never on its own.
  public let causedBy: FilingEvent.ID?

  /// Where the item was before this event.
  public var sourceURL: URL { action.sourceURL }
  /// Where the item was after this event: the move's destination or the item's place in the Trash.
  public var resultURL: URL { action.resultURL }
}
