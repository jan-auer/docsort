import Foundation

/// One `Codable` value stored as JSON-encoded `Data` under a key in `UserDefaults`.
///
/// The value is read and written on demand; nothing is cached, so two instances for the same key and defaults always
/// see the same value.
///
/// `@unchecked Sendable`: the only non-`Sendable` stored property is `UserDefaults`, which the macOS 27 SDK does not
/// mark `Sendable` but documents in `NSUserDefaults.h` as thread-safe for use from multiple threads or tasks at once.
public struct StoredPreference<Value: Codable & Sendable>: @unchecked Sendable {
  /// The `UserDefaults` key the value is stored under.
  public let key: String
  private let defaults: UserDefaults

  /// A preference for the value under `key` in `defaults`.
  public init(key: String, defaults: UserDefaults) {
    self.key = key
    self.defaults = defaults
  }

  /// The stored value, or `nil` when nothing is stored under the key.
  ///
  /// Throws when something is stored under the key but cannot be read as a `Value`; the error names the key.
  public func load() throws(PreferenceError) -> Value? {
    guard let stored = defaults.object(forKey: key) else {
      return nil
    }
    guard let data = stored as? Data else {
      throw .valueIsNotData(key: key)
    }
    do {
      return try JSONDecoder().decode(Value.self, from: data)
    } catch {
      throw .decodingFailed(key: key, underlying: error)
    }
  }

  /// Stores `value` as JSON-encoded `Data` under the key, replacing any previous value.
  ///
  /// When encoding fails, the error names the key and the previously stored value is left unchanged.
  public func save(_ value: Value) throws(PreferenceError) {
    let data: Data
    do {
      data = try JSONEncoder().encode(value)
    } catch {
      throw .encodingFailed(key: key, underlying: error)
    }
    defaults.set(data, forKey: key)
  }

  /// Removes the stored value; `load()` returns `nil` afterwards.
  public func remove() {
    defaults.removeObject(forKey: key)
  }
}

/// Why a `StoredPreference` could not be loaded or saved.
public enum PreferenceError: Error, CustomStringConvertible {
  /// The object stored under `key` is not `Data`, so it was not written by `StoredPreference`.
  case valueIsNotData(key: String)
  /// The data stored under `key` is not valid JSON for the expected type.
  case decodingFailed(key: String, underlying: any Error)
  /// The value for `key` could not be encoded as JSON.
  case encodingFailed(key: String, underlying: any Error)

  /// The `UserDefaults` key the failing operation used.
  public var key: String {
    switch self {
    case .valueIsNotData(let key), .decodingFailed(let key, _), .encodingFailed(let key, _):
      key
    }
  }

  /// A message naming the key and the cause, for logs.
  public var description: String {
    switch self {
    case .valueIsNotData(let key):
      "The preference \"\(key)\" does not hold data."
    case .decodingFailed(let key, let underlying):
      "The preference \"\(key)\" could not be decoded: \(underlying)"
    case .encodingFailed(let key, let underlying):
      "The preference \"\(key)\" could not be encoded: \(underlying)"
    }
  }
}
