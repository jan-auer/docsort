# Destination search: UX study

Status: proposal for the user to choose from, 2026-11-08. Nothing here is decided and no app code has changed. The
clickable mockup of the three concepts is `docs/design/destination-search-mock/` (built into `index.html`), published at
https://claude.ai/artifact/8YSxScQexWpfZUaDhjL9BT; the
pattern research behind it is `docs/design/destination-search-research.md`. All folder names come from the fictional
sample archive in `docs/design/sample-data/` (`no-real-data-in-repo`).

## The feedback

The user likes the filing panel overall. This study covers two of their points; the panel's overall visual design
(spacing, typography, standard components) is a separate piece of work, so the mockup keeps today's styling.

1. **The destination search should feel like autocomplete.** Choosing a folder highlights it in the list *and* puts it
   as a pill (token) into the search field. Scoping is needed (search from the current folder, or start again from the
   archive root), but the double representation feels wrong.
2. **Bug**: while stepping through folders with the arrow keys, an empty grey pill appears in the field before the
   placeholder ("[ ] Search in Gesundheit"), while the path bar below reads "Archive › Gesundheit".

## How the picker works today

From `docs/design/ux.md` ("Destination picker", "New folder") and `App/Picker/**`:

- `DestinationPickerModel` keeps four pieces of state that the user sees: `scope` (the folder the picker is in),
  `query` (the filter), `highlightedRowID` (the list's highlight) and `destination` (the chosen folder).
- The filter field (`PickerFilterField`) draws, left to right: a magnifier, then **either** the chosen destination as
  an accent-tinted token (`ChosenTokenView`, "Rechnungen › Elektronik") **or**, inside a folder, a grey scope chip
  ("in Gesundheit"), then the text field, whose placeholder repeats the scope ("Search in Gesundheit").
- Under the field, the path bar (`PickerPathBar`) shows the scope a third time ("Archive › Gesundheit").
- Choosing (Tab/Return) sets `destination`; `filterText` then reads `""` and the field shows the token while the list
  keeps the query's rows and marks the chosen row with the grey unfocused highlight. Typing or moving the highlight
  un-chooses it.

So the **scope** is shown up to three times (chip, placeholder, path bar), and a **chosen folder** twice (token and
list highlight). The field mixes three kinds of content: where you search, what you typed, and what you picked. That
is the "double representation" the user feels; it also explains why it does not read as autocomplete: in
autocomplete, accepting a suggestion *completes the text you typed*; here it *replaces* the text with an object.

## Bug: the empty pill (point 2)

**Cause.** The empty pill is the scope chip, squeezed to zero text width. In `App/Picker/PickerFilterField.swift`
the chip is

```swift
Text("in \(scopeTitle)")
  .lineLimit(1)
  .truncationMode(.middle)
  .padding(.horizontal, 7)
  …
  .layoutPriority(-1)
```

and it shares an `HStack` with the text field (`field().textFieldStyle(.plain).frame(minWidth: 40)`). A plain
SwiftUI `TextField` is horizontally greedy: it accepts any width it is offered. An `HStack` offers space to children
in order of layout priority, so the text field (priority 0) takes the whole remaining width first, and the chip
(priority −1) is left with its minimum: a truncating `Text` can shrink to nothing, leaving only the 7 pt padding on
each side and the grey rounded background. The result is a ~14 pt empty grey capsule before the placeholder.

**Why it shows "while navigating with the arrow keys".** The chip exists only while `scope` is not empty, which is
what → (step in) does; at the archive root there is no chip. It appears the same way after a path-bar click or
⌘L-then-→, and it does not depend on the length of the folder name (even "in Hund Fritzi" collapses). The chosen
token next to it has no `.layoutPriority(-1)`, which is why chosen tokens render with their text.

**Why tests didn't catch it.** The chip carries `.accessibilityLabel("Searching in …")`, so it is present in the
accessibility tree with its full label whatever its drawn width; UI tests assert on elements, not on pixels.

**Fix options (not applied).** Giving the chip `.fixedSize()` (or a higher priority than the field) would make it
render, but the chip duplicates the placeholder and the path bar. All three concepts below remove the chip, so the
bug disappears with any of them; if the concept work waits, the interim fix is to delete the chip (the placeholder and
path bar already show the scope), not to repair it.

## What should stay

The user likes the panel, and these parts work; every concept keeps them:

- Drilling with → into the highlighted folder and ← / ⌫ out, ⌘↑ to the root, clickable path segments.
- Fuzzy search with space-separated words in any order, diacritics folding, closer folders ranked first
  (`search-scoped-ranking`), Recent at the root.
- Tab/Return choose and move to the name field; ⌘Return moves at once; Esc clears, then steps back.
- The "this folder" row, so the folder you are in can be chosen without stepping out.
- New folder with ⇧⌘N inside the highlighted folder, slash nesting, created only on move.
- Folder contents below, following the highlight.
- **The folder list is always visible**, not a popup that appears while typing. Browsing the tree is as important as
  searching it, so every concept keeps the permanent list and differs only in how the field, the scope and the list
  relate.

## What comparable pickers do

Summary of `destination-search-research.md` (sources and unverified details there):

- **Scope is shown once.** Apple's search-field guidance lists a descriptive placeholder, a scope bar or a title as
  *alternative* ways to show the scope, not layers to stack. Today's picker stacks three.
- **Search tokens are filters, never the result.** Tokens in Mail, Photos and SwiftUI `searchable` narrow a search;
  none of the surveyed products writes the chosen item into the field as a token. That is why the chosen-folder pill
  feels wrong.
- **The current path has one home**: either in the input text (Finder's Go to Folder, VS Code's simple file dialog,
  Alfred, zsh/fish: typing `/` steps in, deleting over it steps out, Tab completes) or once beside the list (Default
  Folder X, VS Code breadcrumbs, Finder's path bar).
- **Stepping keys versus the caret is a known trade-off.** Default Folder X's arrow keys fought text editing and it
  added an option to step with Tab/⇧Tab instead; today's rule (→ only with the caret at the end, ← only in an empty
  query) is a sound resolution and every concept keeps it.
- **"Choose the folder I'm in"** is solved differently elsewhere: Raycast's Move to Folder extension opens folders
  with Return and moves into the current one with ⌘Return; VS Code's dialog accepts the current folder when nothing
  is highlighted. The "this folder" row stays, since Tab must keep meaning "choose".

## Concepts

Three concepts, along three axes: **where the chosen folder lives** (in the field, or in the list), **how scope
works** (an explicit path, an explicit location, or soft ranking) and **what typing completes**.

| | A. Path field | B. Location bar, choice in list | C. Soft scope |
| --- | --- | --- | --- |
| Field holds | the path, then the query | only the query | only the query |
| Typing completes | the field (→/Tab write the folder into the path; ghost text) | nothing; the list highlights | nothing; the list highlights |
| Navigating vs searching | one gesture: → appends to the path you search under | separate: → moves the location, typing filters under it | separate: → moves the location, typing searches everywhere, location first |
| Scope shown | as the path in the field | path bar (one place) | path bar (one place) |
| Search covers | the path's subtree | the location's subtree | the whole archive, location's subtree first |
| Chosen folder shown | the field's path | list row (✓) + contents header | list row (✓) + contents header |
| Path bar | gone (the field is it) | stays | stays |
| Closest model | Finder ⇧⌘G, shell Tab completion | Spotlight / Raycast with a location | Xcode Open Quickly, mail "Move to" |

### A. Path field ("Go to Folder")

**Idea.** The field *is* the destination, written as a path: committed folders appear as text before the caret,
`Gesundheit / Margit / `, followed by what you type. The list shows completions for the part you are typing.
Accepting a completion writes it into the path, exactly like Tab completion in a shell or Finder's Go to Folder. There
is no token, no chip and no separate path bar: the field is the breadcrumb, and its segments are clickable.

- Typing searches the subtree of the committed path (at the root: the whole archive), with today's fuzzy matching and
  ranking. A highlighted result whose name starts with the typed text shows the rest as inline ghost text.
- **→** (caret at the end) commits the highlighted folder: its path relative to the current one is written into the
  field with a trailing ` / `, the query empties, and the list shows that folder's children with "this folder" first.
- **⌫** at the start of the query (or in an empty query) removes the last path segment as a whole, like deleting a
  token; **←** in an empty query does the same. **⌘↑** or **Esc** clears the whole path (back to the root).
- **Typing `/`** splits the query into segments matched level by level: `ges/mar/phy` finds
  `Gesundheit/Margit/Physiotherapie` (each segment fuzzy against successive levels). Nothing is committed until you
  press → or Tab, so `/` never jumps somewhere by surprise.
- **Tab / Return** chooses: the highlighted folder is committed into the path (as →), and focus moves to the name
  field. The field now reads the full path, and the list shows that folder with "this folder" highlighted. What the
  field says is what you chose; there is nothing else to look at.
- **New folder**: when the query (with or without slashes) names folders that don't exist, the list's create row
  offers them ("New Folder “2033-11 Besuch Matthias Westerholm/Bahn” in Reisen"). ⇧⌘N on a highlighted folder steps
  into it and puts the field into new-folder mode (placeholder "New folder in Reisen"), so the separate inline name
  row of today is no longer needed: one field, one place to type.
- Folder contents follow the highlight, as today.

**Keystrokes.**

| Task | Keys | Field afterwards |
| --- | --- | --- |
| File into a known deep folder by typing | `margit physio` · Tab | `Gesundheit / Margit / Physiotherapie /` |
| … or by path | `ges/mar/phy` · Tab | same |
| Browse into a folder and pick it | `hund` · → · ↓×5 (to Hundeschule Pfotenweg) · Tab | `Hund Fritzi / Hundeschule Pfotenweg /` |
| Search inside the current folder | (in `Gesundheit /`) `augen` · Tab | `Gesundheit / Konrad / Augenarzt & Brillen /` |
| Start again from the root | Esc (or ⌘↑), then type | empty |
| Create a subfolder | `reisen` · → · `2033-11 Besuch Matthias Westerholm` · ⇧⌘N (or ↓ to the create row and ⇧⌘N) | `Reisen / 2033-11 Besuch Matthias Westerholm /` with New badge |

**Pros.**
- The most autocomplete-like: accepting a suggestion completes the field; the field always states the destination.
- One representation for both scope and choice; the path bar row goes away, which gives the list one more row.
- Typing a path with `/` and creating nested folders become the same gesture; the second text field (the inline
  new-folder row) disappears.
- Familiar from Finder's Go to Folder, the shell, Alfred and VS Code's simple file dialog.

**Cons.**
- Changes the most: the field becomes a custom AppKit text field with a non-editable, clickable path prefix
  (a SwiftUI `TextField` can't render one), and caret/selection rules need care (selecting all and typing must clear
  the path too, which is what Esc does today).
- Long paths need head truncation inside the field (`… / Margit / Physiotherapie /`) in a 300 pt field.
- After Tab, the list switches to the chosen folder's children; returning with ⇧Tab shows that folder rather than the
  results you chose from (you continue from the choice, not from the search).

**Implementation cost: high.** New filter field (an `NSTextField`/`NSTextView` subclass, like the existing
`KeyCommandTextField`, with an attributed path prefix and segment hit-testing); model: `scope` becomes the field's
committed path, `destination` becomes "the committed path when chosen", the new-folder draft merges into the field;
core: segment-wise matching for `/` queries in the search service; UI tests that use `picker-chosen-token`,
`picker-path-bar` and `picker-new-folder-name` need rewriting. Roughly the size of the original picker view work.

**Variant A′ (from the research).** Choosing leaves the field alone: Tab marks the highlighted row with a check, the
field keeps `Gesundheit / augen`, and the chosen path is shown once, at the name field ("Gesundheit › Konrad ›
Augenarzt & Brillen / name"). ⇧Tab then returns to exactly the results you chose from, which A loses. The cost is
that the field no longer states the destination, so it reads less like a completed entry. Also open in A: whether `/`
should step into the highlighted folder (Finder's model, faster) or stay a segment separator in the query (as sketched
above, never jumps by surprise and lets the same text name new nested folders).

### B. Location bar, choice in the list

**Idea.** The smallest change that removes the double representation. The field holds **only what you type**, nothing
else. The location is shown in **one** place, the path bar, which now sits as the header of the list box. Choosing
never writes into the field: the chosen row keeps a check mark and the selection colour, and the folder-contents
header names the destination ("Files in Gesundheit › Margit › Physiotherapie"). It reads like Spotlight or Raycast:
the input is for asking, the list is for picking.

- Typing searches the location's subtree (at the root: the whole archive), as today. The placeholder says where
  ("Search in Gesundheit") and disappears as you type; the path bar stays.
- → / ← / ⌫ / ⌘↑ / path-bar clicks step exactly as today.
- **⌘↑ keeps the query**: it moves to the root and runs the same search over the whole archive, so "not here, look
  everywhere" is one key. Esc still clears query and location together.
- **Tab / Return** chooses the highlighted row: ✓ on the row, focus to the name field. The query stays in the field
  and the list stays as it was, so ⇧Tab returns to exactly what you chose from. Typing or moving the highlight
  replaces the choice with the new highlight (as un-choosing does today), and ⌘Return always files the highlight.
- **New folder**: unchanged (⇧⌘N opens the inline row in the highlighted folder; the create row when nothing matches).

**Keystrokes.**

| Task | Keys | Field afterwards |
| --- | --- | --- |
| File into a known deep folder by typing | `margit physio` · Tab | `margit physio` (row ✓) |
| Browse into a folder and pick it | `hund` · → · ↓×5 · Tab | empty, path bar `Archive › Hund Fritzi`, row ✓ |
| Search inside the current folder | (in Gesundheit) `augen` · Tab | `augen` (row ✓) |
| Same query, whole archive | ⌘↑ | `augen`, now matching everywhere |
| Create a subfolder | `reisen` · ⇧⌘N · `2033-11 Besuch Matthias Westerholm` · Tab | empty, new row ✓ with New badge |

**Pros.**
- Removes both duplications with little code; the field is a plain search field again (standard look, clear button).
- Choosing is non-destructive: the query and list survive the choice, so going back is free.
- Keeps every learned key; the path bar stays visible at a fixed place.

**Cons.**
- Not more autocomplete-like in feel: accepting a suggestion still doesn't complete anything; the choice is a list
  selection, which is a picker, not autocomplete.
- The scope is outside the field, so "search in" vs "search everywhere" is still a mode the user has to notice (the
  placeholder helps only while the field is empty).

**Implementation cost: low.** Delete the scope chip and `ChosenTokenView`; keep `filterText` = `query` when chosen;
add a chosen mark to rows; path bar into the box header; ⌘↑ keeps the query; contents header text. A few UI tests
that look for `picker-chosen-token` change. A day's work for a coordinator.

### C. Soft scope (location-first results)

**Idea.** No search mode at all. The field holds only the query, and **every search covers the whole archive**; the
location only decides what comes first. Inside Gesundheit, results under Gesundheit come first in a section headed
"In Gesundheit", followed by "Elsewhere" from the rest of the archive. So "search here" and "start from the root" are
the same action, and you never have to leave a folder to find something outside it. This is how Xcode's Open Quickly,
Sublime and VS Code quick open, and most mail clients' "Move to" behave: context boosts, it doesn't filter.

- The path bar is the only location display, as in B. The placeholder reads "Search" (in a folder: "Search, Gesundheit
  first").
- → / ← / ⌫ / ⌘↑ step as today; → on a result steps into it and clears the query (as today).
- Within each section the existing ranking applies (closer first, recent boost). At the root there is one section, as
  today.
- Choosing and the chosen mark work as in B.
- New folder as in B; the create row's parent is the location (as today).

**Keystrokes.**

| Task | Keys | Field afterwards |
| --- | --- | --- |
| File into a known deep folder by typing | `margit physio` · Tab | `margit physio` (row ✓) |
| Browse into a folder and pick it | `hund` · → · ↓×5 · Tab | empty, path bar `Archive › Hund Fritzi`, row ✓ |
| Search inside the current folder | (in Gesundheit) `augen` · Tab | `augen`, first section "In Gesundheit" |
| Find something outside the current folder | (in Gesundheit) `noten` · Tab (nothing under Gesundheit matches, so the first "Elsewhere" row is highlighted) | `noten` |
| Create a subfolder | `reisen` · ⇧⌘N · `2033-11 Besuch Matthias Westerholm` · Tab | empty, new row ✓ |

**Pros.**
- Scope can never hide the target: no "why doesn't it find X?" because you forgot you were inside a folder.
- No scope UI in the field at all; nothing to clear before a new search.
- Works well with the planned suggestions (a Suggested section is just another section).

**Cons.**
- The list gets longer and needs section headers; with a broad query inside a folder, "Elsewhere" can push useful
  in-scope rows apart less clearly than a hard filter.
- Like B, choosing is a list selection rather than completion.
- Changes the meaning of the scope the user approved in round 2 (a filter) into a ranking boost; `search-scoped-ranking`
  would need an addendum.

**Implementation cost: medium.** B's view changes plus: `PickerListing` builds two sections when the scope is not the
root (two searches, or one search partitioned by prefix), and the core search's result limit applies per section.
Ranking itself stays.

## Recommendation

**Concept A, the path field**. It is the only concept that makes the search *feel* like
autocomplete, which is what the user asked for: accepting a suggestion completes the field, the field always says
where the file goes, and scope stops being a separate idea because it is just the path you have typed so far. It also
removes the most UI (path bar row, scope chip, chosen token, inline new-folder row) and unifies three gestures (drill
in, type a path, create nested folders) into one. Its cost is real but contained in the picker.

Borrow one thing from C: when a scoped search in A finds nothing under the committed path, show the whole-archive
matches below a hairline ("Not in Gesundheit – elsewhere:"), so scope can never hide the target.

If the user wants the double representation gone soon and the autocomplete feel later, **B is the cheap first step**:
it is a subset of A's direction (the field stops holding a token) and nothing in it is thrown away by A except the
path bar.

Order of work, whichever concept: (1) remove the scope chip (fixes the empty pill; the placeholder and path bar
already show the scope), (2) the concept, coordinated with the separate visual-design work on the panel, since both
touch `PickerFilterField` and the picker's header.

## Mockup

`docs/design/destination-search-mock/`: open `index.html` (built by `build.py` from the parts in that folder and the
sample archive). Panel only, keyboard-driven, with a concept switcher (A, B, C) and the tasks above as a checklist per
concept. The styling stays close to today's app on purpose (the panel's look is decided separately); only the scope
chip and the chosen-token pill are gone, since those are what the concepts replace. It is a sketch for feeling the
interaction, not a rendering of macOS.
