# Northlight

> *An image viewer the way it used to feel. Open an image, scroll.*

A fast, focused image viewer for macOS — built with AppKit, no SwiftUI.

**Free.** No account, no telemetry, no cloud. Files stay on your Mac.

Northlight is inspired by Xee.app: open an image, get out of the way. No editing, no library management, no cloud sync. Just viewing, with mouse-wheel folder navigation, keyboard shortcuts, multi-window support, and proper handling of every format Apple's ImageIO understands (including animated GIF, WebP, AVIF, JPEG XL, and most camera RAW formats).

Distributed outside the Mac App Store with Developer ID signing and notarization. Public site: <https://dgtltech.github.io/Northlight/>.

---

## Features

- **Single-key navigation** — `←` / `→` between images in the current folder, with sort by name / date modified / date created / date added / file size.
- **Smart zoom** — fit-to-window by default, `⌘0` for actual size, `⌘+` / `⌘−` to zoom, `⌘9` for fit. Pinch on trackpad and `⌘+wheel` also work. Double-click toggles 100% at cursor / fit.
- **Drag-to-pan** when zoomed, with a custom centering clip view that keeps the image visually anchored as you zoom in and out.
- **Animated GIF** support (frames preserved via `NSImage(data:)`).
- **Status bar** with folder position, current zoom, frame count for animations, pixel dimensions, file format, file size, and modification date.
- **Multiple windows** — `⌘N` for a new window, each with independent navigation and zoom state.
- **Background color cycling** — six modes (theme default, theme opposite, pink, green, white, black). Click the color dot in the status bar to cycle, synced across all open windows via `NotificationCenter`.
- **Send To submenu** in the right-click menu, configurable in Settings.
- **Customizable app icon** — four presets (Default / Compass / Duck / Aurora) plus custom image upload. Note: macOS only allows runtime icon changes for signed apps, so the custom icon is shown while Northlight is running and the system reverts to the default icon when the app is closed.
- **Set as default app** for image formats — from Settings → Defaults, using `LSSetDefaultRoleHandlerForContentType` (the only path that avoids the macOS 15.4 Gatekeeper bug; see below).
- **Fix Quarantine in Folder** — bulk-removes `com.apple.quarantine` xattr from image files in a selected folder, repairing files broken by the macOS bug.

---

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel
- Swift 6.0 toolchain (for building)

---

## Supported Formats

JPEG (`.jpg .jpeg .jpe .jfif`), PNG, GIF (animated), TIFF, BMP, ICO, ICNS, HEIC / HEIF, WebP, AVIF, JPEG XL (`.jxl`), SVG (`.svg .svgz`), Photoshop (`.psd`).

Camera RAW: Canon (CR2 / CR3 / CRW), Nikon (NEF / NRW), Sony (ARW / SRF / SR2), Adobe DNG, Fujifilm RAF, Panasonic RW2, Olympus ORF, Pentax PEF / PTX, Sigma X3F, Hasselblad 3FR, Mamiya MEF / MOS, Phase One IIQ, Leica RWL, Kodak KDC / DCR, Minolta MRW, Epson ERF, generic RAW.

Loading goes through `ImageIO` via `CGImageSourceCreateWithData`, so anything Apple's framework can decode will load. The exception is SVG, which ImageIO cannot decode. Simple SVGs render through `NSImage` (CoreSVG) as true vectors, staying sharp at any zoom level and preserving transparency. SVGs that use features CoreSVG cannot draw — embedded or external images, filters, stylesheets, scripts — automatically render through WebKit with browser-grade fidelity; the view re-sharpens shortly after each zoom change. The list above is the set with explicit `LSItemContentTypes` declarations in `Info.plist`.

---

## Installation

1. Download `Northlight.zip` from the latest release.
2. Unzip and drag `Northlight.app` to `/Applications`.
3. First launch: right-click → Open (to satisfy Gatekeeper for the initial run after download, since the file has the quarantine xattr).

After that, double-click works normally.

### Setting Northlight as the default for image formats

**Do this from inside the app:** Settings → Defaults → "Set Northlight as Default for All".

**Do NOT** use Finder's Get Info → "Open With → Change All…" on macOS 15.4+. See [macOS 15.4+ Bug](#macos-154-always-open-with-bug) below.

