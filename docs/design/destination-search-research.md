# Destination search: scope, path and choice (research)

Researched 2026-11-08 for the destination picker (`docs/design/ux.md`, "Destination picker"). Question: how do
search-plus-folder pickers show **where you search** (scope / current path), **what you typed** and **what you
chose**, without saying the same thing two or three times? All example folder names below are invented.

## Summary and recommendation

Today the picker shows the scope three times (chip in the field, placeholder "Search in …", path bar) and the chosen
folder twice (highlighted row and token in the field). No product surveyed does this. They each pick **one home for
the current path** and **one home for the selection**:

- **Path in the input** (Finder Go to Folder, VS Code's simple file dialog, Alfred, the shells): the field text *is*
  the current folder plus the query, `Projects/2031/inv`. Typing `/` steps in, deleting back over `/` steps out, Tab
  completes the highlighted name. This is what "feels like autocomplete": there is no chip and no path bar, because
  the text already says it.
- **Path outside the input** (Default Folder X Quick Search, Raycast Move to Folder, VS Code breadcrumbs, Mail's
  scope bar): the field holds only the query, and the path sits **once** next to the list, with a back control.
- **Selection lives in the list.** In every product the highlighted row is the selection. Nothing copies the chosen
  item into the search field as a token. Tokens (Mail, Photos, SwiftUI `searchable`) are used for **filters**, not
  for results.

**Recommendation (for the coordinator to take to the user):** adopt the **path-in-the-input** model, adapted to
a list that is always visible (option 1 under "Implications"). The field reads `Projects › 2031 › ` followed by
the typed query. Committed segments are drawn as dimmed, non-editable text: a path prefix, not pills. Typing `/` or
→ steps into the highlighted folder, and Backspace on an empty query pops one segment. Choosing does not write a
token. The highlighted row becomes the chosen row (a check plus the selection colour), and the panel shows the
chosen path once, as the label of the name field. This removes the scope chip, the "Search in …" placeholder (it
becomes "Search" or "Type a folder"), the separate path bar and the chosen token. The path bar's click-to-jump moves
into the path prefix, where each segment is clickable. The fallback is option 2: query-only field, with the path
shown once as a clickable path above the list.

## Sources

Apple (fetched through the HIG and documentation JSON endpoints, 2026-11-08):
- HIG Search fields (changes dated 2026-06-08 and 2025-06-09):
  https://developer.apple.com/design/human-interface-guidelines/search-fields
- HIG Searching (changes 2026-06-08): https://developer.apple.com/design/human-interface-guidelines/searching
- HIG Token fields: https://developer.apple.com/design/human-interface-guidelines/token-fields
- HIG Combo boxes: https://developer.apple.com/design/human-interface-guidelines/combo-boxes
- HIG Path controls: https://developer.apple.com/design/human-interface-guidelines/path-controls
- HIG Lists and tables: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- HIG Sidebars (2026-06-08): https://developer.apple.com/design/human-interface-guidelines/sidebars
- HIG Keyboards: https://developer.apple.com/design/human-interface-guidelines/keyboards
- HIG Typography (macOS table): https://developer.apple.com/design/human-interface-guidelines/typography
- WWDC26 session 292 "Design intuitive search experiences": https://developer.apple.com/videos/play/wwdc2026/292/
- SwiftUI: `searchScopes(_:scopes:)`, `searchable(text:tokens:…)`, `searchable(text:editableTokens:…)`,
  `searchCompletion(_:)`, "Suggesting search terms", `SearchFieldPlacement`, `GroupedFormStyle`, `ControlSize`:
  https://developer.apple.com/documentation/swiftui/view/searchscopes(_:scopes:) ,
  https://developer.apple.com/documentation/swiftui/suggesting-search-terms ,
  https://developer.apple.com/documentation/swiftui/searchfieldplacement
- AppKit: `NSTokenField` https://developer.apple.com/documentation/appkit/nstokenfield , `NSPathControl`
  https://developer.apple.com/documentation/appkit/nspathcontrol
- Mac User Guide, Go to Folder: https://support.apple.com/guide/mac-help/mchlp1236/mac
- Mail User Guide, search: https://support.apple.com/guide/mail/search-for-emails-mlhlp1003/mac
- Mac User Guide, Spotlight: https://support.apple.com/guide/mac-help/mchlp1008/mac
- Finder settings (search scope): https://support.apple.com/guide/mac-help/mchlp2803/mac

Products:
- Go to Folder walkthroughs (secondary): https://macmost.com/using-the-redesigned-mac-finder-go-to-folder-function.html ,
  https://www.macworld.com/article/550348/how-to-quickly-navigate-to-a-folder-in-macos-big-sur-and-monterey.html
- Alfred cheatsheet: https://www.alfredapp.com/help/getting-started/cheatsheet/ , File Search:
  https://www.alfredapp.com/help/features/file-search/
- Raycast manual: https://manual.raycast.com/keyboard-shortcuts.md , https://manual.raycast.com/search-bar.md ,
  https://manual.raycast.com/file-search.md ; Finder File Actions extension:
  https://www.raycast.com/pa1ar/finder-file-actions
- Default Folder X blog: https://www.stclairsoft.com/blog/2023/06/02/default-folder-x-6-0a4-preview-release/ ,
  https://stclairsoft.com/blog/?p=2656 (6.0.7), https://stclairsoft.com/blog/?p=2842 (6.1.4)
- VS Code: https://code.visualstudio.com/docs/editing/editingevolved (breadcrumbs); simple file dialog source
  https://github.com/microsoft/vscode/blob/main/src/vs/workbench/services/dialogs/browser/simpleFileDialog.ts
- fish: https://fishshell.com/docs/current/interactive.html ; zsh guide ch. 6:
  https://zsh.sourceforge.io/Guide/zshguide06.html
- Slack search: https://slack.com/help/articles/202528808
- Superhuman (help page returned 403; content from a search snippet of
  https://help.superhuman.com/article/595-labels-and-folders); Gmail "Move to" (2009):
  https://gmail.googleblog.com/2009/02/new-ways-to-label-with-move-to-and-auto.html

## HIG and API findings

**Search fields and searching** (HIG, WWDC26-292)
- "Clearly display the current search scope. Use descriptive placeholder text, a scope bar, or a title." The HIG
  offers these as alternatives, not as layers to stack. Mail is the example: "the mailbox being searched is always
  shown."
- Scope bar: for "clearly defined categories". Mail switches between all mailboxes and the current one. "Default to
  a broader scope" so people see the full context before narrowing.
- Tokens are "a visual representation of a search term", used to **filter**. Pair them with suggestions, because
  tokens are hard to discover. WWDC26: "don't use them to replace visible filter UI."
- Predictive completion (WWDC26): suggestions "should directly match the input and feel like a natural completion"
  and should "visually distinguish what the user typed from the predicted part". Limit the number of suggestions so
  results stay the focus.
- Search as you type. Put the most relevant results first. Show recents before typing.
- Empty and no-results state: don't leave the view blank, and consider echoing the typed text so typos are visible.
- The HIG gives no numbers for search fields, token fields, path controls, combo boxes or lists.

**Token fields** (macOS only, `NSTokenField`): typed text becomes tokens. By default a comma converts text to a
token, and Return can be added. Tokens can carry a context menu. Customise the suggestion delay, because instant
suggestions distract. API: `tokenizingCharacterSet`, `completionDelay`, delegate
`tokenField(_:representedObjectForEditing:)` for model objects. Good for a scope token or for path segments as
tokens. Every token is a separate selectable unit, so Backspace selects and then deletes a whole segment (the
standard Mail recipient behaviour; general knowledge, not stated on the page).

**Combo boxes** (macOS only, `NSComboBox`): a text field plus a pop-up list. "Make sure list items aren't wider than
the text field." Not a fit for our case: the list is a transient popup, and we want a permanent list.

**Path controls** (macOS only, `NSPathControl`): show a file-system path. In the **standard** style the middle
segments are hidden when it is too long. The **pop-up** style shows only the last item, with a menu of ancestors.
The navigation-bar style is deprecated. "Use a path control in the window body, not the window frame." Segments are
clickable, and drag-and-drop is built in. In our case it fits only the "path outside the input" model.

**Lists and outline views**: navigation lists "persistently highlight the selected row to clarify the path people are
taking". Use an outline view for hierarchy. Sidebars: "no more than two levels of hierarchy"; deeper data belongs
in a drill-down list. The HIG has no list keyboard guidance. Standard macOS behaviour (general knowledge): ↑/↓
move, →/← expand or collapse in outline views, ⌘↑ goes to the enclosing folder in Finder, type-select jumps by name.

**SwiftUI search APIs** (relevant facts)
- `.searchable` is tied to standard places: toolbar, sidebar, navigation bar. `SearchFieldPlacement` has no
  "inside this inspector" option, and "SwiftUI might not be able to fulfill your request". Our in-panel field is
  already custom (`App/Picker/PickerFilterField.swift`), which is the right call.
- `searchScopes` (macOS 13+): on macOS the scope picker "appears below the search field when search is active". It
  is a segmented picker for a few fixed categories, not a path.
- `searchable(text:tokens:)` (macOS 13+) and `editableTokens:` (macOS 14+). `searchCompletion(String)` *replaces*
  the partial text, and `searchCompletion(token)` inserts a token. Suggestions appear as a list attached below the
  field, which is transient.
- Layout, kept short because the panel's visual design moved to another session: the macOS default text size is
  13 pt, with Body 13/16, Callout 12/15, Subheadline 11/14 and Caption 10/13; the minimum is 10 pt. Grouped forms
  put labels on the leading edge and controls on the trailing edge. `ControlSize` has mini, small, regular, large
  and extraLarge (extraLarge resolves to large on macOS).

## Per-product notes

| Product | Where the current path is | Typed `/` | Into / out | Tab | Choose | Verified? |
| --- | --- | --- | --- | --- | --- | --- |
| Finder Go to Folder (⇧⌘G) | In the field text (`~/Projects/2031/`) | Lists that folder's contents as suggestions | Type `/` / delete the text | Completes the suggested name; when ambiguous, the first Tab only fixes the case | Return opens it | Apple guide plus MacMost |
| VS Code simple file dialog | In the input; value is folder path plus trailing separator | Ending in `/` lists that folder | Enter on a folder steps in; deleting the separator goes to the parent and keeps the segment as a partial name | Not in source (unverified) | Enter with no active item accepts the typed path | Source code |
| Alfred file navigation | In the query text (starts with `/` or `~`) | Path syntax | ↩ enters a folder, ⌘↓ browses it, Backspace goes up a folder; `previous` / ⌥⌘/ goes to the last browsed path | "Autocomplete" | → opens Actions (Move To etc.) | Cheatsheet |
| Raycast root / File Search | Unverified whether in text or in a navigation bar; a sort control appears "in the Navigation Bar when you browse into a folder path" | Paths typed in root search get "Open in Finder" | ⇧Tab goes to the parent directory (Mac manual); Tab goes into a directory (Windows manual and community guide only) | Into a directory (second-hand) | ↵ opens | Manual, partly |
| Raycast "Move to Folder" (extension) | Not described | n/a | Enter opens a folder; you can go back up | n/a | ⌘↩ moves into the current folder, ⌘⇧↩ copies; pins and recents | Store page |
| Default Folder X Quick Search | **Below the field**, with a back arrow | `..` finds the parent | → drills into the selected folder, then typing filters inside it; the back arrow returns to the previous results | Optional: Tab / ⇧Tab replace →/← so the arrows edit text | Opens or saves there | Developer blog |
| VS Code breadcrumbs | Breadcrumb bar above the editor | n/a | ←/→ move between segments; the dropdown lists siblings | n/a | Typing in the dropdown highlights matches and selects the best one | VS Code docs |
| Mail search (macOS) | Scope via the sidebar selection; "Search all mailboxes" when there are no results | n/a | n/a | n/a | Suggestions become **filter tokens** in the field; a token's arrow switches its kind | Mail guide |
| Mail Move to | Message › Move to submenu; ⌃⌘M moves to the *predicted* mailbox | n/a | Menu hierarchy | n/a | Menu item | Apple guide plus forums; no searchable picker found |
| Superhuman Move (V) | Unverified | n/a | n/a | n/a | ↑/↓ select a label; typing can create a new one | Second-hand (403) |
| Spark move | Unverified (user report: ⌘L opens a list with a "suggested" row) | | | | | Unverified |
| Slack | `in:#channel` typed modifier; ⌘F inside a channel searches it | n/a | n/a | n/a | n/a | Slack help; whether ⌘F shows a chip is unverified |
| Spotlight (macOS 26) | ⌘2 switches to files, with filter chips across the top; `kind:` typed | n/a | Not documented | Tab shows Quick Actions | Return opens | Third-party guides plus Apple guide |
| fish | In the command line | Path syntax | n/a | Completes the shared prefix and opens a pager; ⇧Tab completes and starts pager search | Right arrow accepts the ghost-text suggestion, ⌥→ one word | fish docs |
| zsh | In the command line | Path syntax | n/a | `/h/p/z` completes every segment at once; menu-select moves with the cursor keys | Return accepts; `AUTO_REMOVE_SLASH` drops a trailing `/` when you don't continue inside | zsh guide |
| Xcode Open Quickly, Sublime Goto Anything | Flat fuzzy list; no folder scope | Unverified whether `/` narrows by path | n/a | n/a | Return opens | Not verified (Sublime docs URL returned 404) |

Notes worth keeping:
- **Finder Go to Folder** is the closest native model. Typing the path *is* the navigation. The list shows the
  children of the last committed segment, matches are fuzzy and forgive typos (Monterey and later), and recents
  rank first. The panel is a transient sheet, though, not a permanent list.
- **Default Folder X** met our exact conflict: →/← drilling fought text editing. The author shipped an option to move
  drilling to Tab/⇧Tab. Our rule (→ steps in only with the caret at the end, ← only when the query is empty) is
  another way to resolve the same conflict.
- **VS Code's simple dialog** makes the highlighted folder the active item, and Enter steps *into* it. To accept a
  folder itself, there must be no active item. That is the same "choose the folder I'm in" problem our "this folder"
  row solves.
- **Raycast Move to Folder** separates *open* (Enter) from *act on the current folder* (⌘↩). This is another answer
  to the same problem: no "this folder" row is needed, because a modifier acts on where you are.

## Patterns

Each pattern lists who uses it, how the scope or path shows, what the keys do, how it works with a **permanent
list** (the user's requirement), and its pitfalls.

**P1. Path lives in the input as committed segments** (address-bar model)
- Who: Finder ⇧⌘G, VS Code simple dialog, Alfred, zsh/fish.
- Shows: `Projects/2031/` + query in one text run. Nothing else is needed: no chip, no placeholder scope, no path
  bar.
- Keys: `/` or → commits the highlighted segment and steps in. Backspace at a segment boundary steps out (VS Code
  keeps the deleted segment as the query). Return accepts.
- Permanent list: fits well. The list always shows children or matches under the committed prefix, so the field
  and the list say the same thing from two sides.
- Pitfalls: a raw `/` collides with fuzzy queries that contain spaces and words, and with "new folder `A/B`".
  Long paths overflow a 340 pt field, so truncate the head. As plain text, a prefix can be half-deleted into a
  nonexistent path, which Finder and VS Code handle with validation messages. Drawing the committed prefix as
  non-editable, dimmed text avoids that.

**P2. Backspace on an empty query pops a segment**
- Who: Alfred ("backspace: go up a folder"), Raycast ("When the search is empty, Backspace navigates back"), VS Code
  dialog, token fields generally. docsort already does this.
- Permanent list: fits well. The list re-roots at the parent and highlights the folder you came from (as docsort
  does).
- Pitfall: holding Backspace to clear a long query can overshoot into popping segments. Mitigation: stop at an empty
  query and need a fresh keypress (key repeat should not carry over). That mitigation is general practice, not
  taken from a source.

**P3. Inline completion (ghost or selected text); Tab accepts**
- Who: Finder ⇧⌘G (Tab completes), VS Code dialog (the completion is inserted *selected* after the caret), fish
  (ghost suggestion, → accepts, ⌥→ one segment), Spotlight top hit (general knowledge, unverified on macOS 26).
  WWDC26: tell typed text and prediction apart visually.
- Shows: completion of the highlighted row's *last segment* after the caret, in secondary colour.
- Permanent list: fits. The ghost text is simply the highlighted row's name, so ↑/↓ change the ghost.
- Pitfalls: with fuzzy (non-prefix) matches the ghost cannot extend what you typed (`inv` does not lead into
  `2031 Invoices`). Finder and VS Code show inline completion only for prefix matches. Tab already means "choose,
  go to name" in docsort, so a different key would have to accept the completion. → at the end of the text is the
  natural candidate, and it already steps in.

**P4. Choosing does not write into the input; the selection lives in the list**
- Who: all list pickers (Raycast, Default Folder X, Superhuman, VS Code Quick Open, Spotlight, Mail Move to). HIG:
  navigation lists keep the selected row highlighted.
- Shows: the chosen row keeps a strong selection plus a check mark. Elsewhere the choice appears once, in the place
  where it is used: the name field's label or a "Move to …" summary.
- Permanent list: this pattern *needs* a permanent list, or the choice disappears from view.
- Pitfall: when the user starts typing again after choosing, the chosen row can filter out of view. The choice needs
  one stable home outside the list, and the name field's label is that home.

**P5. Scope as a removable leading token**
- Who: Mail's search filters (filter tokens in the field), Slack `in:` (typed), SwiftUI `searchable(tokens:)`. HIG:
  tokens filter.
- Shows: one pill, `in Projects/2031`, before the query. Backspace on an empty query removes it, which jumps to
  the archive root.
- Permanent list: works, but the pill duplicates a path bar if one exists. Pick one.
- Pitfall: it is today's design. One pill hides the intermediate segments, so stepping out one level is not
  representable. Removing the pill jumps to the root, unlike ← which goes up one level. Tokens are less
  discoverable (WWDC26).

**P6. Path shown once next to the list, with back or jump controls**
- Who: Default Folder X (path below the field plus a back arrow), VS Code breadcrumbs, Finder path bar
  (`NSPathControl` "in the window body"), Raycast's navigation bar (partly verified).
- Shows: the field holds only the query, and the placeholder stays generic ("Search").
- Permanent list: fits well, because the path reads as the list's header.
- Pitfall: the scope is outside the eye line of typing, so the user may not notice they are searching a subtree.
  Default Folder X mitigates this with a back arrow. Searching from the root again needs an explicit action.

**P7. Flat global search first, drill-down as a secondary move**
- Who: Spotlight, Raycast root, Xcode Open Quickly, VS Code Quick Open, Sublime, Superhuman, Default Folder X (search
  first, then → into a result).
- Shows: no scope by default. A scope exists only after an explicit drill-in.
- Permanent list: fits.
- Pitfall: a drill-in has to be clearly undone. HIG: "Default to a broader scope."

**P8. A modifier acts on where you are, instead of a "this folder" row**
- Who: Raycast Move to Folder (Enter opens, ⌘↩ moves into the current folder), VS Code dialog (accept with no active
  item).
- Permanent list: fits. It saves a row but is less discoverable than docsort's "this folder" row. docsort could keep
  the row and treat the field's path prefix as "this folder".

**P9. Typed modifiers as an escape hatch for scope**
- Who: Default Folder X (`folders:` and `..` for the parent), Slack (`in:`), Finder and Spotlight (`kind:`).
- Permanent list: neutral. It is a power-user shortcut, not the main representation.
- Pitfall: it is invisible, so it only works alongside visible UI.

**P10. Suggestions become tokens only for filters, never for results**
- Who: Mail, Photos, SwiftUI `searchCompletion(token)`.
- Takeaway: the "chosen destination as a token in the field" pattern has no precedent among the surveyed products.
  It reads as a filter, which explains why it feels wrong.

## Implications for docsort

What the survey says about today's picker:
- Scope shown three times (chip, placeholder, path bar): the HIG lists these as alternatives. Keep one.
- The chosen folder as a token in the field: no precedent (P10). Choosing belongs to the list (P4).
- → / ← / Backspace / "this folder": already the consensus of Alfred, Raycast, Default Folder X and VS Code.

**Option 1 (recommended): path prefix in the field (P1 + P2 + P4, optional P3)**

```
 Destination
 ┌─────────────────────────────────────────┐
 │ 🔍 Projects › 2031 › inv▏               │   dimmed prefix = scope, typed query after it
 └─────────────────────────────────────────┘
 ┌─────────────────────────────────────────┐
 │ ⤓ 2031                     this folder  │
 │ ─────────────────────────────────────── │
 │ ▸ Invoices                              │   ← highlight (selection colour)
 │   Clients/Invoices                      │
 └─────────────────────────────────────────┘
 Name   Projects › 2031 › Invoices  /  [ 2031-04-02 Invoice 17 ].pdf
```

- **Root search:** at the root, the prefix is empty and the placeholder reads "Search archive". To start a new
  search from the root while inside a folder: ⌘↑, or click the 🔍 / first segment, or Backspace through the
  segments. Optionally a typed leading `/` resets to the root, as in Finder.
- **In-folder search:** whatever follows the prefix filters that subtree, which is today's behaviour.
- **Steps:** → (caret at the end) or `/` steps into the highlighted folder. Backspace on an empty query pops one
  segment. ← on an empty query does the same. Clicking a segment jumps there, replacing the path bar.
- **Choose:** Tab or Return marks the highlighted row as chosen. The field does not change. Focus moves to the name
  field, whose leading label shows the chosen path. The chosen row keeps a check when you come back.
- **What it drops:** the scope chip, the "Search in …" placeholder (inside a folder it becomes plain "Search"),
  the path bar and the chosen token.
- **Costs and risks:** a custom field. Draw the prefix in an `HStack` before the `TextField`, as the chip is drawn
  today, so the cost is similar. Truncate the head for deep paths (`… › 2031 › inv`). `/` as a step key conflicts
  with queries that contain `/`, and with new-folder `A/B`, which is entered in its own row so the field is not
  involved. Decide whether `/` is a step key or just a fuzzy character (Finder treats it as a step). The ghost text
  (P3) only works for prefix matches, so leave it out at first.

**Option 2: query-only field, path once above the list (P6 + P4)**

```
 [🔍 inv                                 ]
 ‹  Projects › 2031                          ← clickable path; ‹ = up one level
 ┌ list … ┐
```

- Cheapest: delete the chip and the token, keep the path bar, add a back chevron, make the placeholder generic.
- Weaker "autocomplete" feel, and the scope sits outside the eye line of typing.

**Option 3: one scope token per segment (P5 with `NSTokenField`-style segments)**
- Each committed segment is a pill, and Backspace selects and then deletes one pill. It is the most "tokenised"
  option, but it brings back pills in the field, which the user found heavy. It needs AppKit `NSTokenField` or
  custom drawing. Not recommended.

Notes that apply to all options:
- Keep → / ← / Backspace exactly as documented. Default Folder X shows that arrow keys against caret is a known
  trade-off, and docsort's caret rule is a sound resolution.
- After choosing, typing in the field again should search from the chosen folder's parent scope, with the chosen
  row still checked if it is visible. Write this rule into `ux.md` when the design is settled.
- The empty state "New Folder "…" in <parent>" stays as it is, and its parent equals the field's prefix in option 1.

## Open questions

1. Is `/` a step key (Finder model) or an ordinary character in fuzzy queries? This affects option 1's typing model.
2. Should a typed leading `/` (or `~`) reset to the archive root, or is ⌘↑ enough?
3. Where does the chosen path live: as the name field's leading label (as sketched), or as a line under the list?
   (This belongs to the visual-design session.)
4. Inline ghost completion (P3): worth it for prefix matches only, or left out?
5. Unverified product details, if someone has the apps at hand: Raycast's Tab-into-directory on Mac and how it
   shows the path; Spotlight 26 inline top-hit completion; Slack ⌘F chip; Spark and Superhuman picker layouts;
   whether Xcode Open Quickly and Sublime narrow on `/`.
