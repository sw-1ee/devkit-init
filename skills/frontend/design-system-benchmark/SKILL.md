---
name: design-system-benchmark
description: 프로젝트 특성에 맞는 디자인 시스템 레퍼런스를 추천하고 그 느낌을 토큰/컴포넌트에 반영한다. 36-design-system 하네스의 token-designer, component-developer가 참조하는 확장 스킬.
---

# Design System Benchmark

프로젝트에 가장 적합한 디자인 시스템 레퍼런스를 추천하고, 해당 시스템의 디자인 언어(토큰, 컴포넌트 패턴, 톤)를 프로젝트에 적용한다.

## 트리거

- "어떤 디자인 시스템이 우리 프로젝트에 맞을까?"
- "디자인 레퍼런스 추천해줘"
- "이 프로젝트를 Material/Carbon/Spectrum 느낌으로 만들어줘"
- 36-design-system 하네스의 Phase 1(토큰 설계) 시작 시 자동 참조

## 추천 파이프라인

### Step 1: 프로젝트 프로파일링

아래 5차원으로 프로젝트를 분석한다:

| 차원 | 질문 | 예시 값 |
|------|------|---------|
| **산업** | 어떤 도메인인가? | SaaS, 이커머스, 핀테크, 공공, 미디어, 교육, 헬스케어 |
| **규모** | 컴포넌트 몇 개 수준? | 소(10-20), 중(20-50), 대(50+) |
| **스택** | 프론트엔드 프레임워크? | React, Vue, Angular, Web Components, React Native |
| **미감** | 어떤 느낌을 원하나? | 미니멀, 엔터프라이즈, 플레이풀, 브루탈, 클래식 |
| **제약** | 특수 요구사항? | 접근성 AAA, 다크모드 필수, RTL, 다국어, 모바일 퍼스트 |

### Step 2: 레퍼런스 매칭

프로파일 결과를 기준으로 아래 벤치마크 DB에서 Top 3를 선정한다. 선정 기준:

1. **산업 적합도** — 같은 도메인의 실전 사례 우선
2. **스택 호환** — 같은 프레임워크의 오픈소스 구현 존재
3. **미감 유사도** — 원하는 톤과의 거리
4. **완성도** — Components + Voice & Tone + Designers Kit + Source Code 4가지 보유 우선

### Step 3: 추천 보고

각 추천에 대해:

```
## 추천 N: [디자인 시스템 이름]

- **URL**: [공식 사이트]
- **Source**: [GitHub URL]
- **보유 요소**: Components ✓ | Voice & Tone ✓ | Kit ✓ | Source ✓
- **산업 유사도**: [설명]
- **미감 특징**: [색상 톤, 타이포, 간격 특성, 전반적 느낌]
- **Aice 적용 시 참고점**: [토큰 구조, 컴포넌트 패턴 중 빌려올 것]
- **제한사항**: [라이선스 주의, 미지원 기능 등]
```

### Step 4: 선택된 레퍼런스 적용

사용자가 선택하면:

1. **토큰 추출** — 선택된 디자인 시스템의 토큰 구조(색상 팔레트, 타이포 스케일, 간격 체계, 그림자, 모션)를 분석하고 프로젝트용 토큰으로 변환
2. **컴포넌트 패턴 참고** — 해당 시스템의 컴포넌트 API 패턴(props 구조, 합성 방식, 변형 체계)을 프로젝트 컴포넌트에 반영
3. **톤 앤 매너 가이드** — Voice & Tone이 있으면 프로젝트 카피/UX 라이팅에 참조
4. **차별화 포인트** — 레퍼런스를 그대로 복사하지 않고, 프로젝트 정체성에 맞게 변형한 부분을 명시

## 벤치마크 DB

### Tier 1: 풀 스택 디자인 시스템 (Components + Voice + Kit + Source)

최고 완성도. 토큰부터 문서까지 전체 참조 가능.

