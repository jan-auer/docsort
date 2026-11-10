extension Comparable {
  /// The value, moved into `range` if it lies outside.
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
