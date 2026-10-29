#!/usr/bin/env bash
# Builds home/tcl-home.apk: dumbtv home 1.6 with the TCL changes (grid over a wallpaper,
# Eingänge/WLAN/Einstellungen buttons, TCL apps hidden). No Gradle, as upstream.
# Needs a JDK 17 and an Android SDK (ANDROID_HOME) with platforms;android-30 and build-tools.
# GitHub Actions runs this on every push to home/ (.github/workflows/home.yml).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source version.env

SDK=${ANDROID_HOME:?set ANDROID_HOME to the Android SDK}
JAR=$SDK/platforms/android-30/android.jar
BT=$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)
[[ -f $JAR ]] || { echo "error: $JAR missing: sdkmanager 'platforms;android-30'" >&2; exit 1; }
[[ -x $BT/d8 ]] || { echo "error: no build-tools in $SDK" >&2; exit 1; }

# The signing key lives in the repo so every build can update the installed app.
KEYSTORE=$PWD/tcl-home.keystore
KEYPASS=tclhome

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/gen" "$WORK/classes"

"$BT/aapt2" compile --dir res -o "$WORK/res.zip"
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml "$WORK/res.zip" \
  --min-sdk-version 26 --target-sdk-version 28 \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" \
  --java "$WORK/gen" -o "$WORK/app.apk"

find src "$WORK/gen" -name '*.java' > "$WORK/sources.txt"
javac --release 8 -Xlint:-options -encoding UTF-8 -classpath "$JAR" -d "$WORK/classes" @"$WORK/sources.txt"

find "$WORK/classes" -name '*.class' > "$WORK/classes.txt"
"$BT/d8" --release --min-api 26 --lib "$JAR" --output "$WORK" @"$WORK/classes.txt"
(cd "$WORK" && zip -q -X app.apk classes.dex)

"$BT/zipalign" -f -p 4 "$WORK/app.apk" "$WORK/aligned.apk"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass "pass:$KEYPASS" --key-pass "pass:$KEYPASS" \
  --out tcl-home.apk "$WORK/aligned.apk"
"$BT/apksigner" verify tcl-home.apk
rm -f tcl-home.apk.idsig
echo "built home/tcl-home.apk ($(wc -c < tcl-home.apk | tr -d ' ') bytes)"
