import Foundation

/// Sets the hidden flag (`UF_HIDDEN`) on the item at `url`.
func markHidden(_ url: URL) throws {
  var hiddenURL = url
  var values = URLResourceValues()
  values.isHidden = true
  try hiddenURL.setResourceValues(values)
}

/// Sets the POSIX permissions of the item at `url`.
func setPermissions(_ permissions: Int, of url: URL) throws {
  try FileManager.default.setAttributes(
    [.posixPermissions: permissions], ofItemAtPath: url.path(percentEncoded: false))
}
