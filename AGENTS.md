# Notes for AI agents

Compositor is a macOS image editor for compositing and photo work, written in Swift (SwiftUI and AppKit, with some C for pixel work).

This repository is the **Simplified Chinese edition**, an unofficial fork of [robbietilton/Compositor](https://github.com/robbietilton/Compositor). It tracks upstream and adds the Chinese interface; see [README.md](README.md) and [docs/syncing-with-upstream.md](docs/syncing-with-upstream.md) before changing anything that came from upstream.

## Designing or editing a Compositor project

If you've been asked to make or change an image in a `.comp` project, you don't need the app's source code. Read [docs/writing-comp-files.md](docs/writing-comp-files.md): it covers the file format, the rules that make a project load, and how to write it safely while it's open, so the person can watch the canvas update as you work.

## Working on the app itself

- Build: open `Compositor.xcodeproj` and run the **Compositor** scheme, or `xcodebuild -project Compositor.xcodeproj -scheme Compositor -destination 'platform=macOS' build`.
- Tests: the `CompositorTests` target (`xcodebuild ... test -only-testing:CompositorTests`). CI runs these on every push.
- Match the surrounding code: its naming, its comment style and density.
- American spelling in code, comments and UI ("color", not "colour").
- The project file format is described in [docs/project-format.md](docs/project-format.md). A change to what's saved means a format version bump there and in `ProjectManifest.current`.

## Rules specific to this fork

- **Interface text is never written in Chinese in Swift.** A literal in the source is the English key; the translation lives in `Compositor/zh-Hans.lproj/Localizable.strings`. Text that only exists at runtime is looked up with `"…".localized`. After adding strings, run `perl l10n/check_coverage.pl` and `perl l10n/check_placeholders.pl`.
- **Do not change these to upstream's values**, whatever a merge brings in: `PRODUCT_BUNDLE_IDENTIFIER = com.kkwking.compositor.cn`, `DEVELOPMENT_TEAM = ""`, and the updater being off in `Config/Info.plist`. The app's own updates would otherwise replace this edition with the English original.
- **Tests run in English** (the scheme passes `-AppleLanguages (en)`), because the suites assert English menu titles and labels. Don't "fix" a failing assertion by translating the expectation.
- **Don't send these changes upstream.** The original author isn't taking localization pull requests; see the note in upstream's README.
