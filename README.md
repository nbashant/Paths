# Paths

Paths is a tiny macOS app for opening Finder directly to a pasted file/folder path or a filename search result.

Paste an exact path and press Return to open the folder or reveal the file in Finder. Type a filename and Paths shows fast Spotlight-backed suggestions with file icons and modified dates.

Press Return to open the selected result, or double-click a result row to reveal it in Finder.

## Download

[Download Paths for macOS](https://github.com/nbashant/Paths/releases/latest/download/Paths.dmg)

Open the DMG, then drag `Paths.app` into Applications.

## Build

Requires macOS with Swift and AppKit available.

```sh
./scripts/build.sh
```

The built app is created at:

```text
dist/Paths.app
```

## Local Install

```sh
./scripts/install-local.sh
```

This builds the app and copies it to `~/Applications/Paths.app`.

## Distribution Status

The current public download is ad-hoc signed but not notarized. A Developer ID signed and notarized release will provide the cleanest Gatekeeper experience.

## Notarized Release

To create a Gatekeeper-friendly public release, install a Developer ID Application certificate and create a notarytool keychain profile, then run:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="paths-notary" \
./scripts/package-notarized-dmg.sh
```

Upload the resulting `dist/Paths.dmg` to a GitHub Release.
