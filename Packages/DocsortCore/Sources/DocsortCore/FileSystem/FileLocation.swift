import Foundation

/// How docsort writes a file or folder location as a path, wherever two locations are compared or stored.
public enum FileLocation {
  /// The absolute, standardised path of `url`, without a trailing slash except for the root folder. Two URLs for the
  /// same location (a package as a directory URL or a file URL, `./` and `../` components) give the same path.
  public static func path(of url: URL) -> String {
    var path = url.standardizedFileURL.path(percentEncoded: false)
    while path.count > 1, path.hasSuffix("/") {
      path.removeLast()
    }
    return path
  }
}
