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

1. Select a file in the sidebar. It is shown large in the preview.
2. Type to find the destination folder: the search is fuzzy and covers the whole archive, and the folders you used
   last come first. You can also browse with the arrow keys. Tab chooses the highlighted folder.
3. Adjust the name if you like.
4. Press **⌘Return** to move the file.

Files can also be trashed, new folders can be created while you choose, every action can be undone, filed files can
be moved back to their inbox, and a History window lists everything you filed. New files in your inboxes show up on
their own.

Almost everything works from the keyboard. Every command and its shortcut is in the app's menu bar.

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
