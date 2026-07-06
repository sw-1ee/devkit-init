---
name: backend-patterns
description: 백엔드 아키텍처 확장 스킬. API 설계, 클린/헥사고널 아키텍처, 마이크로서비스, CQRS, 이벤트소싱, Saga, Projection 패턴. harness architect/backend-dev가 참조.
---

# Backend Patterns — 백엔드 아키텍처 확장 스킬

harness의 architect, backend-dev 역할이 참조하는 백엔드 패턴 지식.
wshobson/agents backend-development 7개 스킬에서 추출.

## 트리거

- API 설계, 백엔드 아키텍처 논의 시
- "마이크로서비스", "CQRS", "이벤트소싱", "saga"
- 백엔드 코드 리뷰 시 아키텍처 패턴 참조 필요 시

---

## 1. API 설계 원칙

### REST 설계

```
리소스 중심 URL:
  GET    /api/v1/users          # 목록
  POST   /api/v1/users          # 생성
  GET    /api/v1/users/:id      # 조회
  PATCH  /api/v1/users/:id      # 부분 수정
  DELETE /api/v1/users/:id      # 삭제

중첩 리소스:
  GET    /api/v1/users/:id/sessions    # 사용자의 세션 목록
  POST   /api/v1/sessions              # 세션 생성 (독립 리소스)
```

### 페이지네이션

```typescript
// 커서 기반 (권장)
interface PaginatedResponse<T> {
  data: T[];
  cursor: { next: string | null; prev: string | null };
  meta: { total: number; hasMore: boolean };
}

// GET /api/v1/sessions?cursor=abc123&limit=20
```

### 에러 응답 표준

```typescript
interface ApiError {
  error: {
    code: string;        // "VALIDATION_ERROR"
    message: string;     // 사용자 표시용
    details?: Record<string, string[]>;  // 필드별 에러
    requestId: string;   // 추적용
  };
}
// HTTP 상태: 400 검증, 401 인증, 403 인가, 404 없음, 409 충돌, 429 제한, 500 서버
```

### GraphQL 설계

```graphql
type Query {
  session(id: ID!): Session
  sessions(filter: SessionFilter, pagination: CursorInput): SessionConnection!
}

type SessionConnection {
  edges: [SessionEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type Mutation {
  createSession(input: CreateSessionInput!): CreateSessionPayload!
}
```

---

## 2. 아키텍처 패턴

### 클린 아키텍처

```
바깥 → 안쪽 의존성만 허용:

[Infrastructure] → [Interface Adapters] → [Use Cases] → [Entities]
  DB, API, UI       Controllers, Gateways   비즈니스 규칙    도메인 모델

디렉토리 구조:
src/
├── domain/           # 엔터티, 값 객체, 도메인 이벤트
│   ├── entities/
│   ├── value-objects/
│   └── events/
├── application/      # 유스케이스, 포트(인터페이스)
│   ├── use-cases/
│   └── ports/
├── infrastructure/   # 어댑터 구현 (DB, 외부 API)
│   ├── repositories/
│   ├── services/
│   └── config/
└── interface/        # HTTP 컨트롤러, WebSocket
    ├── http/
    └── ws/
```

### 헥사고널 아키텍처 (Ports & Adapters)

```typescript
// Port (인터페이스)
interface SessionRepository {
  findById(id: string): Promise<Session | null>;
  save(session: Session): Promise<void>;
}

// Adapter (구현)
class PostgresSessionRepository implements SessionRepository {
  async findById(id: string) { /* SQL */ }
  async save(session: Session) { /* SQL */ }
}

// 테스트용 Adapter
class InMemorySessionRepository implements SessionRepository {
  private store = new Map<string, Session>();
  async findById(id: string) { return this.store.get(id) ?? null; }
  async save(session: Session) { this.store.set(session.id, session); }
}
```

### DDD 전술 패턴

```typescript
// Aggregate Root
class Session {
  private events: DomainEvent[] = [];

  sendMessage(content: string, role: 'user' | 'assistant'): Message {
    const message = new Message(this.id, content, role);
    this.events.push(new MessageSentEvent(this.id, message.id));
    return message;
  }

  spawnChild(templateId: string): Session {
    const child = new Session({ parentId: this.id, templateId });
    this.events.push(new SessionSpawnedEvent(this.id, child.id));
    return child;
  }

  pullEvents(): DomainEvent[] {
    const events = [...this.events];
    this.events = [];
    return events;
  }
}
```

---

## 3. 마이크로서비스 패턴

### 서비스 분해 기준

| 기준 | 설명 | Aice 적용 |
|------|------|----------|
| 비즈니스 능력 | 비즈니스 기능 단위 | 세션 관리, LLM 호출, 사용자 관리 |
| 하위 도메인 | DDD bounded context | 대화, 팀플릿, 과금 |
| Strangler Fig | 점진적 분리 | 모놀리스 → 점진적 서비스화 |

### API Gateway 패턴

```
클라이언트 → [API Gateway] → 세션 서비스
                           → LLM 서비스
                           → 사용자 서비스
                           → 알림 서비스

게이트웨이 역할: 라우팅, 인증, rate limiting, 응답 집계
```

