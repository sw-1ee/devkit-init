#!/usr/bin/env bash
# Nutlope/hallmark (MIT) — SKILL.md (20테마+슬롭게이트) + references/ + LICENSE.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="$HERE/../_raw/hallmark"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/Nutlope/hallmark "$TMP/repo"

mkdir -p "$RAW"
cp "$TMP/repo/skills/hallmark/SKILL.md" "$RAW/SKILL.md"
[ -d "$TMP/repo/skills/hallmark/references" ] && cp -r "$TMP/repo/skills/hallmark/references" "$RAW/references"
for f in docs/recipes.md docs/study-examples.md; do
  [ -f "$TMP/repo/$f" ] && { mkdir -p "$RAW/docs"; cp "$TMP/repo/$f" "$RAW/docs/"; }
done
cp "$TMP/repo/LICENSE" "$RAW/LICENSE" 2>/dev/null || echo "WARN: LICENSE not found" >&2
git -C "$TMP/repo" rev-parse HEAD > "$RAW/COMMIT"
echo "  hallmark: SKILL.md $(wc -l < "$RAW/SKILL.md") lines @ $(cat "$RAW/COMMIT" | head -c 12)"
