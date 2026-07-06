#!/usr/bin/env bash
# adopt-sessions-hub.sh — 이 프로젝트의 세션을 지정 허브로 이관 + 서버 기본값 영속.
#
#   bash scripts/adopt-sessions-hub.sh <허브경로>
#
# 처리:
#   1. 현 .agents/sessions (로컬 폴더든, 옛 허브 심링크든) 내용을 새 허브로 이관
#   2. .agents/sessions -> <새허브>/<프로젝트명> 심링크 전환
#   3. ~/.claude/devkit.json 의 sessions_hub 갱신 — 이후 이 서버의 모든
#      devkit init 이 새 허브를 따름 (env DEVKIT_SESSIONS_HUB 는 그보다 우선)
#   4. timeline 재병합
set -euo pipefail

[ $# -ge 1 ] || { echo "Usage: adopt-sessions-hub.sh <허브경로>"; exit 1; }
NEW_HUB="$(mkdir -p "$1" && cd "$1" && pwd)"

PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NAME="$(basename "$PROJ_DIR")"
LOCAL="$PROJ_DIR/.agents/sessions"
DEST="$NEW_HUB/$NAME"

if [ -L "$LOCAL" ]; then
  OLD="$(readlink -f "$LOCAL")"
  if [ "$OLD" = "$DEST" ]; then
    echo "이미 대상 허브: $LOCAL -> $DEST"
  else
    mkdir -p "$DEST"
    cp -rn "$OLD/." "$DEST/" 2>/dev/null || cp -r "$OLD/." "$DEST/"
    rm "$LOCAL"
    ln -s "$DEST" "$LOCAL"
    echo "허브 이관: $OLD -> $DEST"
  fi
elif [ -d "$LOCAL" ]; then
  mkdir -p "$DEST"
  cp -rn "$LOCAL/." "$DEST/" 2>/dev/null || cp -r "$LOCAL/." "$DEST/"
  rm -rf "$LOCAL"
  ln -s "$DEST" "$LOCAL"
  echo "로컬 편입: $LOCAL -> $DEST"
else
  mkdir -p "$DEST"
  mkdir -p "$(dirname "$LOCAL")"
  ln -s "$DEST" "$LOCAL"
  echo "신규 배선: $LOCAL -> $DEST"
fi

# 서버 기본 허브 영속 (~/.claude/devkit.json)
python3 - "$NEW_HUB" <<'PYEOF'
import json, os, sys
cfg = os.path.expanduser("~/.claude/devkit.json")
d = {}
if os.path.exists(cfg):
    try:
        d = json.load(open(cfg))
    except Exception:
        d = {}
d["sessions_hub"] = sys.argv[1]
os.makedirs(os.path.dirname(cfg), exist_ok=True)
json.dump(d, open(cfg, "w"), indent=2, ensure_ascii=False)
print(f"서버 기본 허브 영속: {cfg} sessions_hub={sys.argv[1]}")
PYEOF

echo "timeline 재병합..."
python3 "$PROJ_DIR/scripts/stitch-timeline.py"
