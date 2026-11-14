#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

if [ -d "$HOME/development/flutter/bin" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

if ! command -v flutter &> /dev/null; then
  echo "📦 Clonando Flutter SDK (stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter --version
flutter pub get
flutter build web --release
