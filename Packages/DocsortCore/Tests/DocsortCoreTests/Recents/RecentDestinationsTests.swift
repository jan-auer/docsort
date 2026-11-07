import Foundation
import Testing

@testable import DocsortCore

@Suite("RecentDestinations")
struct RecentDestinationsTests {
  @Test("a new list is empty with the default capacity")
  func emptyByDefault() {
    let recents = RecentDestinations()

    #expect(recents.paths.isEmpty)
    #expect(recents.capacity == 20)
    #expect(RecentDestinations.defaultCapacity == 20)
  }

  @Test("record puts the path at the front")
  func recordToFront() {
    var recents = RecentDestinations()

    recents.record("Finanzen/Steuern")
    recents.record("Wohnung/Miete")

    #expect(recents.paths == ["Wohnung/Miete", "Finanzen/Steuern"])
  }

  @Test("recording a known path moves it to the front without duplicating it")
  func recordDeduplicates() {
    var recents = RecentDestinations(paths: ["a", "b", "c"])

    recents.record("c")

    #expect(recents.paths == ["c", "a", "b"])
  }

  @Test("record drops the oldest paths beyond the capacity")
  func recordCaps() {
    var recents = RecentDestinations(paths: ["b", "a"], capacity: 2)

    recents.record("c")

    #expect(recents.paths == ["c", "b"])
  }

  @Test(
    "leading and trailing slashes do not make a different entry",
    arguments: ["a/b/", "/a/b", "/a/b/", "a/b//"])
  func normalisesSlashes(variant: String) {
    var recents = RecentDestinations(paths: ["a/b", "c"])

    recents.record(variant)

    #expect(recents.paths == ["a/b", "c"])
  }

  @Test("remove deletes the path, matching it after normalisation")
  func remove() {
    var recents = RecentDestinations(paths: ["a/b", "c"])

    recents.remove("/a/b/")

    #expect(recents.paths == ["c"])
  }

  @Test("retain keeps only the paths the predicate accepts, in order")
  func retain() {
    var recents = RecentDestinations(paths: ["a", "gone", "b", "also gone"])

    recents.retain { !$0.contains("gone") }

    #expect(recents.paths == ["a", "b"])
  }

  @Test("init normalises, deduplicates keeping the first occurrence, and caps")
  func initNormalises() {
    let recents = RecentDestinations(paths: ["a/", "b", "/a", "c", "d"], capacity: 3)

    #expect(recents.paths == ["a", "b", "c"])
    #expect(recents.capacity == 3)
  }

  @Test("a negative capacity is treated as zero")
  func negativeCapacity() {
    var recents = RecentDestinations(paths: ["a"], capacity: -1)

    recents.record("b")

    #expect(recents.capacity == 0)
    #expect(recents.paths.isEmpty)
  }

  @Test("a JSON round trip keeps paths and capacity")
  func codableRoundTrip() throws {
    let recents = RecentDestinations(paths: ["a", "b/c"], capacity: 5)

    let decoded = try JSONDecoder().decode(
      RecentDestinations.self, from: JSONEncoder().encode(recents))

    #expect(decoded == recents)
  }

  @Test("decoding normalises stored paths the same way as init")
  func decodingNormalises() throws {
    let json = Data(#"{"paths":["a/","a","b","c"],"capacity":2}"#.utf8)

    let decoded = try JSONDecoder().decode(RecentDestinations.self, from: json)

    #expect(decoded.paths == ["a", "b"])
  }

  @Test("the preference stores the list under recentDestinations")
  func preference() throws {
    let suite = try TemporaryDefaults()
    let preference = RecentDestinations.preference(in: suite.defaults)

    try preference.save(RecentDestinations(paths: ["a"]))

    #expect(preference.key == "recentDestinations")
    #expect(try preference.load() == RecentDestinations(paths: ["a"]))
  }
}