---

## Building from Source

### Prerequisites

- Xcode 16 or later
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Generate the Xcode project

```bash
cd Northlight
xcodegen
```

This reads `project.yml` and writes `Northlight.xcodeproj`. The project file is regenerated — do not edit it by hand; edit `project.yml` instead.

### Build & run for development

Open `Northlight.xcodeproj` in Xcode and hit Run. Debug builds are signed ad-hoc (`CODE_SIGN_IDENTITY = "-"` in `project.yml`).

### Archive for distribution

In Xcode: **Product → Archive**. The Organizer will open with the archived build. From there:

1. **Distribute App → Direct Distribution** (Developer ID, outside the App Store).
2. Xcode will sign with your Developer ID Application certificate, send the build to Apple for notarization, and staple the ticket.
3. Export the `.app` and zip it for distribution.

Version and build number come from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` build settings — Info.plist references them as `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. Bump them in the target's build settings before archiving.

### Distribution checklist

- Bundle ID: `tech.dgtl.northlight`
- Hardened Runtime: enabled
- App Sandbox: **disabled** (required so the in-app "Set as Default" buttons can call `LSSetDefaultRoleHandlerForContentType`; sandboxed apps cannot set themselves as system default handlers).
- Notarization: required (Gatekeeper will block the app on first run otherwise).
- After installing a new build on a test machine, register the bundle so Launch Services picks up the new `Info.plist`. **Prefer the targeted form** — it does not nuke the whole database:
  ```bash
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
      -f /Applications/Northlight.app
  ```
  **Do NOT** run `lsregister -kill -r -domain ...` to "force a refresh" — it orphans PlugInKit / ShareKit references and hangs the Finder Share sheet. If you really need a full rebuild (rare), use the seeded form and flush the dependent caches:
  ```bash
  LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
  $LSREGISTER -kill
  mkdir -p ~/.Trash/pluginkit_cache_$(date +%s)
  mv ~/Library/Caches/com.apple.nsservicescache.plist ~/.Trash/pluginkit_cache_*/ 2>/dev/null
  $LSREGISTER -seed -r -lint -domain local -domain system -domain user
  killall pkd cfprefsd sharingd Finder
  ```

---

## Architecture

AppKit-based (no SwiftUI). Deployment target macOS 15.0 lets the code use Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`) and modern AppKit APIs.

### Module layout

```
Northlight/
├── App/                    # Application lifecycle
│   ├── NorthlightApp.swift         — @main entry point
│   ├── AppDelegate.swift            — multi-window management, file-open events
│   ├── MainMenu.swift               — programmatic NSMenu
│   └── SendToMenuDelegate.swift     — dynamic "Send to" submenu
├── Model/                  # Pure model layer, no AppKit dependencies where avoidable
│   ├── ImageLoader.swift            — async load via ImageIO
│   ├── FolderNavigator.swift        — current-folder enumeration, prev/next
│   ├── ZoomController.swift         — magnification math, fit logic
│   ├── SortPreferences.swift        — sort criteria, persisted in UserDefaults
│   ├── BackgroundPreferences.swift  — 6-mode background color cycle
│   ├── SendToFolders.swift          — user-configured destination folders
│   ├── SupportedFormats.swift       — extension whitelist
│   ├── FileFormatRegistry.swift     — formats exposed in Settings → Defaults
│   ├── FileInfo.swift               — metadata extraction
│   └── AppIconManager.swift         — runtime icon switching via setApplicationIconImage
├── Window/                 # AppKit view controllers and custom views
│   ├── ImageWindowController.swift  — main viewer window
│   ├── ImageScrollView.swift        — NSScrollView subclass + CenteringClipView
│   ├── StatusBarView.swift          — bottom status bar
│   ├── ZoomPopoverViewController.swift — zoom preset popover
│   ├── PreferencesWindowController.swift — Settings (4 tabs)
│   ├── AboutWindowController.swift  — About panel
│   └── WelcomeGuideView.swift       — empty-state keyboard/gesture guide
└── Resources/
    ├── Info.plist                   — UTI declarations, document types
    ├── Assets.xcassets              — app icons
    └── PrivacyInfo.xcprivacy        — privacy manifest
