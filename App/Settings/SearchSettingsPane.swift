import DocsortCore
import SwiftUI

/// The Search pane of the Settings window: which matches the destination search ranks first.
struct SearchSettingsPane: View {
  /// The ranking setting (`search-scoped-ranking`).
  @Binding var ranking: ScopedRanking

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker("Rank first:", selection: $ranking) {
        Text("Closer folders").tag(ScopedRanking.directChildFirst)
        Text("Exact name matches").tag(ScopedRanking.exactNameFirst)
      }
      .pickerStyle(.radioGroup)
      .accessibilityIdentifier("settings-ranking")
      Text(
        "Closer folders: a folder fewer levels below the current one comes first. Exact name matches: a folder named exactly like a typed word may come before a closer one. Applies inside a folder and at the archive folder alike."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frame(width: 640, alignment: .topLeading)
  }
}

#Preview {
  @Previewable @State var ranking = ScopedRanking.directChildFirst
  SearchSettingsPane(ranking: $ranking)
}
