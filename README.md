# Wakareeru

Flutter client for identifying Japanese rolling stock from photos with the
[Wakareeru](https://github.com/wakareeru-team/wakareeru) inference service.

[![Version](https://img.shields.io/github/v/release/wakareeru-team/wakareeru-app)](https://github.com/wakareeru-team/wakareeru-app/releases/latest)
[![CI](https://github.com/wakareeru-team/wakareeru-app/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/wakareeru-team/wakareeru-app/actions/workflows/CI.yml)

## Features

- Pick a photo from the library or take one with the camera.
- Identify multiple trains and inspect ranked predictions and confidence scores.
- Show rolling-stock metadata, operators, liveries, formations, and related links.
- Keep up to 200 recognition records and thumbnails locally on the device.
- Use English, Japanese, or Simplified Chinese with light and dark themes.
- Switch the inference gateway from the app settings.

## Install

Prebuilt Android and iOS artifacts are published on the
[Releases](https://github.com/wakareeru-team/wakareeru-app/releases) page when
available. An iOS IPA still requires a compatible signing and distribution
method before it can be installed on a device.

## Run locally

The project targets Android and iOS. Install
[Flutter](https://docs.flutter.dev/get-started/install) `3.44.2`, then run:

```bash
flutter pub get
flutter run
```

The app uses this Singapore relay gateway by default:

```text
http://159.89.193.182:8787
```

Set a different initial gateway at build time when developing locally or using
a self-hosted service:

```bash
flutter run \
  --dart-define=WAKAREERU_API_BASE_URL=http://127.0.0.1:8787
```

The gateway can also be changed at runtime from the app's settings page.

> [!IMPORTANT]
> Recognition uploads the selected image to the configured gateway. The default
> gateway currently uses unencrypted HTTP, so do not submit sensitive images.

## Development

Check formatting, then run the analysis and tests used by CI before opening a
pull request:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Useful project locations:

- `lib/main.dart` — application UI, gateway client, and inference models
- `lib/history.dart` — local recognition history
- `lib/rolling_stock.dart` — rolling-stock catalog lookup
- `lib/l10n/` — English, Japanese, and Chinese localizations
- `assets/rolling_stock_catalog.json` — bundled rolling-stock metadata
- `docs/RELEASING.md` — signed Android/iOS release setup and workflow

## Releases

Tags matching `v1.2.3` trigger the mobile release workflow. Maintainers should
follow the signing setup and release checklist in
[docs/RELEASING.md](docs/RELEASING.md).
