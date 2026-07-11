#!/usr/bin/env bash
# install.sh — devkit-init bootstrapper.
# Drop this pack into reach, run in an empty (or existing) project dir:
#
#   bash /path/to/pack/install.sh [TARGET_DIR] [--domain web] [--mode prototyper | --stage pre-pmf] [--lang ko|en] [--force] [--update]
#
# Axes:
#   --domain  what you build (stack)  : web | ai | mobile | cli | data | desktop | _generic
#   --mode    how you work (archetype): prototyper | builder | sweeper | grower | maintainer
#   --stage   preset (archetype mix)  : pre-pmf | growing | mature   (alternative to --mode)
#   --update  refresh pack-owned core runtime (hooks/scripts/verifier) on an EXISTING install;
#             never touches CLAUDE.md / MEMORY.md / domain agents / skills. settings hooks are
#             upgraded in place (old command strings superseded, no duplicates).
#
# Layers installed (in order):
#   1. core/    — session-continuity engine (hooks, extract-session, charter, verifier)  [always]
#   2. domains/ — one harness team seed (.claude/agents + team skills + domain charter)  [if wired]
#   3. modes/   — archetype personality profile (charter rules + active skill set)       [if wired]
#
# Idempotent: re-running skips existing files and merges settings hooks by command string.

set -Eeuo pipefail
trap 'echo "[FAIL] install.sh line $LINENO: $BASH_COMMAND" >&2' ERR

# 한국어 Windows 등 비-UTF8 로케일에서 python 기본 인코딩(cp949 등)이
# 팩의 UTF-8 파일을 깨뜨리지 않게 강제. (각 open() 의 encoding 명시와 이중 방어)
export PYTHONUTF8=1

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ---------------------------------------------- preflight: python
# Git for Windows 는 python 을 포함하지 않고, python.org 설치본은 python3 별칭이
# 없다. 실행 가능한 인터프리터를 찾는다 (MS Store 스텁은 -c 실행 실패로 걸러짐).
PY=""
for _p in python3 python; do
  if command -v "$_p" >/dev/null 2>&1 && "$_p" -c "import sys" >/dev/null 2>&1; then
    PY="$_p"; break
  fi
done
if [ -z "$PY" ]; then
  echo "ERROR: python3 (또는 python) 을 PATH 에서 찾을 수 없습니다." >&2
  echo "  Windows: winget install Python.Python.3 후 새 터미널에서 재실행하세요." >&2
  echo "  (Git Bash 자체에는 python 이 포함되어 있지 않습니다.)" >&2
  exit 1
fi

# ---------------------------------------------- preflight: 팩 무결성
# 부분 추출(대개 'curl … | tar xz' 파이프 중단) 감지. core/ 는 tar 뒤쪽이라
# 스트림이 끊기면 앞쪽 modes/·install.sh 만 풀리고 core 가 빠진다.
_missing=""
for _d in core domains modes skills mcp; do
  [ -d "$KIT_DIR/$_d" ] || _missing="$_missing $_d"
done
if [ -n "$_missing" ]; then
  echo "ERROR: 불완전한 팩 — 누락 디렉토리:$_missing" >&2
  echo "  대개 'curl … | tar xz' 파이프 중단으로 인한 부분 추출입니다." >&2
  echo "  tar 를 먼저 파일로 받아 무결성 확인 후 풀어 주세요:" >&2
  echo "    curl -L -o devkit.tar.gz <release-url>" >&2
  echo "    tar xzf devkit.tar.gz -C devkit   # 손상 시 tar 가 에러로 멈춤" >&2
  echo "    bash devkit/install.sh <target> --domain <d> --stage <s>" >&2
  exit 1
fi

# ---------------------------------------------------------------- args
TARGET=""
DOMAIN=""
MODE=""
STAGE=""
LANG_CHOICE="ko"
FORCE=0
UPDATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --mode)   MODE="$2"; shift 2 ;;
    --stage)  STAGE="$2"; shift 2 ;;
    --lang)   LANG_CHOICE="$2"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    --update) UPDATE=1; shift ;;
    -h|--help)
      { grep '^#' "$0" | head -25; } || true; exit 0 ;;
    *)
      if [ -z "$TARGET" ]; then TARGET="$1"; shift; else echo "Unknown arg: $1" >&2; exit 1; fi ;;
  esac
