# devkit-init

빈 디렉토리에서 실행하면 Claude Code 개발 환경이 한 번에 갖춰집니다. `claude init`을 종합 개발용으로 넓힌 부트스트랩 팩입니다.

## 설치

설치 방법은 세 가지입니다.

### 1. 릴리스에서 받기 (권장)

tarball을 파일로 먼저 내려받은 뒤에 풉니다.

```bash
curl -L -o devkit.tar.gz https://github.com/sw-1ee/devkit-init/releases/latest/download/devkit-init.tar.gz
tar xzf devkit.tar.gz -C devkit
bash devkit/install.sh ~/my-project --domain web --stage pre-pmf
```

`curl … | tar xz`처럼 받은 스트림을 곧바로 푸는 방법은 권하지 않습니다. 1.5MB 전송이 중간에 끊기면 tar 앞부분만 풀려 `core/`가 빠진 채로 성공한 것처럼 보일 수 있기 때문입니다. 파일로 받아 `tar xzf`로 풀면 전송이 끊긴 파일은 tar가 오류로 걸러냅니다.

### 2. 저장소를 이미 클론했다면

```bash
bash pack/install.sh ~/my-project --domain web --stage pre-pmf
```

### 3. Claude Code 세션 안에서

`/devkit init` 스킬이 같은 installer를 대화형으로 감쌉니다. 기존 저장소라면 파일 흔적을 보고 도메인을 추천합니다. 예를 들어 `pubspec.yaml`이 있으면 mobile, `package.json`에 next가 있으면 web을 제안합니다.

### install.sh 인자

| 인자 | 뜻 | 값 |
|---|---|---|
| `<target>` | 설치할 프로젝트 디렉토리 | 경로. 없으면 새로 만들고, 생략하면 현재 위치를 씁니다 |
| `--domain` | 무엇을 만드는지 | web / ai / mobile / cli / data / desktop / `_generic` |
| `--stage` | 제품 성숙도 (mode 프리셋) | pre-pmf / growing / mature |
| `--mode` | 단일 원형 (`--stage` 대신) | prototyper / builder / sweeper / grower / maintainer |
| `--lang` | 하네스 팀 언어 | ko (기본) / en |
| `--force` | 기존 CLAUDE.md가 있어도 진행 | 플래그 |
| `--update` | 기존 설치의 팩 소유 런타임(hooks/scripts/verifier)만 새 버전으로 갱신 | 플래그 |

인자를 생략하면 도메인과 단계를 대화형으로 물어봅니다.

Windows에서는 Git Bash에서 실행합니다. python3(또는 python)가 PATH에 있어야 하고, 세션 허브 연결은 심링크 대신 NTFS 정션으로 만들어집니다. 설치 경로에 공백이나 한글이 있어도 동작합니다.

### 실행하면 일어나는 일

1. **팩 무결성 검사** — `core`·`domains`·`modes`·`skills`·`mcp`가 모두 있는지 확인합니다. 부분 추출이면 여기서 멈춥니다.
2. **core 설치** — 세션 연속성 엔진(hooks, extract-session, verifier, 차터 템플릿)을 깝니다.
3. **domain seed** — 선택한 도메인의 하네스 팀 역할들을 `.claude/agents/`에 펼칩니다.
4. **mode 프로파일** — 원형 규칙을 CLAUDE.md에 넣고, 그 원형이 쓰는 스킬 카테고리만 설치합니다.
5. **조립** — CLAUDE.md를 core + domain + mode로 합치고, settings.json의 hooks를 병합합니다.

파일마다 `[ok]` / `[skip]` / `[merged]`로 로그가 남습니다. 이미 있는 파일은 건드리지 않습니다.

### 설치가 끝나면

타겟 디렉토리에서 Claude Code 세션을 새로 시작합니다. 첫 턴에 CLAUDE.md의 `Current State`를 채워 두면 다음 세션이 그 맥락을 이어받습니다.

## 두 개의 축

