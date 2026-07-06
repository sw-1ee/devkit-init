#!/usr/bin/env bash
# nextlevelbuilder/ui-ux-pro-max-skill (MIT) — data/ CSV 16종만 sparse 추출.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="$HERE/../_raw/ui-ux-pro-max"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/nextlevelbuilder/ui-ux-pro-max-skill "$TMP/repo"
# cone mode: 루트 파일(LICENSE 등)은 자동 포함, 디렉토리만 지정
git -C "$TMP/repo" sparse-checkout set src/ui-ux-pro-max/data

mkdir -p "$RAW"
cp -r "$TMP/repo/src/ui-ux-pro-max/data/." "$RAW/data/"
cp "$TMP/repo/LICENSE" "$RAW/LICENSE" 2>/dev/null || echo "WARN: LICENSE not at root" >&2
git -C "$TMP/repo" rev-parse HEAD > "$RAW/COMMIT"
echo "  ui-ux-pro-max: $(ls "$RAW/data" | wc -l) data files @ $(cat "$RAW/COMMIT" | head -c 12)"
