# wakareeru-app

Flutter client for `wakareeru` image inference.

[![Version](https://img.shields.io/github/v/release/wakareeru-team/wakareeru-app)](https://github.com/wakareeru-team/wakareeru-app/releases/latest)
[![CI](https://github.com/wakareeru-team/wakareeru-app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/wakareeru-team/wakareeru-app/actions/workflows/ci.yml)

## Run

```bash
flutter pub get
flutter run
```

The app defaults to the Singapore relay gateway:

```text
http://159.89.193.182:8787
```

Override the initial gateway URL when needed:

```bash
flutter run --dart-define=WAKAREERU_API_BASE_URL=http://127.0.0.1:8787
```

## Development

```bash
dart format lib test
flutter analyze
flutter test
```
