---
name: language-patterns
description: 언어별 패턴 확장 스킬. Python (async, testing, packaging, performance, uv) + JS/TS (advanced types, Node.js, testing, modern JS). harness dev 역할 공통 참조.
---

# Language Patterns — 언어별 패턴 확장 스킬

harness의 모든 dev 역할이 참조하는 Python/JS/TS 패턴 지식.
wshobson/agents python-development (5) + javascript-typescript (4) = 9개 스킬에서 추출.

## 트리거

- Python/JS/TS 코드 작성, 리뷰 시
- "async", "타입", "테스트 패턴", "패키징"
- 성능 최적화, 의존성 관리 논의 시

---

## Part A: Python 패턴

### 1. Async Python

```python
# asyncio 기본 패턴
import asyncio
from contextlib import asynccontextmanager

# 동시 실행 (여러 LLM 호출)
async def parallel_llm_calls(prompts: list[str]) -> list[str]:
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(call_llm(p)) for p in prompts]
    return [t.result() for t in tasks]

# 세마포어로 동시성 제한
sem = asyncio.Semaphore(5)  # 최대 5개 동시 요청

async def rate_limited_call(prompt: str) -> str:
    async with sem:
        return await call_llm(prompt)

# 비동기 컨텍스트 매니저
@asynccontextmanager
async def db_transaction(pool):
    conn = await pool.acquire()
    tx = await conn.begin()
    try:
        yield conn
        await tx.commit()
    except Exception:
        await tx.rollback()
        raise
    finally:
        await pool.release(conn)

# 비동기 제너레이터 (스트리밍)
async def stream_response(session_id: str):
    async for chunk in llm.stream(prompt):
        yield chunk
        await save_chunk(session_id, chunk)
```

### 2. Python 테스팅

```python
# pytest 구조
tests/
├── conftest.py          # 공통 fixture
├── unit/
│   ├── test_session.py
│   └── test_template.py
├── integration/
│   ├── test_api.py
│   └── test_db.py
└── e2e/
    └── test_workflow.py

# Fixture 패턴
import pytest
from unittest.mock import AsyncMock

@pytest.fixture
def mock_llm():
    llm = AsyncMock()
    llm.complete.return_value = "test response"
    return llm

@pytest.fixture
async def db_session():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSession(test_engine) as session:
        yield session
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

# 파라메트릭 테스트
@pytest.mark.parametrize("role,expected", [
    ("user", True),
    ("assistant", True),
    ("system", True),
    ("invalid", False),
])
def test_valid_role(role, expected):
    assert is_valid_role(role) == expected
```

### 3. Python 패키징 (uv 권장)

```bash
# uv — Rust 기반 초고속 패키지 매니저
uv init aice-api            # 프로젝트 초기화
uv add fastapi uvicorn      # 의존성 추가
uv add --dev pytest ruff    # 개발 의존성
uv sync                     # lockfile → 설치
uv run pytest               # 가상환경 내 실행
uv run uvicorn main:app     # 서버 실행

# pyproject.toml
[project]
name = "aice-api"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115",
    "anthropic>=0.40",
]

[project.optional-dependencies]
dev = ["pytest>=8", "ruff>=0.8", "mypy>=1.13"]
```

### 4. Python 성능

```python
# 프로파일링
import cProfile
cProfile.run('main()', 'output.prof')  # → snakeviz output.prof

# 메모리 최적화
from __future__ import annotations  # PEP 563: 지연 어노테이션
from dataclasses import dataclass, field
from functools import lru_cache

@dataclass(slots=True, frozen=True)  # slots=True → 메모리 절약
class Message:
    id: str
    content: str
    role: str

# 대량 데이터 처리
async def process_messages_batched(messages: list, batch_size=100):
    for i in range(0, len(messages), batch_size):
        batch = messages[i:i+batch_size]
        await asyncio.gather(*[process(m) for m in batch])
```

---

## Part B: JavaScript/TypeScript 패턴

### 1. TypeScript 고급 타입

```typescript
// 유틸리티 타입 활용
type SessionCreate = Pick<Session, 'title' | 'templateId'>;
type SessionUpdate = Partial<Pick<Session, 'title' | 'status'>>;
type SessionView = Omit<Session, 'internalState'>;

// Discriminated Union (메시지 타입)
type Message =
  | { role: 'user'; content: string }
  | { role: 'assistant'; content: string; model: string; tokens: number }
  | { role: 'system'; content: string }
  | { role: 'tool'; toolCallId: string; result: unknown };

function formatMessage(msg: Message): string {
  switch (msg.role) {
    case 'assistant': return `[${msg.model}] ${msg.content}`;
    case 'tool': return `Tool ${msg.toolCallId}: ${JSON.stringify(msg.result)}`;
    default: return msg.content;
  }
}

// Template Literal Types
type EventName = `session.${string}.${string}`;
type HttpMethod = 'GET' | 'POST' | 'PATCH' | 'DELETE';
type ApiRoute = `/${string}`;

// Branded Types (타입 안전한 ID)
type SessionId = string & { __brand: 'SessionId' };
type UserId = string & { __brand: 'UserId' };

function createSessionId(id: string): SessionId {
  return id as SessionId;
}
```

### 2. Node.js 백엔드 패턴

```typescript
// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  server.close();
  await db.end();
  await redis.quit();
  process.exit(0);
});

// 에러 처리 미들웨어
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof ValidationError) {
    return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: err.message } });
  }
  if (err instanceof AuthError) {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid credentials' } });
  }
  console.error('Unhandled error:', err);
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' } });
});

// 스트리밍 응답 (LLM)
app.post('/api/sessions/:id/messages', async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const stream = await llm.stream(req.body.content);
  for await (const chunk of stream) {
    res.write(`data: ${JSON.stringify(chunk)}\n\n`);
  }
  res.write('data: [DONE]\n\n');
  res.end();
});
```

### 3. JS/TS 테스팅

```typescript
// Vitest 권장 (Jest 호환, ESM 네이티브, 빠름)
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('SessionService', () => {
  let service: SessionService;
  let mockRepo: MockProxy<SessionRepository>;

  beforeEach(() => {
    mockRepo = mock<SessionRepository>();
    service = new SessionService(mockRepo);
  });

  it('creates session with default status', async () => {
    mockRepo.save.mockResolvedValue(undefined);

    const session = await service.create({ title: 'Test' });

    expect(session.status).toBe('active');
    expect(mockRepo.save).toHaveBeenCalledOnce();
  });

  it('throws when session not found', async () => {
    mockRepo.findById.mockResolvedValue(null);

    await expect(service.get('nonexistent'))
      .rejects.toThrow('Session not found');
  });
});
```

### 4. Modern JS 패턴

```typescript
// Structured Clone (깊은 복사)
const copy = structuredClone(original);

// Promise.allSettled (실패해도 계속)
const results = await Promise.allSettled([
  fetchUser(id),
  fetchSessions(id),
  fetchPreferences(id),
]);
const [user, sessions, prefs] = results.map(r =>
  r.status === 'fulfilled' ? r.value : null
);

// AbortController (취소)
const controller = new AbortController();
setTimeout(() => controller.abort(), 30000);
const response = await fetch(url, { signal: controller.signal });

// using (Explicit Resource Management, TC39 Stage 3)
{
  await using conn = await pool.getConnection();
  await conn.query('SELECT ...');
} // 자동 release
```

## 출처

wshobson/agents python-development (5), javascript-typescript (4) 플러그인 9개 스킬 지식 추출 및 Aice harness 형태로 재구성.
