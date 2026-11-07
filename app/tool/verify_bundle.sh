#!/usr/bin/env bash
# Checks a Google Play App Bundle before it is uploaded (#74).
#
# apksigner can't read an .aab: a bundle carries a JAR signature, and Play
# re-signs every APK it serves from it. So this checks the bundle's own
# signature with the JDK, then has bundletool turn it into the universal APK
# a device would get, and checks that the way release.yml checks the
# sideload APK:
#
#   - signed, and not with the debug key; given a SHA-256, signed with exactly
#     that certificate (the upload key's, never the app-signing key's)
#   - package com.golfy.golfy_app, never the .debug build (#23)
#   - minSdk / targetSdk as pinned in android/app/build.gradle.kts, and a
#     targetSdk Google Play still accepts
#   - no permission PRIVACY.md doesn't mention (tool/assert_permissions.sh, #72)
#   - 64-bit native libraries ready for 16 KB memory pages, which Play
#     requires of apps that target Android 15 or later
#
#   BUNDLETOOL=/path/to/bundletool.jar bash tool/verify_bundle.sh <aab> [upload-cert-sha256]
#
# Run from app/. Needs a JDK (JAVA_HOME, or java and keytool on PATH), the
# Android SDK's build-tools and NDK, and bundletool's jar, which the SDK
# doesn't ship: see "Google Play (App Bundle)" in README.md. The SDK is
# ANDROID_SDK_ROOT or ANDROID_HOME, else sdk.dir from android/local.properties.
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: BUNDLETOOL=<bundletool.jar> bash tool/verify_bundle.sh <aab> [upload-cert-sha256]" >&2
  exit 2
fi
aab=$1
expected_sha256=${2:-}
here=$(cd "$(dirname "$0")" && pwd)
app_dir=$(dirname "$here")

# Google Play's target API floor for new apps and updates. It rises every
# August 31: raise this with targetSdk in android/app/build.gradle.kts.
play_target_sdk_floor=36

fail() {
  echo "::error::$*"
  exit 1
}

[ -f "$aab" ] || fail "$aab not found"
[ -n "${BUNDLETOOL:-}" ] || fail "BUNDLETOOL is not set; point it at bundletool-all-<version>.jar"
[ -f "$BUNDLETOOL" ] || fail "BUNDLETOOL=$BUNDLETOOL not found"

