#!/usr/bin/env bash
# session-hub.sh — 서버 세션 허브 조회/설정.
#
#   bash scripts/session-hub.sh              # 현재 허브 해석 상태 출력
#   bash scripts/session-hub.sh <경로>       # 허브 생성 + 서버 기본값 영속
#                                            # (+ devkit 프로젝트 안이면 그 프로젝트 즉시 이관)
#
# 해석 순서: env DEVKIT_SESSIONS_HUB > ~/.claude/devkit.json sessions_hub
#            > 기본 ~/.claude/sessions-hub
set -euo pipefail

CFG="$HOME/.claude/devkit.json"

resolve_hub() {
  if [ -n "${DEVKIT_SESSIONS_HUB:-}" ]; then echo "$DEVKIT_SESSIONS_HUB (source: env)"; return; fi
  if [ -f "$CFG" ]; then
    local hub
    hub=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('sessions_hub',''))" "$CFG" 2>/dev/null || true)
    [ -n "$hub" ] && { echo "$hub (source: devkit.json)"; return; }
  fi
  echo "$HOME/.claude/sessions-hub (source: default)"
}

if [ $# -eq 0 ]; then
  # ---- 조회 모드 ----
  R="$(resolve_hub)"
  HUB="${R%% (*}"
  echo "sessions hub: $R"
  if [ -d "$HUB" ]; then
    echo "projects:"
    for d in "$HUB"/*/; do
      [ -d "$d" ] || continue
      n=$(find "$d" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
      tl=$([ -f "$d/timeline.md" ] && echo "timeline ✓" || echo "timeline ✗")
      echo "  $(basename "$d"): 세션 ${n}개, $tl"
    done
  else
    echo "(아직 생성 안 됨 — 첫 devkit init 또는 'session-hub.sh <경로>' 가 생성)"
  fi
  exit 0
fi

# ---- 설정 모드 ----
NEW_HUB="$(mkdir -p "$1" && cd "$1" && pwd)"

python3 - "$NEW_HUB" <<'PYEOF'
import json, os, sys
cfg = os.path.expanduser("~/.claude/devkit.json")
d = {}
if os.path.exists(cfg):
    try:
        d = json.load(open(cfg))
    except Exception:
        d = {}
old = d.get("sessions_hub")
d["sessions_hub"] = sys.argv[1]
os.makedirs(os.path.dirname(cfg), exist_ok=True)
json.dump(d, open(cfg, "w"), indent=2, ensure_ascii=False)
print(f"서버 기본 허브 영속: {sys.argv[1]}")
if old and old != sys.argv[1] and os.path.isdir(old):
    projs = [p for p in os.listdir(old) if os.path.isdir(os.path.join(old, p))]
    if projs:
        print(f"[주의] 옛 허브({old})에 프로젝트 {len(projs)}개 잔존: {', '.join(projs)}")
        print("       각 프로젝트에서 'bash scripts/adopt-sessions-hub.sh <새경로>' 로 이관하세요.")
PYEOF

# devkit 프로젝트 안에서 실행됐으면 현 프로젝트 즉시 이관
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="${CLAUDE_PROJECT_DIR:-$HERE}"
if [ -e "$PROJ/.agents" ] && [ -f "$PROJ/scripts/adopt-sessions-hub.sh" ]; then
  echo "현재 프로젝트($(basename "$PROJ")) 이관..."
  CLAUDE_PROJECT_DIR="$PROJ" bash "$PROJ/scripts/adopt-sessions-hub.sh" "$NEW_HUB"
fi
