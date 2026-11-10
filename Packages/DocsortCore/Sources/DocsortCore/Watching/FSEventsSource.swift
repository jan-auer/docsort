import CoreServices
import Foundation
import Synchronization

/// The real ``FolderEventSource``: one FSEvents stream per call, covering all roots recursively.
///
/// The stream reports file-level events (`FileEvents`), changes to the roots themselves and their ancestors
/// (`WatchRoot`: renamed, deleted, unmounted, or a missing root appearing), and delivers the first event of a quiet
/// period at once (`NoDefer`). Only events from the moment of the call on are reported. Paths are canonical for roots
/// that existed when watching started (`/private/var/...`); for a root that did not exist yet, FSEvents reports only
/// `RootChanged` on the path as given, and changes inside that root once it appears are not reported until a new
/// watch is started.
struct FSEventsSource: FolderEventSource {
  /// How long FSEvents collects events before delivering them. Kept short; ``ChangeCoalescer`` does the batching.
  let latency: Duration

  /// Creates a source that delivers events after `latency`.
  init(latency: Duration = .milliseconds(50)) {
    self.latency = latency
  }

  func changedPaths(under roots: Set<URL>) throws(FolderWatchError) -> AsyncStream<String> {
    let (paths, continuation) = AsyncStream.makeStream(of: String.self)
    guard !roots.isEmpty else {
      continuation.finish()
      return paths
    }
    let watch = try FSEventsWatch(
      roots: roots, latency: latency, delivery: EventDelivery(continuation))
    continuation.onTermination = { _ in watch.stop() }
    return paths
  }
}

/// The receiver of an FSEvents stream's callbacks. FSEvents holds it through the context's `info` pointer, retained
/// by the context's retain callback and released once when the stream is released.
private final class EventDelivery: Sendable {
  let continuation: AsyncStream<String>.Continuation

  init(_ continuation: AsyncStream<String>.Continuation) {
    self.continuation = continuation
  }

  /// Retains `info` (an `EventDelivery`) on behalf of FSEvents.
  static let retainInfo: CFAllocatorRetainCallBack = { info in
    guard let info else { return nil }
    _ = Unmanaged<EventDelivery>.fromOpaque(info).retain()
    return info
  }

  /// Releases the reference FSEvents took with ``retainInfo``.
  static let releaseInfo: CFAllocatorReleaseCallBack = { info in
    guard let info else { return }
    Unmanaged<EventDelivery>.fromOpaque(info).release()
  }

  /// Yields the paths of one callback. With `UseCFTypes`, `eventPaths` is a `CFArray` of `CFString`.
  static let deliver: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
    guard let info else { return }
    let delivery = Unmanaged<EventDelivery>.fromOpaque(info).takeUnretainedValue()
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as NSArray
    // `UseCFTypes` guarantees strings; anything else would not be a path to report.
    for case let path as String in paths {
      delivery.continuation.yield(path)
    }
  }
}

/// A running FSEvents stream, scheduled on its own serial queue. Stopped, invalidated and released exactly once.
private final class FSEventsWatch: Sendable {
  private static let flags = FSEventStreamCreateFlags(
    kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot
      | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)

  private let queue = DispatchQueue(label: "DocsortCore.FSEventsSource")
  /// The stream until ``stop()`` takes it.
  private let stream: Mutex<FSEventStreamRef?>

  init(roots: Set<URL>, latency: Duration, delivery: EventDelivery) throws(FolderWatchError) {
    var context = FSEventStreamContext(
      version: 0, info: Unmanaged.passUnretained(delivery).toOpaque(),
      retain: EventDelivery.retainInfo, release: EventDelivery.releaseInfo, copyDescription: nil)
    let rootPaths = roots.map { FileLocation.path(of: $0) } as CFArray
    let created = withExtendedLifetime(delivery) {
      FSEventStreamCreate(
        kCFAllocatorDefault, EventDelivery.deliver, &context, rootPaths,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency.seconds, Self.flags)
    }
    guard let created else {
      throw .streamNotCreated(roots: roots)
    }
    FSEventStreamSetDispatchQueue(created, queue)
    guard FSEventStreamStart(created) else {
      FSEventStreamInvalidate(created)
      FSEventStreamRelease(created)
      throw .streamNotStarted(roots: roots)
    }
    stream = Mutex(created)
  }

  /// Stops the stream on its queue, so that no callback runs concurrently; later calls do nothing.
  func stop() {
    queue.async { [self] in
      guard let stream = stream.withLock({ $0.take() }) else { return }
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      // Releases the stream and with it the context's reference to the delivery.
      FSEventStreamRelease(stream)
    }
  }
}

extension Duration {
  /// The duration in seconds, as Core Foundation time intervals count it.
  fileprivate var seconds: CFTimeInterval {
    let (seconds, attoseconds) = components
    return CFTimeInterval(seconds) + CFTimeInterval(attoseconds) / 1e18
  }
}
