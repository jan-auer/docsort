import Foundation
import Testing

@testable import DocsortCore

/// Search over ``largeArchiveCorpus()``, large enough that the matcher scores and highlights in parallel chunks.
@Suite("Search over a large archive")
struct LargeArchiveSearchTests {
  static let paths = largeArchiveCorpus()
  static let matcher = DestinationMatcher(paths: paths)

  @Test(
    "every copy of the corpus finds the same folders, so no chunk boundary drops or repeats one",
    arguments: ["hund rech", "kontoauszuege", "imk"])
  func copiesMatchAlike(query: String) throws {
    let matches = Self.matcher.matches(for: query, limit: .max)
    var relativePathsByCopy: [String: [String]] = [:]
    for match in matches {
      let segments = match.path.split(separator: "/", maxSplits: 1).map(String.init)
      guard segments.count == 2, segments[0].hasPrefix("Bestand ") else { continue }
      relativePathsByCopy[segments[0], default: []].append(segments[1])
    }
    let first = try #require(relativePathsByCopy[largeArchiveCopyFolder(1)])

    #expect(relativePathsByCopy.count == largeArchiveCopyCount)
    for copy in 1...largeArchiveCopyCount {
      #expect(
        relativePathsByCopy[largeArchiveCopyFolder(copy)]?.sorted() == first.sorted(),
        "copy \(copy)")
    }
    #expect(Set(matches.map(\.path)).count == matches.count)
  }

  @Test(
    "a scoped search in one copy ranks like a search over the corpus alone",
    arguments: ["rech", "hund rech", "imk volk", "kontoauszuege 2036", "rchng"])
  func scopedCopyRanksLikeTheCorpus(query: String) {
    let scoped = Self.matcher.matches(for: query, in: largeArchiveCopyFolder(7))
    let alone = DestinationRankingTests.matcher.matches(for: query)

    #expect(scoped.map(\.pathInScope) == alone.map(\.path))
    #expect(scoped.map(\.score) == alone.map(\.score))
    #expect(scoped.map { highlighted($0) } == alone.map { highlighted($0) })
  }
}

/// Per-keystroke search timings over ``largeArchiveCorpus()``, as the picker searches while a query is typed. Opt-in,
/// and meaningful only in an optimised build:
///
///     DOCSORT_SEARCH_BENCHMARK=1 swift test -c release -Xswiftc -enable-testing --filter DestinationSearchBenchmark
@Suite(
  "DestinationSearchBenchmark",
  .enabled(if: ProcessInfo.processInfo.environment["DOCSORT_SEARCH_BENCHMARK"] != nil))
struct DestinationSearchBenchmark {
  @Test("typing a query, from the root and inside folders")
  func typing() {
    // NFC-normalised through Foundation, as the index holds them: bridged strings, not native ones.
    let paths = largeArchiveCorpus().map(\.precomposedStringWithCanonicalMapping)
    let clock = ContinuousClock()
    var matcher = DestinationMatcher(paths: [])
    let preparation = clock.measure { matcher = DestinationMatcher(paths: paths) }
    print("\(paths.count) folders; matcher prepared in \(milliseconds(preparation))")
    for query in ["kontoauszuege 2036", "hund rech", "seeschwalbe liege", "rchng"] {
      for scope in ["", largeArchiveCopyFolder(7), "Belege"] {
        var keystrokes: [Duration] = []
        for length in 1...query.count {
          let typed = String(query.prefix(length))
          keystrokes.append(
            clock.measure {
              // What the picker lists for one keystroke: the scope's matches, and inside a folder the matches
              // elsewhere and whether the folder itself matches.
              _ = matcher.matches(for: typed, in: scope)
              if !scope.isEmpty {
                _ = matcher.matches(for: typed, outside: scope)
                _ = matcher.matches(typed, folder: scope)
              }
            })
        }
        let total = keystrokes.reduce(.zero, +)
        print(
          "'\(query)' in '\(scope)': mean \(milliseconds(total / keystrokes.count)), worst \(milliseconds(keystrokes.max() ?? .zero))"
        )
      }
    }
  }

  private func milliseconds(_ duration: Duration) -> String {
    let value =
      Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    return String(format: "%.1f ms", value)
  }
}
