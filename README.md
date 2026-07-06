# devkit-init

빈 디렉토리에 풀어놓기만 하면 Claude Code 개발환경이 통째로 선다. `claude init`을 종합 개발판으로 넓힌 부트스트랩 팩이다.

## 설치

설치 경로는 세 가지다.

### 1. 릴리스에서 받기 (권장)

tarball을 파일로 먼저 받은 뒤에 푼다.

```bash
curl -L -o devkit.tar.gz https://github.com/sw-1ee/devkit-init/releases/latest/download/devkit-init.tar.gz
tar xzf devkit.tar.gz -C devkit
bash devkit/install.sh ~/my-project --domain web --stage pre-pmf
```

`curl … | tar xz`처럼 받은 스트림을 곧바로 푸는 방식은 피한다. 1.5MB 전송이 중간에 끊기면 tar 앞쪽만 풀려서 core/가 빠진 채로 성공한 것처럼 보이기 때문이다. 파일로 받아 `tar xzf`로 풀면 도중에 끊긴 파일은 tar가 에러로 걸러낸다.

### 2. 저장소를 이미 클론했다면

```bash
bash pack/install.sh ~/my-project --domain web --stage pre-pmf
```

### 3. Claude Code 세션 안에서

`/devkit init` 스킬이 같은 installer를 대화형으로 감싼다. 기존 저장소라면 파일 흔적으로 도메인을 추천한다. `pubspec.yaml`이 보이면 mobile, `package.json`에 next가 있으면 web 하는 식이다.

### install.sh 인자

| 인자 | 뜻 | 값 |
|---|---|---|
| `<target>` | 설치할 프로젝트 디렉토리 | 경로. 없으면 만들고, 생략하면 현재 위치 |
| `--domain` | 무엇을 만드나 | web / ai / mobile / cli / data / `_generic` |
| `--stage` | 제품 성숙도 (mode 프리셋) | pre-pmf / growing / mature |
| `--mode` | 단일 원형 (`--stage` 대신) | prototyper / builder / sweeper / grower / maintainer |
| `--lang` | 하네스 팀 언어 | ko (기본) / en |
| `--force` | 기존 CLAUDE.md가 있어도 진행 | 플래그 |

인자를 생략하면 도메인과 단계를 대화형으로 묻는다.

### 실행하면 일어나는 일

1. **팩 무결성 검사** — core/domains/modes/skills/mcp가 다 있는지 본다. 부분 추출이면 여기서 멈춘다.
2. **core 설치** — 세션 연속성 엔진 (hooks, extract-session, verifier, 차터 템플릿).
3. **domain seed** — 고른 도메인의 하네스 팀 5역할을 `.claude/agents/`에 편다.
4. **mode 프로파일** — 원형 규칙을 CLAUDE.md에 주입하고, 그 원형이 쓰는 스킬 카테고리만 설치한다.
5. **조립** — CLAUDE.md를 core + domain + mode로 합치고, settings.json의 hooks를 병합한다.

파일마다 `[ok]` / `[skip]` / `[merged]`로 로그가 찍힌다. 이미 있는 파일은 건드리지 않는다.

### 설치가 끝나면

타겟 디렉토리에서 Claude Code 세션을 새로 시작한다. 첫 턴에 CLAUDE.md의 `Current State`를 채워두면 다음 세션이 그 맥락을 이어받는다.

## 두 개의 축

| 축 | 질문 | 선택지 |
|---|---|---|
| **domain** | 무엇을 만드나 (스택) | web / ai / mobile / cli / data / `_generic` |
| **mode** | 어떻게 일하나 (원형) | prototyper / builder / sweeper / grower / maintainer |
| **stage** | (mode 프리셋) 제품 성숙도 | pre-pmf(1+2+3) / growing(2+3+4+5) / mature(3+4+5+2) |

같은 web 프로젝트라도 prototyper와 maintainer는 전혀 다른 환경을 받는다. prototyper는 게이트를 느슨하게 풀어 발산을 부추기고, maintainer는 가장 엄격한 게이트로 보존을 우선한다. 원형은 직무나 도메인에 매이지 않는 별개의 축이다.

## 설치되는 것

```
target/
├── CLAUDE.md              # core 차터 + domain 차터 + mode 규칙 조립
├── MEMORY.md              # 세션 간 기억 색인
├── .mcp.json.template     # MCP 등록 템플릿 (v1 서버 미번들)
├── scripts/extract-session.sh + stitch-timeline.py
├── .agents/sessions/      # → 세션 허브 심링크 (허브는 항상 존재, 경로 하드코딩 없음)
│                          #   해석: env DEVKIT_SESSIONS_HUB > ~/.claude/devkit.json
│                          #         > 기본 ~/.claude/sessions-hub (자동 생성)
│                          #   timeline.md = 전 세션 발화 시간순 연속 통합본
│                          #   (터미널 교체·크래시에도 대화 흐름 이어짐)
│                          #   허브 이관 = scripts/adopt-sessions-hub.sh <새경로> (영속 포함)
└── .claude/
    ├── settings.json      # hooks 배선 (기존 파일엔 idempotent merge)
    ├── hooks/             # 세션 연속성 3계층 (Stop/SessionStart/UserPromptSubmit)
    ├── agents/            # verifier + 도메인 팀 5역할
    └── skills/            # 팀 플레이북 + mode 가 고른 카테고리 번들
```

이 팩의 중심은 세션 연속성이다. Claude Code가 남기는 JSONL을 ground truth 삼아 conversation_log.md를 자동으로 파생한다. 끊긴 세션은 다음 시작 때 복구하고, 마무리 시점에는 체크리스트를 주입한다. 도메인 팀과 원형 프로파일은 그 위에 얹힌다.

## 아직 안 되는 것 (v1)

desktop/exe·Flutter·iOS 전용 팀은 없다. 당분간 `_generic` fallback이 대신한다. run.sh 자율 루프는 신뢰성이 검증될 때까지 뺐고, MCP 서버도 빈 템플릿만 넣었다. 세션 중 mode 전환은 v1.5에서 다룬다.

## 재실행해도 안전하다

installer는 idempotent다. 이미 있는 파일은 `[skip]`으로 건너뛰고, settings hooks는 command 문자열을 비교해 중복 없이 merge한다. 다른 domain이나 mode로 다시 실행하면 새 파일만 추가된다.

## 라이선스

pack 자체는 MIT다. `skills/frontend/web-design-data/references/`에 번들된 외부 데이터는 전부 MIT/Apache 소스에서 왔고, 출처별 표기는 같은 폴더의 `NOTICE.md`에 있다. 라이선스가 불분명한 소스는 배제하고 해당 아이디어만 참고해 직접 다시 작성했다.