| 이름 | URL | Source | 산업 | 미감 | 스택 |
|------|-----|--------|------|------|------|
| Adobe Spectrum | spectrum.adobe.com | [GitHub](https://github.com/adobe/react-spectrum) | 크리에이티브 툴 | 정교하고 기능적 | React |
| Alibaba Ant Design | ant.design | [GitHub](https://github.com/ant-design/ant-design/) | 이커머스/엔터프라이즈 | 깔끔한 엔터프라이즈 | React |
| Atlassian Design System | atlassian.design | [Bitbucket](https://bitbucket.org/atlassian/atlassian-frontend-mirror/) | SaaS/협업 | 프로페셔널, 밀도 높음 | React |
| AWS Cloudscape | cloudscape.design | [GitHub](https://github.com/cloudscape-design/components) | 클라우드/인프라 | 기능 중심 엔터프라이즈 | React |
| Elastic UI | elastic.github.io/eui/ | [GitHub](https://github.com/elastic/eui) | 데이터/분석 | 데이터 밀도 높은 대시보드 | React |
| Firefox Photon | design.firefox.com/photon | [GitHub](https://github.com/FirefoxUX/photon) | 브라우저/소프트웨어 | 따뜻한 미니멀 | Web |
| Google Material Design | material.io | [GitHub](https://github.com/material-components/material-components) | 범용 | 플레이풀, 물리적 메타포 | Multi |
| GOV.UK Design System | gov.uk/design-system | [GitHub](https://github.com/alphagov/govuk-design-system) | 공공/정부 | 극도로 명확, 접근성 우선 | Web |
| IBM Carbon | carbondesignsystem.com | [GitHub](https://github.com/ibm/carbon-components) | 엔터프라이즈/AI | 구조적, 모듈러 | React/Vue/Angular |
| Microsoft Fluent UI | developer.microsoft.com/fluentui | [GitHub](https://github.com/microsoft/fluentui) | 생산성/오피스 | 유연하고 자연스러운 | React |
| PatternFly | patternfly.org | [GitHub](https://github.com/patternfly) | 엔터프라이즈/인프라 | 기능 밀도 높음 | React |
| Salesforce Lightning | lightningdesignsystem.com | [GitHub](https://github.com/salesforce-ux/design-system) | CRM/엔터프라이즈 | 구조적, 비즈니스 | Web |
| Shopify Polaris | polaris.shopify.com | [GitHub](https://github.com/Shopify/polaris) | 이커머스 | 친근하고 실용적 | React |
| Twilio Paste | paste.twilio.design | [GitHub](https://github.com/twilio-labs/paste) | 커뮤니케이션/API | 개발자 친화적, 접근성 강점 | React |
| U.S. Web Design Standards | designsystem.digital.gov | [GitHub](https://github.com/uswds/uswds) | 공공/정부 | 신뢰감, 접근성 AAA | Web |
| VMware Clarity | clarity.design | [GitHub](https://github.com/vmware/clarity) | 인프라/엔터프라이즈 | 구조적, 데이터 테이블 강점 | Angular |

### Tier 2: 개발자 중심 디자인 시스템 (Components + Source, 높은 GitHub 채택률)

소스코드가 강점. 구현 참조용.

| 이름 | URL | Source | 미감 | 스택 | 특징 |
|------|-----|--------|------|------|------|
| Chakra UI | chakra-ui.com | [GitHub](https://github.com/chakra-ui/chakra-ui) | 깔끔한 모던 | React | 합성 패턴, 스타일 props |
| Mantine | mantine.dev | [GitHub](https://github.com/mantinedev/mantine) | 모던 미니멀 | React | 100+ hooks, 풍부한 유틸 |
| Radix | radix.modulz.app | [GitHub](https://github.com/modulz/radix) | 무스타일(headless) | React | 접근성 우선, 스타일 자유 |
| Shadcn/ui | ui.shadcn.com | [GitHub](https://github.com/shadcn-ui) | 모던 미니멀 | React | 복사-붙여넣기 패턴, Tailwind |
| Blueprint | blueprintjs.com | [GitHub](https://github.com/palantir/blueprint) | 데이터 밀도 | React | 테이블/차트 강점 |
| GitHub Primer | primer.style | [GitHub](https://github.com/primer/) | 개발자 도구 | React | GitHub 스타일, 명확함 |
| Semi Design | semi.design | [GitHub](https://github.com/DouyinFE/semi-design) | 모던 엔터프라이즈 | React | 다크모드, 국제화 |
| Kiwi.com Orbit | orbit.kiwi | [GitHub](https://github.com/kiwicom/orbit-components/) | 여행 | React | 모바일 퍼스트 |

### Tier 3: 도메인 특화 레퍼런스

특정 산업/용도에서 참조할 만한 시스템.

| 도메인 | 추천 시스템 | 이유 |
|--------|------------|------|
| **AI/ML 대시보드** | IBM Carbon, Elastic UI | AI 워크플로우, 데이터 시각화 패턴 |
| **개발자 도구** | GitHub Primer, Vercel Geist | 코드 중심 UI, 모노스페이스 미감 |
| **이커머스** | Shopify Polaris, Ant Design | 상품/주문/결제 패턴 |
| **핀테크** | Morningstar, Fish Tank | 숫자 밀도, 신뢰감 |
| **공공/접근성** | GOV.UK, U.S. WDS, NHS | WCAG AAA, 명료한 언어 |
| **SaaS/협업** | Atlassian, Salesforce, Monday Vibe | 복잡한 워크스페이스 UI |
| **모바일 앱** | Kiwi Orbit, Samsung Tizen | 터치 타겟, 모바일 패턴 |
| **미디어/콘텐츠** | BBC GEL, Starbucks | 브랜드 중심, 비주얼 풍부 |
| **헬스케어** | NHS Service Manual | 생명 관련 접근성, 명확한 언어 |
| **정부/교육** | Aurora (Canada), Singapore GDS | 다국어, 접근성, 공공 신뢰 |

## Aice 프로젝트 기본 추천

Aice는 AI 협업 플랫폼(SaaS)이므로 기본 추천:

1. **IBM Carbon** — AI/ML 워크플로우 패턴 풍부, 모듈러 토큰 시스템, React 지원
2. **Atlassian Design System** — 세션/스레드/협업 UI 패턴, 밀도 높은 워크스페이스
3. **Shadcn/ui** — 빠른 프로토타이핑, Tailwind 기반, 커스터마이징 자유도 높음

## 하네스 통합

이 스킬은 36-design-system 하네스의 확장 스킬로 동작한다:

- **token-designer**: 추천된 레퍼런스의 토큰 구조를 분석하고, 프로젝트 토큰의 기반으로 사용
- **component-developer**: 추천된 레퍼런스의 컴포넌트 API 패턴을 참조하여 일관된 props/변형 설계

## 출처

벤치마크 DB 원본: [awesome-design-systems](https://github.com/alexpate/awesome-design-systems) (200+ 항목에서 Tier별 선별)
