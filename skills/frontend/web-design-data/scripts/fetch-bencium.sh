#!/usr/bin/env bash
# bencium/bencium-marketplace — controlled UX designer 의 a11y/motion reference 2종.
# 라이선스: MIT — 단 README 선언만, LICENSE 파일 없음 (2026-07-06 실측).
# 조건부 흡수: attribution 필수, README 원문(라이선스 근거) 동봉.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="$HERE/../_raw/bencium"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/bencium/bencium-marketplace "$TMP/repo"

SKILL_DIR="$TMP/repo/bencium-controlled-ux-designer/skills/bencium-controlled-ux-designer"
mkdir -p "$RAW"
cp "$SKILL_DIR/ACCESSIBILITY.md" "$RAW/ACCESSIBILITY.md"
cp "$SKILL_DIR/MOTION-SPEC.md" "$RAW/MOTION-SPEC.md"
cp "$TMP/repo/README.md" "$RAW/README.md"   # MIT 선언 근거 보존
git -C "$TMP/repo" rev-parse HEAD > "$RAW/COMMIT"
echo "  bencium: a11y $(wc -l < "$RAW/ACCESSIBILITY.md")L + motion $(wc -l < "$RAW/MOTION-SPEC.md")L @ $(cat "$RAW/COMMIT" | head -c 12)"
