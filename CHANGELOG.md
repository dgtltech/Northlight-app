# Changelog

All notable user-facing changes to Northlight are documented here. Format inspired by [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [1.3] — 2026-05-12

### Fixed
- **macOS 15.4+ "file is damaged" issue when setting Northlight as the default app via Finder.** Finder's *Get Info → Open With → Change All…* path triggers a Gatekeeper change introduced in macOS Sequoia 15.4 that flags quarantined files as damaged. Northlight now declares its supported document types in a way that no longer triggers the related "dangerous types" classification, and the in-app **Settings → Defaults** screen sets file associations through the correct Launch Services API that bypasses the broken Finder path.
- **Leica RAW (`.rwl`)** now appears correctly in Settings → Defaults. Previously the entry was associated with the wrong file extension.

### Added
- **Settings → Defaults: "Fix Quarantine in Folder…" button.** Recursively removes the macOS quarantine flag from supported image files in a chosen folder. Repairs files that were already broken by the macOS 15.4+ bug above.
- **Settings → Defaults: explanation panel** describing the macOS 15.4+ behavior, with links to the technical analyses (lapcatsoftware, mjtsai, Apple Developer Forums).
- **Welcome Guide tip** recommending Settings → Defaults instead of Finder's *Open With → Change All…*.

### Changed
- **Info.plist document-type declarations restructured** into four logical groups (system formats / modern web / Adobe Photoshop / Camera RAW), with explicit `UTImportedTypeDeclarations` for every non-Apple UTI. Improves the reliability of *Set as Default* for WebP, AVIF, JPEG XL, PSD, and all RAW vendor formats.
- **Image loading no longer memory-maps files.** Switched to plain `Data(contentsOf:)`. No user-visible effect; reduces edge-case interactions with files held by other processes.

---

## [1.0] — 2026-05-09

Initial public release.
