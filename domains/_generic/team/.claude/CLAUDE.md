# Generic Team Harness

전용 하네스 팀이 없는 도메인(desktop/exe, Flutter, iOS 네이티브 등)을 위한
최소 3역할 fallback. 도메인 특화 지식은 없지만, 설계→구현→검증의 기본
분업은 그대로 동작한다.

## 구조

```
.claude/agents/
├── architect.md   — 요구사항 분석, 시스템 설계, 기술 선택
├── developer.md   — 구현 (스택 무관 원칙 중심)
└── qa.md          — 테스트 전략, 검증, 코드 리뷰
```

## 사용 방식

1. **architect** 로 시작: 요구사항을 `_workspace/01_architecture.md` 로 정리
2. **developer** 가 구현: 아키텍처 문서 기반, 작은 단위로 커밋
3. **qa** 가 검증: 각 마일스톤마다 테스트 + 리뷰

## 한계 (정직 고지)

이 팀은 범용이다. 도메인 전용 팀(웹/AI/모바일/CLI/데이터)이 있으면 그쪽이
항상 낫다: `bash install.sh --domain <web|ai|mobile|cli|data>`.
desktop/exe·Flutter·iOS 전용 팀은 콘텐츠 백로그 — 추가되면 이 fallback 을 대체한다.
