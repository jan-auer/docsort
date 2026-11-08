import Darwin
import Foundation

/// Folder paths as the user reads them: the user's home folder abbreviated to `~`, as in `~/Archiv/_Neu/Scanner`.
nonisolated enum DisplayPath {
  /// The user's real home folder, for example `/Users/margit`.
  ///
  /// In the sandbox `NSHomeDirectory()` is the app's container, so the home folder comes from the user database
  /// instead; `NSHomeDirectory()` is the fallback should that lookup fail.
  static let userHome: String = {
    guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else {
      return NSHomeDirectory()
    }
    return String(cString: directory)
  }()

  /// `path` with the user's home folder abbreviated to `~`.
  static func abbreviating(_ path: String) -> String {
    abbreviating(path, home: userHome)
  }

  /// `path` with `home` abbreviated to `~`; a path outside `home` is returned unchanged.
  ///
  /// Only a whole leading folder matches: with home `/Users/margit`, `/Users/margitta` stays as it is.
  static func abbreviating(_ path: String, home: String) -> String {
    let home = home.hasSuffix("/") && home.count > 1 ? String(home.dropLast()) : home
    guard !home.isEmpty, home != "/" else { return path }
    if path == home { return "~" }
    guard path.hasPrefix(home + "/") else { return path }
    return "~" + path.dropFirst(home.count)
  }
}
