# devkit-init — 범용 종합 개발 부트스트랩 하네스 팩

## Context

사용자는 빈 작업 디렉토리에 던지기만 하면 개발환경이 서는 배포 가능한 팩을 원한다 — `claude init`의 종합 개발판. 웹/AI/Flutter/iOS/exe/CLI/데이터 다도메인. 진입점은 `install.sh`(curl, Claude 없이) + `/devkit init`(Claude 세션 UX) 둘.

조사로 드러난 사실: **재료가 이미 dev-tools에 흩어져 있다.** `share/memory-kit/`=팩 프로토타입(install.sh + portable hooks + templates), `harness/{ko,en}/` 100팀=각각 `.claude/{CLAUDE,agents,skills}` 완결 미니팩, `templates/converted/index.json`=100팀 기계 카탈로그(seed 셀렉터). 그래서 "새로 만들기"보다 **"흩어진 재료를 팩으로 조립 + dev-tools 정리"**다.

**아키텍처 판단 1**: dev-tools는 팩이 "되지" 않고 팩을 **"담고 생산"**한다. 새 `pack/` 에 배포 소스를 조립하되 dev-tools 운영설정(절대경로 hook, 위키, collector)은 안 건드림. → "settings.json이 운영이냐 템플릿이냐" 교착 해소(루트=운영, pack/core=템플릿).

**아키텍처 판단 2 (핵심 축)**: seed 를 **도메인 단독으로 나누면 부족**하다. 같은 웹 프로젝트도 프로토타입 단계와 유지보수 단계는 완전히 다른 작업환경을 요구한다. 그래서 **2D 직교 축**을 채택: **도메인(무엇을 만드나=스택)** × **원형/mode(어느 단계에서 어떤 성격의 판단을 하나)**. 원형은 직무·도메인 무관하며, AI가 도메인 실행을 상향평준화할수록 변별점이 "무엇을 아나"에서 "어떤 판단을 하나"로 이동한다는 관찰에 기반.

**5원형** (Claude Code 팀 관찰): 1.Prototyper(발산·아이디어) 2.Builder(프로토→프로덕션) 3.Sweeper(정리·단순화·성능) 4.Grower(PMF 반복개선) 5.Maintainer(보안·안정·확장). 제품 성숙도별 원형 믹스: pre-PMF=1+2+3 / growing=2+3+4+5 / mature=3+4+5+2.

**사용자 확정 8결정**: 메타 부트스트래퍼(harness=콘텐츠 백엔드) / 다도메인 / 풀 하네스 / dev-tools 재구조화(pack/ 담기) / 이름 `devkit-init` / 웹 데이터 v1 frontend 심화 / **mode 직교 2D** / **mode=프리셋(원형조합) + 개별 5원형**.

## 배포 팩 구조 (`pack/` = dev-tools 안에 조립)

3계층: 도메인+모드무관 **코어** + **도메인 모듈**(무엇, harness seed) + **모드 프로파일**(어떻게, 원형). init 이 세 개 병합.

