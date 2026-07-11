#!/bin/bash
# SessionStart hook: 직전 JSONL 중 conversation_log.md 누락 건 감지.
# 누락 있으면 자동 extract + Claude 컨텍스트에 회복 권고 주입.

set +e
export PYTHONUTF8=1   # 비-UTF8 로케일(Windows cp949 등)에서 stdin/파일 인코딩 고정

PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$PROJ_DIR" || exit 0

PY="$(command -v python3 || command -v python)"
[ -n "$PY" ] || exit 0

# timeline 재병합 — 크래시로 마지막 Stop stitch 누락됐어도 세션 시작 시 복구
"$PY" "$PROJ_DIR/scripts/stitch-timeline.py" >/dev/null 2>&1

# stdin JSON: 현재 session_id(자기 자신 skip) + transcript_path → JSONL 디렉토리.
# SessionStart 시점엔 transcript 파일이 아직 없을 수 있어 디렉토리만 쓴다.
# dirname 은 python 에서 처리 — 백슬래시(C:\...) 경로엔 shell dirname 이 무력.
{ IFS= read -r current; IFS= read -r jsonl_dir; } < <("$PY" -c '
import sys, json, re
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
t = d.get("transcript_path", "") or ""
print(d.get("session_id", "") or "")
print(re.sub(r"[\\/][^\\/]*$", "", t) if t else "")' 2>/dev/null)

if [ -n "$jsonl_dir" ] && command -v cygpath >/dev/null 2>&1; then
  jsonl_dir="$(cygpath -u "$jsonl_dir" 2>/dev/null || printf '%s' "$jsonl_dir")"
fi
if [ -z "$jsonl_dir" ] || [ ! -d "$jsonl_dir" ]; then
  # 폴백(transcript_path 미제공 환경): sanitize 재구성.
  # Claude Code 룰 = 경로의 비영숫자 전부 '-' 치환.
  sanitized=$(printf '%s' "$PROJ_DIR" | sed 's/[^A-Za-z0-9]/-/g')
  jsonl_dir="$HOME/.claude/projects/${sanitized}"
fi
[ -d "$jsonl_dir" ] || exit 0

orphans=""
# 최근 5개 JSONL 검사 (그 이전은 archive 가정) — 공백 경로 안전한 줄단위 read
while IFS= read -r jsonl; do
  [ -n "$jsonl" ] || continue
  uuid=$(basename "$jsonl" .jsonl)
  [ "$uuid" = "$current" ] && continue
  # 이미 conversation_log.md 에 이 session_id 가 등재되어 있나
  if ! grep -lr "session.*: $uuid" .agents/sessions/ >/dev/null 2>&1; then
    bash "$PROJ_DIR/scripts/extract-session.sh" "$jsonl" >/dev/null 2>&1 \
      && orphans="$orphans $uuid"
  fi
done < <(ls -t "$jsonl_dir"/*.jsonl 2>/dev/null | head -5)

if [ -n "$orphans" ]; then
  msg="[세션 회복] 직전 종료절차 미수행 JSONL 감지 → conversation_log.md 자동 생성 완료:$orphans. 해당 세션 작업이 CLAUDE.md ## Current State 에 반영됐는지 확인하고, 미반영이면 회복 작업 수행."
  "$PY" -c "import json,sys; print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':sys.argv[1]}}))" "$msg"
fi

exit 0
