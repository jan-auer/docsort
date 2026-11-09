import Foundation

/// Splits a range of indices into chunks and transforms them on all processor cores, keeping the results in order.
enum ParallelChunks {
  /// `transform` applied to consecutive chunks of `indices` of at most `chunkSize` indices each, concurrently, with
  /// the chunks' results concatenated in the order of `indices`; the same result as `transform(indices)` for a
  /// `transform` that handles each index on its own.
  ///
  /// Blocks the calling thread until every chunk is done, and runs a single chunk on it directly.
  static func flatMap<Element: Sendable>(
    _ indices: Range<Int>, chunkSize: Int, _ transform: @Sendable (Range<Int>) -> [Element]
  ) -> [Element] {
    let chunkSize = max(chunkSize, 1)
    let chunkCount = (indices.count + chunkSize - 1) / chunkSize
    guard chunkCount > 1 else { return transform(indices) }
    let storage = UnsafeMutableBufferPointer<[Element]>.allocate(capacity: chunkCount)
    storage.initialize(repeating: [])
    defer {
      storage.deinitialize()
      storage.deallocate()
    }
    // Safe to share: every iteration writes only its own element, and all are done before it is read.
    nonisolated(unsafe) let chunkResults = storage
    DispatchQueue.concurrentPerform(iterations: chunkCount) { chunk in
      let lowerBound = indices.lowerBound + chunk * chunkSize
      chunkResults[chunk] = transform(lowerBound..<min(lowerBound + chunkSize, indices.upperBound))
    }
    return storage.flatMap(\.self)
  }

  /// A chunk size that spreads `count` items over the cores a few chunks per core, so uneven chunks even out, but
  /// never below `minimum` items, below which handing work to another thread costs more than it saves.
  static func chunkSize(for count: Int, minimum: Int) -> Int {
    max(minimum, count / (ProcessInfo.processInfo.activeProcessorCount * 4) + 1)
  }
}