### 비동기 통신 (이벤트 드리븐)

```typescript
// 이벤트 발행
await eventBus.publish('session.message.sent', {
  sessionId: session.id,
  messageId: message.id,
  parentSessionId: session.parentId,
  timestamp: new Date().toISOString(),
});

// 이벤트 구독 (다른 서비스)
eventBus.subscribe('session.message.sent', async (event) => {
  // PM 세션에 팀원 메시지 전달
  if (event.parentSessionId) {
    await notifyParentSession(event);
  }
});
```

### 복원력 패턴

| 패턴 | 용도 | 구현 |
|------|------|------|
| **Circuit Breaker** | 연쇄 장애 방지 | 실패율 > 50% → open → 30초 후 half-open |
| **Retry + Backoff** | 일시적 장애 복구 | 최대 3회, 지수 백오프 (100ms, 200ms, 400ms) |
| **Bulkhead** | 격리 | 서비스별 커넥션 풀 분리 |
| **Timeout** | 무한 대기 방지 | LLM 호출 30초, DB 5초, 내부 API 10초 |

---

## 4. CQRS (Command Query Responsibility Segregation)

```typescript
// Command 측
interface Command { type: string; payload: unknown; }

class CreateSessionCommand implements Command {
  type = 'CreateSession';
  constructor(public payload: { userId: string; templateId?: string }) {}
}

class CommandBus {
  async dispatch(command: Command): Promise<void> {
    const handler = this.handlers.get(command.type);
    await handler.execute(command);
  }
}

// Query 측 (별도 읽기 모델)
class SessionQueryService {
  async getSessionTree(rootId: string): Promise<SessionTreeView> {
    // 읽기 최적화된 denormalized 뷰
    return this.readDb.query(`
      WITH RECURSIVE tree AS (
        SELECT * FROM session_views WHERE id = $1
        UNION ALL
        SELECT sv.* FROM session_views sv
        JOIN tree t ON sv.parent_id = t.id
      ) SELECT * FROM tree
    `, [rootId]);
  }
}
```

---

## 5. 이벤트 소싱

```typescript
// 이벤트 저장
interface DomainEvent {
  eventId: string;
  aggregateId: string;
  type: string;
  data: unknown;
  version: number;
  timestamp: Date;
}

// PostgreSQL 이벤트 스토어
CREATE TABLE events (
  event_id     UUID PRIMARY KEY,
  aggregate_id UUID NOT NULL,
  type         VARCHAR(255) NOT NULL,
  data         JSONB NOT NULL,
  version      INTEGER NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (aggregate_id, version)  -- 낙관적 동시성
);

// Aggregate 복원
class SessionAggregate {
  static fromEvents(events: DomainEvent[]): Session {
    const session = new Session();
    for (const event of events) {
      session.apply(event);  // 상태 재구성
    }
    return session;
  }
}

// 스냅샷 (성능 최적화)
// 이벤트 100개마다 스냅샷 저장 → 복원 시 스냅샷 + 이후 이벤트만
```

---

## 6. Saga 오케스트레이션

```typescript
// 오케스트레이션 Saga (PM이 조율하는 것과 유사)
class SessionCreationSaga {
  steps = [
    {
      name: 'createSession',
      execute: (ctx) => sessionService.create(ctx.input),
      compensate: (ctx) => sessionService.delete(ctx.sessionId),
    },
    {
      name: 'assignTemplate',
      execute: (ctx) => templateService.assign(ctx.sessionId, ctx.templateId),
      compensate: (ctx) => templateService.unassign(ctx.sessionId),
    },
    {
      name: 'notifyParent',
      execute: (ctx) => notificationService.notifyParent(ctx.parentId, ctx.sessionId),
      compensate: (ctx) => {}, // 알림은 보상 불필요
    },
  ];

  async run(input) {
    const completed = [];
    for (const step of this.steps) {
      try {
        await step.execute({ ...input, ...this.context });
        completed.push(step);
      } catch (error) {
        // 역순 보상
        for (const s of completed.reverse()) {
          await s.compensate(this.context);
        }
        throw new SagaFailedError(step.name, error);
      }
    }
  }
}
```

---

## 7. Projection 패턴

```typescript
// 이벤트 → 읽기 모델 동기화
class SessionTreeProjection {
  async handle(event: DomainEvent) {
    switch (event.type) {
      case 'SessionCreated':
        await this.db.insert('session_views', {
          id: event.aggregateId,
          parent_id: event.data.parentId,
          status: 'active',
          message_count: 0,
        });
        break;

      case 'MessageSent':
        await this.db.increment('session_views',
          { id: event.aggregateId },
          { message_count: 1 }
        );
        break;

      case 'SessionCompleted':
        await this.db.update('session_views',
          { id: event.aggregateId },
          { status: 'completed', completed_at: event.timestamp }
        );
        break;
    }
    await this.saveCheckpoint(event.eventId);
  }
}
```

## 출처

wshobson/agents backend-development 플러그인 7개 스킬 (api-design-principles, architecture-patterns, microservices-patterns, cqrs-implementation, event-store-design, saga-orchestration, projection-patterns) 지식 추출 및 Aice harness 형태로 재구성.
