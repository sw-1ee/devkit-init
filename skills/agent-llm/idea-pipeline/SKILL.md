---
name: idea-pipeline
description: 아이디어 발상→검증→기획→실행 메타 오케스트레이션. PM은 조율만, 실질 판단은 하네스 팀원 세션이 수행. 산출물은 LLM 위키에 축적.
---

# Idea Pipeline — PM 메타 오케스트레이션 스킬

아이디어를 프로덕트로 만드는 전체 파이프라인. PM은 **라우터/조율자** 역할만
하고, 각 단계의 실질적 판단·분석·산출은 해당 하네스가 적용된 **팀원 세션**이
수행한다.

## 트리거

- "새 아이디어가 있어"
- "이거 만들어보고 싶어"
- "프로젝트 기획하자"
- "아이디어 브레인스토밍"
- 사용자가 제품/서비스 아이디어를 제시할 때

## 핵심 원칙

1. **PM은 판단하지 않는다** — PM은 "누구에게 물어볼지"를 결정하고, 팀원의 답변을 사용자에게 전달·종합한다
2. **팀원이 판단한다** — 시장 분석은 market-analyst가, 기술 추정은 architect가, 리스크는 launch-reviewer가 판단
3. **PM ↔ 팀원 대화가 핵심** — PM이 팀원에게 질문하고, 팀원이 근거와 함께 답변하고, PM이 후속 질문하는 구조
4. **위키에 축적** — 모든 산출물은 LLM 위키에 저장. 채팅에 묻히지 않는다

## 파이프라인 구조

```
사용자
  ↕ (대화)
PM 세션 ─── 조율만 ───┬─ Phase A: 발상
                      ├─ Phase B: 검증 (43-startup-launcher 팀원들)
                      ├─ Phase C: 기획 (46-product-manager 팀원들)
                      └─ Phase D: 실행 (16-fullstack-webapp 팀원들)
```

---

## Phase A: 발상 (PM ↔ 사용자)

PM이 직접 사용자와 대화하며 아이디어를 구체화하는 유일한 Phase.

### A-1: 새 아이디어 생성

사용자가 아이디어를 제시하면:

1. PM이 아이디어의 **한 줄 정의**를 확인
2. 3가지 계층으로 정리:
   - **Theme**: 전체 방향 (무엇을 해결하나)
   - **Goal**: 사용자가 얻는 능력 (왜 쓰나)
   - **Feature**: 구현 사항 (어떻게 만드나)
3. 위키에 프로젝트 컨셉 페이지 생성

### A-2: 브레인스토밍

사용자 입력을 Theme/Goal/Feature로 분류하며 발산:

- 아이디어를 부정하지 않고 발전시킨다
- 모호한 부분은 질문으로 명확히 한다
- 충분히 구체화되면 Phase B로 전환

### 산출물 → 위키

```
docs/wiki/pages/topics/<project-slug>-concept.md
  - 한 줄 정의
  - Theme / Goal / Feature 계층
  - 브레인스토밍 핵심 아이디어
```

---

## Phase B: 검증 (43-startup-launcher 팀원)

PM이 startup-launcher 하네스의 4개 팀원 세션을 spawn. 각 팀원이 독립적으로 분석하고 PM에게 보고.

### 팀원 세션 구성

| 순서 | 팀원 세션 | 하네스 역할 | 하는 일 |
|------|----------|-----------|--------|
| B-1 | `market-analyst` | 43-startup-launcher | 경쟁 서비스 3-5개 조사, TAM/SAM/SOM, 차별화 포인트, PMF 가설 |
| B-2 | `business-modeler` | 43-startup-launcher | BMC, 수익 모델, 유닛 이코노믹스, 개발 난이도·기간 추정 |
| B-3 | `mvp-architect` | 43-startup-launcher | MoSCoW 우선순위, MVP 범위, 기술 스택 선정, 릴리스 로드맵 |
| B-4 | `launch-reviewer` | 43-startup-launcher | 기술/비즈니스 리스크 매트릭스, 완화 전략, 전체 정합성 검증 |

### PM ↔ 팀원 소통 흐름

```
PM → market-analyst: "이 아이디어의 경쟁 환경 분석해줘" + 컨셉 페이지
  ← market-analyst: 경쟁 분석 결과 + 차별화 제안

PM → business-modeler: "이 분석 기반으로 비즈니스 모델 짜줘" + 시장 분석 결과
  ← business-modeler: BMC + 수익 모델 + 난이도 추정

PM → mvp-architect: "MVP 범위 잡아줘" + 시장 분석 + 비즈니스 모델
  ← mvp-architect: MoSCoW 분류 + MVP 구성 + 기술 스택

PM → launch-reviewer: "전체 검증해줘" + 위 모든 산출물
  ← launch-reviewer: 리스크 매트릭스 + 정합성 보고
```

### 의사결정 포인트

launch-reviewer 검증 후 PM이 사용자에게 보고:
- **Go**: Phase C로 진행
- **Pivot**: 컨셉 수정 후 Phase B 재실행
- **Kill**: 아이디어 보류 (위키에 기록은 남김)

### 산출물 → 위키

```
docs/wiki/pages/topics/<project-slug>-validation.md
  - 시장 분석 요약 (market-analyst)
  - 비즈니스 모델 (business-modeler)
  - MVP 범위 (mvp-architect)
  - 리스크 분석 (launch-reviewer)
  - Go/Pivot/Kill 결정 + 근거

docs/wiki/log.md
  → [YYYY-MM-DD] decision | <project> validation result
```

---

## Phase C: 기획 (46-product-manager 팀원)

검증 통과한 아이디어를 실행 가능한 기획서로 변환. PM이 product-manager 하네스의 4개 팀원 세션을 spawn.

