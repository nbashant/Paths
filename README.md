# Paths

Paths is a tiny macOS app for opening Finder directly to a pasted file or folder path.

Paste a path, press Return or click Open, and Paths will either open the folder or reveal the file in Finder.

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

This repo currently contains source code only. Public binary releases should be Developer ID signed and notarized before being shared broadly.
