#!/usr/bin/env bash
# install.sh — devkit-init bootstrapper.
# Drop this pack into reach, run in an empty (or existing) project dir:
#
#   bash /path/to/pack/install.sh [TARGET_DIR] [--domain web] [--mode prototyper | --stage pre-pmf] [--lang ko|en] [--force]
#
# Axes:
#   --domain  what you build (stack)  : web | ai | mobile | cli | data | _generic
#   --mode    how you work (archetype): prototyper | builder | sweeper | grower | maintainer
#   --stage   preset (archetype mix)  : pre-pmf | growing | mature   (alternative to --mode)
#
# Layers installed (in order):
#   1. core/    — session-continuity engine (hooks, extract-session, charter, verifier)  [always]
#   2. domains/ — one harness team seed (.claude/agents + team skills + domain charter)  [if wired]
#   3. modes/   — archetype personality profile (charter rules + active skill set)       [if wired]
#
# Idempotent: re-running skips existing files and merges settings hooks by command string.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --mode)   MODE="$2"; shift 2 ;;
    --stage)  STAGE="$2"; shift 2 ;;
    --lang)   LANG_CHOICE="$2"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    -h|--help)
      grep '^#' "$0" | head -20; exit 0 ;;
    *)
      if [ -z "$TARGET" ]; then TARGET="$1"; shift; else echo "Unknown arg: $1" >&2; exit 1; fi ;;
  esac
done

TARGET="${TARGET:-$(pwd)}"
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

