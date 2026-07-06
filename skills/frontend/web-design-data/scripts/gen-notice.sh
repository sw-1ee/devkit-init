#!/usr/bin/env bash
# gen-notice.sh — references/NOTICE.md 생성 (소스별 라이선스·attribution·커밋 SHA).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="$HERE/../_raw"
OUT="$HERE/../references/NOTICE.md"

sha() { head -c 12 "$RAW/$1/COMMIT" 2>/dev/null || echo "unknown"; }

cat > "$OUT" <<EOF
# NOTICE — web-design-data 외부 소스 라이선스·출처

이 스킬의 references/ 데이터는 아래 외부 저장소에서 추출·정규화되었다.
정책: MIT/Apache-2.0 소스만 흡수. 원본 LICENSE 는 각 \`_raw/<source>/LICENSE\` 에 보존
(단 \`_raw/\` 는 git 미추적 — 재현은 \`scripts/fetch-all.sh\`).

| 소스 | 라이선스 | 커밋 | 흡수 자산 |
|---|---|---|---|
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | MIT | \`$(sha ui-ux-pro-max)\` | design-rules/*.json (161 산업규칙 · 192 팔레트 · 74 타이포 · 99 UX · 25 차트 · 84 스타일) |
| [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) | MIT | \`$(sha design-systems)\` | design-systems/ (74 브랜드 DESIGN.md — "publicly visible CSS values") |
| [Nutlope/hallmark](https://github.com/Nutlope/hallmark) | MIT | \`$(sha hallmark)\` | anti-slop/hallmark-SKILL.md + hallmark-references/ (20테마 · 슬롭게이트, 원본 보존) |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | Apache-2.0 | \`$(sha impeccable)\` | anti-slop/rules.json (45 안티패턴 카탈로그; upstream 에 NOTICE 파일 없음, LICENSE 는 _raw 보존) |
| [bencium/bencium-marketplace](https://github.com/bencium/bencium-marketplace) | MIT (README 선언 — LICENSE 파일 없음, 2026-07-06 실측) | \`$(sha bencium)\` | a11y-motion/ (ACCESSIBILITY.md 828L · MOTION-SPEC.md 544L, controlled 변형 원본) |

## Native (자체 작성 — 외부 코드 복제 없음)

- \`tokens/brand-hue.css\` — 단일 hue OKLCH 파생 팔레트. 아이디어 계보만 커뮤니티
  패턴(널리 알려진 기법)이며 코드는 devkit-init 이 새로 작성.
- \`tokens/motion.css\` — 트랜지션 토큰·유틸리티. transitions.dev(라이선스 unknown)를
  **복제하지 않고** 관용적 easing/duration 조합으로 새로 작성.

## 제외 (라이선스 정책)

- phrazzld design-tokens — repo 404 / 라이선스 unknown → 배제, native 재작성으로 대체.
- transitions.dev — LICENSE 파일 없음(unknown) → 배제, native 재작성으로 대체.
EOF
echo "  NOTICE.md generated ($(wc -l < "$OUT") lines)"
