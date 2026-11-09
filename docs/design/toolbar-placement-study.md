# Toolbar placement with a full-height filing inspector

Status: proposal for the user's decision, 2026-11-09. Design study only; no app code changes. Builds on
`docs/design/ux.md` ("Window layout", "Filing panel look", "Toolbar and History placement", "Keyboard map") and
decision `filing-panel-redesign`. Sample names in the sketches come from the existing fictional sample archive in
`ux.md`.

## Summary

The question: if the filing panel becomes a full-height, edge-to-edge glass pane with its own toolbar section, as
the action library in Shortcuts does, where do the toolbar items go?

**Recommendation: layout A, "Shortcuts pattern".**

1. **File actions stay over the preview.** Open, Reveal in Finder and Move to Trash stay in the main toolbar
   section, at its trailing end, after the file's title. They act on the document the preview shows, and the HIG
   says toolbars "act on content in the view". This is what Shortcuts does (Share and Run sit over the editor, not
   over the library) and what Apple's Landmarks sample does (the item's actions are declared on the detail view).
2. **The panel's toolbar section holds only the panel toggle**, at its trailing edge, where the toggle is today.
   The search field stays in the panel, as its first row, directly under the toolbar band and above the list it
   filters. The HIG's search-field guidance supports that: an inline field "above the list it searches" when the
   search is local to that list, a toolbar field for search across the window. The user's worry about a toolbar
   search field is justified, though for grouping more than distance (see Q2).