```
pack/
├── install.sh                      # bash 진입점, Claude 무관 (memory-kit/install.sh 진화)
├── README.md   manifest.json       # 버전 + core 목록 + domain→team 맵 + mode 목록
├── core/                           # 도메인+모드 무관 — 항상 verbatim
│   ├── CLAUDE.core.md.template      # 세션절차+가드레일, {{PROJECT_NAME}}/{{DOMAIN}}/{{MODE}} 슬롯
│   ├── settings.core.json.fragment  # hooks 만, ${CLAUDE_PROJECT_DIR} portable
│   ├── hooks/{auto-extract-session,session-start-recover,session-end-reminder}.sh
│   ├── scripts/extract-session.sh
│   ├── agents/verifier.md           # mode-aware 교차검증 subagent (게이트 엄격도 mode 주입)
│   └── MEMORY.md.template
├── domains/                        # 무엇 — init 시 1개 (harness 팀 seed)
│   ├── index.json                  # templates/converted/index.json 뷰
│   ├── web/→16-fullstack-webapp  ai/→41-llm-app-builder  mobile/→17
│   ├── cli/→40  data/→27  _generic/→minimal(desktop/exe/Flutter/iOS 갭 fallback)
├── modes/                          # 어떻게 — init 시 1개 (원형/프리셋)
│   ├── index.json
│   ├── prototyper/ builder/ sweeper/ grower/ maintainer/   # 각: CLAUDE.mode.md + skills.list + gates.json
│   └── presets/{pre-pmf,growing,mature}.json               # 원형 조합 + 가중
├── skills/                         # 짧은 카테고리 번들 (mode 가 활성셋 선택)
│   ├── agent-llm/ debug/ security/ frontend/ testing/
│   └── refactor/ docs/ data/ git-ops/ diagram/
└── mcp/.mcp.json.template          # {} (v1 미번들)
```

## 모드(원형) 프로파일 — 각 mode = 에이전트 성격 프로파일

mode 는 스킬묶음이 아니라 **성격 세트**: 활성스킬 + 게이트엄격도 + 자율성 + anti-slop강도 + 테스트요구 + effort + verifier 태도. CLAUDE.mode.md(운영규칙 조각) + skills.list(활성 카테고리 우선순위) + gates.json(hook/게이트 파라미터)로 구현.

| mode | 판단 성격 | 활성 스킬 | 게이트/자율성 |
|---|---|---|---|
| **prototyper** | 발산·많이버림 | brainstorming, frontend(빠른 스캐폴드), diagram, artifact | 게이트 느슨 / 자율↑ / anti-slop 완화 / 테스트 최소 / effort 낮음(속도) |
| **builder** | 프로토→프로덕션 | test-driven-development, writing-plans, executing-plans, backend/db/auth-patterns | 게이트 중 / TDD 강제 / 타입안전 / CI |
| **sweeper** | 정리·단순화 | /simplify·/code-review, refactor(language-patterns), verification-before-completion | 회귀방지 게이트 / 죽은코드 제거 / 성능 |
| **grower** | PMF 반복개선 | llm-evaluation, data(analytics/vega), a11y, 계측 | 측정 게이트 / 실험·A/B / 반복 |
| **maintainer** | 보존·확장 | security-hardening, auth-patterns, verification-before-completion, devops | 최엄격 게이트 / 자율↓ / 회귀·보안 강제 |

**프리셋**(기본 선택지, 원형 조합): `pre-pmf`=proto+builder+sweeper / `growing`=builder+sweeper+grower+약간maintainer / `mature`=sweeper+grower+maintainer+약간builder. 프리셋 선택 시 구성 원형들의 skills.list 합집합 + 단계별 가중. 고급 사용자는 개별 원형 직접 지정.

**프랙탈 고려(v1.5)**: mode 는 세션 중 전환 가능해야(`/devkit mode sweeper` → 활성규칙·스킬 재세팅). v1 은 init 세팅, 세션 전환은 v1.5.

## `init` 부트스트랩 — 2 진입점, 2 축

- **install.sh (bash, 1차, Claude 무관)**: `curl … | bash -s -- --domain web --stage pre-pmf`(또는 `--mode prototyper`) 또는 대화형(도메인 질문 + 단계 질문). 로직: 타깃=pwd(비었나)→domain→팀 seed 복사→**mode profile 적용**(CLAUDE.mode.md 병합 + 활성 스킬 카테고리만 복사 + gates.json→settings)→core verbatim(hooks chmod)→CLAUDE 템플릿 병합({{MODE}} 치환)→memory-kit idempotent Python merger 로 settings 병합→검증 출력.
- **/devkit init (Claude 스킬, 2차, 세션 UX)**: 도메인+단계 대화형 + 기존 repo 추론(`pubspec.yaml`→mobile, 성숙 repo→growing/mature 추천)→같은 install.sh 위임→`[ok]/[skip]/[merged]` 보고 + 의미적 후속(첫 Current State, 옵션 팀·mode 추천).

