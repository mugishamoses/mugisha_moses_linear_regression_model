#!/usr/bin/env bash
# Run the app in Chrome (default); if Chrome is unavailable or the web run fails, fall back to Android.
# Port 8080 matters: it is the origin allowed by the API's CORS config.
# Usage: ./run.sh            (uses the Render API)
#        API_URL=http://localhost:8000/predict ./run.sh   (local API; Android fallback needs 10.0.2.2 instead of localhost)
set -u
cd "$(dirname "$0")"
DEFINE=()
[ -n "${API_URL:-}" ] && DEFINE=(--dart-define=API_URL="$API_URL")

flutter pub get >/dev/null
if flutter devices | grep -q '• chrome'; then
  flutter run -d chrome --web-port 8080 "${DEFINE[@]}" && exit 0
  echo "Web run failed - falling back to Android."
else
  echo "Chrome not found - falling back to Android."
fi

ANDROID=$(flutter devices | grep -i 'android' | awk -F'•' '{gsub(/ /,"",$2); print $2}' | head -1)
if [ -z "$ANDROID" ]; then
  AVD=$(flutter emulators | grep -i android | awk -F'•' '{gsub(/ /,"",$1); print $1}' | head -1)
  [ -z "$AVD" ] && { echo "No Android device or emulator found. Create one in Android Studio."; exit 1; }
  echo "Starting emulator $AVD..."
  flutter emulators --launch "$AVD"
  for _ in $(seq 60); do
    ANDROID=$(flutter devices | grep -i 'android' | awk -F'•' '{gsub(/ /,"",$2); print $2}' | head -1)
    [ -n "$ANDROID" ] && break; sleep 5
  done
  [ -z "$ANDROID" ] && { echo "Emulator did not start."; exit 1; }
fi
flutter run -d "$ANDROID" "${DEFINE[@]}"