```

### Key architectural decisions

- **AppKit over SwiftUI** — SwiftUI's `Image` does not preserve animated GIF frames, and its scroll/magnification primitives lack the precise control needed for a viewer (specifically: zoom centered on the cursor, not the document origin). Direct `NSScrollView` magnification with a custom `CenteringClipView` is the only reliable path.
- **NSImage(data:) over NSImage(contentsOfFile:)** — preserves animated frames; the file-based initializer collapses GIFs to a single frame.
- **Manual zoom math** — `setMagnification(_:centeredAt:)` interacts poorly with `CenteringClipView`. We compute `newOrigin = docAnchor - anchorPoint/target` ourselves to keep the cursor pinned during `⌘+` / `⌘−`.
- **Override `NSImage.size = pixelSize` after loading** — bypasses Retina dpi metadata in the file, so fit-to-window calculations use true pixel dimensions.
- **Multi-window via `AppDelegate.windowControllers: [ImageWindowController]`** — each window owns its own state. Cross-window state (background color, sort) syncs via `NotificationCenter` posts from singleton preference objects.
- **Sandbox disabled** — required for `LSSetDefaultRoleHandlerForContentType`. The trade-off is no Mac App Store distribution; the app is Developer ID + notarized for direct download instead.
- **No third-party dependencies** — everything is Apple frameworks (AppKit, ImageIO, UniformTypeIdentifiers, Vision for icon background-removal in the icon generator script).

---

## macOS 15.4+ "Always Open With" Bug

Since macOS Sequoia 15.4 (April 2025), Finder's Get Info → **"Open With → Change All…"** path is broken for files that carry the `com.apple.quarantine` xattr (i.e. anything downloaded via Telegram, Safari, AirDrop, Messages, iCloud). After redirecting the binding, double-clicking the file shows:

> "[filename] is damaged and can't be opened. You should move it to the Trash."

The file is not actually damaged.

### Root cause

Two overlapping bugs, both triggered by the same UI path:

1. **Gatekeeper "redirected binding" check** — When Launch Services sees a Finder-redirected binding on a quarantined file, it sets `LSDownloadRiskCategoryKey = LSRiskCategoryHasRedirectedBinding` and refuses to open the file. Apple DTS confirmed this is intentional anti-malware behavior. No app-side change can suppress it.

2. **"Dangerous CFBundleDocumentTypes" classification** — When an app declares unrecognized / dynamic UTIs in `CFBundleDocumentTypes` without corresponding `UTImportedTypeDeclarations`, Launch Services treats the entire bundle as potentially dangerous, producing the same "damaged" dialog even on non-quarantined files. This one is fixable in `Info.plist`.

References:
- [lapcatsoftware.com — bug analysis (Jeff Johnson)](https://lapcatsoftware.com/articles/2025/4/8.html)
- [mjtsai.com — summary](https://mjtsai.com/blog/2025/07/15/gatekeeper-change-in-macos-15-4/)
- [Apple Developer Forums (DTS)](https://developer.apple.com/forums/thread/795994)

Apple Feedback IDs: FB19468486, FB19623735.

### Northlight's mitigation

- **`CFBundleDocumentTypes` split into 4 logical groups** (system formats / modern web / Photoshop / RAW) with appropriate `LSHandlerRank` per group, instead of one flat list.
- **`public.image` removed** from `LSItemContentTypes` — the over-broad declaration was a Bug #2 trigger.
- **`UTImportedTypeDeclarations`** added for all 21 non-Apple UTIs (WebP, Photoshop, all RAW vendors) with `UTTypeConformsTo`, `UTTypeTagSpecification`, and MIME types. This stops Launch Services from treating them as "dangerous unknown".
- **Settings → Defaults** uses `LSSetDefaultRoleHandlerForContentType` directly, bypassing Finder's broken redirected-binding path entirely.
- **"Fix Quarantine in Folder…"** button — bulk-removes `com.apple.quarantine` xattr from supported image files in a chosen folder, repairing files that already triggered the bug.
- **In-app warning block** in Settings → Defaults explains the bug, links to the analyses above, and tells users not to use Finder's "Change All".
- **Welcome Guide tip** at the bottom of the empty-state guide says the same thing.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## About

© 2026 DGTL TECH LLC. Powered by RAGE.
