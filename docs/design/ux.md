# docsort-ui: UX design

Status: the spec, kept current with the app. Approved by the user on 2026-11-08 and changed with every landing since;
what is not built yet is marked *planned*. Examples use the fictional sample archive in `docs/design/sample-data/`: an
invented household written from scratch in the style of a German-language document archive, describing no real
archive (`no-real-data-in-repo`). The approved mockup and the design studies are in git history (`docs/decision-log.md`,
`filing-panel-redesign`).

docsort-ui files documents from inbox folders (Downloads, Scans) into an existing archive folder tree. It replaces
the TUI `~/Coding/docsort-cli` and keeps what made the TUI good (every action on the keyboard, fuzzy folder search,
recent destinations first, existing files visible while choosing) while fixing what it lacked: a large, side-by-side
preview of the file being filed.

## Principles

1. **Preview never hides.** The file being filed is always visible, large, while you choose a folder and type a
   name. No step covers it.
2. **Only ⌘Return files.** Moving a file is always a deliberate ⌘Return (or a click on Move). Tab and Return only
   advance between steps, so a stray Return never files anything.
3. **The list stands still.** Inbox files keep their place in the sidebar; filing checks a file off instead of
   moving its row.
4. **Nothing is lost.** Every change (move, rename, new folder, trash) can be undone. Delete moves to the Trash. A
   replaced file goes to the Trash. A persistent filing history records every move.
5. **Native first.** Standard macOS controls, menu commands with their shortcuts, Full Keyboard Access, VoiceOver
   labels, light and dark mode. Shortcuts follow macOS conventions where one exists.

## Window layout

