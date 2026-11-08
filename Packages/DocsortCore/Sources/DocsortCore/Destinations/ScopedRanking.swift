/// How destination search weighs a folder's closeness to the scope against a folder named exactly like a query word.
///
/// Both modes rank by match quality first and keep every other rule of ``DestinationIndex/search(_:in:ranking:recents:limit:)``;
/// they differ only where a folder whose own name equals a query word lies deeper than a folder whose name merely
/// starts with or contains it. Inside `Töpferei`, `glasur` finds:
///
/// | Mode                 | First                        | Second                       |
/// | -------------------- | ---------------------------- | ---------------------------- |
/// | ``directChildFirst`` | `Töpferei/Glasurrezepte`     | `Töpferei/Werkstoffe/Glasur` |
/// | ``exactNameFirst``   | `Töpferei/Werkstoffe/Glasur` | `Töpferei/Glasurrezepte`     |
///
/// The archive root is a scope like any other: closer folders come first there too. In this example neither folder is
/// a direct child of the root, so from the root both modes find `Töpferei/Werkstoffe/Glasur` first.
///
/// The raw values are stored as the user's setting; never change them.
public enum ScopedRanking: String, Codable, Sendable, Hashable, CaseIterable {
  /// Closer folders first, the default. A direct child of the scope whose name starts with the word ranks above a
  /// folder one level deeper that is named exactly like it, because the direct child's match starts the path the
  /// picker shows.
  case directChildFirst = "directChildFirst"
  /// A folder whose own name (its last segment) equals a query word, ignoring case and diacritics, gets an extra bonus
  /// worth more than one level of depth and less than two. Among matches of comparable quality it ranks above a
  /// folder one level closer to the scope whose name only starts with or contains the word, but not above one two
  /// levels closer: `hobby` from the root still finds `Hobbys` before `Wohnung/Keller/Hobby`.
  case exactNameFirst = "exactNameFirst"
}