둘 다 domains/index.json + modes/index.json 읽음 = 100팀 카탈로그 + 원형 세트가 단일 선택 소스.

## dev-tools 재구조화 타깃

dev-tools = 팩 개발 스튜디오이자 자신의 라이브 워크스페이스. 팩 소스는 dev-tools 자산에서 조립되는 빌드 산출물.
```
/mnt/volumes/dev-tools/
├── pack/                # 신규 — 배포 팩 소스 (harness + .agents/skills + memory-kit 에서 조립)
├── .claude/  .agents/  harness/  templates/  docs/wiki/  collector/  scripts/  # 라이브, 초기 불변(심링크 교정만)
├── CLAUDE.md            # dev-tools 자신 차터
└── share/memory-kit/    # 코어 프로토타입 잔류 (pack/core 가 대체)
```
CLAUDE.md/settings/hooks = 정본=운영(절대경로) / pack/core=파생 템플릿(portable) 공존.

## 웹 데이터 대량추출 (v1 frontend 심화) — 라이브 검증 완료

`pack/skills/frontend/references/` 흡수. MIT/Apache 만, unknown 제외. (prototyper/grower mode 가 이 데이터 주 소비자):
| 소스 | 자산 | 라이선스 | 처리 |
|---|---|---|---|
| nextlevelbuilder/ui-ux-pro-max-skill | 16 CSV (161규칙 Decision_Rules JSON임베드 / 161 shadcn 팔레트+WCAG / 99 UX / 57 타이포 / 25 차트 / 67 스타일) | MIT | sparse-clone → 정규화 JSON |
| VoltAgent/awesome-design-md | 73 DESIGN.md (open-design 71DS 의 MIT 상류) | MIT | DESIGN.md 만 + index.json |
| Nutlope/hallmark | 20테마/57 슬롭게이트 | MIT | 원본 md + 게이트 JSON |
| pbakaus/impeccable | 45 detector 룰 + 23 command | Apache-2.0 | 코드→룰 카탈로그 JSON (+NOTICE) |
| phrazzld / transitions.dev | OKLCH / 9 CSS | **unknown** | 제외 → native 재작성 |
| Bencium UX | a11y/motion | 미확인 | 착수 시 실측 |
파이프라인: `pack/skills/frontend/scripts/fetch-*.sh`(sparse, --depth1, SHA핀) → `_raw/` → normalize.py → references/ → NOTICE.md. ≈2–3MB. AGPL/GPL 없음.

## 안전 단계 마이그레이션 (되돌릴 수 있는 얇은 Phase)

각 Phase 독립 커밋·검증. 라이브 절대경로 hook 배선은 최후.
- **P0 스냅샷** — manifest 초안 + plan 커밋. 검증: git clean, 세션 hook 발화. 위험0.
- **P1 pack/core 순수추가** — memory-kit + portable 재작성 hook. `.claude/` 불변. 검증: `bash -n` + scratchpad 빈 디렉토리 install.sh → 환경 섬. 롤백 `rm -rf pack/`.
- **P2 domains 배선** — index.json→templates/converted, manifest domain→team, install.sh seed-unpack. 검증: 도메인별 scratchpad init → harness diff.
- **P3 modes 축** — 5 원형 프로파일(CLAUDE.mode.md + skills.list + gates.json) + 3 프리셋 + install.sh mode 병합. 검증: `--domain web --mode maintainer` vs `--mode prototyper` 가 다른 CLAUDE/스킬/게이트 산출.
- **P4 스킬 심링크 교정** (dev-tools `.claude/skills/`, 팩 독립): caveman* 5→`../../.agents/skills/caveman*`(로컬 실체) / blue-print 노출 / 로컬4 유지 문서화. 검증: broken-link 0.
- **P5 웹 데이터 추출 + 위생** — frontend fetch + `pack/**/sessions/`·`data/` gitignore + copy 가드. 검증: palettes.json 11키 shadcn + NOTICE 4소스.
- **P6 hook portable 수렴** (최고위험, 최후, P1-5 후만) — dev-tools hook `${CLAUDE_PROJECT_DIR:-/mnt/volumes/dev-tools}` fallback = 동작불변. 검증: 풀 세션 사이클(recover/extract/wiki-graph/easy-alert). 롤백 단일커밋.

