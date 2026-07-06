---
name: security-hardening
description: 보안 강화 확장 스킬. SAST 구성, STRIDE 위협 모델링, 공격 트리 분석, 보안 요구사항 추출, 위협 완화 매핑. harness QA/보안 역할이 참조.
---

# Security Hardening — 보안 강화 확장 스킬

보안 관련 하네스 팀원(security-auditor, QA, backend-dev)이 참조하는 통합 보안 지식.
wshobson/agents security-scanning 5개 스킬에서 추출.

## 트리거

- 보안 감사, 위협 모델링, SAST 구성 요청 시
- "보안 점검", "threat model", "STRIDE", "attack tree"
- 코드 리뷰에서 보안 관점 필요 시
- 배포 전 보안 체크리스트 요청 시

---

## 1. SAST 구성 (Static Application Security Testing)

### 도구 비교

| 도구 | 언어 | 속도 | 커스텀 룰 | CI 통합 | 라이선스 |
|------|------|------|----------|---------|---------|
| **Semgrep** | 30+ | 빠름 | YAML 패턴 | ✓ | OSS (LGPL) |
| **SonarQube** | 25+ | 중간 | Java 플러그인 | ✓ | Community/Commercial |
| **CodeQL** | 12 | 느림 | QL 쿼리 | GitHub only | Free for OSS |

### Semgrep 설정 (권장)

```yaml
# .semgrep.yml
rules:
  - id: hardcoded-secret
    patterns:
      - pattern: $KEY = "..."
      - metavariable-regex:
          metavariable: $KEY
          regex: (password|secret|api_key|token)
    message: "Hardcoded secret detected in $KEY"
    severity: ERROR

  - id: sql-injection
    patterns:
      - pattern: cursor.execute(f"...{$VAR}...")
    message: "Potential SQL injection via f-string"
    severity: ERROR

  - id: ssrf-risk
    patterns:
      - pattern: requests.get($URL, ...)
      - pattern-not: requests.get("https://api.internal...", ...)
    message: "Unvalidated URL in HTTP request (SSRF risk)"
    severity: WARNING
```

### CI 통합

```yaml
# GitHub Actions
- name: Semgrep SAST
  uses: returntocorp/semgrep-action@v1
  with:
    config: .semgrep.yml
    generateSarif: true
  env:
    SEMGREP_RULES: p/security-audit p/owasp-top-ten
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/returntocorp/semgrep
    rev: v1.52.0
    hooks:
      - id: semgrep
        args: ['--config', '.semgrep.yml', '--error']
```

---

## 2. STRIDE 위협 모델링

### STRIDE 카테고리

| 위협 | 설명 | 보안 속성 | 완화 예시 |
|------|------|----------|----------|
| **S**poofing | 신원 위장 | 인증 | MFA, 인증서 |
| **T**ampering | 데이터 변조 | 무결성 | HMAC, 디지털 서명 |
| **R**epudiation | 행위 부인 | 부인방지 | 감사 로그, 타임스탬프 |
| **I**nformation Disclosure | 정보 노출 | 기밀성 | 암호화, ACL |
| **D**enial of Service | 서비스 거부 | 가용성 | Rate limiting, CDN |
| **E**levation of Privilege | 권한 상승 | 인가 | RBAC, 최소 권한 |

### 위협 모델 작성 절차

1. **DFD 작성** — 시스템 경계, 데이터 흐름, 신뢰 경계 식별
2. **STRIDE-per-element** — 각 요소(프로세스, 데이터스토어, 데이터흐름, 외부엔터티)에 STRIDE 적용
3. **위험 평가** — 영향도(1-5) × 발생확률(1-5) = 위험 점수
4. **완화 전략** — 위험 점수 높은 것부터 완화 방안 수립

### 위험 매트릭스

```
영향도 ↑
5  | M  H  H  C  C
4  | L  M  H  H  C
3  | L  M  M  H  H
2  | L  L  M  M  H
1  | L  L  L  M  M
   +-----------------→ 발생확률
     1  2  3  4  5

L=Low, M=Medium, H=High, C=Critical
```

---

## 3. 공격 트리 분석

### 구조

```
[ROOT: 시스템 침해]
├── [AND] 인증 우회
│   ├── [OR] 비밀번호 공격
│   │   ├── 브루트포스 (비용: L, 탐지: H)
│   │   ├── 크레덴셜 스터핑 (비용: L, 탐지: M)
│   │   └── 피싱 (비용: M, 탐지: L)
│   └── [OR] 토큰 탈취
│       ├── XSS → 세션쿠키 (비용: M, 탐지: M)
│       └── MITM (비용: H, 탐지: H)
├── [OR] 데이터 접근
│   ├── SQL 인젝션 (비용: L, 탐지: M)
│   ├── IDOR (비용: L, 탐지: L)
│   └── API 키 노출 (비용: L, 탐지: L)
└── [OR] 서비스 거부
    ├── 볼류메트릭 DDoS (비용: M, 탐지: H)
    └── 앱 레벨 DoS (비용: L, 탐지: M)
```