# A tool by name, as a Windows .exe too, so this also runs in Git Bash.
find_tool() {
  local dir=$1 name=$2 candidate
  for candidate in "$dir/$name" "$dir/$name.exe"; do
    if [ -f "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
  return 1
}

jdk_bin=${JAVA_HOME:+$JAVA_HOME/bin}
java=$(find_tool "${jdk_bin:-$(dirname "$(command -v java || echo /none/java)")}" java) ||
  fail "no java; set JAVA_HOME (Android Studio ships a JDK in its jbr folder)"
keytool=$(find_tool "$(dirname "$java")" keytool) || fail "no keytool next to $java"
jarsigner=$(find_tool "$(dirname "$java")" jarsigner) || fail "no jarsigner next to $java"

sdk=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
if [ -z "$sdk" ] && [ -f "$app_dir/android/local.properties" ]; then
  # local.properties escapes Windows paths: C\:\\Users\\…
  sdk=$(sed -n 's/^sdk\.dir=//p' "$app_dir/android/local.properties" | tr -d '\r' | sed 's/\\\(.\)/\1/g')
  if command -v cygpath > /dev/null; then sdk=$(cygpath -u "$sdk"); fi
fi
[ -d "$sdk" ] || fail "no Android SDK; set ANDROID_HOME"
build_tools=$(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)
aapt2=${AAPT2:-$(find_tool "$build_tools" aapt2)} || fail "no aapt2 in $build_tools"
zipalign=$(find_tool "$build_tools" zipalign) || fail "no zipalign in $build_tools"
readelf=${READELF:-$(find "$sdk/ndk" -path '*/toolchains/llvm/prebuilt/*/bin/llvm-readelf*' 2> /dev/null | sort -V | tail -1)}
[ -n "$readelf" ] || fail "no llvm-readelf; install an NDK or set READELF"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "== Signature ($aab)"
verify=$("$jarsigner" -verify "$aab" 2>&1) || true
grep -q '^jar verified' <<< "$verify" || fail "$aab is not signed: $verify"
cert=$("$keytool" -printcert -jarfile "$aab")
owner=$(grep -m1 -oP '^Owner: \K.*' <<< "$cert")
sha256=$(grep -m1 -oP '^\s*SHA256: \K[0-9A-F:]+' <<< "$cert")
echo "  signer   $owner"
echo "  SHA-256  $sha256"
if grep -q 'CN=Android Debug' <<< "$owner"; then
  fail "$aab is debug-signed; key.properties has no upload key (uploadStoreFile)"
fi
if [ -n "$expected_sha256" ]; then
  normalize() { tr -d ': ' <<< "$1" | tr '[:lower:]' '[:upper:]'; }
  [ "$(normalize "$sha256")" = "$(normalize "$expected_sha256")" ] ||
    fail "$aab is signed by $sha256, not the upload key $expected_sha256"
else
  echo "  (no expected SHA-256 given; compare it with the upload key's yourself)"
fi

echo "== Bundle"
"$java" -jar "$BUNDLETOOL" validate --bundle="$aab" > /dev/null
package=$("$java" -jar "$BUNDLETOOL" dump manifest --bundle="$aab" --xpath=/manifest/@package | tr -d '\r')
echo "  package  $package"
[ "$package" = "com.golfy.golfy_app" ] || fail "$aab is $package, not com.golfy.golfy_app"

# The APK a device without split support would get: everything in one, so the
# checks below see every ABI's libraries and the whole merged manifest.
"$java" -jar "$BUNDLETOOL" build-apks --bundle="$aab" --mode=universal \
  --output="$work/golfy.apks" > /dev/null
unzip -q -o "$work/golfy.apks" universal.apk -d "$work"
apk=$work/universal.apk

echo "== SDK levels"
badging=$("$aapt2" dump badging "$apk")
min_sdk=$(grep -oP "^minSdkVersion:'\K[0-9]+" <<< "$badging")
target_sdk=$(grep -oP "^targetSdkVersion:'\K[0-9]+" <<< "$badging")
gradle=$app_dir/android/app/build.gradle.kts
pinned_min=$(grep -oP '^\s*minSdk = \K[0-9]+' "$gradle")
pinned_target=$(grep -oP '^\s*targetSdk = \K[0-9]+' "$gradle")
echo "  minSdk $min_sdk, targetSdk $target_sdk (build.gradle.kts pins $pinned_min / $pinned_target)"
[ "$min_sdk" = "$pinned_min" ] && [ "$target_sdk" = "$pinned_target" ] ||
  fail "$aab wasn't built from this tree's SDK levels; rebuild it"
[ "$target_sdk" -ge "$play_target_sdk_floor" ] ||
  fail "targetSdk $target_sdk is below Google Play's floor of $play_target_sdk_floor"

echo "== Permissions"
AAPT2=$aapt2 bash "$here/assert_permissions.sh" "$apk"

echo "== 16 KB page size"
# Two halves: each library's LOAD segments must be 16 KB-aligned, and an
# uncompressed library must start on a 16 KB boundary inside the APK.
aligned=$("$zipalign" -c -v -P 16 4 "$apk" 2>&1) ||
  fail "native libraries aren't 16 KB zip-aligned: $(grep BAD <<< "$aligned" | head -5)"
unzip -q -o "$apk" 'lib/arm64-v8a/*' 'lib/x86_64/*' -d "$work" 2> /dev/null || true
libs=$(find "$work/lib" -name '*.so' 2> /dev/null | sort)
[ -n "$libs" ] || fail "no 64-bit native libraries in $apk; is it a Flutter build?"
misaligned=()
while IFS= read -r lib; do
  # Each LOAD line ends in its alignment, e.g. 0x4000 for 16 KB.
  while read -r align; do
    if [ $((align)) -lt $((0x4000)) ]; then
      misaligned+=("${lib#"$work"/} ($align)")
      break
    fi
  done < <("$readelf" -lW "$lib" | awk '$1 == "LOAD" { print $NF }')
  echo "  ${lib#"$work"/}"
done <<< "$libs"
if [ ${#misaligned[@]} -gt 0 ]; then
  fail "not 16 KB-aligned: ${misaligned[*]}"
fi

echo "$aab is ready to upload to Google Play."
