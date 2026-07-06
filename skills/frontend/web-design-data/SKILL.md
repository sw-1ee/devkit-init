---
name: web-design-data
description: "웹/제품 UI를 만들 때 산업별 검증 디자인 데이터를 조회하는 스킬. 161 산업 추론규칙, 192 산업별 shadcn 팔레트(WCAG 조정), 74 브랜드 DESIGN.md(Linear/Stripe/Vercel…), 45 anti-slop 안티패턴, 접근성 828줄·모션 544줄 레퍼런스, OKLCH/모션 토큰을 담고 있다. '랜딩 만들자', '팔레트 골라줘', 'SaaS UI 디자인', '슬롭 없이', 'design tokens', 'anti-slop', 'pick a palette' 등 UI 디자인 결정 시 사용. 데이터는 references/ 아래 JSON/md — 필요한 파일만 읽는다."
---

# web-design-data — 산업별 검증 디자인 데이터

UI 디자인 결정을 감이 아니라 **큐레이트된 데이터**로 한다. 프롬프트에 전부 넣지
말고, 아래 라우팅으로 **필요한 파일만** 읽어라.

## 라우팅 (질문 → 파일)

| 질문 | 파일 | 내용 |
|---|---|---|
| 이 산업엔 어떤 UI 패턴/스타일? | `references/design-rules/industry-rules.json` | 161 규칙. `industry` 로 필터. `decision_rules` = 조건 분기(JSON), `anti_patterns` = 피할 것 |
| 팔레트 뭐 쓰지? | `references/design-rules/palettes.json` | 192 산업별 완전한 shadcn 토큰 세트(16키) + WCAG 조정 노트. `industry` 매칭 → `tokens` 를 CSS 변수/@theme 로 주입 |
| 폰트 페어링? | `references/design-rules/typography.json` | 74 조합 |
| UX 원칙 체크? | `references/design-rules/ux-guidelines.json` | 99 가이드라인 |
| 차트 타입 선택? | `references/design-rules/charts.json` | 25 추천 |
| 스타일 사조 참고? | `references/design-rules/styles.json` | 84 스타일 정의 |
| 브랜드급 레퍼런스 톤? | `references/design-systems/index.json` → `<slug>/DESIGN.md` | 74 브랜드 (linear, stripe, vercel …). index 에서 slug 찾고 해당 DESIGN.md 만 읽기 |
| AI 슬롭 피하기 (룰) | `references/anti-slop/rules.json` | 45 안티패턴 (id/category/name/description). 산출물 자가검사 체크리스트로 사용 |
| AI 슬롭 피하기 (테마·워크플로) | `references/anti-slop/hallmark-SKILL.md` | 20 네임드 테마 + 게이트 프로즈 (원본) |
| 접근성 구현 상세 | `references/a11y-motion/ACCESSIBILITY.md` | 828줄 실무 레퍼런스 |
| 모션 스펙 상세 | `references/a11y-motion/MOTION-SPEC.md` | 544줄 실무 레퍼런스 |
| 토큰 시작점 (복붙) | `references/tokens/brand-hue.css` | 단일 `--brand-hue` OKLCH 파생 팔레트 + 다크모드 |
| 트랜지션 (복붙) | `references/tokens/motion.css` | duration/easing 토큰 + 유틸 + reduced-motion 가드 |

## 표준 흐름 (새 UI 만들 때)

1. `industry-rules.json` 에서 프로젝트 산업 규칙 1건 조회 → 패턴·스타일·anti_patterns 확보
2. `palettes.json` 같은 산업 → `tokens` 16키를 CSS 변수로 주입
   (또는 브랜드 hue 가 정해져 있으면 `tokens/brand-hue.css` 시작점)
3. `typography.json` 페어링 1개 선택
4. 구현 후 `anti-slop/rules.json` 45룰로 자가검사 — 특히 category `slop` 항목
5. 모션은 `tokens/motion.css` 토큰만 사용, 임의 duration 금지

## Hard rules

- **데이터 전량 로드 금지.** design-systems 는 index → 해당 slug 1개만.
- **팔레트 임의 발명 금지.** palettes.json 또는 brand-hue.css 파생에서 시작.
- **reduced-motion 가드 제거 금지** (motion.css 하단).
- 출처·라이선스 = `references/NOTICE.md`. 데이터 재생성 = `scripts/fetch-all.sh`.
