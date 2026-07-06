---
name: db-patterns
description: 데이터베이스 설계 확장 스킬. PostgreSQL 테이블 설계, 인덱싱, 마이그레이션 패턴. harness architect/backend-dev가 참조.
---

# DB Patterns — 데이터베이스 설계 확장 스킬

harness의 architect, backend-dev, database 역할이 참조하는 DB 패턴.
wshobson/agents database-design 스킬에서 추출.

## 트리거

- DB 스키마 설계, 마이그레이션 논의 시
- "테이블 설계", "인덱스", "마이그레이션", "PostgreSQL"
- 데이터 모델링 리뷰 시

---

## 1. PostgreSQL 테이블 설계 원칙

### 명명 규칙

```sql
-- 테이블: 복수형 snake_case
CREATE TABLE sessions (...);
CREATE TABLE session_messages (...);

-- 컬럼: snake_case, 약어 금지
user_id (O) vs uid (X)
created_at (O) vs crt_dt (X)

-- PK: id (테이블명_id는 FK에서 사용)
-- FK: {참조테이블 단수형}_id
```

### Aice 세션 트리 스키마 예시

```sql
-- 세션 (자기참조 트리)
CREATE TABLE sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id     UUID REFERENCES sessions(id),
  user_id       UUID NOT NULL REFERENCES users(id),
  template_id   VARCHAR(100),    -- harness template slug
  title         VARCHAR(500) NOT NULL,
  status        VARCHAR(20) NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'completed', 'archived')),
  role_name     VARCHAR(100),    -- 팀원 역할명 (null = PM)
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 세션 트리 인덱스
CREATE INDEX idx_sessions_parent ON sessions(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_sessions_user_status ON sessions(user_id, status);

-- 메시지
CREATE TABLE messages (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID NOT NULL REFERENCES sessions(id),
  role          VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
  content       TEXT NOT NULL,
  model         VARCHAR(100),
  tokens_input  INTEGER,
  tokens_output INTEGER,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_session_created ON messages(session_id, created_at);
```

### 인덱싱 전략

| 패턴 | 사용 시점 | 예시 |
|------|----------|------|
| **B-tree** (기본) | 등호, 범위, 정렬 | `WHERE status = 'active'` |
| **Partial** | 특정 조건만 | `WHERE parent_id IS NOT NULL` |
| **GIN** | JSONB, 배열, 전문검색 | `WHERE tags @> '["ai"]'` |
| **Covering** | 인덱스만으로 쿼리 완료 | `INCLUDE (title, status)` |
| **Composite** | 다중 조건 | `(user_id, status, created_at)` |

```sql
-- 부분 인덱스: 활성 세션만 (대부분 쿼리가 active만 조회)
CREATE INDEX idx_sessions_active ON sessions(user_id, created_at DESC)
  WHERE status = 'active';

-- JSONB 인덱스: 메타데이터 검색
ALTER TABLE sessions ADD COLUMN metadata JSONB DEFAULT '{}';
CREATE INDEX idx_sessions_metadata ON sessions USING GIN (metadata);

-- Covering 인덱스: 목록 조회 최적화
CREATE INDEX idx_sessions_list ON sessions(user_id, created_at DESC)
  INCLUDE (title, status, role_name);
```

---

## 2. 마이그레이션 패턴

### 안전한 마이그레이션 규칙

1. **컬럼 추가**: 항상 `DEFAULT` 또는 `NULL` 허용 → 테이블 잠금 없음
2. **컬럼 삭제**: 코드에서 먼저 제거 → 다음 배포에서 컬럼 삭제
3. **컬럼 이름 변경**: 하지 않는다. 새 컬럼 추가 → 데이터 복사 → 옛 컬럼 삭제
4. **인덱스 생성**: 항상 `CONCURRENTLY` (테이블 잠금 방지)
5. **NOT NULL 추가**: DEFAULT 먼저 설정 → 기존 행 채우기 → 제약 추가

```sql
-- 안전한 인덱스 생성
CREATE INDEX CONCURRENTLY idx_name ON table(column);

-- 안전한 NOT NULL 추가
ALTER TABLE sessions ADD COLUMN summary TEXT DEFAULT '';
UPDATE sessions SET summary = '' WHERE summary IS NULL;
ALTER TABLE sessions ALTER COLUMN summary SET NOT NULL;

-- 안전한 타입 변경 (varchar 확장만 잠금 없음)
ALTER TABLE sessions ALTER COLUMN title TYPE VARCHAR(1000);  -- 확장: OK
-- 축소, 타입 변경: 새 컬럼 방식 사용
```

### 마이그레이션 도구

```bash
# Prisma (TypeScript)
npx prisma migrate dev --name add_session_summary
npx prisma migrate deploy  # 프로덕션

# Drizzle (TypeScript, SQL-first)
npx drizzle-kit generate
npx drizzle-kit push

# Alembic (Python)
alembic revision --autogenerate -m "add session summary"
alembic upgrade head
```

---

## 3. 쿼리 최적화

```sql
-- CTE로 세션 트리 조회
WITH RECURSIVE session_tree AS (
  SELECT id, parent_id, title, role_name, 0 AS depth
  FROM sessions WHERE id = :root_id

  UNION ALL

  SELECT s.id, s.parent_id, s.title, s.role_name, st.depth + 1
  FROM sessions s
  JOIN session_tree st ON s.parent_id = st.id
)
SELECT * FROM session_tree ORDER BY depth, created_at;

-- EXPLAIN ANALYZE 필수 확인
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
  SELECT * FROM messages WHERE session_id = :id ORDER BY created_at;
```

## 출처

wshobson/agents database-design 플러그인 postgresql 스킬 + framework-migration database-migration 스킬 지식 추출 및 Aice harness 형태로 재구성.
