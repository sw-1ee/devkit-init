#!/bin/bash
# Stop hook: 매 턴 종료 시 JSONL → conversation_log.md 자동 갱신.
# Claude 컨텍스트엔 안 들어감 (Stop 의 stdout 은 주입 안 됨).
# 백그라운드 실행이라 매 턴 latency 안 추가.

set +e
export PYTHONUTF8=1   # 비-UTF8 로케일(Windows cp949 등)에서 stdin/파일 인코딩 고정

# Claude Code 가 PROJECT_DIR 환경변수 제공. 폴백 = 스크립트 위치 기준.
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$PROJ_DIR" || exit 0

PY="$(command -v python3 || command -v python)"
[ -n "$PY" ] || exit 0

# stdin JSON 에서 session_id + transcript_path(현 세션 JSONL 절대경로) 추출.
# transcript_path 를 그대로 쓰면 JSONL 위치 재구성(sanitize)이 불필요 —
# HOME 불일치·Windows 경로 형태 문제를 구조적으로 회피한다.
{ IFS= read -r session_id; IFS= read -r transcript; } < <("$PY" -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print(d.get("session_id", "") or "")
print(d.get("transcript_path", "") or "")' 2>/dev/null)

# Windows 네이티브 경로(C:\...)는 unix 형으로 정규화 (Git Bash)
if [ -n "$transcript" ] && command -v cygpath >/dev/null 2>&1; then
  transcript="$(cygpath -u "$transcript" 2>/dev/null || printf '%s' "$transcript")"
fi

jsonl=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  jsonl="$transcript"
elif [ -n "$session_id" ]; then
  # 폴백(transcript_path 미제공 환경): sanitize 재구성.
  # Claude Code 룰 = 경로의 비영숫자 전부 '-' 치환.
  sanitized=$(printf '%s' "$PROJ_DIR" | sed 's/[^A-Za-z0-9]/-/g')
  candidate="$HOME/.claude/projects/${sanitized}/${session_id}.jsonl"
  [ -f "$candidate" ] && jsonl="$candidate"
fi

# 백그라운드 실행. extract-session.sh 가 default 로 가장 최근 JSONL 사용.
( bash "$PROJ_DIR/scripts/extract-session.sh" ${jsonl:+"$jsonl"} >/dev/null 2>&1; "$PY" "$PROJ_DIR/scripts/stitch-timeline.py" >/dev/null 2>&1 ) &

exit 0
