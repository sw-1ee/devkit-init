#!/bin/bash
# Stop hook: 매 턴 종료 시 JSONL → conversation_log.md 자동 갱신.
# Claude 컨텍스트엔 안 들어감 (Stop 의 stdout 은 주입 안 됨).
# 백그라운드 실행이라 매 턴 latency 안 추가.

set +e

# Claude Code 가 PROJECT_DIR 환경변수 제공. 폴백 = 스크립트 위치 기준.
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$PROJ_DIR" || exit 0

# stdin JSON 에서 session_id 추출
session_id=$(python3 -c "import sys,json
try:
  d=json.load(sys.stdin)
  print(d.get('session_id',''))
except Exception:
  pass" 2>/dev/null)

# JSONL 디렉토리 = Claude Code 가 PROJ_DIR 의 슬래시를 dash 로 sanitize 한 형태
sanitized=$(echo "$PROJ_DIR" | sed 's|/|-|g')
JSONL_DIR="$HOME/.claude/projects/${sanitized}"

jsonl=""
if [ -n "$session_id" ]; then
  candidate="${JSONL_DIR}/${session_id}.jsonl"
  [ -f "$candidate" ] && jsonl="$candidate"
fi

# 백그라운드 실행. extract-session.sh 가 default 로 가장 최근 JSONL 사용.
( bash "$PROJ_DIR/scripts/extract-session.sh" ${jsonl:+"$jsonl"} >/dev/null 2>&1 ) &

exit 0
