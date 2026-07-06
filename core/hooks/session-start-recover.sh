#!/bin/bash
# SessionStart hook: 직전 JSONL 중 conversation_log.md 누락 건 감지.
# 누락 있으면 자동 extract + Claude 컨텍스트에 회복 권고 주입.

set +e

PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$PROJ_DIR" || exit 0

# timeline 재병합 — 크래시로 마지막 Stop stitch 누락됐어도 세션 시작 시 복구
python3 "$PROJ_DIR/scripts/stitch-timeline.py" >/dev/null 2>&1

# 현재 session_id (자기 자신 skip)
current=$(python3 -c "import sys,json
try:
  d=json.load(sys.stdin)
  print(d.get('session_id',''))
except Exception:
  pass" 2>/dev/null)

sanitized=$(echo "$PROJ_DIR" | sed 's|/|-|g')
JSONL_DIR="$HOME/.claude/projects/${sanitized}"
[ -d "$JSONL_DIR" ] || exit 0

orphans=""
# 최근 5개 JSONL 검사 (그 이전은 archive 가정)
for jsonl in $(ls -t "$JSONL_DIR"/*.jsonl 2>/dev/null | head -5); do
  uuid=$(basename "$jsonl" .jsonl)
  [ "$uuid" = "$current" ] && continue
  # 이미 conversation_log.md 에 이 session_id 가 등재되어 있나
  if ! grep -lr "session.*: $uuid" .agents/sessions/ >/dev/null 2>&1; then
    bash "$PROJ_DIR/scripts/extract-session.sh" "$jsonl" >/dev/null 2>&1 \
      && orphans="$orphans $uuid"
  fi
done

if [ -n "$orphans" ]; then
  msg="[세션 회복] 직전 종료절차 미수행 JSONL 감지 → conversation_log.md 자동 생성 완료:$orphans. 해당 세션 작업이 CLAUDE.md ## Current State 에 반영됐는지 확인하고, 미반영이면 회복 작업 수행."
  python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':sys.argv[1]}}))" "$msg"
fi

exit 0
