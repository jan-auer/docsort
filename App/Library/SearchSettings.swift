import DocsortCore
import Foundation
import OSLog
import Observation

/// The user's destination-search settings, stored in the preferences; the destination picker reads them.
///
/// Like the other libraries it uses only Foundation, Observation and DocsortCore.
@Observable
final class SearchSettings {
  /// Whether closer folders or exact name matches rank first (`search-scoped-ranking`); saved on every change.
  var ranking: ScopedRanking {
    didSet {
      guard ranking != oldValue else { return }
      save(ranking)
    }
  }

  @ObservationIgnored private let preference: StoredPreference<ScopedRanking>

  /// The preference that stores the ranking, under the key `"searchRanking"`.
  static func rankingPreference(in defaults: UserDefaults) -> StoredPreference<ScopedRanking> {
    StoredPreference(key: "searchRanking", defaults: defaults)
  }

  /// Loads the settings from `defaults`; nothing stored, or a value that cannot be read, means the default ranking,
  /// closer folders first.
  init(defaults: UserDefaults) {
    preference = Self.rankingPreference(in: defaults)
    do {
      ranking = try preference.load() ?? .directChildFirst
    } catch {
      // A ranking that cannot be read loses nothing worth keeping: the default applies, and the next change the user
      // makes replaces the stored value.
      Logger.preferences.error(
        "The search ranking could not be read; using closer folders first: \(error.description, privacy: .public)"
      )
      ranking = .directChildFirst
    }
  }

  private func save(_ ranking: ScopedRanking) {
    do {
      try preference.save(ranking)
      Logger.preferences.notice("Search ranking set to \(ranking.rawValue, privacy: .public)")
    } catch {
      Logger.preferences.error(
        "Could not save the search ranking: \(error.description, privacy: .public)")
    }
  }
}
