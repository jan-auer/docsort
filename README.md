# Docsort

Docsort is a native macOS app for filing documents. Files pile up in inbox folders such as Downloads and a scanner's
output folder; Docsort moves them from there into the folders of an archive you already keep, with a large preview
of the file beside the controls and almost everything on the keyboard.

![Docsort's main window with an invoice selected: the inbox list on the left, the PDF preview in the middle, and on the right a destination search for "marg" listing the matching folders, with the path "Archive › Arbeit Margit" under the search field, the folder's file list and the name field](docs/images/docsort-main-window.png)

*Searching for "marg" while filing an invoice: the matching folders are listed, the destination path is shown under
the search field, and the folder's files appear below the list. The screenshot shows invented sample data only.*

- **Preview that stays put.** The file you are filing is shown large (PDFs, images and anything Quick Look can show)
  the whole time you choose a folder and a name.
- **Fuzzy folder search.** Type a few letters of any folder's name. Words match in any order, case and accents are
  ignored, and the folders you used last come first.
- **Keyboard first.** Type to search, Tab to confirm the folder, ⌘Return to file, ⌘Z to take it back.
- **Nothing is lost.** Every move, rename and trash can be undone, and a history of everything you filed is kept.

Docsort needs macOS 27.

## Usage

### First-time setup

On first launch the window asks you to choose your folders. Open **Settings** (⌘, or **Open Settings…**), pane
**Folders**:

1. **Archive folder:** click **Choose…** and pick the top folder of your archive. Docsort indexes its folders and
   shows how many it found.
2. **Inboxes:** click **+** and pick each folder you want to file from. Every inbox gets its own section in the
   sidebar. The **Name** is editable, and you can drag the rows to reorder the sections. **−** removes the selected
   inbox from Docsort; its files are not touched.

Docsort runs in the macOS App Sandbox, so it can only touch folders you picked through these buttons, including
everything inside them. An inbox folder inside the archive is left out of the folder search.

The **Search** pane has one option, **Rank first:** *Closer folders* (the default) or *Exact name matches*, which
decides what comes first when several folders match.

### Filing a file

The sidebar lists the files of each inbox, oldest first. Filing a file takes three steps, and only the last one moves
anything:

1. **Select the file** with ↑ / ↓. The preview follows.
2. **Choose the destination.** Just start typing: the text goes straight into the search field of the filing panel.
   The first match is highlighted; ↑ / ↓ moves the highlight, and the files already in the highlighted folder are
   listed below, so you can see what is there. With an empty search field you see your recent destinations first.
   The search covers the whole archive; while you are inside a folder, its own matches come first. Press **Tab** (or
   **Return**) to choose the highlighted folder. A check mark appears and the destination is shown as a path.
   You can also browse: → steps into the highlighted folder, ← (or Backspace in an empty search field) steps out,
   and ⌘↑ jumps to the archive's top folder. To look at a folder in Finder, right-click its row in the list for
   **Open in Finder** or **Reveal in Finder**, or choose **File › Open Destination in Finder** (⇧⌘O), which opens the
   chosen folder, or else the highlighted one. A folder that does not exist yet has neither.
3. **Name the file.** The name field starts with the file's current name, selected, so typing replaces it. The
   extension is fixed after the field. The ↺ button (or ⇧⌘R) restores the original name. Clicking a file in the
   folder's file list copies its name into the field. If the folder already has a file with that name, Docsort says
   so, and moving asks whether to **Keep Both** or **Replace** (the replaced file goes to the Trash).

Then press **⌘Return** (or click **Move**). Only ⌘Return files; Return in the name field just reminds you of that.
You can press ⌘Return earlier, too: in the search field it files into the highlighted folder with the current name
right away.

The file stays in its place in the sidebar with a check mark and its new name, the list does not shuffle, and the
next unfiled file is selected, with the keyboard focus back on the sidebar so you can start typing its destination.

Esc steps back: from the name field to the search field, then clears the search text, then returns to the sidebar.
⇧Tab goes back one step without clearing anything.

### New folders

If the folder you need does not exist yet, highlight the folder it should go into and press **⇧⌘N** (or click
**New Folder** under the folder list). A name row appears inside it; type the name (a `/` creates nested folders)
and press Tab or Return. When a search matches nothing, the list offers to create a folder with the text you typed.

The new folder is created on disk only when you move the file. Undoing the move removes it again if it is empty.

