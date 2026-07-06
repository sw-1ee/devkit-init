#!/usr/bin/env bash
# pbakaus/impeccable (Apache-2.0) — detector 룰 소스 + LICENSE + NOTICE(Apache 보존 의무).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="$HERE/../_raw/impeccable"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/pbakaus/impeccable "$TMP/repo"

mkdir -p "$RAW/src"
# 룰 정본 = cli/engine/registry/antipatterns.mjs (45룰 JS 배열)
# + skill/SKILL.src.md + skill/reference/ (critique/audit 프로즈)
cp -r "$TMP/repo/cli/engine/registry" "$RAW/src/registry"
cp "$TMP/repo/skill/SKILL.src.md" "$RAW/src/SKILL.src.md"
[ -d "$TMP/repo/skill/reference" ] && cp -r "$TMP/repo/skill/reference" "$RAW/src/reference"
[ -f "$TMP/repo/skill/scripts/command-metadata.json" ] && cp "$TMP/repo/skill/scripts/command-metadata.json" "$RAW/src/command-metadata.json"
cp "$TMP/repo/LICENSE" "$RAW/LICENSE" 2>/dev/null || echo "WARN: LICENSE not found" >&2
cp "$TMP/repo/NOTICE" "$RAW/NOTICE" 2>/dev/null || true   # Apache NOTICE 있으면 보존
cp "$TMP/repo/README.md" "$RAW/README.md" 2>/dev/null || true
git -C "$TMP/repo" rev-parse HEAD > "$RAW/COMMIT"
echo "  impeccable: $(find "$RAW/src" -type f | wc -l) source files @ $(cat "$RAW/COMMIT" | head -c 12)"
