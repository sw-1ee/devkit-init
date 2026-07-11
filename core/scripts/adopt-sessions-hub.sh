#!/usr/bin/env bash
# adopt-sessions-hub.sh — 이 프로젝트의 세션을 지정 허브로 이관 + 서버 기본값 영속.
#
#   bash scripts/adopt-sessions-hub.sh <허브경로>
#
# 처리:
#   1. 현 .agents/sessions (로컬 폴더든, 옛 허브 심링크든) 내용을 새 허브로 이관
#   2. .agents/sessions -> <새허브>/<프로젝트명> 링크 전환 (Windows = NTFS junction)
#   3. ~/.claude/devkit.json 의 sessions_hub 갱신 — 이후 이 서버의 모든
#      devkit init 이 새 허브를 따름 (env DEVKIT_SESSIONS_HUB 는 그보다 우선)
#   4. timeline 재병합
set -euo pipefail
export PYTHONUTF8=1

[ $# -ge 1 ] || { echo "Usage: adopt-sessions-hub.sh <허브경로>"; exit 1; }
NEW_HUB="$(mkdir -p "$1" && cd "$1" && pwd)"

PROJ_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NAME="$(basename "$PROJ_DIR")"
LOCAL="$PROJ_DIR/.agents/sessions"
DEST="$NEW_HUB/$NAME"

PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then echo "ERROR: python3 (or python) not found on PATH" >&2; exit 1; fi

is_msys() { # Git Bash / MSYS2 / Cygwin 감지
  case "${OSTYPE:-}${MSYSTEM:-}" in *msys*|*cygwin*|*mingw*|*MINGW*|*MSYS*|*UCRT*) return 0 ;; esac
  return 1
}

remove_link() { # $1 링크 경로 — 링크/정션만 분리. rm -rf 는 junction 을 관통해
  # 허브 실데이터까지 삭제할 수 있으므로 금지. Windows rmdir 는 reparse point 만
  # 떼어내고, 내용물 있는 실디렉토리면 실패한다(=안전 신호).
  if is_msys && command -v cygpath >/dev/null 2>&1; then
    cmd //c rmdir "$(cygpath -w "$1")" >/dev/null 2>&1 && return 0
  fi
  rm -f "$1" 2>/dev/null || rmdir "$1" 2>/dev/null || true
}

make_link() { # $1 링크, $2 대상 — 생성 후 python 왕복 검증(실소비자 기준). 0 = 성공
  if is_msys; then
    # MSYS 의 ln -s 는 기본이 복사라 신뢰 불가 — NTFS junction 으로 배선.
    command -v cygpath >/dev/null 2>&1 || return 1
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
      cmd //c mklink //J "$(cygpath -w "$1")" "$(cygpath -w "$2")" >/dev/null 2>&1 || :
  else
    ln -s "$2" "$1" 2>/dev/null || :
  fi
  [ -e "$1" ] || return 1
  "$PY" - "$1" "$2" <<'PYEOF'
import os, sys
link, hub = sys.argv[1], sys.argv[2]
p_link = os.path.join(link, ".devkit-probe")
p_hub = os.path.join(hub, ".devkit-probe")
ok = False
try:
    with open(p_link, "w", encoding="utf-8") as f:
        f.write("ok")
    ok = os.path.isfile(p_hub)
except OSError:
    ok = False
finally:
    for p in (p_link, p_hub):
        try:
            os.remove(p)
        except OSError:
            pass
sys.exit(0 if ok else 1)
PYEOF
}

relink() { # $1 = 안내 라벨 — LOCAL 을 DEST 링크로 전환 (실패 시 로컬 폴더 유지)
  if make_link "$LOCAL" "$DEST"; then
    echo "$1: $LOCAL -> $DEST"
  else
    remove_link "$LOCAL"
    mkdir -p "$LOCAL"
    echo "[warn] 링크 생성 실패 — 데이터는 허브($DEST)에 이관됐고 $LOCAL 은 로컬 폴더로 유지됩니다." >&2
    exit 1
  fi
}

# 이전 실패가 남긴 깨진 링크 정리 (깨진 링크는 -e 가 false)
if [ -L "$LOCAL" ] && [ ! -e "$LOCAL" ]; then
  remove_link "$LOCAL"
fi

if [ -L "$LOCAL" ]; then
  OLD="$(readlink -f "$LOCAL" 2>/dev/null || readlink "$LOCAL")"
  if [ "$OLD" = "$DEST" ]; then
    echo "이미 대상 허브: $LOCAL -> $DEST"
  else
    mkdir -p "$DEST"
    cp -rn "$OLD/." "$DEST/" 2>/dev/null || cp -r "$OLD/." "$DEST/"
    remove_link "$LOCAL"
    relink "허브 이관"
  fi
elif [ -d "$LOCAL" ]; then
  mkdir -p "$DEST"
  cp -rn "$LOCAL/." "$DEST/" 2>/dev/null || cp -r "$LOCAL/." "$DEST/"
  # junction 이 -d 로만 보이는 환경 대비: 먼저 reparse 분리 시도,
  # 그래도 남아 있으면 그때만 실디렉토리로 판단해 삭제.
  remove_link "$LOCAL"
  if [ -e "$LOCAL" ]; then rm -rf "$LOCAL"; fi
  relink "로컬 편입"
else
  mkdir -p "$DEST"
  mkdir -p "$(dirname "$LOCAL")"
  relink "신규 배선"
fi

# 서버 기본 허브 영속 (~/.claude/devkit.json)
"$PY" - "$NEW_HUB" <<'PYEOF'
import json, os, sys
cfg = os.path.expanduser("~/.claude/devkit.json")
d = {}
if os.path.exists(cfg):
    try:
        with open(cfg, encoding="utf-8-sig") as f:
            d = json.load(f)
    except Exception:
        d = {}
d["sessions_hub"] = sys.argv[1]
os.makedirs(os.path.dirname(cfg), exist_ok=True)
with open(cfg, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
print(f"서버 기본 허브 영속: {cfg} sessions_hub={sys.argv[1]}")
PYEOF

echo "timeline 재병합..."
"$PY" "$PROJ_DIR/scripts/stitch-timeline.py"
