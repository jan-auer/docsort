import Foundation

/// Every move and trash Docsort made, grouped into documents, so filing can be listed, followed and undone across
/// restarts.
///
/// A *document* is one item followed through its chain of events. A new event whose source is a document's current
/// location continues that document; any other event starts a new one. A document's *current location* is the result
/// of its latest active (not undone) event, or, when every event is undone, the source of its first event. Locations
/// compare as standardized file paths, ignoring a trailing slash, so a package recorded as a directory URL matches
/// the same path without the slash.
///
/// Guarantees:
/// - Events are kept in the order they were recorded and never removed; undone events stay with their undo date.
/// - Only the latest active event of a document can be marked undone, so a document's active events always form an
///   unbroken chain from its origin to its current location.
/// - The model never reads the clock; every date is passed in.
public struct FilingHistory: Codable, Equatable, Sendable {
  /// The version of the encoded format. Decoding any other version fails, so a later format can be migrated
  /// explicitly instead of being misread.
  static let formatVersion = 1

  /// All events in the order they were recorded (with dates from the clock: chronological, oldest first).
  public private(set) var events: [FilingEvent]

  /// An empty history.
  public init() {
    events = []
  }

  // MARK: - Recording

  /// Records a completed move at `date` and returns the new event. The move continues the document currently at its
  /// original URL, or starts a new document.
  @discardableResult
  public mutating func recordMove(_ record: MoveRecord, at date: Date) -> FilingEvent {
    append(.moved(record), at: date)
  }

  /// Records a completed move to the Trash at `date` and returns the new event. It continues the document currently
  /// at the trashed item's original URL, or starts a new document.
  @discardableResult
  public mutating func recordTrash(_ record: TrashRecord, at date: Date) -> FilingEvent {
    append(.trashed(record), at: date)
  }

  /// Marks the event `eventID` as undone at `date`; call it after the matching `FileOperations.undo` succeeded.
  ///
  /// Fails, changing nothing, when the event is unknown, already undone, or not the latest active event of its
  /// document: a file can only be put back from where its latest event left it, so undoing an earlier event first
  /// would leave the history describing places the file never was.
  public mutating func markUndone(
    _ eventID: FilingEvent.ID, at date: Date
  ) throws(FilingHistoryError) {
    guard let index = events.firstIndex(where: { $0.id == eventID }) else {
      throw .unknownEvent(eventID)
    }
    let event = events[index]
    if let undoneDate = event.undoneDate {
      throw .alreadyUndone(eventID, undoneDate: undoneDate)
    }
    if let laterEvent = events[(index + 1)...].first(where: {
      $0.documentID == event.documentID && $0.undoneDate == nil
    }) {
      throw .laterEventActive(eventID, later: laterEvent.id)
    }
    events[index].undoneDate = date
  }

  // MARK: - Documents

  /// The events of `documentID`, active and undone, in the order they were recorded; empty for an unknown document.
  public func events(ofDocument documentID: UUID) -> [FilingEvent] {
    events.filter { $0.documentID == documentID }
  }

  /// The latest active event of `documentID`: the one to undo next. `nil` when the document is unknown or all its
  /// events are undone.
  public func latestActiveEvent(ofDocument documentID: UUID) -> FilingEvent? {
    events.last { $0.documentID == documentID && $0.undoneDate == nil }
  }

  /// Where `documentID` was before its first active event (before its first event when all are undone): its inbox
  /// path and original name. Use its folder and name to move the document back to the inbox or to revert its name.
  /// `nil` for an unknown document.
  public func origin(ofDocument documentID: UUID) -> URL? {
    let documentEvents = events(ofDocument: documentID)
    return (documentEvents.first { $0.undoneDate == nil } ?? documentEvents.first)?.sourceURL
  }

  /// Where `documentID` is now according to the history (see ``FilingHistory``); `nil` for an unknown document.
  public func currentLocation(ofDocument documentID: UUID) -> URL? {
    latestActiveEvent(ofDocument: documentID)?.resultURL
      ?? events(ofDocument: documentID).first?.sourceURL
  }