One main window, three columns: a `NavigationSplitView` whose detail column splits into the preview and the filing
panel. Accepted by the user in round 1; the panel left `.inspector` for a pane of its own in the 2026-11-08 redesign
(`filing-panel-redesign`), because it is the main work surface, not details about the selection.

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●  ◧  ‹ ›  Rechnung_NA-33-08812.pdf                         [Open|Finder|Trash]     ◨  │  toolbar
│                Web-Downloads                                                               │
├────────────────┬───────────────────────────────────────────┬───────────────────────────────┤
│ WEB-DOWNLOADS 9│                                           │ [🔍 Search, Gesundheit first] │
│   Gehaltszett… │                                           │ Archive › Musik › Noten       │
│ ✓ 2033-10-20 … │                                           ├───────────────────────────────┤
│                │                                           │ In Gesundheit                 │
│ ▸ Rechnung_NA… │                                           │  folder list, edge to edge    │
│ ▾ Uni Westerh… │              large preview                │ ⊕ New Folder  ↻  → into · ←   │
│     Rechnung_… │      (PDF pages, image, Quick Look)       ├──────── drag to resize ───────┤
│ SCANNER      4 │                                           │ › Files in Noten     12 files │
│   2033-10-11_… │                                           │  folder contents              │
│   2033-10-16_… │                                           ├───────────────────────────────┤
│ ────────────── │                                           │ Name: [2033-10-13 No… ↺ .pdf] │
│ ⏱ History  ⌘Y  │                                           │                               │
│                │  page 1 of 2 · 94 KB · PDF · 13 Oct 2033  │                ( Move  ⌘↩ )   │
└────────────────┴───────────────────────────────────────────┴───────────────────────────────┘
```

- **Sidebar: inbox list** (260 pt, resizable, collapsible with ⌃⌘S). One section per configured inbox, in the order
  set in Settings, each listing its files **oldest first** by modification date. Files inside subfolders of an inbox
  are grouped under a disclosure row for that subfolder, placed by the folder's date. The disclosure triangle
  expands and collapses on click, and → / ← do the same from the keyboard. Each row shows the file icon, the file
  name (middle-truncated) and a compact absolute date, as Finder and Mail show it: day and abbreviated month
  ("12 Oct"), with the year only when it isn't the current one ("12 Oct 2033").
  - **Row anatomy, as in Finder's list view**: every row starts with the same narrow disclosure gutter (about 12 pt).
    A folder row puts its chevron there; a file row leaves it empty. So file and folder icons line up in one column,
    and the chevron costs no extra width. Files inside an expanded group are indented by one step (about 16 pt), so
    their icons sit under the folder's name.
  - **New-file marker**: a small accent dot (6 pt, with a ring in the sidebar colour) on the top-leading corner of
    the row's icon, not in a column of its own. It works the same on a file and on a folder that has both a chevron
    and new content, and it never shifts the icon or the name.
  - **Handled files**: filed and trashed files stay in their row (see "Files handled this session").
  - **History row**: at the very bottom, below the inbox sections and separated by a hairline, a fixed **History** row
    (clock icon, "⌘Y" in secondary colour) opens the History window.
- **Centre: preview** (takes the remaining width, at least 420 pt). PDFs render with PDFKit: continuous scroll,
  fit-to-width by default with a margin around each page; zooming (⌘− or pinch) also goes below fit-to-width. Images
  render at fit size. Everything else uses an embedded Quick Look preview (`QLPreviewView`). A thin footer shows page
  count, size, kind and dates.
- **Right: filing panel** (340 pt, 300–480, resizable against the preview by the divider between them, toggled with
  ⌥⌘I and the trailing toolbar button, `sidebar.trailing`; it slides in and out at the trailing edge as an inspector
  does). SwiftUI offers no system toggle for a trailing pane, the inspector included, so the toggle is the app's own
  button. Laid out list first, like the save panel (see "Filing panel look"). Top to bottom:
  1. **Destination picker**: the search field; under it the **destination line**, the one place the full destination
     path is shown (`Archive › Musik Margit › Noten & Bücher`), so the destination reads where it is chosen; then the
     folder list edge to edge, with the **New Folder** button under the list (choosing or creating the folder is the
     earlier step, so New Folder sits with the list, not at the bottom).
  2. **Folder contents**: a drawer under the list with the files already in the highlighted destination. Dragging its
     header resizes it against the list (only its grab bar shows the resize cursor); its chevron collapses it to the
     header. Size and state are kept with the window.
  3. **Bottom bar**: **Name:** the name field with the extension and the revert control inside it, and the conflict
     notice under it; then the **Move button**: the default (accent-filled) button, large and capsule-shaped, with its
     shortcut shown inside it as a small key-cap badge to the right of the label: `Move  ⌘↩`. For a filed file the label
     reads Rename or Move.

  The panel is always visible but inactive until a file is selected; it never covers the preview's pages (it sits
  beside the preview, though it lies over the PDF view's trailing edge, see "Filing panel look").

### Filing panel look

From the 2026-11-08 visual study: concept A's tidiness and contrast in concept C's structure (`filing-panel-redesign`).

- **Two surfaces**: the bars (search, list footer, drawer header, bottom bar) on the window colour; the two lists edge
  to edge on the content colour, with system separators between. In light mode the lists are white on grey, in dark
  mode darker than the bars, so areas are told apart by contrast, not by hairlines on white.
- **Type**: system text styles only. Rows in Body (13) in both lists; list section headers ("Recent", "In Gesundheit",
  "Elsewhere") and the drawer header in Subheadline semibold, secondary; counts and hints in Subheadline or Footnote.
- **Rows**: one style for folders and files: 24 pt, 7 pt padding, a 5 pt rounded highlight inset 6 pt from the list
  edges, accent while the picker has focus and grey otherwise. No stripes in Folder contents; its conflict row keeps
  the orange warning.
- **Search field**: capsule, as the system search field, with a clear button and a focus ring drawn outside it. It
  holds only the query.
- **Banners**: the filed/trashed status (green tint or the content colour) and the failures (orange tint, orange
  warning symbol) run across the top of the panel, so information and failure never look alike.
- **Empty states** use `ContentUnavailableView`, like the preview.
- **The window's toolbar spans the preview and the filing panel** as one glass surface, as Keynote's toolbar spans
  its canvas and inspector. The panel starts below the toolbar; the file's actions and the panel toggle sit in the
  toolbar's trailing area above it. The panel's backgrounds stop at the toolbar instead of running under it, so it
  never reads as a full-height column. The panel lies over the preview's trailing edge rather than beside it, and a
  PDF runs on under it: its pages scroll under the translucent toolbar, and the system's scroll edge effect (blur
  and darkening) covers the whole toolbar, panel included, with no edge at the divider. Above the panel it shows
  the PDF's background, and page colour only where a zoomed page reaches there. The PDF keeps its pages in the part
  left of the panel: fit-to-width fits that width, pages centre in it (narrower pages of a mixed-width PDF too), a
  page scrolled fully right stops one margin short of the panel, and the pages refit along with the panel's slide
  (how: `PartlyCoveredPDFView`). Quick Look content stays below the toolbar. The window's titlebar separator
  (`NSWindow.titlebarSeparatorStyle = .line`), the system hairline, separates the toolbar from the content, as in
  Finder. The system draws it only over the preview (and only with a PDF), even though the PDF runs on under the
  panel; the panel continues it with the same one-pixel separator-colour line at its top edge.
- **Toolbar**: sidebar toggle, a ‹ › pair (Previous File / Next File, like Finder's back and forward, each disabled at
  the list's start or end), then the standard window title as in Finder: the selected file's name as the title and its
  inbox as the subtitle (`navigationTitle` and `navigationSubtitle`), or "docsort" while nothing is selected. At the
  right, the three actions on that file (Open, Reveal in Finder, Move to Trash) as one group, and the filing panel
  toggle on its own at the very right. Everything in the toolbar is about the selected file; History, which is about all
  files, sits at the bottom of the sidebar instead (see "Toolbar and History placement"). All toolbar items have menu
  equivalents.

Minimum window size 1000 × 640 pt. Below about 1180 pt wide the sidebar collapses first; the preview keeps priority.

## Filing flow

Three focus stops: sidebar, destination picker, name field. Focus decides what keys do.

1. **Pick a file.** Select it in the sidebar with ↑/↓ (or ‹ › in the toolbar, ⌥⌘↑/⌥⌘↓ from anywhere). The preview
   follows the selection at once. At launch, once the inboxes are listed, the first file is selected (unless the
   user already picked one).
2. **Choose the destination.** Start typing: with a file selected in the sidebar, any printable key goes straight into
   the destination filter (Return or Tab also move focus there without typing; ⌘L is *planned*). See "Destination
   picker" for browsing, filtering, Recent and creating folders.
   - The **folder contents** list follows the highlighted folder (see below).
   - **Tab** (or Return) chooses the highlighted folder: its row gets a check mark, the destination line names it
     (`Archive › Rechnungen › Elektronik`), the search text and the list stay as they were, and focus moves to the
     name field.
3. **Name the file.** The name field is pre-filled with the file's current name without extension, fully selected,
   so typing replaces it and → keeps it for editing. The extension is a fixed label after the field and is never
   doubled: typing `Rechnung.pdf` for a PDF gives `Rechnung.pdf`. An empty field means "keep the original name".
   - **Revert**: a small ↺ button at the trailing end of the field, shown only when the name differs from the
     original, restores the original name (also ⇧⌘R). For a filed file the original is the name it had before
     filing.
   - **Take a name from the folder**: double-clicking a file in Folder contents (or Return on the selected file, or Use
     Name in its menu) copies its name (without extension) into the name field, selected, so it can be edited from
     there. A single click only selects the file, as in Finder. *Planned*: ⌥↑ in the name field takes the last name in
     the list, and repeated ⌥↑ / ⌥↓ walk up and down the list.
   - Characters macOS forbids in names (`:` and `/`) are refused with an inline notice.
4. **Move.** **⌘Return** from anywhere in the window, or a click on Move, files the file. Return in the name field
   does not file; it shows a brief hint "Press ⌘Return to move" as a small toast that floats just below the name field
   for about two seconds. The toast overlays what is below it and takes no layout space, so nothing shifts. Tab in
   the name field does not file either: it wraps focus back to the sidebar, as focus does in any macOS window.
   - **⌘Return before a destination is chosen**: in the picker, ⌘Return takes the highlighted folder as the
     destination and moves at once with the pre-filled name. Anywhere else (for example in the sidebar right after
     selecting a file), it moves nothing: focus goes to the picker and the toast says "Choose a destination first".
   - The row stays in place in the sidebar, gets a check mark and shows its new name; a short confirmation appears in
     the window's bottom bar: `Moved to Musik Margit/Noten & Bücher as 2033-10-13 Notenhaus Allegretto.pdf · Undo ⌘Z`.
   - The destination becomes the most recent entry in Recent, and the move is added to the filing history.
   - Selection advances to the next unfiled file below (wrapping to the top of the next inbox section) and **focus
     returns to the sidebar**, so typing starts the next file's search. The next file's picker starts with an empty
     filter and the folder just used, now the top of Recent, highlighted.

⌘Return also works from the destination picker: it moves at once with the pre-filled name, skipping the name stop.
Esc steps back: name field → picker (filter kept); in the picker a first Esc clears the filter and a second returns to
the sidebar. ⇧Tab steps back one stop without clearing anything.

### Folder contents

The files already in the highlighted destination folder, sorted **alphabetically** and **scrolled to the bottom** when
the highlight changes. With the archive's `YYYY-MM-DD Beschreibung` names, the bottom shows the newest files, and
the list reads in date order upwards. Subfolders are not listed here (the picker shows them). A file whose name
conflicts with the current name field is highlighted in the warning colour and scrolled into view.

Files are selected as in Finder. A click selects a file and gives the list keyboard focus; the selection is drawn in
the accent colour while the list has focus and grey otherwise, and another folder clears it.

- **↑ / ↓** move the selection (with nothing selected, ↓ starts at the first file and ↑ at the last, the newest).
- **Space** opens the system Quick Look panel on the selected file. While it is open, ↑ / ↓ move through the
  folder's files and the panel follows, as in Finder; Space or Esc closes it.
- **Double-click** or **Return** uses the file's name for the name field (see "Name the file").

A file's context menu: **Use Name**, **Quick Look**, **Open**, **Open With ›** (the default app first), **Reveal in
Finder**, **Copy Name** (with its extension), **Copy Path**, **Rename…** and **Move to Trash**. Rename… asks for the
new name in a dialog, without the extension, which the file keeps (as in the name field); a taken or forbidden name
is refused with an alert. Rename… and Move to Trash change the archive, so they work like filing: they are
recorded in the filing history (History lists them as Renamed and Moved to Trash), ⌘Z undoes them, and an inbox
row whose filed file it is follows it: it shows the new name, or the trashed state with Put Back, which returns
the file to its archive folder and files the row there again. Move to Trash has
no confirmation, because it is undoable; the next file is selected.

It is a drawer under the folder list: its header ("Files in Noten & Bücher", the file count) names the folder only,
since the destination line shows its full path. Dragging the header resizes the drawer against the list (the list keeps
at least about 200 pt with the search field); the chevron collapses it to the header.

### New folder

The user usually knows the parent. So creating a folder starts from the folder that is highlighted in the picker:

1. Highlight the parent (by filtering or browsing).
2. Press **⇧⌘N** (Finder's New Folder) or click the **New Folder** button under the folder list. The button's
   tooltip names the parent: "New Folder in Reisen".
3. An editable row appears inside the parent, where the new folder will sit among its siblings, with an empty name
   field active (placeholder "Folder name").
4. Type the name. A slash creates nested folders (`2033-11 Besuch Westerholm/Bahn`). An existing sibling with the same
   name (ignoring case) is shown inline ("Reisen already contains a folder named …") and Return selects that
   existing folder instead.
5. **Tab or Return** confirms. The new folder becomes the chosen destination, marked with a **New** badge, and focus
   moves to the name field. Esc cancels and removes the row.

When the filter matches nothing, the empty picker shows **New Folder "…" in <parent>** using the filter text as the
name. The parent is the folder you are browsing in, or the archive root at the top level; never the closest fuzzy
match, which would be arbitrary. ⇧⌘N or a click confirms it.

The new folder is created on disk only when the file is moved, so cancelling leaves no empty folder behind. Undoing
the move also removes the folder if it is still empty.

### Name conflicts and overwrite

The panel checks the target path while you type the name:

- **No conflict**: nothing shown.
- **Same name exists** in the destination: an inline notice under the name field, in the warning colour:
  `"2033-10-04 Rechnung Oktober.pdf" already exists in this folder.` The matching row in Folder contents is highlighted.
  Pressing ⌘Return then opens a sheet in Finder's wording: **Keep Both** (adds ` 2`, ` 3`, … before the extension; the
  default button), **Replace** (moves the existing file to the Trash, then moves this one; undoable; never the
  default), **Cancel** (back to the name field).
- **Names differ only in case** (`rechnung.pdf` vs `Rechnung.pdf`): treated as a conflict, because the archive volume
  is case-insensitive.
- **The source file changed or vanished** before the move (renamed in Finder, download still in progress): the move
  is refused with an error notice in the panel; the list refreshes.

### Undo

- ⌘Z / ⇧⌘Z undo and redo the session's actions in order: move (with its rename), rename of a filed file, new folder,
  move to Trash, replace, and Rename… or Move to Trash of an archive file in Folder contents. Each undo is named in the
  Edit menu ("Undo Move of 'Rechnung_NA-33…'"). It uses the window's `UndoManager`, so it behaves like Finder's. Undo
  lasts for the session.
- For any filed file, **Move Back** (File › Move Back to Inbox, ⌥⌘Z, also in the row's context menu and in History)
  returns that one file to its original inbox path and name, including after a restart, through the filing history.
- An undo or move-back that cannot complete (the original path is now taken, or the file was moved again outside the
  app) shows an alert that names the path in the way, offering **Keep Both** or **Cancel**.

### Delete, open, reveal

- **Move to Trash**: ⌘⌫ on the selected file (outside text fields, where ⌘⌫ edits text). No confirmation dialog,
  matching Finder, because it is undoable. The row stays in place with a trash icon and struck-through name. **Put
  Back** (⌘Z, or context menu) restores it.
- **Open** in the default app: ⌘O. Works for unfiled and filed files (filed files open from their new location).
- **Reveal in Finder**: ⌥⌘R. Same rule.
- **Open Destination in Finder**: ⇧⌘O opens the filing panel's chosen folder (else the highlighted one) in a Finder
  window. Disabled for a pending new folder, which is not on disk yet.
- **Quick Look**: Space in the sidebar opens the standard Quick Look panel on the selected file for a full-screen
  look. While it is open, ↑ / ↓ move through the sidebar's files and the panel follows; Space or Esc closes it. Space
  never starts a search. Folder contents shares the same panel (see "Folder contents"). Space is the only key
  that opens it: Finder's ⌘Y is History here, and ⌃Space switches the input source.

## Files handled this session

Filed and trashed files **stay where they are** in their inbox section, so the list never reorders while you work
(user decision `inbox-and-history-behaviour`):

- **Filed**: a green check mark replaces the file icon, the row shows the **new name** in secondary colour, and the
  tooltip and toolbar show the destination (`→ Mobilität/Jahreskarte Regio Plus`).
- **Trashed**: a trash icon, the original name struck through.

Filed rows stay selectable. Selecting one shows its preview from the new location, and the filing panel shows the
file as it is now: the picker holds its current folder as the chosen destination, the name field holds its current
name. Changing either and pressing ⌘Return renames it or moves it on (the button reads **Rename** or **Move**
accordingly). Revert (↺) restores the name it had in the inbox.

For a filed file the panel opens with a status banner across its top, above the picker: a green check, "Filed to
Mobilität/Jahreskarte Regio Plus · today 09:41", and a small bordered **Move Back** button at its trailing end. The
status and the action that undoes it sit together, and the bottom of the panel keeps one button: **Rename ⌘↩** or **Move
⌘↩**, disabled until the name or folder changes (the disabled state says "nothing to change", so no extra label). A
separate "Move back or file again" panel was considered earlier and rejected: it looked cleaner but made changing a
filed file a two-step detour.

A trashed file shows the same banner in the same place and layout: a trash icon, "Moved to Trash · today 09:41", and a
small bordered **Put Back** button at its trailing end (tooltip "Put back in Web-Downloads (⌥⌘Z)"), which returns the
file to its inbox under its original name. The picker and name field below stay inactive for a trashed file.

A filed row stays checked off for the session even if its archive copy is later moved, renamed or deleted by someone
else (History then shows "Moved or deleted since"). An unfiled inbox file that someone else moves away simply
disappears from the list (see "Live folder watching").

The selection-advance rule skips filed and trashed rows. After a restart, the sidebar shows only what is in the inbox
folders now; earlier work is in History.

## History

Every move is recorded persistently: original path and name, destination folder, new name, time. Renames of filed
files and move-backs are recorded as their own entries. Trash is recorded too.

**Window › History** (⌘Y, as in Safari) opens a separate window; so does the History row at the bottom of the sidebar:

- A table, newest at the bottom (chronological order), grouped by day, with columns *Filed* (time), *Original name*,
  *Inbox*, *New name*, *Destination*. A search field filters all columns.
- Selecting an entry shows a preview of the file at its current place in a pane on the right.
- Actions on the selected entry: Open (⌘O), Reveal in Finder (⌥⌘R), Move Back to Inbox (⌥⌘Z), and "Show in Main
  Window" when the file is still in this session's list.
- Renames and trashes of archive files from Folder contents are entries too. An archive file that was never in an
  inbox gets no inbox return: its rename offers **Revert Name** (its earlier name, in its folder) and its trash **Put
  Back** (to its folder). A filed file trashed from Folder contents is put back into its archive folder, and its inbox
  row is filed there again.
- An entry whose file is no longer at the recorded place shows "Moved or deleted since" and offers only Reveal of the
  folder.

## Destination picker

The most important control: a **drill-down list with a search that prefers the current folder** (the drill-down
list was chosen by the user in round 2 from two clickable candidates; the soft scope in the 2026-11-08
destination-search study, concept C; see `filing-panel-redesign` in `docs/decision-log.md`).

```
 [🔍 physio                      ⊗]
 ───────────────────────────────────
  In Konrad
  📁 Physiotherapie                    ← highlighted first
  Elsewhere
  📁 Gesundheit/Margit/Physiotherapie
 ───────────────────────────────────
  ⊕ New Folder  ↻      → into folder · ← out
