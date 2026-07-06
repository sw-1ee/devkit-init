# devkit-init

**빈 작업 디렉토리에 던지면 개발환경이 선다.** `claude init` 의 종합 개발판.

```bash
# one-line (레포 클론 후)
bash pack/install.sh ~/my-new-project --domain web --stage pre-pmf

# 대화형
cd ~/my-new-project && bash /path/to/pack/install.sh
```

Claude Code 세션 안에서는 `/devkit init` 스킬이 같은 installer 를 대화형으로 감싼다
(도메인 자동 추론: `pubspec.yaml`→mobile, `package.json`+`next`→web …).

## 2축 설계

| 축 | 질문 | 선택지 |
|---|---|---|
| **domain** | 무엇을 만드나 (스택) | web / ai / mobile / cli / data / `_generic` |
| **mode** | 어떻게 일하나 (원형) | prototyper / builder / sweeper / grower / maintainer |
| **stage** | (mode 프리셋) 제품 성숙도 | pre-pmf(1+2+3) / growing(2+3+4+5) / mature(3+4+5+2) |

같은 web 프로젝트라도 prototyper(게이트 느슨·발산)와 maintainer(최엄격·보존)는
완전히 다른 작업환경을 받는다. 원형은 직무·도메인과 직교한다.

## 설치되는 것

```
target/
├── CLAUDE.md              # core 차터 + domain 차터 + mode 규칙 조립
├── MEMORY.md              # 세션 간 기억 색인
├── .mcp.json.template     # MCP 등록 템플릿 (v1 서버 미번들)
├── scripts/extract-session.sh + stitch-timeline.py
├── .agents/sessions/      # 대화 로그 — 서버에 전역 허브(/mnt/volumes/sessions)가
│                          #   있으면 자동 심링크(프로젝트별 식별), 없으면 로컬.
│                          #   timeline.md = 전 세션 발화 시간순 연속 통합본
│                          #   (터미널 바뀌어도 대화 흐름 이어짐, 크래시도 recover가 복구)
└── .claude/
    ├── settings.json      # hooks 배선 (기존 파일엔 idempotent merge)
    ├── hooks/             # 세션 연속성 3계층 (Stop/SessionStart/UserPromptSubmit)
    ├── agents/            # verifier + 도메인 팀 5역할
    └── skills/            # 팀 플레이북 + mode 가 고른 카테고리 번들
```

핵심 가치 = **세션 연속성**: JSONL(ground truth) → conversation_log.md 자동 파생,
끊긴 세션 자동 회복, wrap-up 체크리스트 주입. 여기에 도메인 팀과 원형 프로파일이 얹힌다.

## 정직한 현재 한계 (v1)

- **desktop/exe, Flutter, iOS 전용 팀 없음** → `_generic` fallback. 콘텐츠 백로그.
- **run.sh 자율 루프 없음** → 신뢰성 미검증 컴포넌트는 배포하지 않는다. post-v1.
- **MCP 서버 미번들** → 빈 템플릿만.
- **세션 중 mode 전환** → v1.5 (`/devkit mode sweeper`).

## 재실행 안전

installer 는 idempotent: 존재하는 파일은 `[skip]`, settings hooks 는 command
문자열 비교로 dedupe merge. 다른 domain/mode 로 재실행하면 새 파일만 추가된다.

## 라이선스

pack 자체 = MIT. `skills/frontend/references/` 외부 데이터 = MIT/Apache 소스만
(각 출처는 `references/NOTICE.md`). unknown 라이선스 소스는 배제하고 native 재작성.
