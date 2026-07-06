---
name: devops-patterns
description: DevOps 확장 스킬. CI/CD 파이프라인, GitHub Actions, 시크릿 관리, Prometheus/Grafana, 분산 트레이싱, SLO, 인시던트 대응. harness devops 역할이 참조.
---

# DevOps Patterns — DevOps 확장 스킬

harness의 devops, SRE 역할이 참조하는 DevOps 지식.
wshobson/agents CI/CD (3) + Observability (4) + Incident (3) = 10개 스킬에서 추출.

## 트리거

- CI/CD 파이프라인, 배포 전략 논의 시
- 모니터링, 알림, SLO 설정 시
- 인시던트 대응, 포스트모템 작성 시
- "GitHub Actions", "Prometheus", "배포", "알림"

---

## 1. CI/CD 파이프라인 설계

### 다단계 파이프라인 구조

```
[Commit] → [Build] → [Test] → [Security] → [Stage] → [Approve] → [Prod]
             │          │         │
             │          │         └─ SAST, 의존성 스캔, 시크릿 스캔
             │          └─ Unit, Integration, E2E
             └─ Lint, Type check, Docker build
```

### 배포 전략

| 전략 | 다운타임 | 롤백 속도 | 리스크 | 적합 상황 |
|------|---------|----------|--------|----------|
| **Rolling** | 없음 | 느림 | 중간 | 일반 서비스 |
| **Blue-Green** | 없음 | 즉시 | 낮음 | 스테이트리스 서비스 |
| **Canary** | 없음 | 빠름 | 최저 | 대규모 사용자 |
| **Feature Flag** | 없음 | 즉시 | 최저 | 점진적 출시 |

### GitHub Actions 패턴

```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm run typecheck
      - run: npm run lint
      - run: npm test -- --coverage
      - uses: actions/upload-artifact@v4
        with: { name: coverage, path: coverage/ }

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: returntocorp/semgrep-action@v1
        with: { config: 'p/security-audit p/owasp-top-ten' }
      - run: npm audit --audit-level=high

  deploy-staging:
    needs: [test, security]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh staging

  deploy-prod:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://aice.app
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh production
```

### 시크릿 관리

```yaml
# GitHub Actions 시크릿 사용
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

# 시크릿 스캔 (pre-commit)
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

**원칙:** 시크릿은 코드에 절대 하드코딩 하지 않는다. `.env.local` (gitignore), GitHub Secrets, 또는 Vault 사용.

---

## 2. Prometheus + Grafana

### Prometheus 설정

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'aice-api'
    static_configs:
      - targets: ['api:3000']
    metrics_path: /metrics

rule_files:
  - 'rules/*.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

### 핵심 메트릭 (RED Method)

```typescript
// Express/Fastify 미들웨어
import { Counter, Histogram } from 'prom-client';

const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route'],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
});

// LLM 호출 전용 메트릭
const llmTokensUsed = new Counter({
  name: 'llm_tokens_total',
  help: 'LLM tokens consumed',
  labelNames: ['provider', 'model', 'type'],  // type: input/output
});

const llmLatency = new Histogram({
  name: 'llm_request_duration_seconds',
  help: 'LLM API call duration',
  labelNames: ['provider', 'model'],
  buckets: [0.5, 1, 2, 5, 10, 30],
});
```

### 알림 규칙

```yaml
groups:
  - name: aice-alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels: { severity: critical }
        annotations:
          summary: "Error rate > 5% for 5 minutes"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels: { severity: warning }

      - alert: LLMCostSpike
        expr: increase(llm_tokens_total[1h]) > 1000000
        labels: { severity: warning }
        annotations:
          summary: "LLM token usage spike: >1M tokens/hour"
```

---

## 3. 분산 트레이싱

### OpenTelemetry 설정 (Node.js)

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({ url: 'http://tempo:4318/v1/traces' }),
  instrumentations: [new HttpInstrumentation()],
  serviceName: 'aice-api',
});
sdk.start();

// 커스텀 스팬 (LLM 호출 추적)
import { trace } from '@opentelemetry/api';
const tracer = trace.getTracer('aice-llm');

async function callLLM(prompt: string) {
  return tracer.startActiveSpan('llm.completion', async (span) => {
    span.setAttribute('llm.provider', 'anthropic');
    span.setAttribute('llm.model', 'claude-sonnet-4-6');
    span.setAttribute('llm.prompt_tokens', prompt.length);
    try {
      const result = await anthropic.messages.create({ /* ... */ });
      span.setAttribute('llm.completion_tokens', result.usage.output_tokens);
      return result;
    } catch (error) {
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

---

## 4. SLO (Service Level Objectives)

### SLI/SLO 정의

| SLI | 측정 | SLO 목표 |
|-----|------|---------|
| **가용성** | 성공 요청 / 전체 요청 | 99.9% (월 43.8분 다운) |
| **지연시간** | P95 응답 시간 | < 500ms (API), < 2s (LLM 스트림 시작) |
| **처리량** | 초당 요청 수 | > 100 RPS |
| **정확성** | 올바른 LLM 응답 비율 | > 95% (자동 평가) |

### 에러 버짓

```
월간 에러 버짓 = 1 - SLO = 0.1% = 43.8분

소진율 = 사용된 에러 버짓 / 전체 에러 버짓
  - 소진율 > 50% at mid-month → 경고
  - 소진율 > 80% → 변경 동결
  - 소진율 100% → 안정성 복구에 집중
```

---

## 5. 인시던트 대응

### 포스트모템 템플릿

```markdown
# 인시던트 포스트모템: [제목]

**날짜:** YYYY-MM-DD
**심각도:** SEV-1/2/3
**영향:** [영향받은 사용자 수, 기간]
**담당:** [이름]

## 타임라인
- HH:MM — [이벤트]
- HH:MM — [감지]
- HH:MM — [대응 시작]
- HH:MM — [완화]
- HH:MM — [복구]

## 근본 원인
[비난 없이 기술적 원인만]

## 교훈
- 잘한 것: ...
- 개선할 것: ...

## 후속 조치
- [ ] [조치 1] — 담당: [이름], 기한: [날짜]
- [ ] [조치 2] — 담당: [이름], 기한: [날짜]
```

### 런북 구조

```
1. 증상 확인 — 어떤 알림이 왔는가?
2. 영향 범위 — 몇 명의 사용자가 영향받는가?
3. 심각도 판단 — SEV-1 (전면 장애), SEV-2 (부분), SEV-3 (경미)
4. 즉시 완화 — 롤백? 스케일업? 페일오버?
5. 근본 원인 조사 — 로그, 트레이스, 메트릭 확인
6. 수정 배포 — hotfix or rollback
7. 포스트모템 — 24시간 내 작성
```

## 출처

wshobson/agents cicd-automation (3), observability-monitoring (4), incident-response (3) 플러그인 10개 스킬 지식 추출 및 Aice harness 형태로 재구성.