  /// The document whose current location is `url`, or `nil` when there is none.
  ///
  /// When several documents are at the same location (for example after a Replace sent one of them to the Trash),
  /// the one with the most recent activity, an event or an undo, is the one there.
  public func document(at url: URL) -> UUID? {
    let wantedKey = Self.locationKey(url)
    var latest: (documentID: UUID, summary: DocumentSummary)?
    for (documentID, summary) in documentSummaries()
    where Self.locationKey(summary.currentLocation) == wantedKey {
      if let current = latest, !summary.isMoreRecent(than: current.summary) { continue }
      latest = (documentID, summary)
    }
    return latest?.documentID
  }

  // MARK: - Coding

  private enum CodingKeys: String, CodingKey {
    case version
    case events
  }

  /// Decodes a history of format version ``formatVersion``; any other or a missing version fails.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let version = try container.decode(Int.self, forKey: .version)
    guard version == Self.formatVersion else {
      throw DecodingError.dataCorruptedError(
        forKey: .version, in: container,
        debugDescription:
          "Filing history format version \(version) is not supported; expected \(Self.formatVersion)."
      )
    }
    events = try container.decode([FilingEvent].self, forKey: .events)
  }

  /// Encodes the events together with the format version.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Self.formatVersion, forKey: .version)
    try container.encode(events, forKey: .events)
  }

  // MARK: - Private

  /// What linking needs to know about one document, gathered in a single pass over the events.
  private struct DocumentSummary {
    var currentLocation: URL
    /// The latest event date or undo date of the document.
    var lastActivity: Date
    /// The position of the document's latest event in ``events``, to break ties between equal activity dates.
    var lastIndex: Int

    func isMoreRecent(than other: DocumentSummary) -> Bool {
      (lastActivity, lastIndex) > (other.lastActivity, other.lastIndex)
    }
  }

  private func documentSummaries() -> [UUID: DocumentSummary] {
    var summaries: [UUID: DocumentSummary] = [:]
    for (index, event) in events.enumerated() {
      let activity = max(event.date, event.undoneDate ?? event.date)
      if var summary = summaries[event.documentID] {
        if event.undoneDate == nil { summary.currentLocation = event.resultURL }
        summary.lastActivity = max(summary.lastActivity, activity)
        summary.lastIndex = index
        summaries[event.documentID] = summary
      } else {
        summaries[event.documentID] = DocumentSummary(
          currentLocation: event.undoneDate == nil ? event.resultURL : event.sourceURL,
          lastActivity: activity, lastIndex: index)
      }
    }
    return summaries
  }

  private mutating func append(_ action: FilingAction, at date: Date) -> FilingEvent {
    let event = FilingEvent(
      id: UUID(), date: date, documentID: document(at: action.sourceURL) ?? UUID(), action: action,
      undoneDate: nil)
    events.append(event)
    return event
  }

  /// The standardized path of `url` without a trailing slash, under which equal locations compare equal.
  private static func locationKey(_ url: URL) -> String {
    var path = url.standardizedFileURL.path(percentEncoded: false)
    while path.count > 1, path.hasSuffix("/") {
      path.removeLast()
    }
    return path
  }
}

/// Why ``FilingHistory/markUndone(_:at:)`` refused; the history is unchanged.
public enum FilingHistoryError: Error, Equatable, Sendable, CustomStringConvertible {
  /// No event has this ID.
  case unknownEvent(FilingEvent.ID)
  /// The event was already undone at `undoneDate`.
  case alreadyUndone(FilingEvent.ID, undoneDate: Date)
  /// A later event of the same document, `later`, is still active and must be undone first.
  case laterEventActive(FilingEvent.ID, later: FilingEvent.ID)

  /// A message naming the event and the cause, for logs.
  public var description: String {
    switch self {
    case .unknownEvent(let id):
      "The filing history has no event \(id)."
    case .alreadyUndone(let id, let undoneDate):
      "The filing event \(id) was already undone at \(undoneDate)."
    case .laterEventActive(let id, let later):
      "The filing event \(id) cannot be undone before the later event \(later) of the same document."
    }
  }
}
