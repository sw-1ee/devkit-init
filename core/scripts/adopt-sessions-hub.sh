#!/usr/bin/env bash
# adopt-sessions-hub.sh — 로컬 .agents/sessions 를 서버 전역 허브로 편입.
# 허브 없이 시작한 프로젝트가 나중에 허브를 도입할 때 1회 실행.
#
#   bash scripts/adopt-sessions-hub.sh [허브경로]
#   허브경로 기본 = $DEVKIT_SESSIONS_HUB or /mnt/volumes/sessions (없으면 생성 시도)
set -euo pipefail

PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HUB="${1:-${DEVKIT_SESSIONS_HUB:-/mnt/volumes/sessions}}"
NAME="$(basename "$PROJ_DIR")"
LOCAL="$PROJ_DIR/.agents/sessions"

if [ -L "$LOCAL" ]; then
  echo "이미 허브 심링크: $LOCAL -> $(readlink "$LOCAL")"; exit 0
fi
[ -d "$LOCAL" ] || { echo "ERROR: $LOCAL 없음"; exit 1; }

mkdir -p "$HUB/$NAME"
# 로컬 세션 이관 (기존 허브 내용과 병합, 충돌 시 로컬 우선하지 않음 — 동일명 폴더는 스킵)
cp -rn "$LOCAL/." "$HUB/$NAME/"
moved=$(find "$HUB/$NAME" -mindepth 1 -maxdepth 1 -type d | wc -l)
rm -rf "$LOCAL"
ln -s "$HUB/$NAME" "$LOCAL"
echo "편입 완료: $LOCAL -> $HUB/$NAME (세션 ${moved}개)"
echo "timeline 재병합..."
python3 "$PROJ_DIR/scripts/stitch-timeline.py"