**이동 절대 금지**: docs/wiki/, collector/, wiki-lint-hook WIKI_DIR, JSONL 프로젝트 dir.

## v1 범위
- **run.sh 자율 loop = DEFER** — dev-tools 자율loop 미해결(ScheduleWakeup 첫 wake 전 죽음). 알려진 결함 전파 = 가드레일7 위반. `pack/optional/run.sh` post-v1.
- **.mcp.json = 빈 `{}`** — MCP 0개, cap `<10`. 주석 예시만.
- **다도메인 정직성** — Flutter/iOS/exe 전용팀 없음 → `_generic` + README backlog. 팀 조작 금지.
- **세션 중 mode 전환 = v1.5** — v1 은 init 세팅만.

## 위험 등록부 (톱5)
1. 세션연속성 엔진 파손(절대경로 hook) → P6 최후 + fallback + 단일커밋 롤백 + 풀사이클 검증.
2. settings.json 병합이 라이브 hook 손상 → 통째 재생성 금지, per-event Python merger, 팩은 fragment 만.
3. 심링크 재지정 orphan → P4 broken-link 스캔, caveman 로컬 실체 지정.
4. mode 프로파일 조합 폭발/모순(프리셋이 상충 원형 합침) → skills.list 우선순위 규칙 + 프리셋 dry-run(pre-pmf/growing/mature 각 산출 검증).
5. 다도메인 overpromise → _generic + 정직한 backlog.

## 검증 (end-to-end)
- **팩 동작**: scratchpad 빈 디렉토리 → `install.sh --domain web --stage pre-pmf` → `.claude/{settings,hooks,skills,agents}`+CLAUDE 섬, `bash -n`, 재실행 idempotent.
- **2D 직교**: 같은 web 도메인에 mode 만 바꿔 2회 init → CLAUDE 규칙·활성스킬·게이트 엄격도가 실제로 다름(prototyper 느슨 vs maintainer 엄격) 실측.
- **웹 데이터**: fetch→normalize→palettes.json 11키 shadcn + NOTICE 4소스.
- **dev-tools 무회귀**: 세션 hook 4계층 발화, 위키 그래프, collector 무관, 심링크 broken 0, git clean.

## 착수 순서
P0 → P1(core+scratchpad) → P2(domains) → P3(modes) → P4(심링크) → P5(웹 데이터) → P6(hook 수렴, 최후) → 위키 등재(devkit-init entity) + Phase별 커밋.

## 핵심 파일
- 재사용 정본: `share/memory-kit/{install.sh,settings.json.fragment,SKILL.md,CLAUDE.md.template}`, `harness/ko/16-fullstack-webapp/.claude/`(seed 표본), `templates/converted/index.json`(셀렉터).
- 라이브 위험 중심: `.claude/settings.json`(hybrid), `.claude/hooks/*.sh`(절대경로), `scripts/wiki-lint-hook.sh`.
- 규약: `.agents/skills/writing-skills/SKILL.md`, `CLAUDE.md`(가드레일), `docs/operations/cleanup-todo.md`.
- 웹 데이터 근거: `docs/wiki/pages/entities/{ui-ux-pro-max,open-design-claude-alternative,impeccable-ai-design-skills,hallmark-anti-ai-slop-design-skill}.md`.
- mode 원형 스킬 매핑: `.agents/skills/` 전체 + `/simplify`·`/code-review` 슬래시커맨드.