if [ "$TARGET" = "$KIT_DIR" ] || [[ "$KIT_DIR" == "$TARGET"/* ]]; then
  echo "ERROR: target must not be the pack itself." >&2; exit 1
fi

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

if [ -z "$DOMAIN" ] && [ -t 0 ]; then
  DOMAIN="$(ask 'Project domain? (what you build)' 'web / ai / mobile / cli / data / _generic')"
fi
DOMAIN="${DOMAIN:-_generic}"

if [ -z "$MODE" ] && [ -z "$STAGE" ] && [ -t 0 ]; then
  STAGE="$(ask 'Product stage? (how you work — archetype preset)' 'pre-pmf / growing / mature  (or: proto typer/builder/sweeper/grower/maintainer via --mode)')"
fi
STAGE="${STAGE:-}"
MODE_LABEL="${MODE:-${STAGE:-none}}"

echo "═══════════════════════════════════════════════════"
echo "  devkit-init installer"
echo "═══════════════════════════════════════════════════"
echo "  Pack:   $KIT_DIR"
echo "  Target: $TARGET"
echo "  Domain: $DOMAIN   Mode/Stage: $MODE_LABEL   Lang: $LANG_CHOICE"
echo ""

# non-empty guard (core files may coexist; only warn hard when no --force and target has a CLAUDE.md already)
if [ -f "$TARGET/CLAUDE.md" ] && [ "$FORCE" -ne 1 ]; then
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
    hub=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('sessions_hub',''))" "$cfg" 2>/dev/null || true)
    [ -n "$hub" ] && { echo "$hub"; return; }
  fi
  echo "$HOME/.claude/sessions-hub"
}
HUB="$(resolve_hub)"
if [ ! -e "$TARGET/.agents/sessions" ]; then
  if mkdir -p "$HUB/$(basename "$TARGET")" 2>/dev/null; then
    ln -s "$HUB/$(basename "$TARGET")" "$TARGET/.agents/sessions"
    echo "  [ok]   .agents/sessions -> sessions hub ($HUB/$(basename "$TARGET"))"
  else
    mkdir -p "$TARGET/.agents/sessions"   # 최후 안전망 (HUB 쓰기 불가)
    echo "  [warn] sessions hub unwritable ($HUB) — local fallback; fix then run scripts/adopt-sessions-hub.sh"
  fi
fi

copied=0; skipped=0
install_file() { # $1 src, $2 dst, $3 executable(0/1)
  if [ -f "$2" ]; then echo "  [skip] ${2#$TARGET/}"; skipped=$((skipped+1)); return 0; fi
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  [ "${3:-0}" = "1" ] && chmod +x "$2"
  echo "  [ok]   ${2#$TARGET/}"; copied=$((copied+1))
}

# ---------------------------------------------------------- 1) CORE
echo "── core (session continuity) ──"
for f in auto-extract-session.sh session-start-recover.sh session-end-reminder.sh; do
  install_file "$KIT_DIR/core/hooks/$f" "$TARGET/.claude/hooks/$f" 1
done
install_file "$KIT_DIR/core/scripts/extract-session.sh" "$TARGET/scripts/extract-session.sh" 1
install_file "$KIT_DIR/core/scripts/stitch-timeline.py" "$TARGET/scripts/stitch-timeline.py" 1
install_file "$KIT_DIR/core/scripts/adopt-sessions-hub.sh" "$TARGET/scripts/adopt-sessions-hub.sh" 1
install_file "$KIT_DIR/core/scripts/session-hub.sh" "$TARGET/scripts/session-hub.sh" 1
install_file "$KIT_DIR/core/agents/verifier.md" "$TARGET/.claude/agents/verifier.md"
install_file "$KIT_DIR/mcp/.mcp.json.template" "$TARGET/.mcp.json.template"

# MEMORY.md
if [ ! -f "$TARGET/MEMORY.md" ]; then
  sed "s/{{PROJECT_NAME}}/$(basename "$TARGET")/g" "$KIT_DIR/core/MEMORY.md.template" > "$TARGET/MEMORY.md"
  echo "  [ok]   MEMORY.md"; copied=$((copied+1))
else
  echo "  [skip] MEMORY.md"; skipped=$((skipped+1))
fi

# ------------------------------------------------------ 2) DOMAIN seed
DOMAIN_DIR="$KIT_DIR/domains/$DOMAIN"
DOMAIN_CLAUDE=""
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

# ------------------------------------------------------ 3) MODE profile
MODE_RULES_FILE=""
MODE_SKILL_CATS=""
resolve_mode_files() { # $1 = archetype name -> appends
  local m="$1" d="$KIT_DIR/modes/$1"
  [ -f "$d/CLAUDE.mode.md" ] && MODE_RULES_FILES="$MODE_RULES_FILES $d/CLAUDE.mode.md"
  [ -f "$d/skills.list" ] && MODE_SKILL_CATS="$MODE_SKILL_CATS $(grep -v '^#' "$d/skills.list" | tr '\n' ' ')"
}
MODE_RULES_FILES=""
if [ -n "$MODE" ] && [ -d "$KIT_DIR/modes/$MODE" ]; then
  echo "── mode: $MODE ──"
  resolve_mode_files "$MODE"
elif [ -n "$STAGE" ] && [ -f "$KIT_DIR/modes/presets/$STAGE.json" ]; then
  echo "── stage preset: $STAGE ──"
  for m in $(python3 -c "import json,sys; print(' '.join(a.split(':')[0] for a in json.load(open(sys.argv[1]))['archetypes']))" "$KIT_DIR/modes/presets/$STAGE.json"); do
    resolve_mode_files "$m"
  done
elif [ "$MODE_LABEL" != "none" ]; then
  echo "── mode/stage '$MODE_LABEL' — not wired in this pack build (skipping) ──"
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
if [ ! -f "$TARGET/CLAUDE.md" ]; then
  python3 - "$KIT_DIR" "$TARGET" "$DOMAIN" "$MODE_LABEL" "$DOMAIN_CLAUDE" $MODE_RULES_FILES <<'PYEOF'
import sys, os, re
kit, target, domain, mode_label = sys.argv[1:5]
domain_claude = sys.argv[5]
mode_files = sys.argv[6:]

with open(os.path.join(kit, 'core', 'CLAUDE.core.md.template')) as f:
    tpl = f.read()

mode_rules = []
for mf in mode_files:
    with open(mf) as f:
        mode_rules.append(f.read().strip())
mode_block = "\n\n".join(mode_rules) if mode_rules else "(모드 미지정 — 필요 시 `bash install.sh --mode <archetype>` 재실행으로 주입)"

out = (tpl
       .replace('{{PROJECT_NAME}}', os.path.basename(target))
       .replace('{{DOMAIN}}', domain)
       .replace('{{MODE}}', mode_label)
       .replace('{{MODE_RULES}}', mode_block))

if domain_claude:
    with open(domain_claude) as f:
        dom = f.read().strip()
    out += "\n\n---\n\n# Domain Charter — " + domain + "\n\n" + dom + "\n"

with open(os.path.join(target, 'CLAUDE.md'), 'w') as f:
    f.write(out)
print("  [ok]   CLAUDE.md assembled (core" + (" + domain" if domain_claude else "") + (" + mode" if mode_rules else "") + ")")
PYEOF
  copied=$((copied+1))
else
  echo "  [skip] CLAUDE.md (exists — merge sections manually from $KIT_DIR/core/CLAUDE.core.md.template)"
  skipped=$((skipped+1))
fi

# --------------------------------------------- 5) settings.json merge
dst="$TARGET/.claude/settings.json"
if [ -f "$dst" ]; then
  python3 - "$KIT_DIR/core/settings.core.json.fragment" "$dst" <<'PYEOF'
import json, sys
frag_path, dst_path = sys.argv[1], sys.argv[2]
with open(frag_path) as f:
    frag = json.load(f)
frag.pop('_README', None)
with open(dst_path) as f:
    cur = json.load(f)
cur.setdefault('hooks', {})
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
with open(dst_path, 'w') as f:
    json.dump(cur, f, indent=2, ensure_ascii=False)
print(f"  [merged] .claude/settings.json ({added} new hook command(s))")
PYEOF
else
  python3 - "$KIT_DIR/core/settings.core.json.fragment" "$dst" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
d.pop('_README', None)
with open(sys.argv[2], 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
print("  [ok]   .claude/settings.json created")
PYEOF
  copied=$((copied+1))
fi

# ---------------------------------------------------------- summary
echo ""
echo "═══════════════════════════════════════════════════"
echo "  devkit-init complete: $copied installed, $skipped kept."
echo ""
echo "  Next:"
echo "    1) Restart Claude Code (or start a new session) in $TARGET"
echo "    2) Verify hooks:  bash -n .claude/hooks/*.sh"
echo "    3) Open CLAUDE.md — fill '## Current State' on first session"
echo "    4) Need MCP? copy .mcp.json.template → .mcp.json and add servers"
echo "═══════════════════════════════════════════════════"
