#!/usr/bin/env bash
set -euo pipefail
OUT_ROOT="${1:-}"
TAG_REGEX="${2:-}"
if [ -z "$OUT_ROOT" ] || [ -z "$TAG_REGEX" ]; then
  exit 0
fi
RELEASES_FILE="all_releases.txt"
mkdir -p "$OUT_ROOT"
mkdir -p index
touch index/.nojekyll
if [ ! -f "$RELEASES_FILE" ]; then
  cat > "$OUT_ROOT/index.html" <<'HTML'
<!doctype html>
<html><head><meta charset="utf-8"><title>Index</title></head><body><h1>Index</h1><p>No releases data available.</p></body></html>
HTML
  exit 0
fi
RELEASE_TAGS="$(jq -r '.[] | select(.tag_name | test("'"$TAG_REGEX"'")) | .tag_name' "$RELEASES_FILE" 2>/dev/null || true)"
if [ -z "$RELEASE_TAGS" ]; then
  mkdir -p "$OUT_ROOT"
  cat > "$OUT_ROOT/index.html" <<'HTML'
<!doctype html>
<html><head><meta charset="utf-8"><title>Index</title></head><body><h1>Index</h1><p class="empty">No wheel files found for this category.</p></body></html>
HTML
  exit 0
fi
FOUND=0
while IFS= read -r TAG; do
  ASSETS="$(jq -r --arg TAG "$TAG" '.[] | select(.tag_name==$TAG) | .assets[]? | select(.name|endswith(".whl")) | "\(.browser_download_url)|\(.name)"' "$RELEASES_FILE" 2>/dev/null || true)"
  if [ -z "$ASSETS" ]; then
    continue
  fi
  while IFS="|" read -r URL NAME; do
    PACKAGE="$(echo "$NAME" | sed -E 's/-[0-9].*//')"
    PACKAGE_DIR="$OUT_ROOT/$PACKAGE"
    mkdir -p "$PACKAGE_DIR"
    WHEEL_PATH="$PACKAGE_DIR/$NAME"
    if [ ! -f "$WHEEL_PATH" ]; then
      curl -sSL "$URL" -o "$WHEEL_PATH" || rm -f "$WHEEL_PATH" || true
    fi
    FOUND=$((FOUND+1))
  done <<< "$ASSETS"
done <<< "$RELEASE_TAGS"
for PACKAGE_DIR in "$OUT_ROOT"/*/; do
  PKG="$(basename "$PACKAGE_DIR")"
  printf '%s\n' "<!doctype html><html><head><meta charset=\"utf-8\"><title>Index of $PKG</title></head><body><h1>Index of $PKG</h1><ul>" > "$PACKAGE_DIR/index.html"
  shopt -s nullglob 2>/dev/null || true
  for FILE in "$PACKAGE_DIR"*.whl; do
    F="$(basename "$FILE")"
    printf '%s\n' "  <li><a href=\"./$F\">$F</a></li>" >> "$PACKAGE_DIR/index.html"
  done
  printf '%s\n' "</ul></body></html>" >> "$PACKAGE_DIR/index.html"
done
PKG_LIST_HTML="$OUT_ROOT/index.html"
printf '%s\n' "<!doctype html><html><head><meta charset=\"utf-8\"><title>Packages</title></head><body><h1>Packages</h1><ul>" > "$PKG_LIST_HTML"
for DIR in "$OUT_ROOT"*/; do
  P="$(basename "$DIR")"
  printf '%s\n' "  <li><a href=\"./$P/\">$P</a></li>" >> "$PKG_LIST_HTML"
done
printf '%s\n' "</ul></body></html>" >> "$PKG_LIST_HTML"
if [ "$FOUND" -eq 0 ]; then
  exit 0
fi
exit 0