3. **Yes, the panel becomes a regular inspector again, and that fits the HIG.** Apple's own definitions are broader
   than "details about the selection": WWDC23's inspector session names Shortcuts' action library, a primary work
   tool, as a standard use ("content that supplements an app's main content"). The filing panel also meets the
   narrower definition: it updates with every selected file and edits that file's name and location. The reasons
   `filing-panel-redesign` gave for leaving `.inspector` (Panels guidance on simple controls, "primary content
   belongs in split-view panes") came from guidance for floating panels, and on macOS 26+ an inspector *is* a
   split-view pane. Whether to build it with SwiftUI's `.inspector` or an AppKit inspector split item is the
   spike's call. The decision entry and the comment in `App/MainWindowView.swift` would need rewording.

With the panel hidden, layout A's toolbar is exactly today's toolbar, so nothing moves for someone who hides the
panel. Keyboard flow is unchanged: every toolbar item already has a menu command and shortcut, and the search
field keeps its place in the focus order.

Two alternatives are written up below: **B, "Pages pattern"** (file actions in the panel's toolbar section) and
**C, "Search up"** (the search field in the panel's toolbar section). Neither is recommended.

## What the sources say

Read on 2026-11-09 in a browser (page text only; the published screenshot was viewed as a web image, nothing on
screen was captured).

### Apple's guidance

- **Toolbars** ([HIG: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), last
  changed 2025-12-16):
  - "Toolbars act on content in the view, facilitate navigation, and help orient people in the app."
  - Leading edge: back/forward and the sidebar toggle, then the view title. "Next to the title, the toolbar can
    include a document menu" for commands on the document as a whole, "such as Duplicate, Rename, Move, and
    Export".
  - Trailing edge: "important items that need to remain available, buttons that open nearby inspectors, an
    optional search field", and a primary action. "Items on the trailing edge remain visible at all window sizes."
  - Group items by function; "aim for a maximum of three" groups. Every toolbar item also needs a menu command.
  - "Don't title windows with your app name." (docsort shows "docsort" while nothing is selected; see Open
    questions.)
- **Search fields** ([HIG: Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields),
  last changed 2026-06-08):
  - macOS: "Put a search field at the trailing side of the toolbar" for apps "that need to search across multiple
    columns of information, like Mail, Notes, and Voice Memos".
  - "Include search at the top of the sidebar when filtering content or navigation there", to keep "a distinct
    separation between the sidebar you're filtering and the adjacent view".
  - Inline: "Place search as an inline field when its position alongside the content it searches strengthens that
    relationship", useful "if location plays a critical role in the scope of your search". "Position an inline
    search field above the list it searches." (Written under iOS, but it is the only guidance on inline fields.)
- **Split views** ([HIG: Split views](https://developer.apple.com/design/human-interface-guidelines/split-views)):
  Keynote "uses split view panes to present the slide navigator, the presenter notes, and the inspector pane". Panes
  can be hidden; "provide multiple ways to reveal hidden panes" (toolbar button, menu command, shortcut).
- **Panels** ([HIG: Panels](https://developer.apple.com/design/human-interface-guidelines/panels)): "An inspector
  displays the details of the currently selected item, automatically updating its contents when the item changes".
  "Depending on the layout of your app, you might also consider using a split view pane to present an inspector."
  The advice to prefer sliders and steppers over typing is about floating panels (`NSPanel`), not split-view
  inspectors.
- **WWDC23 10161, "Inspectors in SwiftUI"**
  ([video and transcript](https://developer.apple.com/videos/play/wwdc2023/10161/)):
  - "Inspector is the name for views that show further detail of selected content." Also: "Another common use case
    for inspectors is showing content that supplements an app's main content. Shortcuts uses inspector for this
    purpose. The main interface is the shortcut that the user is editing, and the inspector supplements that with
    the library of available apps and actions."
  - Placement decides the style: full height ("no separation between toolbar and content") or under the toolbar
    (the title separator spans the window). Toolbar content declared inside the inspector's view builder goes "in
    a toolbar section specifically for the inspector"; the toggle in the example is declared there. Inside a
    `NavigationSplitView`, put the inspector in the detail column's view builder or outside the split view.
- **WWDC25 310, "Build an AppKit app with the new design"**
  ([video and transcript](https://developer.apple.com/videos/play/wwdc2025/310/)):
  - "Sidebars appear as a pane of glass that floats above the window's content, whereas inspectors use an
    edge-to-edge glass that sits alongside the content." `NSSplitViewController` items with inspector behaviour get
    it automatically.
  - Split item accessories (`NSSplitViewItemAccessoryViewController`) are bars that "only span one split" at its
    top or bottom edge and take part in the scroll edge effect: the AppKit way to pin a bar, such as a search row,
    to the top of one pane under the toolbar.
  - The new extra-large control size is for "the actions that people launch your app to get done" (Move).
- **WWDC25 323, "Build a SwiftUI app with the new design"**
  ([video and transcript](https://developer.apple.com/videos/play/wwdc2025/323/)): the inspector "hosts content
  with a more subtle layering. This associates the inspector with its related selection." Toolbar search on Mac
  "appears in the top-trailing position of the toolbar", applied to the whole `NavigationSplitView`, and "the system
  may choose to minimize the search field into a toolbar button".
- **Landmarks sample**
  ([Refining the system provided Liquid Glass effect in toolbars](https://developer.apple.com/documentation/swiftui/landmarks-refining-the-system-provided-glass-effect-in-toolbars),
  macOS 27): the detail view declares Share, then Favorite and Collections as one group, then the inspector toggle
  ("Info") as its own group at the end. The item's actions belong to the detail view's toolbar, not the
  inspector's.

### Apple's apps

| App | Where the actions on the document sit | What the inspector's toolbar section holds | Search | How verified |
| --- | --- | --- | --- | --- |
| Shortcuts (editor) | Main section over the editor: title, then Share, Run and a third round button at its trailing end | One segmented control (library / details), centred | Search field at the top of the inspector's content, directly under the toolbar band, above the categories | Screenshot from the user via the hub (macOS 27); the library-as-inspector role from WWDC23 10161 |
| Pages 15 (Liquid Glass) | Comment and Share in the inspector's section; insert tools in the main section; document menu on the title | Comment, Share, and the Format / Document pair at the trailing edge | None in the toolbar | Published screenshot, [Pixel Envy, 2026-03-02](https://pxlnv.com/blog/window-chrome-of-our-discontent/) (full-height inspector with its own toolbar section; inspector content starts with a "Text" header) |
| Keynote, Numbers 15 | Probably as Pages (same redesign, January 2026) | Format / Animate (Keynote), Format / Organize (Numbers) at the trailing edge | None | From memory; [9to5Mac](https://9to5mac.com/2026/01/28/pages-keynote-numbers-get-ios-26-updates-heres-everything-new/) confirms the shared redesign, not the layout |
| Xcode | Run and scheme in the main section | Inspector toggle at the trailing edge; the inspector's tabs sit inside the inspector, under the toolbar | Navigator filters at the bottom of each pane | From memory |
| Finder (preview pane) | All in one toolbar over the whole window; quick actions at the bottom of the preview pane | No section of its own; the pane sits under the toolbar | Toolbar, trailing | From memory |
| Mail, Notes, Reminders | Message or note actions over the detail column | No inspector | Toolbar, trailing (searches across columns) | From memory |
| Preview | Markup and sharing over the document | Inspector is a floating panel (⌘I), not a pane | Toolbar, trailing | From memory |
| Photos | Edit, Info, Share over the photo | Info as a separate panel | Toolbar, trailing | From memory; unsure whether Info is a pane on macOS 26+ |

Two patterns stand out:

- **Shortcuts**: document actions over the document, the inspector's section holds only the inspector's own
  control, the inspector's search sits in its content. The inspector is a tool palette for the main content, as
  docsort's filing panel is.
- **Pages**: document actions over the inspector. Pages has many insert tools that fill the main section, and its
  Comment and Share are at the window's trailing edge in every state. The inspector's mode buttons (Format /
  Document) double as its toggles.

Only Shortcuts and Pages were checked against a picture of the current version. The rest are from memory and
should not decide anything on their own; see "Questions the user can answer by looking".

### Second-hand notes on macOS 27

- Developers reported toolbar regressions in macOS 27 betas: a white band with `NSTrackingSeparatorToolbarItem` and
  off-centre toolbar search fields (`NSSearchToolbarItem`), reported fixed in beta 6
  ([Michael Tsai, 2026-09-08](https://mjtsai.com/blog/2026/09/08/nstoolbar-in-golden-gate/)). A forum thread
  reports `NavigationSplitView` resize glitches on macOS 27 only when an inspector is present
  ([forum 836901](https://developer.apple.com/forums/thread/836901), not read: the forum asked for a bot check). A
  further thread (forum 795561, also unread) reports that on Tahoe, toolbar items that sat leading of the inspector's
  separator now end up flush-trailing next to the inspector toggle. All three are worth checking in the spike, not
  facts this study relies on.

## docsort's constraints

From `ux.md` and `App/MainWindowView.swift`:

- **Keyboard first.** Three focus stops: sidebar, destination picker (search field and list), name field. Typing in
  the sidebar goes straight into the destination filter; Esc clears it, then returns to the sidebar. ⌘Return files.
  Toolbar buttons are not focus stops; each has a menu command and shortcut (⌘O, ⌥⌘R, ⌘⌫, ⌥⌘I).
- **Preview never hides.** Nothing may float over the page.
- **Toolbar today**: sidebar toggle, ‹ › (Previous / Next File), the file name as title with its inbox as subtitle,
  then Open, Reveal and Trash as one group, a fixed space, and the panel toggle (`sidebar.trailing`) on its own at
  the far right. The toolbar spans preview and panel; the panel starts under it with a separator line.
- **Panel order, top to bottom**: suggestions slot (reserved, empty), search field, destination line (full path),
  folder list, New Folder, Folder contents drawer, name field, Move. The eye travels down: query → result → path
  → name → Move.
- **Window**: at least 1000 pt wide; the sidebar collapses below about 1180 pt. Panel 340 pt (300–480). At the
  minimum width the preview's toolbar section is about 660 pt with the panel shown.

## Q1: File actions over the preview or over the panel?

**Over the preview, at the trailing end of the main section.**

- **Meaning.** Open, Reveal and Trash act on the file whose name is the window title and whose content fills the
  preview. Next to the title they read as "this file: open it, show it, throw it away", the unit `ux.md` chose when
  it moved History out of the toolbar. Over the panel they read as filing steps. Trash is a triage outcome, a peer
  of Move, which is an argument for the panel; Open and Reveal are not filing steps, and Move itself sits at the
  panel's bottom, not its top, so placing Trash in the panel's toolbar doesn't put it near Move anyway.
- **Precedent.** Shortcuts and the Landmarks sample keep the document's actions in the main section. Pages puts
  Comment and Share over its inspector, but Pages fills its main section with insert tools and treats Share as a
  window-level action at the trailing edge; docsort's main section has room to spare.
- **Panel hidden.** In both places, hiding the panel moves the actions to the window's trailing edge, giving today's
  toolbar. Over the preview they slide right by the panel's width; over the panel they stay in place and the
  panel's surface disappears under them. Neither is a reason to choose.
- **Keyboard.** No difference: the actions are menu commands with shortcuts.
- **Width.** At 1000 pt the main section holds ‹ ›, a truncated title and three buttons. The panel's section
  (300–480 pt) would also hold three buttons and the toggle.

A document menu on the title (HIG; Pages has one) could later gather Open With ›, Copy Path, Rename… and Move Back
to Inbox. It would complement the buttons, not replace them: Trash and Open are one-click actions for mouse users.

## Q2: What goes in the panel's toolbar section?

Given Q1, the candidates are the panel toggle alone, a segmented control, or the search field.

- **The panel toggle alone (recommended).** It stays where it is today (far right) whether the panel is shown or
  hidden. The section then looks almost empty; so does Shortcuts', which holds one control in a wider pane. The
  glass of a full-height inspector already makes the band read as the top of the panel.
- **A segmented control, as in Shortcuts.** Shortcuts switches between two real modes (library, details). docsort's
  panel has one mode; History is a separate window (decided). A control without modes would be decoration. If the
  panel ever gets a second mode (for example file details next to filing), this is where its switch goes.
- **The search field.** It would win about one row of height for the list (some 40 pt). Against it:
  - **Grouping, not distance, is the real problem.** The field would move up by roughly the band's height, which
    hardly lengthens the eye path. But a field in the toolbar is a separate glass capsule above the scroll edge
    effect, while its results sit in the panel's content below. On macOS a toolbar search field means "search the
    window" (Mail, Notes, Finder, and SwiftUI's `.searchable` on the split view); the HIG keeps local filters
    above the list they filter. The destination line under the field, which echoes the chosen path, would be cut
    off from the query that produced it.
  - **The suggestions slot.** `ux.md` reserves a row above the picker for suggested destinations. With the field in
    the toolbar, the suggestion chips would land between the query and its results.
  - **Focus behaviour.** The filter's focus code (type-to-filter from the sidebar, Esc clears then returns, Tab to
    the list) is tuned for a field in the panel (`swiftui-focus-binding`). In a toolbar item it is hosted in the
    toolbar's view, and a `.searchable` field brings its own Esc and focus rules and may collapse into a button at
    narrow widths (WWDC25 323). None of this is verified; each is a risk.
  - **Panel hidden.** The field must disappear with the panel. A filter with no visible list would be meaningless.

The user's worry is right in substance: the field would be visually set apart from the lists and the name field,
by the toolbar band's styling rather than by many points of distance.

## Q3: Is the panel then a regular inspector, and does that fit the HIG?

**Structurally yes, and it fits.**

- With layout A or B it is a trailing pane with edge-to-edge glass, its own toolbar section and a trailing
  toggle, shown and hidden from the toolbar, the View menu and ⌥⌘I: an inspector in everything but name. (The
  iWork apps use ⌥⌘I for Show Inspector, from memory.)
- **Against the HIG's narrow definition** ("displays the details of the currently selected item, automatically
  updating its contents when the item changes"): the panel follows the selected file, its name field edits the
  file's name, and the destination is where the file will live. It is a read-write view of the selection, like the
  WWDC23 example inspector that edits the selected row's fields.
- **Against the broader use**: WWDC23 cites Shortcuts' action library as a standard inspector, supplementing the
  main content. That library is as essential to Shortcuts as the filing panel is to docsort. Pages' Format
  inspector is equally essential to formatting.
- **What `filing-panel-redesign` got right and what it didn't.** The panel is docsort's main work surface. But the
  conclusion that this rules out an inspector rested on the Panels page's advice for floating panels and on
  treating "inspector" and "split-view pane" as opposites; on macOS 26+ an inspector is a split-view item with
  inspector behaviour (WWDC25 310). In docsort the preview is the main content, as principle 1 says, and the panel
  is the tool that acts on it.
- **What remains to respect**: an inspector can be hidden, so the app must stay usable and say so when it is (it
  already shows the panel when the filter or name field is asked for). The panel stays shown by default.

If the user adopts this, `filing-panel-redesign` (last bullet), the "Window layout" and "Filing panel look"
sections of `ux.md` (separator line under the toolbar, panel starting below the toolbar) and the comment in
`App/MainWindowView.swift` need rewording. Whether to use SwiftUI's `.inspector`, an AppKit inspector split item or
a hand-made glass pane is an implementation choice for the spike.

## Layouts

Each sketch shows the window's top band and the panel's first rows. `◧` is the sidebar toggle, `◨` the panel
toggle, `[…]` a glass group. Widths are not to scale.

### A · Shortcuts pattern (recommended)

Panel shown:

```
┌──────────────────────┬────────────────────────────────────────────┬────────────────────────────┐
│ ● ● ●             ◧  │ ‹ ›  Rechnung_NA-33…  [Open Reveal Trash]  │                       [◨]  │ toolbar band
│                      │      Web-Downloads                         │                            │
│ WEB-DOWNLOADS      9 ├────────────────────────────────────────────┤ (Search, Gesundheit first) │ panel row 1
│   Rechnung_NA-33…    │                                            │ Archive › Gesundheit       │
│   Gehaltszettel…     │              preview                       │ In Gesundheit              │
└──────────────────────┴────────────────────────────────────────────┴────────────────────────────┘
```

Panel hidden (identical to today's toolbar):

```
┌──────────────────────┬─────────────────────────────────────────────────────────────────────────┐
│ ● ● ●             ◧  │ ‹ ›  Rechnung_NA-33-08812.pdf             [Open Reveal Trash]      [◨]  │
│                      │      Web-Downloads                                                      │
└──────────────────────┴─────────────────────────────────────────────────────────────────────────┘
```

- Discoverability: the file's actions sit with its name; the toggle is where it always was.
- Keyboard flow: unchanged.
- Eye travel to the search field: none added; the field opens the panel's content, right under the band, and the
  query, path, list, name and Move read top to bottom as today.
- Panel hidden: today's toolbar; the actions slide right by the panel's width.
- Cost: the panel's band looks sparse. If that bothers the user, the inspector toggle could move into the main
  section's trailing end and the band stay empty, as in the Landmarks sample.

### B · Pages pattern

Panel shown:

```
┌──────────────────────┬────────────────────────────────────────────┬────────────────────────────┐
│ ● ● ●             ◧  │ ‹ ›  Rechnung_NA-33-08812.pdf              │ [Open Reveal Trash]   [◨]  │ toolbar band
│                      │      Web-Downloads                         │                            │
│ WEB-DOWNLOADS      9 ├────────────────────────────────────────────┤ (Search, Gesundheit first) │ panel row 1
│   Rechnung_NA-33…    │              preview                       │ Archive › Gesundheit       │
└──────────────────────┴────────────────────────────────────────────┴────────────────────────────┘
```

Panel hidden: as in A.

- Discoverability: the panel's band is used, and the title gets the whole main section, so long names truncate
  less. But the actions read as part of filing, and Open and Reveal are not.
- Keyboard flow: unchanged.
- Eye travel to the search field: as in A, though the field now sits right under three buttons, a busier band
  directly above the place the eye goes most.
- Panel hidden: the actions stay put and the panel's surface disappears from under them; the main section's
  trailing end is empty while the panel shows.
- Cost: none in code beyond A.

### C · Search up

Panel shown:

```
┌──────────────────────┬────────────────────────────────────────────┬────────────────────────────┐
│ ● ● ●             ◧  │ ‹ ›  Rechnung_NA-33…  [Open Reveal Trash]  │ ( Search, Gesundheit… ) [◨]│ toolbar band
│                      │      Web-Downloads                         │                            │
│ WEB-DOWNLOADS      9 ├────────────────────────────────────────────┤ Archive › Gesundheit       │ panel row 1
│   Rechnung_NA-33…    │              preview                       │ In Gesundheit              │
└──────────────────────┴────────────────────────────────────────────┴────────────────────────────┘
```

Panel hidden: as in A; the field goes with the panel.

- Discoverability: the field is prominent, but it looks like window-wide search, which it is not.
- Keyboard flow: same stops in theory, but the focus code moves into a toolbar item, with the risks listed under Q2.
  Type-to-filter from the sidebar must still reach it.
- Eye travel to the search field: a little longer, and across the band's edge. The suggestions slot would sit
  between field and results.
- Panel hidden: the field disappears and the toggle moves to the window edge.
- Cost: about one more list row; more implementation risk than A or B.

## Open questions

1. Does the user want the full-height inspector at all? This study assumes yes; the sibling spike shows how it
   looks.
2. If yes: layout A (recommended), B or C?
3. Should a document menu on the title (Open With ›, Copy Path, Rename…, Move Back to Inbox) join the toolbar
   later? It would complement A or B.
4. While nothing is selected the window is titled "docsort"; the HIG says not to title windows with the app name.
   An empty title or the inbox name would do. Small, separate from this study.

### Questions the user can answer by looking

These would turn "from memory" rows above into checked ones. None blocks the recommendation.

1. In Pages (or Keynote) on this Mac, hide the inspector with the Format button: do Comment, Share and Format /
   Document stay at the window's trailing edge?
2. In Shortcuts, hide the action library: where does the library / details control go, and do Share and Run move?
3. In Xcode, with the inspector shown: does it run full height with its own toolbar section, and which buttons sit
   above it?
4. In Finder with the preview pane shown (⇧⌘P): does the toolbar span the pane, or does the pane have a section of
   its own?