| 축 | 질문 | 선택지 |
|---|---|---|
| **domain** | 무엇을 만드는지 (스택) | web / ai / mobile / cli / data / desktop / `_generic` |
| **mode** | 어떻게 일하는지 (원형) | prototyper / builder / sweeper / grower / maintainer |
| **stage** | (mode 프리셋) 제품 성숙도 | pre-pmf(1+2+3) / growing(2+3+4+5) / mature(3+4+5+2) |

같은 web 프로젝트라도 prototyper와 maintainer는 전혀 다른 환경을 받습니다. prototyper는 게이트를 느슨하게 풀어 발산을 돕고, maintainer는 가장 엄격한 게이트로 보존을 우선합니다. 원형은 직무나 도메인에 매이지 않는 별개의 축입니다.

## 설치되는 것

```
target/
├── CLAUDE.md              # core 차터 + domain 차터 + mode 규칙 조립
├── MEMORY.md              # 세션 간 기억 색인
├── .mcp.json.template     # MCP 등록 템플릿 (v1 서버 미번들)
├── scripts/extract-session.sh + stitch-timeline.py
├── .agents/sessions/      # → 세션 허브 링크 (Linux/macOS=심링크, Windows=NTFS 정션)
│                          #   해석: env DEVKIT_SESSIONS_HUB > ~/.claude/devkit.json
│                          #         > 기본 ~/.claude/sessions-hub (자동 생성)
│                          #   timeline.md = 전 세션 발화 시간순 연속 통합본
│                          #   (터미널 교체·크래시에도 대화 흐름 이어짐)
│                          #   허브 이관 = scripts/adopt-sessions-hub.sh <새경로> (영속 포함)
└── .claude/
    ├── settings.json      # hooks 배선 (기존 파일엔 idempotent merge)
    ├── hooks/             # 세션 연속성 3계층 (Stop/SessionStart/UserPromptSubmit)
    ├── agents/            # verifier + 도메인 팀 5역할
    └── skills/            # 팀 플레이북 + mode가 고른 카테고리 번들
```

이 팩의 중심은 세션 연속성입니다. Claude Code가 남기는 JSONL을 ground truth로 삼아 conversation_log.md를 자동으로 파생하고, 끊긴 세션은 다음 시작 때 복구하며, 마무리 시점에는 체크리스트를 띄웁니다. 도메인 팀과 원형 프로파일은 그 위에 얹힙니다.

## 아직 안 되는 것

Flutter·iOS 전용 팀은 아직 없어서 당분간 `_generic` fallback이 대신합니다. run.sh 자율 루프는 신뢰성이 검증될 때까지 뺐고, MCP 서버도 빈 템플릿만 넣었습니다. 세션 중 mode 전환은 이후 버전에서 다룰 예정입니다.

## 재실행해도 안전합니다

installer는 idempotent합니다. 이미 있는 파일은 `[skip]`으로 건너뛰고, settings hooks는 command 문자열을 비교해 중복 없이 병합합니다. 다른 domain이나 mode로 다시 실행하면 새 파일만 추가됩니다.

## 기존 설치 업그레이드

새 버전의 팩을 받은 뒤 `--update`로 실행하면 팩 소유 런타임(hooks 3종, scripts 4종, verifier)만 새 버전으로 교체합니다. 내용이 같으면 건너뛰고, 다르면 기존 파일을 `.bak`으로 남긴 뒤 갱신합니다. 직접 작성하신 CLAUDE.md·MEMORY.md·도메인 에이전트·스킬은 건드리지 않으며, settings.json의 hook 명령은 구버전 문자열을 자동으로 새 버전으로 교체합니다.

```bash
bash devkit/install.sh ~/my-project --update
```

## 라이선스

pack 자체는 MIT입니다. `skills/frontend/web-design-data/references/`에 번들된 외부 데이터는 모두 MIT 또는 Apache 소스에서 가져왔고, 출처별 표기는 같은 폴더의 `NOTICE.md`에 있습니다. 라이선스가 불분명한 소스는 넣지 않고, 아이디어만 참고해 직접 다시 작성했습니다.
