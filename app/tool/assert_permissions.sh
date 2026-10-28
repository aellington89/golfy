#!/usr/bin/env bash
# Fails if an APK asks for an Android permission outside an allow-list (#72).
#
# PRIVACY.md tells people Golfy has no permission to use the internet and
# asks for no other access. This keeps that true: a dependency that brings in
# a permission fails CI until PRIVACY.md (and #77's Play Data Safety answers)
# say so in the same pull request, and the permission is allowed here.
#
#   bash tool/assert_permissions.sh <apk> [allowed-permission ...]
#
# Run from app/ by flutter-build.yml (debug APK, which may also have INTERNET
# for Flutter's own tooling) and by release.yml (release APK, which may not).
set -euo pipefail

apk=$1
shift

aapt2=${AAPT2:-$(find "${ANDROID_SDK_ROOT:-$ANDROID_HOME}/build-tools" -name aapt2 | sort -V | tail -1)}
badging=$("$aapt2" dump badging "$apk")

package=$(grep -oP "^package: name='\K[^']+" <<< "$badging") || {
  echo "::error::$apk has no package name in its badging; is it an APK?"
  exit 1
}
# AndroidX declares, and uses, a signature-level permission of the app's own
# to protect its broadcast receivers. It grants no access to anything outside
# Golfy and is never shown to anyone.
allowed=("$package.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" "$@")

requested=$(grep -oP "^uses-permission(-sdk-23)?: name='\K[^']+" <<< "$badging" | sort -u || true)

echo "$apk ($package) asks for:"
if [ -z "$requested" ]; then
  echo "  nothing"
else
  sed 's/^/  /' <<< "$requested"
fi

unexpected=()
while IFS= read -r permission; do
  [ -n "$permission" ] || continue
  known=false
  for allowed_permission in "${allowed[@]}"; do
    if [ "$permission" = "$allowed_permission" ]; then known=true; fi
  done
  if ! $known; then unexpected+=("$permission"); fi
done <<< "$requested"

if [ ${#unexpected[@]} -gt 0 ]; then
  echo "::error::$apk asks for a permission PRIVACY.md doesn't mention: ${unexpected[*]}"
  echo "Update PRIVACY.md (and #77's Data Safety answers), then allow it in the workflow."
  exit 1
fi
