#!/usr/bin/env bash
set -euo pipefail

# Netlify builds from the frontend/ directory. Flutter is not pre-installed.
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
else
  SDK_DIR="../.flutter-sdk"
  if [ ! -x "$SDK_DIR/bin/flutter" ]; then
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$SDK_DIR"
  fi
  FLUTTER_BIN="$SDK_DIR/bin/flutter"
fi

: "${API_BASE_URL:?Set API_BASE_URL to your Render HTTPS URL in Netlify environment settings}"
"$FLUTTER_BIN" config --enable-web
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build web --release --dart-define="API_BASE_URL=$API_BASE_URL"
