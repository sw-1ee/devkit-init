---
name: a11y-patterns
description: 접근성 확장 스킬. WCAG 감사, 스크린 리더 테스팅, ARIA 패턴, 키보드 네비게이션. harness frontend-dev, QA가 참조.
---

# A11y Patterns — 접근성 확장 스킬

harness의 frontend-dev, QA, ui-designer 역할이 참조하는 접근성 패턴.
wshobson/agents accessibility-compliance 2개 스킬에서 추출.

## 트리거

- UI 컴포넌트 구현 시 접근성 확인 필요
- "접근성", "a11y", "WCAG", "스크린 리더", "키보드"
- 접근성 감사, 컴플라이언스 검토 시

---

## 1. WCAG 핵심 기준

### 레벨별 요구사항

| 레벨 | 대상 | 핵심 요구 |
|------|------|----------|
| **A** (필수) | 모든 서비스 | 키보드 접근, 대체 텍스트, 색상만으로 정보 전달 금지 |
| **AA** (표준) | 공공/상업 | 명도 대비 4.5:1, 리사이즈 200%, 포커스 표시 |
| **AAA** (최고) | 선택적 | 명도 대비 7:1, 수어 지원 |

**Aice 목표: AA 준수**

### 4원칙 (POUR)

| 원칙 | 설명 | 적용 |
|------|------|------|
| **Perceivable** | 인식 가능 | alt 텍스트, 캡션, 색상 대비 |
| **Operable** | 조작 가능 | 키보드, 충분한 시간, 발작 방지 |
| **Understandable** | 이해 가능 | 명확한 언어, 예측 가능한 동작 |
| **Robust** | 견고함 | 유효한 HTML, ARIA, 보조기술 호환 |

---

## 2. ARIA 패턴 (채팅 UI용)

### 메시지 목록

```tsx
// 채팅 메시지 영역 — role="log"로 스크린 리더에 실시간 메시지 알림
<div
  role="log"
  aria-label="Chat messages"
  aria-live="polite"
  aria-relevant="additions"
>
  {messages.map(msg => (
    <div
      key={msg.id}
      role="article"
      aria-label={`${msg.role === 'user' ? 'You' : 'Assistant'} said`}
    >
      <span className="sr-only">{msg.role === 'user' ? 'You' : 'Assistant'}:</span>
      <p>{msg.content}</p>
      <time dateTime={msg.createdAt} className="sr-only">
        {formatRelativeTime(msg.createdAt)}
      </time>
    </div>
  ))}
</div>
```

### 입력 영역

```tsx
<form onSubmit={handleSend} role="form" aria-label="Message input">
  <label htmlFor="message-input" className="sr-only">
    Type your message
  </label>
  <textarea
    id="message-input"
    aria-describedby="input-hint"
    placeholder="메시지를 입력하세요..."
    onKeyDown={(e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSend();
      }
    }}
  />
  <span id="input-hint" className="sr-only">
    Press Enter to send, Shift+Enter for new line
  </span>
  <button type="submit" aria-label="Send message">
    <SendIcon aria-hidden="true" />
  </button>
</form>
```

### 세션 사이드바

```tsx
<nav aria-label="Sessions">
  <ul role="listbox" aria-label="Session list">
    {sessions.map(s => (
      <li
        key={s.id}
        role="option"
        aria-selected={s.id === activeId}
        tabIndex={0}
        onClick={() => setActive(s.id)}
        onKeyDown={(e) => e.key === 'Enter' && setActive(s.id)}
      >
        <span>{s.title}</span>
        {s.unread > 0 && (
          <span aria-label={`${s.unread} unread messages`} className="badge">
            {s.unread}
          </span>
        )}
      </li>
    ))}
  </ul>
</nav>
```

---

## 3. 키보드 네비게이션

### 필수 단축키

| 키 | 동작 |
|----|------|
| `Tab` | 포커스 이동 (입력, 버튼, 링크) |
| `Shift+Tab` | 역방향 포커스 |
| `Enter` | 메시지 전송, 버튼 활성화 |
| `Escape` | 모달 닫기, 메뉴 닫기 |
| `Arrow Up/Down` | 세션 목록 탐색 |

### 포커스 트랩 (모달)

```tsx
function FocusTrap({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const focusable = el.querySelectorAll<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const first = focusable[0];
    const last = focusable[focusable.length - 1];

    first?.focus();

    const handler = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return;
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last?.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first?.focus();
      }
    };

    el.addEventListener('keydown', handler);
    return () => el.removeEventListener('keydown', handler);
  }, []);

  return <div ref={ref}>{children}</div>;
}
```

---

## 4. 테스팅

### 자동화 도구

```bash
# axe-core (가장 널리 사용)
npm install @axe-core/react  # React 개발 시
npm install axe-playwright   # E2E 테스트

# Lighthouse CI
npx lighthouse --accessibility-audit http://localhost:3000
```

### 테스트 코드

```typescript
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

test('chat page has no a11y violations', async () => {
  const { container } = render(<ChatPage />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});

// Playwright + axe
test('session page a11y', async ({ page }) => {
  await page.goto('/sessions/test-id');
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

### 수동 체크리스트

- [ ] 키보드만으로 모든 기능 사용 가능
- [ ] 포커스 순서 논리적
- [ ] 포커스 표시 시각적으로 명확 (outline)
- [ ] 모든 이미지에 alt 텍스트 (장식 이미지 = `alt=""`)
- [ ] 색상 대비 4.5:1 이상 (텍스트), 3:1 (큰 텍스트)
- [ ] 폼 입력에 label 연결
- [ ] 에러 메시지가 폼 필드와 연결
- [ ] VoiceOver/NVDA로 주요 흐름 테스트
- [ ] 200% 확대 시 콘텐츠 잘림 없음
- [ ] 동영상/오디오에 캡션

## 출처

wshobson/agents accessibility-compliance 플러그인 2개 스킬 (wcag-audit-patterns, screen-reader-testing) 지식 추출 + Aice 채팅 UI 특화 ARIA 패턴 추가.