### 팀원 세션 구성

| 순서 | 팀원 세션 | 하네스 역할 | 하는 일 |
|------|----------|-----------|--------|
| C-1 | `strategist` | 46-product-manager | 제품 비전, OKR, 로드맵, 우선순위 프레임워크 |
| C-2 | `prd-writer` | 46-product-manager | 요구사항 정의서, 성공 지표, 제약 조건 |
| C-3 | `story-writer` | 46-product-manager | 유저 스토리, 스토리 맵, 인수 기준, 스토리 포인트 |
| C-4 | `sprint-planner` | 46-product-manager | 스프린트 목표, 용량 계산, 스토리 배분, 리스크 관리 |

### PM ↔ 팀원 소통 흐름

```
PM → strategist: "이 MVP로 로드맵 짜줘" + validation 페이지
  ← strategist: OKR + 로드맵

PM → prd-writer: "PRD 작성해줘" + 로드맵
  ← prd-writer: 요구사항 정의서

PM → story-writer: "유저 스토리 쪼개줘" + PRD
  ← story-writer: 스토리 목록 + 인수 기준

PM → sprint-planner: "스프린트 계획 세워줘" + 스토리 목록
  ← sprint-planner: 스프린트 계획

PM → pm-reviewer (launch-reviewer 재활용 가능): "전체 기획 검증해줘"
  ← 정합성 보고서
```

### 산출물 → 위키

```
docs/wiki/pages/topics/<project-slug>-plan.md
  - 로드맵 요약 (strategist)
  - PRD 핵심 (prd-writer)
  - 유저 스토리 개요 (story-writer)
  - 스프린트 계획 (sprint-planner)
  - 기획 검증 결과

docs/wiki/log.md
  → [YYYY-MM-DD] decision | <project> plan approved
```

---

## Phase D: 실행 (16-fullstack-webapp 팀원)

기획서를 코드로 변환. PM이 fullstack-webapp 하네스의 4개 팀원 세션을 spawn.

### 팀원 세션 구성

| 순서 | 팀원 세션 | 하네스 역할 | 하는 일 |
|------|----------|-----------|--------|
| D-1 | `architect` | 16-fullstack-webapp | 시스템 아키텍처, API 설계, DB 모델링 |
| D-2a | `frontend-dev` | 16-fullstack-webapp | React/Next.js UI, 라우팅, 상태 관리 |
| D-2b | `backend-dev` | 16-fullstack-webapp | API 구현, 인증, 비즈니스 로직 |
| D-2c | `devops` | 16-fullstack-webapp | CI/CD, 인프라, 배포 |
| D-3 | `qa` | 16-fullstack-webapp | 테스트 전략, 코드 품질 검증 |

### PM ↔ 팀원 소통 흐름

```
PM → architect: "이 PRD로 아키텍처 설계해줘" + plan 페이지
  ← architect: 아키텍처 + API spec + DB schema

PM → frontend-dev + backend-dev + devops: (병렬) "구현해줘" + 아키텍처
  ← 각 팀원: 구현 결과

PM → qa: "검증해줘" + 전체 산출물
  ← qa: 테스트 보고서 + 이슈 목록
```

### 산출물 → 위키

```
docs/wiki/pages/topics/<project-slug>-architecture.md
  - 시스템 아키텍처 (architect)
  - API 설계 요약 (architect)
  - 기술 결정 사항 (architect + devs)

docs/wiki/log.md
  → [YYYY-MM-DD] decision | <project> architecture decisions
```

---

## 포트폴리오 관리

### list-ideas

PM이 위키 index에서 `<project-slug>-*` 페이지를 검색해서 프로젝트별 진행 상태 표시:

| 프로젝트 | Phase A | Phase B | Phase C | Phase D |
|----------|---------|---------|---------|---------|
| my-app   | ✅      | ✅      | 🔄      | ⬜      |
| other    | ✅      | ⬜      | ⬜      | ⬜      |

### compare

두 프로젝트의 위키 페이지를 읽어 4차원 비교:
- 비전/가치 (concept 페이지)
- 시장 환경 (validation 페이지)
- 기술 복잡도 (architecture 페이지)
- 리스크 (validation 리스크 섹션)

비교 결과도 위키에 남긴다: `pages/comparisons/<slug-a>-vs-<slug-b>.md`

---

## 위키 연동 규칙

1. **각 Phase 완료 시** 해당 위키 페이지 생성/갱신
2. **주요 결정마다** `log.md`에 decision 엔트리 추가
3. **팀원 산출물은 원본 보존** — 팀원이 만든 상세 문서는 `_workspace/`에, 위키에는 요약+링크
4. **Phase 간 연결** — 각 위키 페이지의 `related` 필드로 같은 프로젝트 페이지 상호 링크
5. **위키 frontmatter** — category: `topics`, tags에 프로젝트 슬러그 포함

## PM이 하는 것 vs 안 하는 것

| PM이 하는 것 | PM이 안 하는 것 |
|-------------|---------------|
| 사용자 의도 파악 | 시장 분석 (→ market-analyst) |
| 적절한 팀원 선택·spawn | 기술 추정 (→ business-modeler, architect) |
| 팀원에게 컨텍스트 전달 | MVP 설계 (→ mvp-architect) |
| 팀원 답변을 사용자에게 종합 보고 | 리스크 판단 (→ launch-reviewer) |
| Phase 전환 결정 (사용자와 합의) | PRD 작성 (→ prd-writer) |
| 위키 기록 지시 | 아키텍처 설계 (→ architect) |
| Go/Pivot/Kill 선택지 제시 | 코드 작성 (→ devs) |