### Trash and undo

**⌘⌫** moves the selected file to the Trash, without a confirmation (the toolbar and the context menu have it too).
The row stays in the list with a trash icon and a struck-through name.

**⌘Z** undoes the latest action of the session, **⇧⌘Z** redoes it: a move, a rename, a new folder, a trash, a
replace. The Edit menu names what it will undo.

### Move Back and Put Back

Select a filed file and its panel shows where it went, with a **Move Back** button. It returns the file to its
original place in the inbox under its original name (also **File › Move Back to Inbox**, ⌥⌘Z, or the row's context
menu). This works for any file filed earlier, also after a restart, through the history. A trashed file has **Put
Back** in the same place.

A filed file can also be renamed or moved on: change the folder or the name and press ⌘Return (the button then reads
**Rename** or **Move**).

### History

**Window › History** (⌘Y), or the History row at the bottom of the sidebar, opens a window with every move, rename,
move back and trash, grouped by day: when, the original name, the inbox, the new name and the destination. The search
field filters all columns, and the selected entry is previewed beside the list. From there you can open the file,
reveal it in Finder or move it back. If the file is no longer where Docsort put it, the entry says "Moved or deleted
since".

### Live inboxes and refresh

Docsort watches the inbox folders, so a new download or scan appears in the sidebar as it arrives, marked with a
small dot until you first select it, and a file someone else removes disappears. Changes Docsort makes itself never
reorder the list. The archive's folder index is refreshed when you switch back to the app; **⌘R** (View › Refresh,
or the ↻ button under the folder list) rescans the inboxes and the archive at once, for example after you created
folders in Finder.

### Keyboard shortcuts

Every command is in the menu bar.

| Keys | What it does |
| --- | --- |
| ↑ / ↓ | Previous / next file in the sidebar |
| ⌥⌘↑ / ⌥⌘↓ | Previous / next file, from anywhere in the window |
| *type* | With a file selected in the sidebar: search for a destination |
| Tab / Return | Next step: sidebar → search → name field (in the search field: choose the highlighted folder) |
| ⇧Tab | Back one step |
| Esc | In the name field: back to search. In search: clear the text, then back to the sidebar |
| → / ← | In search: step into the highlighted folder / out to its parent |
| ⌘↑ | In search: jump to the archive's top folder |
| ⇧⌘N | New folder in the highlighted folder |
| ⌘Return | **Move** the file (File › Move) |
| ⇧⌘R | Revert the name to the original |
| ⌘⌫ | Move the selected file to the Trash |
| ⌘Z / ⇧⌘Z | Undo / redo |
| ⌥⌘Z | Move Back to Inbox (Put Back for a trashed file) |
| ⌘O | Open the file in its default app |
| ⌥⌘R | Reveal the file in Finder |
| ⇧⌘O | Open the destination folder (chosen, else highlighted) in Finder |
| ⌘Y | History |
| ⌘R | Refresh inboxes and archive |
| ⌥⌘I | Show / hide the filing panel |
| ⌃⌘S | Show / hide the sidebar |
| ⌘+ / ⌘− / ⌘0 | Zoom the preview in / out / to fit |
| ⌘, | Settings |

## Development

Requirements: macOS 27 and Xcode 27. The project has no signing team; builds are signed ad hoc ("Sign to Run
Locally"). `CLAUDE.md` lists the project's toolchain and conventions.

### Build and run from the terminal

```sh
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/Docsort.app
```

### Install a Release build

```sh
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' -configuration Release -derivedDataPath .build/xcode-release build
ditto .build/xcode-release/Build/Products/Release/Docsort.app /Applications/Docsort.app
```

Because local builds are signed ad hoc, macOS may not recognise an updated copy as the same app: after replacing it,
you may have to pick the archive and inbox folders in Settings again.

### Build and install from Xcode

1. Open `Docsort.xcodeproj`, choose the scheme **Docsort** and the destination **My Mac**, and press ⌘R to build and
   run.
2. To install: **Product › Scheme › Edit Scheme…**, select **Run**, set **Build Configuration** to **Release** and
   close the sheet. Press ⌘B, then choose **Product › Show Build Folder in Finder**, open `Build/Products/Release`
   and drag `Docsort.app` to `/Applications`.

### Tests

The check commands (formatting, the package's unit tests, the app's unit tests and the UI tests) are listed in
`CLAUDE.md`, under "Check Commands".
