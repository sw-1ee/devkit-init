---
name: team-parallel
description: 팀원 병렬 실행 확장 스킬. 다중 리뷰어, 병렬 디버깅, 태스크 조율, 팀 구성 패턴. idea-pipeline 및 PM 세션이 참조.
---

# Team Parallel — 팀원 병렬 실행 스킬

idea-pipeline의 PM이 팀원 세션을 병렬로 실행할 때 참조하는 패턴.
wshobson/agents agent-teams 6개 스킬에서 추출.

## 트리거

- 여러 팀원 동시 실행 필요 시
- "병렬 리뷰", "동시 작업", "팀 리뷰"
- idea-pipeline Phase B/C/D 팀원 spawn 시

---

## 1. 다중 리뷰어 패턴

### 관점별 리뷰어 구성

```
[PM] ──┬── [architecture-reviewer]  → 구조, 의존성, 확장성
       ├── [security-reviewer]      → 취약점, 인증/인가, 데이터 보호
       ├── [performance-reviewer]   → 복잡도, 캐싱, DB 쿼리
       └── [ux-reviewer]           → 사용성, 접근성, 일관성
```

### 실행 규칙

1. **독립 실행** — 리뷰어 간 의존성 없음 → 병렬 spawn
2. **동일 컨텍스트** — 모든 리뷰어에게 같은 코드/PR diff 전달
3. **구조화 출력** — 각 리뷰어가 동일 포맷으로 보고

```typescript
interface ReviewResult {
  reviewer: string;
  verdict: 'approve' | 'request-changes' | 'comment';
  issues: Array<{
    severity: 'critical' | 'major' | 'minor' | 'nit';
    file: string;
    line?: number;
    description: string;
    suggestion?: string;
  }>;
  summary: string;
}
```

### PM 종합 규칙

```
critical 1개 이상 → 머지 불가
major 3개 이상 → 머지 불가
리뷰어 50% 이상 request-changes → 머지 불가
전원 approve → 머지 가능
```

---

## 2. 병렬 디버깅

### 가설 기반 병렬 조사

```
[PM: 버그 보고 접수]
  │
  ├── [hypothesis-1]: "인증 토큰 만료 문제"
  │     → auth 로그 확인, 토큰 라이프사이클 추적
  │
  ├── [hypothesis-2]: "DB 커넥션 풀 고갈"
  │     → 커넥션 메트릭 확인, 슬로우 쿼리 조회
  │
  └── [hypothesis-3]: "외부 API 타임아웃"
        → 외부 API 응답 시간, 서킷 브레이커 상태 확인

[PM: 결과 종합]
  → hypothesis-2 확인: 커넥션 누수 발견
  → 수정 담당 할당
```

### 실행 패턴

```typescript
// PM이 가설별 팀원 spawn
const hypotheses = [
  { id: 'auth', assignee: 'backend-dev', task: 'Check auth token lifecycle and logs' },
  { id: 'db', assignee: 'backend-dev', task: 'Check connection pool metrics and slow queries' },
  { id: 'external', assignee: 'devops', task: 'Check external API latency and circuit breaker state' },
];

// 병렬 실행 → 결과 수집
const results = await Promise.all(
  hypotheses.map(h => spawnTeammate(h.assignee, h.task))
);

// 근본 원인 판별
const rootCause = results.find(r => r.confirmed);
```

---

## 3. 병렬 기능 개발

### 의존성 기반 분할

```
[architect: API 설계 + DB 스키마]  (먼저, 순차)
          │
          ├── [frontend-dev: UI 구현]      ─┐
          ├── [backend-dev: API 구현]       ─┤ 병렬
          └── [devops: 인프라 + CI/CD]      ─┘
                    │
          [qa: 통합 테스트]  (마지막, 순차)
```

### 인터페이스 계약

```typescript
// architect가 먼저 정의 → frontend-dev와 backend-dev가 각자 구현
interface SessionAPI {
  'GET /api/sessions': {
    query: { status?: string; cursor?: string; limit?: number };
    response: PaginatedResponse<SessionView>;
  };
  'POST /api/sessions': {
    body: { title: string; templateId?: string };
    response: Session;
  };
  'POST /api/sessions/:id/messages': {
    body: { content: string };
    response: ReadableStream<MessageChunk>;  // SSE
  };
}

// frontend-dev는 이 계약 기반으로 mock API로 개발
// backend-dev는 이 계약 기반으로 실제 API 구현
// 둘 다 완료 후 통합
```

---

## 4. 태스크 조율 전략

### 의존성 그래프

```
DAG (Directed Acyclic Graph) 기반:

  A (독립) ──→ C (A 의존)
  B (독립) ──→ C (B 의존)
  C ──→ D

실행:
  Wave 1: A, B (병렬)
  Wave 2: C (A,B 완료 후)
  Wave 3: D (C 완료 후)
```

### 진행 상태 추적

```
| 팀원 | 태스크 | 상태 | 블로커 |
|------|--------|------|--------|
| frontend-dev | UI 컴포넌트 | 🔄 진행중 | - |
| backend-dev | API 구현 | 🔄 진행중 | - |
| devops | CI/CD | ✅ 완료 | - |
| qa | 통합 테스트 | ⏳ 대기 | frontend-dev, backend-dev |
```

### 교착 상태 방지

1. **타임아웃** — 팀원 응답 없으면 PM이 개입 (30분)
2. **에스컬레이션** — 블로커 발생 시 즉시 PM에 보고
3. **우선순위 재조정** — critical path 팀원에 리소스 집중

---

## 5. 팀 구성 패턴 (idea-pipeline 연동)

### Phase별 병렬 구성

| Phase | 순차 | 병렬 | 총 세션 |
|-------|------|------|---------|
| **B: 검증** | market→biz→mvp→launch (순차) | - | 4 |
| **C: 기획** | strategy→prd→story→sprint (순차) | - | 4 |
| **D: 실행** | architect (순차) → fe+be+devops (병렬) → qa (순차) | fe, be, devops | 5 |

### 컨텍스트 전달 규칙

```
PM → 팀원 spawn 시 전달:
1. 위키 페이지 (이전 Phase 산출물)
2. 현재 태스크 상세
3. 인터페이스 계약 (있으면)
4. 제약 조건/비기능 요구사항

팀원 → PM 보고 시 포함:
1. 태스크 완료 상태
2. 산출물 요약
3. 발견한 이슈/리스크
4. 다음 팀원에게 전달할 정보
```

## 출처

wshobson/agents agent-teams 플러그인 6개 스킬 (multi-reviewer-patterns, parallel-debugging, parallel-feature-development, task-coordination-strategies, team-communication-protocols, team-composition-patterns) 지식 추출 및 Aice idea-pipeline 연동 형태로 재구성.