done

TARGET="${TARGET:-$(pwd)}"
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

# 팩 안으로의 설치만 거부 (물리 경로 비교 — 심링크 별칭 오판 방지).
# 반대 방향(팩이 타겟 하위 = repo 를 프로젝트 안에 클론한 자연 플로우)은 허용:
# 설치는 팩→타겟 단방향 복사라 재귀가 없다.
_tgt_phys="$(cd "$TARGET" && pwd -P)"
if [ "$_tgt_phys" = "$KIT_DIR" ] || [[ "$_tgt_phys" == "$KIT_DIR"/* ]]; then
  echo "ERROR: target 이 팩 디렉토리(또는 그 하위)입니다 — 팩 안으로는 설치할 수 없습니다." >&2
  exit 1
fi
KIT_IN_TARGET=0
if [[ "$KIT_DIR" == "$_tgt_phys"/* ]]; then KIT_IN_TARGET=1; fi

if [ -n "$MODE" ] && [ -n "$STAGE" ]; then
  echo "ERROR: pass --mode OR --stage, not both." >&2; exit 1
fi

# ------------------------------------------------------- interactive
ask() { # $1 prompt, $2 options csv -> echo answer
  local ans
  echo "" >&2
  echo "$1" >&2
  echo "  options: $2" >&2
  read -r -p "> " ans
  echo "$ans"
}

if [ "$UPDATE" -ne 1 ]; then
  if [ -z "$DOMAIN" ] && [ -t 0 ]; then
    DOMAIN="$(ask 'Project domain? (what you build)' 'web / ai / mobile / cli / data / desktop / _generic')"
  fi
  DOMAIN="${DOMAIN:-_generic}"

  if [ -z "$MODE" ] && [ -z "$STAGE" ] && [ -t 0 ]; then
    STAGE="$(ask 'Product stage? (how you work — archetype preset)' 'pre-pmf / growing / mature  (or: proto typer/builder/sweeper/grower/maintainer via --mode)')"
  fi
fi
STAGE="${STAGE:-}"
MODE_LABEL="${MODE:-${STAGE:-none}}"
[ "$UPDATE" -eq 1 ] && MODE_LABEL="(--update: core runtime refresh)"

echo "═══════════════════════════════════════════════════"
echo "  devkit-init installer"
echo "═══════════════════════════════════════════════════"
echo "  Pack:   $KIT_DIR"
echo "  Target: $TARGET"
if [ "$UPDATE" -eq 1 ]; then
  echo "  Mode:   --update (hooks/scripts/verifier 갱신 + settings 업그레이드만)"
else
  echo "  Domain: $DOMAIN   Mode/Stage: $MODE_LABEL   Lang: $LANG_CHOICE"
fi
echo ""
if [ "$KIT_IN_TARGET" -eq 1 ]; then
  echo "  [note] 팩 디렉토리가 타겟 안에 있습니다 (${KIT_DIR#$_tgt_phys/})."
  echo "         설치 후 삭제하거나 .gitignore 에 추가해도 됩니다."
  echo ""
fi

# non-empty guard (core files may coexist; only warn hard when no --force and target has a CLAUDE.md already)
if [ "$UPDATE" -ne 1 ] && [ -f "$TARGET/CLAUDE.md" ] && [ "$FORCE" -ne 1 ]; then
  echo "  [note] CLAUDE.md already exists — existing files are kept, new ones added, settings merged."
fi

mkdir -p "$TARGET/.claude/hooks" "$TARGET/.claude/agents" "$TARGET/.claude/skills" \
         "$TARGET/scripts" "$TARGET/.agents"

# 세션 대화 허브 배선 — 허브는 항상 존재한다 (경로 하드코딩 없음).
# 해석 순서: (1) env DEVKIT_SESSIONS_HUB  (2) ~/.claude/devkit.json 의 sessions_hub
#            (3) 기본 = ~/.claude/sessions-hub (어느 서버든 존재하는 전역 클로드 폴더)
# 추후 이관: scripts/adopt-sessions-hub.sh <새경로>
resolve_hub() {
  if [ -n "${DEVKIT_SESSIONS_HUB:-}" ]; then echo "$DEVKIT_SESSIONS_HUB"; return; fi
  local cfg="$HOME/.claude/devkit.json" hub=""
  if [ -f "$cfg" ]; then
    hub=$("$PY" -c "import json,sys; print(json.load(open(sys.argv[1], encoding='utf-8-sig')).get('sessions_hub',''))" "$cfg" 2>/dev/null || true)
    [ -n "$hub" ] && { echo "$hub"; return; }
  fi
  echo "$HOME/.claude/sessions-hub"
}

is_msys() { # Git Bash / MSYS2 / Cygwin 감지
  case "${OSTYPE:-}${MSYSTEM:-}" in *msys*|*cygwin*|*mingw*|*MINGW*|*MSYS*|*UCRT*) return 0 ;; esac
  return 1
}

remove_link() { # $1 링크 경로 — 링크/정션만 분리. 실데이터 관통 삭제(rm -rf) 금지.
  if is_msys && command -v cygpath >/dev/null 2>&1; then
    # Windows: rmdir 는 junction/reparse point 만 떼어낸다. 내용물 있는 실디렉토리면 실패(=안전).
    cmd //c rmdir "$(cygpath -w "$1")" >/dev/null 2>&1 && return 0
  fi
  rm -f "$1" 2>/dev/null || rmdir "$1" 2>/dev/null || true
}

probe_link() { # $1 링크, $2 허브 실경로 — 왕복 검증. 실소비자(python)로 수행:
  # bash 는 통과하지만 native python 이 못 따라가는 링크 유형이 있다.
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

link_sessions_hub() { # $1 링크 경로, $2 허브 디렉토리 -> 0 = 왕복 검증 통과
  if is_msys; then
    # MSYS 의 ln -s 는 기본이 복사라 신뢰 불가 — NTFS junction 으로 배선.
    # (junction 은 OneDrive 클라우드 동기화도 타지 않는다.)
    command -v cygpath >/dev/null 2>&1 || return 1
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
      cmd //c mklink //J "$(cygpath -w "$1")" "$(cygpath -w "$2")" >/dev/null 2>&1 || :
  else
    ln -s "$2" "$1" 2>/dev/null || :
  fi
  if [ -e "$1" ] && probe_link "$1" "$2"; then return 0; fi
  remove_link "$1"
  return 1
}

HUB="$(resolve_hub)"
SESS="$TARGET/.agents/sessions"
# 이전 실패 설치가 남긴 깨진 링크 정리 (깨진 링크는 -e 가 false)
if [ -L "$SESS" ] && [ ! -e "$SESS" ]; then remove_link "$SESS"; fi
if [ ! -e "$SESS" ]; then
  if mkdir -p "$HUB/$(basename "$TARGET")" 2>/dev/null \
     && link_sessions_hub "$SESS" "$HUB/$(basename "$TARGET")"; then
    echo "  [ok]   .agents/sessions -> sessions hub ($HUB/$(basename "$TARGET"))"
  else
    mkdir -p "$SESS"   # 최후 안전망 (허브 쓰기 불가 / 링크 불가 환경)
    echo "  [warn] sessions hub 링크 실패 ($HUB) — 로컬 폴더로 대체; 이후 scripts/adopt-sessions-hub.sh 로 이관 가능"
  fi
fi

copied=0; skipped=0; updated=0; baks=0
install_file() { # $1 src, $2 dst, $3 executable(0/1)
  if [ -f "$2" ]; then echo "  [skip] ${2#$TARGET/}"; skipped=$((skipped+1)); return 0; fi
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  [ "${3:-0}" = "1" ] && chmod +x "$2"
  echo "  [ok]   ${2#$TARGET/}"; copied=$((copied+1))
}

# --update 전용: 팩 소유 런타임 갱신. 내용 동일 = skip(멱등), 다르면 기존본 .bak 후 교체.
update_file() { # $1 src, $2 dst, $3 executable(0/1)
  if [ ! -f "$2" ]; then install_file "$@"; return 0; fi
  if cmp -s "$1" "$2"; then echo "  [skip] ${2#$TARGET/} (up-to-date)"; skipped=$((skipped+1)); return 0; fi
  cp "$2" "$2.bak"; baks=$((baks+1))
  cp "$1" "$2"
  [ "${3:-0}" = "1" ] && chmod +x "$2"
  echo "  [updated] ${2#$TARGET/} (이전본 → .bak)"; updated=$((updated+1))
}

core_file() { # 팩 소유 core 런타임 파일 설치/갱신 분기
  if [ "$UPDATE" -eq 1 ]; then update_file "$@"; else install_file "$@"; fi
}

# ---------------------------------------------------------- 1) CORE
echo "── core (session continuity) ──"
for f in auto-extract-session.sh session-start-recover.sh session-end-reminder.sh; do
  core_file "$KIT_DIR/core/hooks/$f" "$TARGET/.claude/hooks/$f" 1
done
core_file "$KIT_DIR/core/scripts/extract-session.sh" "$TARGET/scripts/extract-session.sh" 1
core_file "$KIT_DIR/core/scripts/stitch-timeline.py" "$TARGET/scripts/stitch-timeline.py" 1
core_file "$KIT_DIR/core/scripts/adopt-sessions-hub.sh" "$TARGET/scripts/adopt-sessions-hub.sh" 1
core_file "$KIT_DIR/core/scripts/session-hub.sh" "$TARGET/scripts/session-hub.sh" 1
core_file "$KIT_DIR/core/agents/verifier.md" "$TARGET/.claude/agents/verifier.md"

if [ "$UPDATE" -ne 1 ]; then
  install_file "$KIT_DIR/mcp/.mcp.json.template" "$TARGET/.mcp.json.template"

  # MEMORY.md (python 치환 — sed 는 프로젝트명의 &/구분자 메타문자에 오염됨)
  if [ ! -f "$TARGET/MEMORY.md" ]; then
    "$PY" - "$KIT_DIR/core/MEMORY.md.template" "$TARGET/MEMORY.md" "$(basename "$TARGET")" <<'PYEOF'
import os, sys
tpl, dst, name = sys.argv[1:4]
with open(tpl, encoding='utf-8') as f:
    t = f.read()
tmp = dst + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(t.replace('{{PROJECT_NAME}}', name))
os.replace(tmp, dst)
PYEOF
    echo "  [ok]   MEMORY.md"; copied=$((copied+1))
  else
    echo "  [skip] MEMORY.md"; skipped=$((skipped+1))
  fi
fi

# ------------------------------------------------------ 2) DOMAIN seed
DOMAIN_CLAUDE=""
if [ "$UPDATE" -ne 1 ]; then
  DOMAIN_DIR="$KIT_DIR/domains/$DOMAIN"
  if [ -d "$DOMAIN_DIR/team/.claude" ]; then
    echo "── domain seed: $DOMAIN ──"
    # agents
    if [ -d "$DOMAIN_DIR/team/.claude/agents" ]; then
      for f in "$DOMAIN_DIR/team/.claude/agents/"*.md; do
        [ -e "$f" ] || continue
        install_file "$f" "$TARGET/.claude/agents/$(basename "$f")"
      done
    fi
    # team skills (playbooks)
    if [ -d "$DOMAIN_DIR/team/.claude/skills" ]; then
      while IFS= read -r -d '' sk; do
        rel="${sk#$DOMAIN_DIR/team/.claude/skills/}"
        install_file "$sk" "$TARGET/.claude/skills/$rel"
      done < <(find "$DOMAIN_DIR/team/.claude/skills" -type f -print0)
    fi
    [ -f "$DOMAIN_DIR/team/.claude/CLAUDE.md" ] && DOMAIN_CLAUDE="$DOMAIN_DIR/team/.claude/CLAUDE.md"
  else
    echo "── domain seed: $DOMAIN — not wired in this pack build (skipping; core still installs) ──"
  fi
fi

# ------------------------------------------------------ 3) MODE profile
MODE_SKILL_CATS=""
MODE_RULES_FILES=()
resolve_mode_files() { # $1 = archetype name -> appends
  local d="$KIT_DIR/modes/$1"
  if [ -f "$d/CLAUDE.mode.md" ]; then MODE_RULES_FILES+=("$d/CLAUDE.mode.md"); fi
  if [ -f "$d/skills.list" ]; then
    MODE_SKILL_CATS="$MODE_SKILL_CATS $(grep -v '^#' "$d/skills.list" | tr '\n' ' ')"
  fi
}
if [ "$UPDATE" -ne 1 ]; then
  if [ -n "$MODE" ] && [ -d "$KIT_DIR/modes/$MODE" ]; then
    echo "── mode: $MODE ──"
    resolve_mode_files "$MODE"
  elif [ -n "$STAGE" ] && [ -f "$KIT_DIR/modes/presets/$STAGE.json" ]; then
    echo "── stage preset: $STAGE ──"
    for m in $("$PY" -c "import json,sys; print(' '.join(a.split(':')[0] for a in json.load(open(sys.argv[1], encoding='utf-8-sig'))['archetypes']))" "$KIT_DIR/modes/presets/$STAGE.json"); do
      resolve_mode_files "$m"
    done
  elif [ "$MODE_LABEL" != "none" ]; then
    echo "── mode/stage '$MODE_LABEL' — not wired in this pack build (skipping) ──"
  fi
fi

# skill category bundles selected by mode (dedup).
# NOTE: categories are pack-side organization only — Claude Code discovers skills
# at .claude/skills/<name>/SKILL.md (one level), so we FLATTEN on install.
if [ -n "$MODE_SKILL_CATS" ]; then
  for cat in $(echo "$MODE_SKILL_CATS" | tr ' ' '\n' | sort -u); do
    [ -d "$KIT_DIR/skills/$cat" ] || continue
    while IFS= read -r -d '' sk; do
      rel="${sk#$KIT_DIR/skills/$cat/}"
      install_file "$sk" "$TARGET/.claude/skills/$rel"
    done < <(find "$KIT_DIR/skills/$cat" -type f -not -path "*/_raw/*" -not -path "*/sessions/*" -print0)
  done
fi

# ------------------------------------------------ 4) CLAUDE.md assembly
if [ "$UPDATE" -ne 1 ] && [ ! -f "$TARGET/CLAUDE.md" ]; then
  # 배열 확장: [@]+ 관용구 — 빈 배열이면 인자 0개 (":-" 는 빈 인자 1개를 만든다)
  "$PY" - "$KIT_DIR" "$TARGET" "$DOMAIN" "$MODE_LABEL" "$DOMAIN_CLAUDE" \
    ${MODE_RULES_FILES[@]+"${MODE_RULES_FILES[@]}"} <<'PYEOF'
import sys, os
kit, target, domain, mode_label = sys.argv[1:5]
domain_claude = sys.argv[5]
mode_files = [a for a in sys.argv[6:] if a]

with open(os.path.join(kit, 'core', 'CLAUDE.core.md.template'), encoding='utf-8') as f:
    tpl = f.read()

mode_rules = []
for mf in mode_files:
    with open(mf, encoding='utf-8') as f:
        mode_rules.append(f.read().strip())
mode_block = "\n\n".join(mode_rules) if mode_rules else "(모드 미지정 — 필요 시 `bash install.sh --mode <archetype>` 재실행으로 주입)"

out = (tpl
       .replace('{{PROJECT_NAME}}', os.path.basename(target))
       .replace('{{DOMAIN}}', domain)
       .replace('{{MODE}}', mode_label)
       .replace('{{MODE_RULES}}', mode_block))

if domain_claude:
    with open(domain_claude, encoding='utf-8') as f:
        dom = f.read().strip()
    out += "\n\n---\n\n# Domain Charter — " + domain + "\n\n" + dom + "\n"

# atomic write — 조립 중 사망 시 부분 CLAUDE.md 가 남아 재실행이 skip 하는 사고 방지
dst = os.path.join(target, 'CLAUDE.md')
tmp = dst + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(out)
os.replace(tmp, dst)
print("  [ok]   CLAUDE.md assembled (core" + (" + domain" if domain_claude else "") + (" + mode" if mode_rules else "") + ")")
PYEOF
  copied=$((copied+1))
elif [ "$UPDATE" -ne 1 ]; then
  echo "  [skip] CLAUDE.md (exists — merge sections manually from $KIT_DIR/core/CLAUDE.core.md.template)"
  skipped=$((skipped+1))
fi

# --------------------------------------------- 5) settings.json merge
dst="$TARGET/.claude/settings.json"
if [ -f "$dst" ]; then
  "$PY" - "$KIT_DIR/core/settings.core.json.fragment" "$dst" <<'PYEOF'
import json, os, sys
frag_path, dst_path = sys.argv[1], sys.argv[2]
with open(frag_path, encoding='utf-8-sig') as f:
    frag = json.load(f)
frag.pop('_README', None)
with open(dst_path, encoding='utf-8-sig') as f:
    cur = json.load(f)
cur.setdefault('hooks', {})

# (1) supersede — 구버전 팩이 등록한 명령 문자열을 신버전으로 정확일치 교체.
#     사용자가 커스텀한 명령은 문자열이 달라 일치하지 않으므로 건드리지 않는다.
_P = '${CLAUDE_PROJECT_DIR}'
SUPERSEDE = {
    'bash ' + _P + '/.claude/hooks/auto-extract-session.sh':
        'bash "' + _P + '/.claude/hooks/auto-extract-session.sh"',
    'bash ' + _P + '/.claude/hooks/session-start-recover.sh':
        'bash "' + _P + '/.claude/hooks/session-start-recover.sh"',
    'bash ' + _P + '/.claude/hooks/session-end-reminder.sh':
        'bash "' + _P + '/.claude/hooks/session-end-reminder.sh"',
    'cd ' + _P + ' && dirty=$(git status --short 2>/dev/null | wc -l); if [ "$dirty" -gt 0 ]; then echo "SESSION END CHECK: $dirty uncommitted file(s). Run \'git status\' and decide: commit now or explicitly defer as WIP."; fi':
        'cd "' + _P + '" && dirty=$(git status --short 2>/dev/null | wc -l); if [ "$dirty" -gt 0 ]; then echo "SESSION END CHECK: $dirty uncommitted file(s). Run \'git status\' and decide: commit now or explicitly defer as WIP."; fi',
}
for ev, blocks in cur['hooks'].items():
    for blk in blocks:
        for h in blk.get('hooks', []):
            if h.get('command', '') in SUPERSEDE:
                h['command'] = SUPERSEDE[h['command']]

# (2) dedupe — supersede 로 (또는 과거 수동 패치로) 같은 명령이 중복되면 첫 것만 유지
for ev, blocks in cur['hooks'].items():
    seen = set()
    new_blocks = []
    for blk in blocks:
        kept = []
        for h in blk.get('hooks', []):
            c = h.get('command', '')
            if c in seen:
                continue
            seen.add(c)
            kept.append(h)
        if kept:
            new_blocks.append({**blk, 'hooks': kept})
        elif not blk.get('hooks'):
            new_blocks.append(blk)   # hooks 없는 이질 블록은 보존
    cur['hooks'][ev] = new_blocks

# (3) merge — fragment 의 신규 명령만 추가
added = 0
for ev, blocks in frag.get('hooks', {}).items():
    cur['hooks'].setdefault(ev, [])
    existing_cmds = {h.get('command','')
                     for blk in cur['hooks'][ev]
                     for h in blk.get('hooks', [])}
    for blk in blocks:
        new_hooks = [h for h in blk.get('hooks', [])
                     if h.get('command','') not in existing_cmds]
        if new_hooks:
            cur['hooks'][ev].append({**blk, 'hooks': new_hooks})
            added += len(new_hooks)

tmp = dst_path + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(cur, f, indent=2, ensure_ascii=False)
os.replace(tmp, dst_path)
print(f"  [merged] .claude/settings.json ({added} new hook command(s))")
PYEOF
else
  "$PY" - "$KIT_DIR/core/settings.core.json.fragment" "$dst" <<'PYEOF'
import json, os, sys
with open(sys.argv[1], encoding='utf-8-sig') as f:
    d = json.load(f)
d.pop('_README', None)
tmp = sys.argv[2] + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
os.replace(tmp, sys.argv[2])
print("  [ok]   .claude/settings.json created")
PYEOF
  copied=$((copied+1))
fi

# ---------------------------------------------------------- summary
echo ""
echo "═══════════════════════════════════════════════════"
if [ "$UPDATE" -eq 1 ]; then
  echo "  devkit-init update complete: $updated updated ($baks backup), $copied installed, $skipped up-to-date."
else
  echo "  devkit-init complete: $copied installed, $skipped kept."
fi
echo ""
echo "  Next:"
echo "    1) Restart Claude Code (or start a new session) in $TARGET"
echo "    2) Verify hooks:  bash -n .claude/hooks/*.sh"
if [ "$UPDATE" -ne 1 ]; then
  echo "    3) Open CLAUDE.md — fill '## Current State' on first session"
  echo "    4) Need MCP? copy .mcp.json.template → .mcp.json and add servers"
fi
echo "═══════════════════════════════════════════════════"
