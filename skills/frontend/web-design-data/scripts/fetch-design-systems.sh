#!/usr/bin/env bash
# VoltAgent/awesome-design-md (MIT) — 브랜드별 DESIGN.md 만 (preview*.html 제외, 수십MB 방지).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="$HERE/../_raw/design-systems"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 --filter=blob:none \
  https://github.com/VoltAgent/awesome-design-md "$TMP/repo"

mkdir -p "$RAW/systems"
# 브랜드 폴더의 DESIGN.md 만 복사
find "$TMP/repo" -mindepth 2 -maxdepth 3 -name "DESIGN.md" | while read -r f; do
  slug="$(basename "$(dirname "$f")")"
  mkdir -p "$RAW/systems/$slug"
  cp "$f" "$RAW/systems/$slug/DESIGN.md"
done
cp "$TMP/repo/LICENSE" "$RAW/LICENSE" 2>/dev/null || echo "WARN: LICENSE not found" >&2
git -C "$TMP/repo" rev-parse HEAD > "$RAW/COMMIT"
echo "  design-systems: $(ls "$RAW/systems" | wc -l) brands @ $(cat "$RAW/COMMIT" | head -c 12)"
