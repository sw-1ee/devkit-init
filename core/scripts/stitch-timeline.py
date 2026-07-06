#!/usr/bin/env python3
"""stitch-timeline.py — 프로젝트의 전 세션 대화를 하나의 연속 타임라인으로 병합.

세션 단위 conversation_log.md 들을 발화 타임스탬프 기준 전역 정렬해
sessions 디렉토리 루트에 timeline.md 를 재생성한다.

- 연속 작업(터미널 A 종료 → B 재개)은 시간순으로 자연스럽게 이어진다.
- 병렬 세션은 시간순 인터리브 + 발화별 [세션태그] 로 갈래 식별.
- 결정적 병합(내용 추측 없음). 원본 세션 폴더는 불변.

Usage: stitch-timeline.py [sessions_dir]   (기본 = <project>/.agents/sessions)
"""
import re
import sys
from pathlib import Path

HEADER_RE = re.compile(r"^## (사용자|ai) \(([^)]*)\)\s*$")


def parse_log(path: Path, session_tag: str):
    """conversation_log.md → [(timestamp_str, speaker, body, session_tag)]"""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    entries = []
    cur = None  # (ts, speaker, [lines])
    for line in text.splitlines():
        m = HEADER_RE.match(line)
        if m:
            if cur:
                entries.append((cur[0], cur[1], "\n".join(cur[2]).strip(), session_tag))
            cur = (m.group(2), m.group(1), [])
        elif cur is not None:
            if line.strip() == "---":
                continue
            cur[2].append(line)
    if cur:
        entries.append((cur[0], cur[1], "\n".join(cur[2]).strip(), session_tag))
    return entries


def main():
    if len(sys.argv) > 1:
        sess_dir = Path(sys.argv[1])
    else:
        proj = Path(__file__).resolve().parent.parent
        sess_dir = proj / ".agents" / "sessions"
    sess_dir = sess_dir.resolve()  # 심링크면 허브 실경로
    if not sess_dir.is_dir():
        print(f"no sessions dir: {sess_dir}", file=sys.stderr)
        return 1

    project = sess_dir.name
    all_entries = []
    session_meta = []  # (첫 ts, tag, dirname)
    for d in sorted(p for p in sess_dir.iterdir() if p.is_dir()):
        log = d / "conversation_log.md"
        if not log.is_file():
            continue
        tag = d.name[:15]  # YYYYMMDD-HHMMSS
        entries = parse_log(log, tag)
        if entries:
            all_entries.extend(entries)
            session_meta.append((entries[0][0], tag, d.name))

    # 타임스탬프 문자열(ISO 유사) 사전순 = 시간순. 파싱불가 ts 는 뒤로.
    def key(e):
        return (e[0] or "9999", )
    all_entries.sort(key=key)
    session_meta.sort(key=lambda s: s[0] or "9999")

    out = [
        f"# Timeline — {project} (전 세션 연속 통합)",
        "",
        f"> 자동 생성 (stitch-timeline.py) — 세션 {len(session_meta)}개 · 발화 {len(all_entries)}개.",
        "> 발화 타임스탬프 전역 정렬. `[태그]` = 세션 식별 (병렬 세션 = 인터리브).",
        "> 편집 금지 — 원본은 각 세션 폴더의 conversation_log.md.",
        "",
    ]
    seen_sessions = set()
    for ts, speaker, body, tag in all_entries:
        if tag not in seen_sessions:
            seen_sessions.add(tag)
            full = next((m[2] for m in session_meta if m[1] == tag), tag)
            out.append(f"\n⟨⟨ 세션 시작 · {full} ⟩⟩\n")
        out.append(f"## {speaker} ({ts}) [{tag}]")
        out.append("")
        out.append(body)
        out.append("")
    (sess_dir / "timeline.md").write_text("\n".join(out), encoding="utf-8")
    print(f"timeline.md: sessions={len(session_meta)} utterances={len(all_entries)} -> {sess_dir/'timeline.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
