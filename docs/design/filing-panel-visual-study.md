# Filing panel: visual study

Status: proposal, 2026-11-08. Nothing here is decided until the user picks a direction. The mockup is
`docs/design/filing-panel-visual-mock/index.html` (static, lightly clickable: three panel states, light and dark).
All names in it and here come from the fictional sample archive in `docs/design/sample-data/`
(`no-real-data-in-repo`).

Scope: the filing panel's overall look and structure. The destination search *interaction* (scope token, pill,
autocomplete, navigation) is a parallel study; here the search field and the folder list stay neutral, and the
folder list is permanently visible in every concept, so either study's outcome fits into any concept below.

## Summary

- The panel is the app's main work surface but is built and styled as an inspector, with a forced white background,
  hand-drawn boxes and search field, eight ad-hoc font sizes and one spacing value for everything. That is most of
  what reads as "a little off": no one thing is wrong, nothing lines up with the system's rhythm.
- Three directions: **A · Tidy pane** (same layout, system type, spacing, radii and controls), **B · Grouped form**
  (System Settings idiom), **C · List-first** (an edge-to-edge folder list with a save-panel-style bottom bar).
- Recommendation: **C, reached in two steps**, with the panel moved out of `.inspector` into its own split-view
  pane. Step 1 is A's clean-up, which C needs anyway and which can land on its own. B is not recommended.

## What the guidelines say

Sources were read on 2026-11-08 by a research subagent; its full sourced notes are outside the repo. The points that
shape the concepts:

