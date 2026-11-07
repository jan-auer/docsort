import Foundation

/// The archive folders documents were most recently filed into, most recent first.
///
/// Paths are relative to the archive root. Each path is normalised by trimming leading and trailing slashes, so
/// `"a/b/"` and `"/a/b"` are the same entry as `"a/b"`; the archive root itself is the empty path. The list never holds
/// a path twice and never holds more than `capacity` paths.
public struct RecentDestinations: Codable, Equatable, Sendable {
  /// The capacity used when none is given.
  public static let defaultCapacity = 20

  /// Normalised archive-relative folder paths, most recent first, without duplicates.
  public private(set) var paths: [String]
  /// The most paths the list keeps; never negative.
  public let capacity: Int

  /// A list of `paths`, given most recent first.
  ///
  /// The paths are normalised; of duplicates, the first (most recent) is kept, and paths beyond `capacity` are
  /// dropped. A negative capacity is treated as zero.
  public init(paths: [String] = [], capacity: Int = defaultCapacity) {
    self.capacity = max(0, capacity)
    self.paths = []
    for path in paths {
      let normalised = Self.normalised(path)
      if !self.paths.contains(normalised) {
        self.paths.append(normalised)
      }
    }
    trimToCapacity()
  }

  /// Moves `path` to the front, adding it when new and dropping the oldest path beyond the capacity.
  public mutating func record(_ path: String) {
    let normalised = Self.normalised(path)
    paths.removeAll { $0 == normalised }
    paths.insert(normalised, at: 0)
    trimToCapacity()
  }

  /// Removes `path` (after normalisation) when present.
  public mutating func remove(_ path: String) {
    let normalised = Self.normalised(path)
    paths.removeAll { $0 == normalised }
  }

  /// Keeps only the paths for which `isKept` returns true, in their order; use it to drop folders that no longer
  /// exist.
  public mutating func retain(where isKept: (String) -> Bool) {
    paths.removeAll { !isKept($0) }
  }

  /// The preference that stores the list, under the key `"recentDestinations"`.
  public static func preference(in defaults: UserDefaults) -> StoredPreference<RecentDestinations> {
    StoredPreference(key: "recentDestinations", defaults: defaults)
  }

  private enum CodingKeys: String, CodingKey {
    case paths
  }

  /// Decodes a stored list with the default capacity and normalises it like `init(paths:capacity:)`.
  ///
  /// Only the paths are stored, so a change of ``defaultCapacity`` also applies to lists saved earlier.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(paths: try container.decode([String].self, forKey: .paths))
  }

  /// Encodes the paths only; the capacity is not stored.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(paths, forKey: .paths)
  }

  private mutating func trimToCapacity() {
    if paths.count > capacity {
      paths.removeLast(paths.count - capacity)
    }
  }

  private static func normalised(_ path: String) -> String {
    path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }
}
