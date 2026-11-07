import Foundation
import Testing

@testable import DocsortCore

@Suite("StoredPreference")
struct StoredPreferenceTests {
  struct Sample: Codable, Equatable, Sendable {
    var name: String
    var count: Int
  }

  @Test("load returns nil when the key is absent")
  func absentKey() throws {
    let suite = try TemporaryDefaults()
    let preference = StoredPreference<Sample>(key: "sample", defaults: suite.defaults)

    #expect(try preference.load() == nil)
  }

  @Test("a saved value loads back unchanged")
  func roundTrip() throws {
    let suite = try TemporaryDefaults()
    let preference = StoredPreference<Sample>(key: "sample", defaults: suite.defaults)

    try preference.save(Sample(name: "Rechnungen", count: 3))

    #expect(try preference.load() == Sample(name: "Rechnungen", count: 3))
  }

  @Test("save stores JSON data under the key")
  func savesJSONData() throws {
    let suite = try TemporaryDefaults()
    let preference = StoredPreference<Sample>(key: "sample", defaults: suite.defaults)

    try preference.save(Sample(name: "a", count: 1))

    let stored = try #require(suite.defaults.data(forKey: "sample"))
    #expect(try JSONDecoder().decode(Sample.self, from: stored) == Sample(name: "a", count: 1))
  }

  @Test("remove deletes the stored value")
  func remove() throws {
    let suite = try TemporaryDefaults()
    let preference = StoredPreference<Sample>(key: "sample", defaults: suite.defaults)
    try preference.save(Sample(name: "a", count: 1))

    preference.remove()

    #expect(try preference.load() == nil)
    #expect(suite.defaults.object(forKey: "sample") == nil)
  }

  @Test("undecodable data throws an error naming the key")
  func corruptData() throws {
    let suite = try TemporaryDefaults()
    suite.defaults.set(Data("not json".utf8), forKey: "sample")
    let preference = StoredPreference<Sample>(key: "sample", defaults: suite.defaults)

    let error = try #require(throws: PreferenceError.self) { try preference.load() }

    #expect(error.key == "sample")
    guard case .decodingFailed = error else {
      Issue.record("expected decodingFailed, got \(error)")
      return
    }
  }

  @Test("a stored value that is not data throws an error naming the key")
  func valueOfWrongType() throws {
    let suite = try TemporaryDefaults()
    suite.defaults.set("a string", forKey: "sample")
    let preference = StoredPreference<Sample>(key: "sample", defaults: suite.defaults)

    let error = try #require(throws: PreferenceError.self) { try preference.load() }

    #expect(error.key == "sample")
    guard case .valueIsNotData = error else {
      Issue.record("expected valueIsNotData, got \(error)")
      return
    }
  }

  @Test("a value JSON cannot encode throws an error naming the key and stores nothing")
  func unencodableValue() throws {
    let suite = try TemporaryDefaults()
    let preference = StoredPreference<Double>(key: "ratio", defaults: suite.defaults)

    let error = try #require(throws: PreferenceError.self) { try preference.save(.nan) }

    #expect(error.key == "ratio")
    guard case .encodingFailed = error else {
      Issue.record("expected encodingFailed, got \(error)")
      return
    }
    #expect(suite.defaults.object(forKey: "ratio") == nil)
  }

  @Test("the error description names the key")
  func errorDescription() throws {
    let suite = try TemporaryDefaults()
    suite.defaults.set(Data("not json".utf8), forKey: "folderSettings")
    let preference = StoredPreference<Sample>(key: "folderSettings", defaults: suite.defaults)

    let error = try #require(throws: PreferenceError.self) { try preference.load() }

    #expect(error.description.contains("folderSettings"))
  }
}
