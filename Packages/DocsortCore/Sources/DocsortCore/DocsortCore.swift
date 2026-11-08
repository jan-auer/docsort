/// Non-UI logic for docsort-ui. Foundation only; no SwiftUI or AppKit.
///
/// - `Settings`: inbox folders and the archive root as security-scoped bookmarks (`FolderSettings`), resolved at
///   launch into a `FolderAccessSession` that reports each folder as available, stale, missing or unreachable.
/// - `Inbox`: `InboxScanner` lists an inbox oldest first, grouping files in subfolders under their top-level folder.
/// - `Destinations`: `DestinationIndex` holds every archive folder, with fuzzy search, navigation and folder listing.
/// - `FileOperations`: moving, renaming, creating folders, trashing and undoing, never overwriting anything.
/// - `History`: `FilingHistory` and `FilingHistoryStore`, the persistent, versioned log of every move and trash.
/// - `Recents`, `Preferences`: recent destinations and the `UserDefaults` storage they and the settings use.
/// - `FileSystem`: `VisibleContentsWalker`, the Finder-like walk the inbox scan and the destination index share.
