# Keyboard shortcuts sheet

Status: built, 2026-11-09. A read-only list of every shortcut, as a sheet over the main window, opened with ⌘/ and
Help › Keyboard Shortcuts (`ux.md`, "Keyboard map › Anywhere in the main window"). Code: `App/Shortcuts/`.

## Prior art

A research subagent read these sources on 2026-11-09. Nobody looked at the products' own panels, so their visual
details are second-hand.

- **Apple HIG.** [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) gives the
  modifier order ⌃⌥⇧⌘. It writes the upper character of a two-character key without ⇧ (⌘?, ⌘+). It says to give
  only frequent commands a shortcut. [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
  are modal, dim their window, and need a visible way to close besides Esc. The iPadOS and visionOS hold-⌘ overlay
  groups commands by menu, and its titles have to make sense on their own. Users complain that it opens by
  accident, so no trigger on a held modifier.
- **Raycast** ([manual](https://manual.raycast.com/keyboard-shortcuts)) groups shortcuts by context (Global, Root
  Search, Action Panel). It puts the action on the left and the keys on the right as one glyph string. Alternatives
  read "or", and its Action Panel filters as you type. This was the closest model.
- **Linear** made its shortcuts panel searchable in 2021
  ([changelog](https://linear.app/changelog/2021-03-25-keyboard-shortcuts-help)). **GitHub**'s `?` dialog lists the
  current page's shortcuts, with alternatives as "or"
  ([docs](https://docs.github.com/en/get-started/accessibility/keyboard-shortcuts)).
- **Things** (Help › Keyboard Shortcuts) opens a web page with sections by task and readable labels. It has no
  search, and it takes the user out of the app. **Craft** documents its shortcuts by topic. **Slack**'s ⌘/ toggles a
  reference panel, and Figma has a bottom panel with tabs. Those panels stay open beside the work, which a reference
  for keys you look up now and then doesn't need.

## Design

- **A sheet, 760 × 640 pt.** A title, a search field with focus, the list, and a footer line ("Every command is
  also in the menu bar.") with Done. Esc, ⌘/ and Done close it. System materials and colours only, so light and dark
  mode need nothing of their own.
- **Grouped by where a key works:** Anywhere (the menu bar), Sidebar, Destination Picker, New Folder Name (the
  picker's new-folder row handles Return, Esc and ⌘Return its own way), Name Field, History Window. Small secondary
  headings, no boxes. The sections fill two columns of about equal height and keep their order.
- **Rows.** The title is in menu-title style and makes sense on its own ("Out to Parent Folder"). An optional
  caption says when the key applies ("With an empty filter"). The keys are right-aligned, one keycap per
  combination. The cap holds the combined glyph string in ⌃⌥⇧⌘ order ("⇧⌘O"), as menus write it, on a soft key with
  a hairline edge. Alternatives are joined by "or". A pair for a two-part title ("Previous / Next File") is joined by
  "/". Typing shows as a dashed "Type" cap.
- **Search.** Every word of the query has to start a word of the row's title, caption or section, or one of its key
  names: glyphs, the notation ("⌘Y"), and words like "cmd", "shift", "esc", "up". Case and diacritics are ignored.
  When nothing matches, the system "No results" view shows.

## One source, no drift

- `MenuCommand` holds the shortcut of every app menu command. `MainCommands` and the History window's buttons
  apply it with `keyboardShortcut(for:)`, and the catalog lists it. Nothing else spells those keys.
- `ShortcutCatalogTests` reads the real menu bar in the test host (`NSApp.mainMenu`). Every visible key equivalent
  has to be listed under Anywhere or be in `ShortcutCatalog.standardMacShortcuts` (Quit, Hide, Close, Minimize,
  Cut, Copy, Paste, Select All, Emoji & Symbols, Help). Every Anywhere key has to be in the menu bar. System items
  are covered too: on macOS 27, View › Show Sidebar is ⌃⌘S.
- The picker's keys come from `PickerKey`, and the name field's from `TextFieldKeyCommand`. Each maps through an
  exhaustive switch, so a new key fails to compile until it has a combination. The tests check that every handled
  key is listed and that each picker combination round-trips through `PickerKey(NSEvent)`. The sidebar's
  `onKeyPress` keys have no such type, and their rows are written by hand.

## Left out, and differences from `ux.md`

- Quick Look keys (Space, ↑/↓ in Folder contents, Return to use a name) are left out for now. A parallel branch
  adds them.
- `ux.md` plans keys the app doesn't handle yet. The sheet lists only the keys that work: ⌘L (Choose Destination),
  ⌘1…⌘9 (inbox sections), PgUp/PgDn in the sidebar, and ⌥↑/⌥↓ in the name field.
- ⌘/ is Hide Status Bar in the HIG's list of standard shortcuts. docsort has no status bar, so the user's choice
  stands. ⌘? stays Help.
