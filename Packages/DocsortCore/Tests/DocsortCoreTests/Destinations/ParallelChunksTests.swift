import Testing

@testable import DocsortCore

@Suite("ParallelChunks")
struct ParallelChunksTests {
  @Test(
    "transforms every index once and keeps the order, whatever the chunk size",
    arguments: [0, 1, 7, 64, 1000, 5000])
  func keepsOrder(chunkSize: Int) {
    let indices = 3..<2_503

    let result = ParallelChunks.flatMap(indices, chunkSize: chunkSize) { chunk in
      chunk.filter { $0 % 3 != 0 }.map { $0 * 2 }
    }

    #expect(result == indices.filter { $0 % 3 != 0 }.map { $0 * 2 })
  }

  @Test("an empty range transforms to nothing")
  func emptyRange() {
    #expect(ParallelChunks.flatMap(0..<0, chunkSize: 8) { Array($0) }.isEmpty)
  }
}
