import Foundation

/// How docsort writes a file or folder location as a path, wherever two locations are compared or stored.
public enum FileLocation {
  /// The absolute, standardised path of `url`, without a trailing slash except for the root folder. Two URLs for the
  /// same location (a package as a directory URL or a file URL, `./` and `../` components) give the same path.
  public static func path(of url: URL) -> String {
    withoutTrailingSlashes(url.standardizedFileURL.path(percentEncoded: false))
  }

  /// `path` without trailing slashes, except for the root folder. For paths that are already absolute and
  /// standardised, such as those FSEvents reports, where building a URL to standardise them again would gain nothing.
  static func withoutTrailingSlashes(_ path: String) -> String {
    var trimmed = Substring(path)
    while trimmed.count > 1, trimmed.hasSuffix("/") {
      trimmed = trimmed.dropLast()
    }
    return String(trimmed)
  }
}
