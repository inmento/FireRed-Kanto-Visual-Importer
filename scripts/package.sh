#!/usr/bin/env bash
# Build a clean public installer archive for FireRed Kanto Visual Importer.
# The allowlist deliberately excludes tests, research notes, tooling, Git data,
# player-provided ROMs, and all locally generated/imported content.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$ROOT/manifest.json" | head -n1)
if [[ -z "$VERSION" ]]; then
  echo "Could not read version from manifest.json" >&2
  exit 1
fi
OUT=${1:-"$ROOT/dist/FIRERED_KANTO_VISUALS-$VERSION.zip"}
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
PKG="$STAGE/FIRERED_KANTO_VISUALS"

mkdir -p "$PKG/lib" "$(dirname "$OUT")"
cp "$ROOT/manifest.json" "$ROOT/main.lua" "$ROOT/README.md" "$ROOT/CHANGELOG.md" "$PKG/"
cp "$ROOT"/lib/*.lua "$PKG/lib/"

rm -f "$OUT"
(
  cd "$STAGE"
  zip -qr "$OUT" FIRERED_KANTO_VISUALS
)
unzip -t "$OUT" >/dev/null

echo "Built $OUT"