1. **An inspector is for details about the selection.** The HIG's inspector guidance sits under Panels: an
   inspector shows details about the current selection, and panels should prefer simple adjustment controls over
   typing and multi-step choices ([Panels](https://developer.apple.com/design/human-interface-guidelines/panels),
   [Windows](https://developer.apple.com/design/human-interface-guidelines/windows)). A pane where you search,
   choose a folder and type a name is the opposite profile. Primary content belongs in split-view panes
   ([Split views](https://developer.apple.com/design/human-interface-guidelines/split-views)).
2. **On macOS 26 the system draws inspectors as edge-to-edge glass** beside the content, and sidebars as a floating
   pane of glass ([WWDC25 310](https://developer.apple.com/videos/play/wwdc2025/310/),
   [WWDC25 323](https://developer.apple.com/videos/play/wwdc2025/323/)). The panel paints a white background over
   that, which fights the container instead of using it. (Not verified on a screenshot.)
3. **Glass is for the controls and navigation layer, never content.** Lists and tables stay in the content layer;
   no glass on glass; tint only the primary action
   ([Materials](https://developer.apple.com/design/human-interface-guidelines/materials),
   [WWDC25 219](https://developer.apple.com/videos/play/wwdc2025/219/)). A bar of controls pinned over a scrolling
   list may be glass; `safeAreaBar(edge:)` (macOS 26) gives such a bar the scroll edge effect
   ([safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)),
   [Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views)).
4. **Shapes are concentric; control size sets shape.** Inner radius = outer radius − inset. Mini, small and medium
   controls are rounded rectangles; large and extra large are capsules
   ([WWDC25 356](https://developer.apple.com/videos/play/wwdc2025/356/), WWDC25 310).
5. **Use the text styles.** macOS: Headline 13/16 bold, Body 13/16, Callout 12/15, Subheadline 11/14, Footnote and
   Caption 10/13; 10 pt minimum ([Typography](https://developer.apple.com/design/human-interface-guidelines/typography)).
   Secondary text uses the secondary label colour
   ([Labels](https://developer.apple.com/design/human-interface-guidelines/labels)). Since macOS 26, section headers
   in lists and forms use title case, not capitals
   ([Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)).
6. **Lists:** standard `List` styles (`.inset`, `.bordered`), selection in the accent colour when emphasised and
   grey when not, stripes for large multi-column tables
   ([Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)).
7. **Search at the top of the pane it filters** is a documented placement (Settings' sidebar)
   ([Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields),
   [WWDC26 292](https://developer.apple.com/videos/play/wwdc2026/292/)). Path controls belong in the window body
   ([Path controls](https://developer.apple.com/design/human-interface-guidelines/path-controls)).
8. **Boxes:** keep them small relative to their container and never nest them
   ([Boxes](https://developer.apple.com/design/human-interface-guidelines/boxes)). Grouped `Form` is a settings
   layout, labels leading and controls trailing ([Form](https://developer.apple.com/documentation/swiftui/form)).
9. **Buttons:** one prominent button per view, marked by style not size; the default button owns Return
   ([Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)). Move is deliberately ⌘Return,
   not Return (ux.md principle 2), so it stays `.borderedProminent` (or `.glassProminent`) without
   `.defaultAction`. The HIG prints key equivalents in menus, not in buttons.
10. **Bottom of the window:** the HIG warns that people drag windows partly off screen, so keep critical controls
    away from the bottom edge ([Layout](https://developer.apple.com/design/human-interface-guidelines/layout)). A
    pinned Move bar accepts that risk; ⌘Return and File › Move cover it.
11. **macOS 27** changes nothing structural: sidebars reach the window edge, sidebar selection turns semibold, the
    scroll edge effect turns hard next to free-floating title text, and a user glass slider arrives
    ([WWDC26 289](https://developer.apple.com/videos/play/wwdc2026/289/),
    [WWDC26 269](https://developer.apple.com/videos/play/wwdc2026/269/)).

Apple publishes **no point values** for macOS margins, control heights or list row heights. The mockup uses the
common values (20 pt content margin, 24 pt rows, 28 pt fields), which should be checked against a real build with
`RenderPreview` before implementation.

First-party comparison (general knowledge, not from a source): Mail's and Notes' list columns are plain
content-layer lists that run edge to edge, with search above them; System Settings' detail pane is a grouped form;
Finder and Xcode navigators are sidebar-style lists with a filter field. The closest first-party relative of the
filing panel is the **save panel**: choose a folder in a browser, type a name, press the default button, with New
Folder at the bottom left. Concept C borrows its anatomy.

## The panel today: issues

Read from the code on `master` at 499a18d (`App/Filing/FilingPanel.swift`, `NameField.swift`,
`FilingStatusStrip.swift`, `App/Picker/DestinationPickerView.swift`, `PickerFilterField.swift`, `PickerBox.swift`,
`PickerRowViews.swift`, `PickerRowAppearance.swift`, `FolderContentsView.swift`, `App/MainWindowView.swift`). The
mockup's "Today" column reconstructs it.

### Container and background

1. The panel is an `.inspector`, toggled like one (⌥⌘I and the trailing toolbar button), and its doc comment calls
   it "the main window's inspector". By the HIG's definition it is not one (guideline 1).
2. It paints `textBackgroundColor` over the inspector's own background (guideline 2). The outlined boxes inside use
   `controlBackgroundColor`, the same white in light mode and nearly the same in dark mode, so boxes are told apart
   from the panel only by a hairline: the panel reads as one flat sheet with lines drawn on it.

### Type

3. Eight ad-hoc sizes instead of text styles: 9.5 (New badge), 10 and 10.5 (chevron, footer hints, key caps), 11
   (contents header, Recent header), 11.5 (path bar), 12 (file rows, notes), 13 (folder rows, name field), plus
   `.subheadline`, `.callout` and `.caption` elsewhere. 10.5 and 11.5 match no macOS text style.
4. Three heading treatments for peers: "Destination" and "Name" are subheadline semibold secondary above their
   controls; Folder contents has an inline 11 pt header ("In Mobilität › Jahreskarte Regio Plus … 6 files") with
   only "In" emphasised; Recent is an 11 pt semibold header inside the list. The type doesn't say which are
   sections and which are captions.
5. The two lists side by side use different text sizes: folder rows 13 pt, file rows 12 pt.

### Spacing and alignment

6. One gap (12 pt) between everything in the panel: a label sits as far from its own control as from the previous
   section, so labels don't bind to what they label. Inside the picker the gap is 6, between the contents header
   and its box 4. There is no rhythm to feel.
7. The panel margin is 16 pt; the common macOS content margin is 20 pt.
8. Radii differ per element (filter 7, boxes 7, folder highlight 5, file-row stripe 4, chip and token 5, status
   strip 6, notices 8, toast capsule) and aren't derived from each other (guideline 4).

### Components

9. The search field is hand-drawn (`PickerFilterField`): own background, 0.5 pt border and a 2 pt accent stroke
   instead of the system focus ring. It looks close to a macOS search field but not like one.
10. Both lists are `LazyVStack`s in a hand-built box (`PickerBox`), not `List`. Their styles disagree: the folder list
    has inset rounded highlights like a source list; Folder contents has zebra stripes drawn as rounded 4 pt pills
    inset by 4 pt, where a macOS table stripes full-width rows.
11. The folder list's footer (borderless icon, 10.5 pt key cap, tertiary key hint) resembles the macOS "＋ − bar
    under a list" without being one.
12. The Move button carries a hand-drawn key-cap badge (`⌘↩` on a 20 % white fill), which macOS doesn't do
    (guideline 9) and which lowers the label's contrast.
13. Move sits in the flow under the name field, not anchored to the panel's edge, so its position depends on the
    list heights above it.
14. The status strip ("Filed to …", Move Back) and the two failure notices (archive unreachable, history unreadable)
    share one look (quaternary fill, rounded), although one is information and the others are failures.

### Information

15. The destination path can appear three times at once: in the filter token, in the path bar and in the Folder
    contents header.
16. The empty state ("Select a file to file it" in tertiary text) differs from the preview column's
    `ContentUnavailableView("No file selected")` beside it.
17. A trashed file shows the whole panel disabled, with nothing but the strip saying why.

## Concepts

All three share a base, which is concept A's clean-up:

- **Type:** text styles only. Section titles in Headline (13 semibold, primary); captions and list section headers
  in Subheadline (11, semibold, secondary); rows in Body (13) in both lists; path bar in Subheadline. Retire 9.5,
  10.5, 11.5 and 12.
- **Spacing:** 8 pt between a title and its control, 20 pt between sections, 20 pt margins (12 pt where content
  runs edge to edge, as in C).
- **Shapes:** concentric radii derived from one outer value (well 10 → row highlight 5 at 5 pt inset); small
  and medium controls rounded, the large Move button a capsule.
- **One row style** for folders and files: 24 pt rows, the same inset highlight; accent while the picker has focus,
  grey otherwise (as today). No stripes in Folder contents; its conflict row keeps the orange warning.
- **Path once:** the path bar keeps the full path; the Folder contents header names only the folder
  ("Files in Jahreskarte Regio Plus", count trailing).
- **Move:** no key-cap inside the button. The shortcut stays in the help tag and the File menu, and appears as
  secondary text beside the button.
- **States:** the filed/trashed status uses a tinted icon, Body title and Subheadline time with a small bordered
  button; the two failure notices get the warning symbol in orange and stay visually distinct from it. The empty
  state becomes `ContentUnavailableView` like the preview's.
- **Container (recommended for all three, separate step):** the panel leaves `.inspector` and becomes a trailing
  split-view pane in the main window (an `NSSplitViewController` item or `HSplitView` in the detail column), with
  its own min/ideal/max width and a toggle in the View menu and toolbar. Its background is the plain content or
  window background the concept needs, not glass. Cost: about a day, mostly window-restoration and toggle wiring.

### A · Tidy pane

Same layout as today: Destination section (search, path bar, folder list in a well with a footer), Files in …,
Name, Move.

- **Changes:** the panel uses the window background, so the white wells read as wells without heavy borders; the
  base above; Move as a large prominent capsule pinned at the bottom (`safeAreaInset(edge: .bottom)`, or
  `safeAreaBar` on macOS 26), with ⌘↩ beside it.
- **Standard components:** system text styles, `.controlSize(.large)` + `.borderedProminent` for Move, standard
  search field look. The lists stay custom `LazyVStack`s in the existing box.
- **Pros:** the smallest change; nothing moves, so nothing to relearn; keeps today's density; fixes most of the
  "off" feeling.
- **Cons:** still a custom list in a custom box; the panel still stacks four sections of nearly equal weight, so
  the folder list doesn't dominate.
- **Cost:** low, 1–2 days. Modifier and constant changes in `FilingPanel`, `PickerBox`, `PickerFilterField`,
  `PickerRowViews`, `FolderContentsView`, `FilingStatusStrip`, `NameField`; no model or keyboard changes.

### B · Grouped form

The System Settings idiom: sections as rounded groups on the window background, headers above the groups.

- **Changes:** status as its own group with Move Back trailing; a Destination group holding the search field, path
  bar, folder rows with inset separators and a New Folder button row; a Files group; a Name group with the field;
  Move trailing below.
- **Standard components:** the `Form` + `.formStyle(.grouped)` look with `Section` headers. A real grouped `Form`
  scrolls as one and can't host a fill-height scrolling list well, so in practice this means custom group
  containers that imitate it.
- **Pros:** instantly reads as native and calm; strong grouping.
- **Cons:** reads as settings, not as a work surface; rows are taller and separators add noise, so fewer folders
  fit; puts the panel's largest element, the list, inside a box, where the HIG wants boxes small relative to
  their container; imitating `Form` means
  owning the look when macOS changes it.
- **Cost:** medium, 3–4 days, mostly new container views and tuning; no model or keyboard changes.

### C · List-first

The folder list becomes the pane's main body, edge to edge like Mail's message list; the bottom of the pane is laid
out like the save panel.

- **Changes:**
  - A header with the search field and the path bar, separated from the list by the scroll edge.
  - The folder list runs edge to edge with standard section headers ("Recent", "All folders") and 26 pt rows; it
    takes all the height the other parts leave.
  - Folder contents becomes a resizable, collapsible drawer under the list (a split divider with a disclosure
    header: folder name, file count).
  - A bottom bar holds the name field with a leading "Name:" label, **New Folder** as a real bordered button at the
    leading end (replacing the footer icon), and Move trailing at regular size. The bar is the one glass surface,
    over the scrolling content.
  - Filed and trashed status becomes a full-width banner at the top of the pane, as Mail shows message banners.
- **Standard components:** `List` with `.listStyle(.inset)` and `Section`; `safeAreaBar`/`safeAreaInset` for the
  bottom bar; a split-view divider (`VSplitView` or `NSSplitView`) for the drawer; regular bordered and prominent
  buttons; `NSPathControl` stays an option for the path bar.
- **Pros:** the most room for folders at every window height, which is where the work happens; the closest match
  to first-party list columns and to the save panel people already know; New Folder becomes a discoverable button;
  the visual hierarchy finally matches the task (find folder → check contents → name → move).
- **Cons:** the biggest change to a panel the user uses daily; the folder-contents drawer is smaller by default; a
  SwiftUI `List` draws its selection grey while it isn't first responder, but the picker's highlight must show the
  accent while the search field has focus, so rows keep a custom `listRowBackground` (as today) or the list moves
  to an `NSTableView` with an emphasised highlight; the list's own keyboard handling must stay out of the picker's
  key monitor.
- **Cost:** medium to high, 4–6 days: layout restructure of `FilingPanel`, `DestinationPickerView` (list and footer)
  and `FolderContentsView` (drawer), the bottom bar, and UI-test identifiers kept stable. The picker model, keys and
  focus handling stay as they are.

### Comparison

| | A · Tidy | B · Grouped | C · List-first |
| --- | --- | --- | --- |
| Folder rows visible | as today | fewer | most |
| Reads as | today, cleaner | settings | a first-party list column |
| Standard parts | type, controls | grouped look (imitated) | `List`, sections, bottom bar |
| Risk | low | look drifts from real `Form` | list highlight while typing |
| Cost | 1–2 days | 3–4 days | 4–6 days |

## Recommendation

Choose **C**, in three reviewable steps:

1. **A's base** (type, spacing, radii, one row style, path once, Move pinned without the badge, distinct notices,
   `ContentUnavailableView`). Lands on its own and fixes most of what looks off. 1–2 days.
2. **Container:** move the panel from `.inspector` to a trailing split-view pane. About a day.
3. **C's structure:** edge-to-edge list, Folder contents drawer, save-panel bottom bar with New Folder, status
   banner. 3–4 days on top of step 1. Combine with the destination-search study's outcome here, since both touch
   the picker's header and list.

If the user prefers less change, stopping after steps 1 and 2 gives concept A, and C can follow later without
redoing anything. B is not recommended: it borrows the settings idiom for a work surface and fights the HIG's box
guidance.

Whichever is chosen, `docs/design/ux.md` ("Window layout", "Destination picker") needs updating with it; this study
changes nothing there yet.

## Open questions for the user

1. Which direction: A, B, C, or A now and C later?
2. Keep a key hint for Move (⌘↩ beside the button), or rely on the menu and help tag only?
3. Move the panel out of `.inspector` (the HIG's reading), accepting that ⌥⌘I and the toggle become a View menu
   item and toolbar button of its own?