### 경로 분석 기준

- **최저 비용 경로**: 공격자 관점에서 가장 저렴한 경로 → 우선 완화
- **최저 탐지 경로**: 탐지 어려운 경로 → 모니터링 강화
- **최고 영향 경로**: 성공 시 피해 최대 경로 → 방어 심층화

---

## 4. 보안 요구사항 추출

### STRIDE → 요구사항 매핑

| STRIDE | 요구사항 카테고리 | 예시 |
|--------|----------------|------|
| Spoofing | 인증 (AUTH) | "모든 API 엔드포인트는 JWT 검증 필수" |
| Tampering | 무결성 (INT) | "입력 데이터는 서버사이드 검증 필수" |
| Repudiation | 감사 (AUD) | "모든 상태 변경에 감사 로그 기록" |
| Info Disclosure | 기밀성 (CONF) | "PII는 AES-256 암호화 저장" |
| DoS | 가용성 (AVAIL) | "API rate limit: 100 req/min/user" |
| EoP | 인가 (AUTHZ) | "리소스 접근 시 소유권 확인 필수" |

### 컴플라이언스 매핑

| 프레임워크 | 핵심 요구사항 |
|-----------|-------------|
| **OWASP Top 10** | Injection, Broken Auth, XSS, SSRF, etc. |
| **PCI-DSS** | 카드 데이터 암호화, 네트워크 세그멘테이션, 접근 로그 |
| **GDPR** | 동의 관리, 삭제권, 데이터 이동성, DPO |
| **HIPAA** | PHI 암호화, 접근 제어, 감사 추적 |

---

## 5. 위협 완화 매핑

### 표준 컨트롤 라이브러리

| ID | 카테고리 | 컨트롤 | 효과 |
|----|---------|--------|------|
| AUTH-01 | 인증 | MFA 적용 | Spoofing ↓90% |
| AUTH-02 | 인증 | 비밀번호 정책 (12자+, 복잡성) | Brute force ↓80% |
| VAL-01 | 검증 | 입력 화이트리스트 검증 | Injection ↓95% |
| VAL-02 | 검증 | 출력 인코딩 (컨텍스트별) | XSS ↓95% |
| ENC-01 | 암호화 | TLS 1.3 전송 암호화 | MITM ↓99% |
| ENC-02 | 암호화 | AES-256 저장 암호화 | 데이터 유출 ↓95% |
| LOG-01 | 로깅 | 구조화 감사 로그 | Repudiation ↓90% |
| LOG-02 | 로깅 | 실시간 이상 탐지 알림 | 탐지 시간 ↓80% |
| ACC-01 | 접근제어 | RBAC/ABAC | EoP ↓85% |
| ACC-02 | 접근제어 | API rate limiting | DoS ↓70% |
| AVL-01 | 가용성 | CDN + DDoS 방어 | 볼류메트릭 DoS ↓95% |
| AVL-02 | 가용성 | 서킷 브레이커 + 폴백 | 연쇄 장애 ↓80% |

### 완화 우선순위 결정

```
우선순위 = (위험 점수 × 커버리지 갭) / 구현 비용

1순위: 비용 낮고 위험 높은 것 (입력 검증, 출력 인코딩)
2순위: 비용 중간 위험 높은 것 (MFA, 암호화)
3순위: 비용 높고 위험 높은 것 (WAF, DDoS 방어)
후순위: 위험 낮은 것
```

---

## 보안 체크리스트 (배포 전)

- [ ] SAST 스캔 통과 (critical/high 0건)
- [ ] 의존성 취약점 스캔 (npm audit / pip-audit)
- [ ] 시크릿 스캔 (git-secrets, trufflehog)
- [ ] STRIDE 위협 모델 작성/갱신
- [ ] 인증/인가 테스트 통과
- [ ] 입력 검증 테스트 (fuzzing 포함)
- [ ] 에러 메시지에 내부 정보 미노출 확인
- [ ] HTTPS 강제 + HSTS 헤더
- [ ] CORS 정책 최소 권한
- [ ] Rate limiting 적용

## 출처

wshobson/agents security-scanning 플러그인 5개 스킬 (sast-configuration, stride-analysis-patterns, attack-tree-construction, security-requirement-extraction, threat-mitigation-mapping) 지식 추출 및 Aice harness 형태로 재구성.