```

- **One list at the panel's normal width**, edge to edge under the search field. Where the picker is shows in the
  list itself (the "this folder" row while browsing, "In <folder>" while searching) and in the placeholder; the full
  path of the folder a file would go to is on the destination line under the search field, whose ancestor segments
  are links that take the picker there. There is no path bar and no scope chip in the field.
- **Empty filter at the archive root**: Recent first (up to 20, most recent first), then the top-level folders.
- **Stepping**: ↑/↓ move the highlight; → steps into the highlighted folder (the list now shows its subfolders);
  ← or Backspace in an empty filter steps out and highlights the folder you came from; ⌘↑ jumps to the
  archive root. Folders with subfolders show a chevron. Double-click steps in; double-click on a folder without
  subfolders chooses it. → and ← move the text caret while the filter has text, so they never fight typing: → steps
  in only with the caret at the end, ← steps out only when the filter is empty.
- **"This folder" row**: inside a folder, the first row stands for the folder itself, highlighted on entry, so Tab
  chooses it without stepping back out. It must read as "choose the folder I'm in", not as one more child: it uses a
  different icon (a folder with a downward "file here" arrow instead of the plain folder), the folder's name followed
  by the secondary label "this folder", no chevron, and a hairline separator under it before the subfolders.
- **Soft scope**: every search covers the **whole archive**; the current folder only decides what comes first. At the
  root the results are one list. Inside a folder the folder's own matches come first under **In <folder>**, with paths
  relative to it, then the rest of the archive under **Elsewhere**, with full paths. The placeholder reads "Search,
  Gesundheit first". When nothing in the folder matches, "In Gesundheit" offers **New Folder "…" in Gesundheit**
  (click or ⇧⌘N) and the **first Elsewhere match is highlighted**, so Tab takes it; when nothing matches anywhere,
  the New Folder row is all there is, and highlighted. When the query names the folder itself, it is offered as its
  "this folder" row. So a folder you stand in can never hide the target.
- **No scattered matches**: a folder the query's letters reach only one by one, scattered over its path, is not a match
  (more separate runs than half the query's length): `asdf` doesn't find `Ahnenforschung/Stammbaum/Druckfassung`, while
  `fpfl` still finds `Fußpflege` and `ba37` `Bad 2037`. A nonsense query then offers only New Folder, and the default
  highlight never lands on a misleading hit that ⌘Return would file into. Rows show the parent part of their path in
  secondary colour; → on a result steps into it and clears the filter.
- **Choosing**: Tab or Return chooses the highlighted folder: a check mark on its row (value `chosen`), the destination
  line names it, and the search text and list stay, so ⇧Tab returns to exactly what you chose from. Typing or moving
  the highlight un-chooses it. ⌘Return files into the chosen folder, else the highlighted one.
- **Matching**: space-separated words match independently in any order (`margit physio` finds
  `Gesundheit/Margit/Physiotherapie`); case and diacritics are ignored (`einkaufe` finds `Einkäufe & Garantien`). The
  matching library is `fuzzy-matching-library`'s choice.
- **Ranking rule** (for the core to implement, `search-scoped-ranking`), within each section: among results of
  comparable match quality, **closer folders come first** by default: a folder fewer levels below the current scope
  wins, even over a deeper folder whose name matches exactly, then shorter paths. The archive root is a scope like any
  other. So inside Mobilität, `bahn` ranks `Mobilität/Bahntickets` above `Mobilität/Bahntickets/2033`, and from the root
  `dienstreisen` ranks `Arbeit Margit/Dienstreisen & Exkursionen` above the exactly named `! Abgeschlossen/Dienst
  Vermessungsamt bis 2032/Dienstreisen`. This is a setting: **Settings › Search › Rank first:** *Closer folders*
  (default) or *Exact name matches*. Recent destinations get a boost.
- **Highlighting**: matched characters are bold, and when the typed text matches more than one segment of a path, the
  highlight marks the **first** one (typing `chor` against `Chor Liederkranz/Chorreisen/2033-09 Chorfest Hochalm` bolds
  `Chor Liederkranz`, not a later segment).
- Tab or Return chooses the highlighted folder and moves to the name field. ⌘Return moves the file at once.
- ⇧⌘N or the New Folder button under the list creates a folder inside the highlighted folder (see "New folder").
- **Context menu**: right-clicking a folder row (or the "this folder" row) offers **Open in Finder** and **Reveal in
  Finder**. A pending new folder has no menu: it is not on disk yet.
- Inbox folders inside the archive are left out.

**Considered and rejected: columns with filter.** Finder's column view inside the panel, with the filter narrowing the
columns to matching branches. It shows best where a match sits in the tree, but: the panel had to widen to about 520 pt
while picking, so panel and preview jumped in width on every focus change, and at the minimum window size the preview
fell to about 220 pt; ← / → fought the text caret while typing; Recent filled the whole first column; and only one match
was visible at a time (⌘G to step). The drill-down list keeps the tree visible through the destination line and the
relative paths in results, at a fixed width.

## Toolbar and History placement

The toolbar mixed actions on the selected file (Open, Reveal in Finder, Move to Trash) with History, which is about all
files. Two fixes were considered:

- **History at the bottom of the sidebar (chosen).** The sidebar is where the app's places live; History is another
  place, and the bottom row is where macOS apps put such fixed entries. The toolbar then holds only the selected file's
  name and its actions, which reads as one unit. Nothing covers the preview.
- **File actions floating over the preview** (Liquid Glass capsule). It ties the actions visually to the document, but
  it covers part of the page (against "preview never hides"), needs hover or a reserved strip to stay out of the way,
  and leaves History alone in an otherwise empty toolbar.

## Keyboard map

Every command is in the menu bar, so it is discoverable and rebindable in System Settings → Keyboard → Shortcuts. The
keys by context are listed once, in the app: `App/Shortcuts/ShortcutCatalog.swift` feeds the menus, the tooltips and the
keyboard shortcuts sheet (⌘/, Help › Keyboard Shortcuts; design in `keyboard-shortcuts-sheet.md`), and tests keep the
menus, the picker's keys and the Quick Look panel's keys in sync with it. The sections above say what each key does.

### The rule

| Key | Effect everywhere |
| --- | --- |
| **⌘Return** | Move (file) the selected file now. The only key that files. |
| **Tab / Return** | Go to the next step: sidebar → picker → name. Never files. |
| **⇧Tab** | Go back one step, keeping what was entered. |
| **Esc** | In the picker: clear the filter; with an empty filter, back to the sidebar. In the name field: back to the picker. |

Sheets and alerts are standard macOS: Return presses the default button (Keep Both), Esc cancels. The destructive
Replace is never the default; reach it with Tab and Space.

### Planned keys

| Keys | Where | Command |
| --- | --- | --- |
| ⌘L | Anywhere | Focus the destination filter (File › Choose Destination…) |
| ⌘1 … ⌘9 | Anywhere | Jump to inbox section 1…9 (Go) |
| PgUp / PgDn (fn↑ / fn↓) | Sidebar | Scroll the preview without leaving the list |
| ⌥↑ / ⌥↓ | Name field | Take the previous / next name from Folder contents |

## Edge states

| State | What the user sees |
| --- | --- |
| **First launch, nothing configured** | The window shows a welcome view in place of the preview: "Choose your archive folder and inbox folders to start." with **Open Settings…** (⌘,). Sidebar and panel are empty. |
| **All inboxes empty** | Sidebar sections read "No files"; the preview reads "No file selected". *Planned*: "All filed" with the count filed this session and the inbox names. |
| **One inbox empty** | Its section shows a single dimmed "No files" row; other sections work normally. |
| **Inbox folder unreachable** (missing, renamed, drive not mounted, permission denied) | One row in its section, with a warning icon, explains the cause ("Folder not found: ~/Archiv/_Neu/Scanner") with a **Settings…** button (**Locate…** is *planned*). Other inboxes work. The app keeps checking the path and recovers by itself when it reappears. |
| **Inbox needs its own access grant** (*planned*; a symlinked folder that points outside the granted archive, see `app-sandbox`) | The section row reads "docsort needs permission to open Gemeinsam" with **Grant Access…**, which opens a folder picker at that path. |
| **Archive root unreachable** | The filing panel shows "Archive folder not available: ~/Archiv" with **Locate…**; Move is disabled. Preview, open, reveal and trash still work. |
| **Archive indexing** | The first scan of an archive with a few thousand folders takes well under a second; until it finishes the filter field shows "Indexing archive…" and Recent is already usable. The archive is rebuilt when the app becomes active and on ⌘R, without a visible state; it is not watched (`archive-refresh`). |
| **File still downloading or syncing** (`.download`, `.crdownload`, iCloud placeholder) | Row shows a progress or cloud icon; preview shows "Downloading…"; Move is disabled until it is complete. |
| **No preview for the type** | Large file icon, name, kind, size, dates and **Open with <App>** (⌘O). |
| **Preview loading** | Spinner in the preview area after 200 ms; the panel works meanwhile. |
| **Files added or removed outside docsort** | The sidebar updates live; see "Live folder watching". |
| **Move or trash failed** (permissions, disk full, destination gone) | A red notice in the filing panel with the system's reason in plain words and **Try Again**; the file stays selected and in its inbox. Nothing is half-done: a cross-volume move copies first and deletes the source only after the copy succeeded. |
| **Undo or move-back failed** | Alert naming the blocking path, with **Keep Both** and **Cancel**. |
| **Inbox lies inside the archive** (for example `~/Archiv/_Neu/…`) | Inbox folders are excluded from the destination picker automatically. |

## Live folder watching

The inbox folders are watched (FSEvents, `InboxWatcher` in the core), so the sidebar always shows what is in them,
without ⌘R.

- **Who changed it decides how the row behaves.** Files that docsort moves, renames or trashes stay in their row,
  checked off or marked trashed (see "Files handled this session"). Changes made by anything else (Finder, a browser,
  the scanner, a sync client) are applied as they come, and the list may shift for those.
- **A new file arrives**: its row is inserted at its date position in its inbox section. With oldest-first order, a
  fresh download or scan lands at the bottom of its section; a file copied in with an older date lands further up.
  A new file in a new inbox subfolder creates the subfolder's group row at the folder's date position. The row shows a
  small accent dot on its icon's corner (like an unread marker) until it is first selected.
- **The selection never moves because of an arrival.** *Planned*: if the selected row is visible, the visible rows above
  it stay where they are on screen: insertions above the viewport adjust the scroll position so nothing on screen jumps.
- **A file disappears** (moved or deleted by someone else): its row is removed. If it was the selected file, the
  selection moves to the next unfiled file below (as after a move), the preview follows, and the bottom bar says
  "'2033-10-11_Optik Klarblick.pdf' was removed from Scanner outside docsort." Anything typed in the filing panel
  for that file is discarded.
- **A file is renamed in place by someone else**: it keeps its row and position (same file identity), and shows the new
  name. If it was being filed, the name field is left as the user typed it.
- **A file's content changes** (a scan finishes writing, a download completes from `.crdownload` to `.pdf`): same row,
  the preview reloads, and Move becomes available when the file is complete.
- **Bursts** (a scanner writing several pages, a folder being copied in) are coalesced: updates are applied together
  after the folder has been quiet for about half a second.
- **An inbox folder itself disappears or reappears**: the section switches to the "unreachable" state and back (see
  "Edge states").
- **Filed files changed later** (moved or deleted in the archive by someone else): their row stays checked off for the
  session; History shows "Moved or deleted since".
- The archive tree is not watched (`archive-refresh`): its index is rebuilt when the app becomes active, on ⌘R and
  with the picker's ↻ button, so folders made elsewhere appear then.

## Settings window

A standard Settings scene (⌘,) with two panes. **Folders**:

- **Archive folder**: its path (`~/Archiv`) with **Choose…** (a path control is *planned*). Below it, the folder count
  once indexed ("576 folders" in the sample archive).
- **Inboxes**: a table with columns *Name* (editable, defaults to the folder name), *Folder* (path), *Status* (OK, or a
  warning such as "Not found"; "Needs access" is *planned*, see "Edge states"). **+** opens a folder picker; **−**
  removes the selected inbox (files are untouched). Drag to reorder; the order is the sidebar order (and the order of
  the *planned* ⌘1…⌘9).
- Footnote: "Inbox folders inside the archive folder are left out of destination search."

**Search**: one option, "Rank first:" with *Closer folders* (default) and *Exact name matches*
(`search-scoped-ranking`). It applies inside a folder and at the archive root alike.

Folders are stored as security-scoped bookmarks in the app's preferences (`config-in-settings`, `app-sandbox`);
nothing is read from `.docsort.toml`. Changes apply immediately, with no Save button.

## Later

Kept free, not designed here:

- **Document dates.** Inferring the document's own date (from PDF text, OCR or metadata) and shortcuts that insert a
  date into the name or a new folder name (⌘D / ⌥⌘D were drafted and dropped: today's date and the file's creation date
  are rarely the document's date). They return together with date inference (`date-shortcuts-deferred`).
- **Suggestions slot** at the top of the filing panel, above the picker: up to three suggested destinations and a
  suggested name as clickable chips, from PDF text, OCR or the download source.
- A Suggested group above Recent in the picker.
- A ranking hook in fuzzy search for boosting suggested folders.
- The preview footer can later show the detected source (for example the download URL from Spotlight metadata).

## Not in this version

- Filing several selected files to one destination in one go. The sidebar uses single selection; multi-selection can
  be added later without changing the panel.
- Merging, splitting or rotating PDF pages.
- Renaming or moving folders inside the archive.

## Decisions

Settled by the user and not recorded elsewhere (see `docs/decisions.md` for `inbox-and-history-behaviour`,
`filing-panel-redesign`, `date-shortcuts-deferred` and `search-scoped-ranking`, and the two "considered" sections
above):

- Three columns, with the filing panel always beside the preview; each inbox is its own sidebar section.
- Typing in the sidebar goes straight into the destination filter (no type-to-select in the sidebar).
- After a move, focus returns to the sidebar with the next unfiled file selected; the name field starts with the current
  name, fully selected.
- Key scheme: only ⌘Return files; Tab and Return advance; ⇧Tab goes back; Esc clears the filter, then goes back. The
  Return hint is a toast that takes no layout space; the Move button shows ⌘↩ as a key-cap badge.
- Folder contents selects as Finder does; sorted alphabetically, scrolled to the bottom.
- New folder: ⇧⌘N or the button creates an editable row inside the highlighted folder; a slash nests folders.
- Move to Trash has no confirmation, because it is undoable.
- History is a separate window (⌘Y), opened from a fixed row at the bottom of the sidebar.
- Filed and trashed files show a status banner at the top of the filing panel with Move Back or Put Back.
- Inbox folders are watched live; outside changes may shift the list, docsort's own changes never do. The archive
  is refreshed instead of watched (`archive-refresh`).
- Sidebar rows share a Finder-style disclosure gutter; the new-file dot sits on the icon's corner.
