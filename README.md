# wakareeru-app

Flutter client for `wakareeru` image inference.

## Run

```bash
flutter pub get
flutter run
```

The app defaults to the production gateway:

```text
https://wakareeru-api-gateway.fengyukunfyk.workers.dev
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
