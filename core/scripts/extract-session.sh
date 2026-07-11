#!/usr/bin/env bash
# extract-session.sh — JSONL transcript → conversation_log.md
# Usage: ./scripts/extract-session.sh [jsonl_path] [output_dir]
#   jsonl_path: defaults to most recent JSONL in the project's Claude Code transcript dir
#   output_dir: defaults to .agents/sessions/{auto-generated}/

set -euo pipefail
export PYTHONUTF8=1   # 비-UTF8 로케일(Windows cp949 등)에서 파일 인코딩 고정

# Project root 자동 감지: CLAUDE_PROJECT_DIR 우선, 폴백은 스크립트 위치 기준.
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then echo "ERROR: python3 (or python) not found on PATH" >&2; exit 1; fi

# JSONL 디렉토리 추정 — Claude Code sanitize 룰 = 경로의 비영숫자 전부 '-'.
# Windows(Git Bash)에선 같은 경로가 유닉스형(/c/...)과 네이티브형(C:/...) 둘로
# 표현되고 HOME ≠ USERPROFILE 일 수 있어, 후보를 만들어 존재하는 것을 쓴다.
find_jsonl_dir() {
  local bases=("$HOME/.claude/projects") paths=("$PROJ_DIR") b p s d
  if command -v cygpath >/dev/null 2>&1; then
    if [ -n "${USERPROFILE:-}" ]; then
      bases+=("$(cygpath -u "$USERPROFILE" 2>/dev/null || true)/.claude/projects")
    fi
    paths+=("$(cygpath -m "$PROJ_DIR" 2>/dev/null || true)")
  fi
  for b in "${bases[@]}"; do
    for p in "${paths[@]}"; do
      [ -n "$p" ] || continue
      s=$(printf '%s' "$p" | sed 's/[^A-Za-z0-9]/-/g')
      d="$b/$s"
      if [ -d "$d" ]; then printf '%s' "$d"; return 0; fi
    done
  done
  # 아무 후보도 없으면 1차 후보를 그대로 반환 (아래 에러 메시지용)
  printf '%s' "${bases[0]}/$(printf '%s' "$PROJ_DIR" | sed 's/[^A-Za-z0-9]/-/g')"
}
JSONL_DIR="$(find_jsonl_dir)"

jsonl_path="${1:-}"
output_dir="${2:-}"

# Find most recent JSONL if not specified
if [[ -z "$jsonl_path" ]]; then
  jsonl_path="$(ls -t "$JSONL_DIR"/*.jsonl 2>/dev/null | head -1)"
  if [[ -z "$jsonl_path" ]]; then
    echo "ERROR: No JSONL files found in $JSONL_DIR" >&2
    exit 1
  fi
fi

if [[ ! -f "$jsonl_path" ]]; then
  echo "ERROR: File not found: $jsonl_path" >&2
  exit 1
fi

session_id="$(basename "$jsonl_path" .jsonl)"

"$PY" - "$jsonl_path" "$output_dir" "$session_id" "$PROJ_DIR" << 'PYEOF'
import json
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

jsonl_path = sys.argv[1]
output_dir = sys.argv[2] if sys.argv[2] else ""
session_id = sys.argv[3]
proj_dir = sys.argv[4]

KST = timezone(timedelta(hours=9))

messages = []
first_user_msg = ""
first_timestamp = None

with open(jsonl_path, encoding="utf-8") as f:
    for line in f:
        obj = json.loads(line)
        msg_type = obj.get("type")
        ts_str = obj.get("timestamp", "")

        if ts_str:
            try:
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00")).astimezone(KST)
            except Exception:
                ts = None
        else:
            ts = None

        if msg_type == "user":
            content = obj.get("message", {}).get("content", "")
            if isinstance(content, list):
                content = "\n".join(
                    b.get("text", "") for b in content if b.get("type") == "text"
                )
            if not content.strip():
                continue
            if not first_user_msg:
                first_user_msg = content.strip()[:60]
                first_timestamp = ts
            messages.append(("user", ts, content.strip()))

        elif msg_type == "assistant":
            blocks = obj.get("message", {}).get("content", [])
            text_parts = []
            for b in blocks:
                if b.get("type") == "text" and b.get("text", "").strip():
                    text_parts.append(b["text"].strip())
            if text_parts:
                combined = "\n\n".join(text_parts)
                messages.append(("assistant", ts, combined))

if not messages:
    print("No user/assistant messages found in JSONL", file=sys.stderr)
    sys.exit(1)

# Determine output path
if output_dir:
    out_path = Path(output_dir) / "conversation_log.md"
else:
    if first_timestamp:
        date_prefix = first_timestamp.strftime("%Y%m%d-%H%M%S")
    else:
        date_prefix = "unknown"
    topic_slug = "".join(c if c.isalnum() or c in "-_" else "-" for c in first_user_msg[:30]).strip("-").lower()
    if not topic_slug:
        topic_slug = "session"
    session_dir_name = f"{date_prefix}-{topic_slug}"
    out_dir = Path(proj_dir) / ".agents" / "sessions" / session_dir_name
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "conversation_log.md"

out_path.parent.mkdir(parents=True, exist_ok=True)

# Build markdown
lines = []
lines.append("# Conversation Log\n")
lines.append(f"- **session**: {session_id}")
if first_timestamp:
    lines.append(f"- **started**: {first_timestamp.isoformat()}")
lines.append("- **participants**: 사용자, ai")
lines.append("- **ai_provider**: claude")
topic_short = first_user_msg[:50] if first_user_msg else "unknown"
lines.append(f"- **topic**: {topic_short}")
lines.append(f"- **source**: JSONL auto-extract")
lines.append(f"- **project**: {Path(sys.argv[4]).name}")
lines.append("")
lines.append("---")
lines.append("")

for role, ts, content in messages:
    ts_str = ts.strftime("%Y-%m-%d %H:%M:%S") if ts else "unknown"
    if role == "user":
        lines.append(f"## 사용자 ({ts_str})\n")
    else:
        lines.append(f"## ai ({ts_str})\n")

    # Truncate very long assistant responses for readability
    if role == "assistant" and len(content) > 2000:
        content = content[:2000] + "\n\n*(truncated — full text in JSONL)*"

    lines.append(content)
    lines.append("")
    lines.append("---")
    lines.append("")

out_path.write_text("\n".join(lines), encoding="utf-8")
print(f"Extracted {len(messages)} messages → {out_path}")
print(f"  Users: {sum(1 for r,_,_ in messages if r == 'user')}")
print(f"  Assistant: {sum(1 for r,_,_ in messages if r == 'assistant')}")
PYEOF
