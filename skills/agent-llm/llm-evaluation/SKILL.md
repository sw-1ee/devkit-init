---
name: llm-evaluation
description: LLM 출력 품질 평가 확장 스킬. 자동 평가 파이프라인, 평가 지표, 벤치마크, A/B 테스트. Aice QA 및 품질 관리용.
---

# LLM Evaluation — LLM 출력 품질 평가 스킬

Aice가 LLM 플랫폼이므로, LLM 출력의 품질을 체계적으로 평가하는 프레임워크.
wshobson/agents llm-evaluation 스킬에서 추출.

## 트리거

- LLM 응답 품질 평가, 프롬프트 최적화 효과 측정 시
- "평가", "evaluation", "품질 측정", "벤치마크"
- 모델 비교, A/B 테스트, 프롬프트 튜닝 시

---

## 1. 평가 지표

### 핵심 지표

| 지표 | 측정 대상 | 범위 | 계산 |
|------|----------|------|------|
| **Relevance** | 질문-답변 관련성 | 0-1 | LLM judge 또는 cosine similarity |
| **Faithfulness** | 환각 없음 (출처 기반) | 0-1 | 답변의 각 claim이 소스에 근거 |
| **Coherence** | 논리적 일관성 | 1-5 | LLM judge |
| **Helpfulness** | 실제 도움 됨 | 1-5 | 사용자 피드백 또는 LLM judge |
| **Toxicity** | 유해성 | 0-1 | 분류기 (낮을수록 좋음) |
| **Latency** | 응답 시간 | ms | TTFB + 전체 |
| **Cost** | 토큰 비용 | $ | input_tokens × rate + output_tokens × rate |

### Aice 특화 지표

| 지표 | 설명 |
|------|------|
| **Role Adherence** | 팀원이 할당된 역할에 맞게 응답하는가 (PM이 코드를 짜지 않는가) |
| **Context Utilization** | 제공된 컨텍스트를 얼마나 활용하는가 |
| **Instruction Following** | systemPrompt 지시 준수도 |
| **Inter-session Coherence** | PM-팀원 간 대화 일관성 |

---

## 2. 평가 방법

### LLM-as-Judge

```typescript
const JUDGE_PROMPT = `
You are evaluating an AI assistant's response.

**Question:** {question}
**Context provided:** {context}
**Response:** {response}

Rate on these criteria (1-5 each):
1. Relevance: Does it answer the question?
2. Faithfulness: Is it grounded in the context (no hallucination)?
3. Helpfulness: Would the user find this useful?
4. Coherence: Is it logically structured?

Output JSON: { "relevance": N, "faithfulness": N, "helpfulness": N, "coherence": N, "reasoning": "..." }
`;

async function evaluateResponse(input: EvalInput): Promise<EvalScore> {
  const result = await llm.complete({
    model: 'claude-sonnet-4-6',  // judge는 비용 효율적 모델
    prompt: JUDGE_PROMPT
      .replace('{question}', input.question)
      .replace('{context}', input.context)
      .replace('{response}', input.response),
  });
  return JSON.parse(result);
}
```

### Golden Dataset 평가

```typescript
// 정답 데이터셋
interface GoldenExample {
  input: string;
  expectedOutput: string;    // 또는 expectedPatterns
  context?: string;
  tags: string[];            // ['role-adherence', 'coding', 'planning']
}

// 자동 평가 파이프라인
async function runEvalSuite(model: string, examples: GoldenExample[]): Promise<EvalReport> {
  const results = await Promise.all(
    examples.map(async (ex) => {
      const response = await llm.complete({ model, prompt: ex.input, context: ex.context });
      const score = await evaluateResponse({ question: ex.input, context: ex.context, response });
      return { example: ex, response, score };
    })
  );

  return {
    model,
    timestamp: new Date(),
    overall: average(results.map(r => r.score)),
    byTag: groupByTag(results),
    failures: results.filter(r => r.score.relevance < 3),
  };
}
```

### A/B 테스트 프레임워크

```typescript
// 모델/프롬프트 비교
interface ABTest {
  name: string;
  variantA: { model: string; systemPrompt: string };
  variantB: { model: string; systemPrompt: string };
  dataset: GoldenExample[];
  metrics: string[];  // ['relevance', 'latency', 'cost']
}

async function runABTest(test: ABTest): Promise<ABResult> {
  const [resultsA, resultsB] = await Promise.all([
    runEvalSuite(test.variantA, test.dataset),
    runEvalSuite(test.variantB, test.dataset),
  ]);

  return {
    winner: compare(resultsA, resultsB, test.metrics),
    variantA: resultsA,
    variantB: resultsB,
    significanceTest: welchTTest(resultsA.scores, resultsB.scores),
  };
}
```

---

## 3. 평가 파이프라인

### CI/CD 통합

```yaml
# 모델 변경 시 자동 평가
- name: LLM Eval
  run: |
    npm run eval -- \
      --dataset eval/golden.json \
      --model claude-sonnet-4-6 \
      --threshold relevance=4,faithfulness=4 \
      --output eval-results.json

- name: Check Regression
  run: |
    npm run eval:compare -- \
      --baseline eval-results-main.json \
      --current eval-results.json \
      --max-regression 0.1
```

### 모니터링 (프로덕션)

```typescript
// 샘플링 기반 실시간 품질 모니터링
async function monitorQuality(response: LLMResponse, sampleRate = 0.05) {
  if (Math.random() > sampleRate) return;

  const score = await evaluateResponse({
    question: response.input,
    context: response.context,
    response: response.output,
  });

  metrics.record('llm_quality_score', score.relevance, {
    model: response.model,
    role: response.role,
  });

  if (score.relevance < 3 || score.faithfulness < 3) {
    await alertSlack(`Low quality response detected: ${JSON.stringify(score)}`);
  }
}
```

---

## 4. 역할 준수 평가 (Aice 특화)

```typescript
// 팀원이 역할을 벗어나지 않는지 평가
const ROLE_ADHERENCE_PROMPT = `
A team member with role "{role}" and the following system prompt:
---
{systemPrompt}
---

Was asked: {input}
And responded: {response}

Did the team member stay within their role? Specifically:
1. Did they perform tasks within their expertise?
2. Did they defer tasks outside their scope?
3. Did they follow the system prompt instructions?

Output JSON: { "adherent": true/false, "violations": ["..."], "score": 1-5 }
`;
```

## 출처

wshobson/agents llm-application-dev 플러그인 llm-evaluation 스킬 지식 추출 + Aice Session Tree 특화 지표 추가.
