---
name: frontend-patterns
description: 프론트엔드 확장 스킬. React 상태관리, Next.js App Router, Tailwind 디자인 시스템, React Native 아키텍처. harness frontend-dev가 참조.
---

# Frontend Patterns — 프론트엔드 확장 스킬

harness의 frontend-dev, ui-designer 역할이 참조하는 프론트엔드 패턴 지식.
wshobson/agents frontend-mobile-development 4개 스킬에서 추출.

## 트리거

- React/Next.js 컴포넌트 설계, 상태 관리 논의 시
- "상태 관리", "App Router", "Tailwind", "React Native"
- 프론트엔드 코드 리뷰 시 패턴 참조 필요 시

---

## 1. React 상태 관리

### 상태 유형별 도구 선택

| 유형 | 설명 | 권장 도구 |
|------|------|----------|
| **로컬** | 단일 컴포넌트 | `useState`, `useReducer` |
| **서버** | API 데이터, 캐시 | **React Query (TanStack Query)** |
| **글로벌** | 여러 컴포넌트 공유 | **Zustand** (간단) / Redux Toolkit (복잡) |
| **URL** | 라우트 파라미터, 검색 | `useSearchParams`, `nuqs` |
| **폼** | 폼 입력, 검증 | React Hook Form + Zod |

### Zustand (권장 — 간결)

```typescript
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

interface SessionStore {
  sessions: Map<string, Session>;
  activeSessionId: string | null;
  setActive: (id: string) => void;
  addMessage: (sessionId: string, message: Message) => void;
}

const useSessionStore = create<SessionStore>()(
  devtools(
    persist(
      (set, get) => ({
        sessions: new Map(),
        activeSessionId: null,
        setActive: (id) => set({ activeSessionId: id }),
        addMessage: (sessionId, message) =>
          set((state) => {
            const session = state.sessions.get(sessionId);
            if (!session) return state;
            session.messages.push(message);
            return { sessions: new Map(state.sessions) };
          }),
      }),
      { name: 'session-store' }
    )
  )
);
```

### React Query (서버 상태)

```typescript
function useSession(sessionId: string) {
  return useQuery({
    queryKey: ['session', sessionId],
    queryFn: () => api.getSession(sessionId),
    staleTime: 30_000,
  });
}

function useSendMessage() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { sessionId: string; content: string }) =>
      api.sendMessage(input),
    // 낙관적 업데이트
    onMutate: async (input) => {
      await queryClient.cancelQueries({ queryKey: ['session', input.sessionId] });
      const prev = queryClient.getQueryData(['session', input.sessionId]);
      queryClient.setQueryData(['session', input.sessionId], (old: Session) => ({
        ...old,
        messages: [...old.messages, { content: input.content, role: 'user', pending: true }],
      }));
      return { prev };
    },
    onError: (_err, input, context) => {
      queryClient.setQueryData(['session', input.sessionId], context?.prev);
    },
    onSettled: (_data, _err, input) => {
      queryClient.invalidateQueries({ queryKey: ['session', input.sessionId] });
    },
  });
}
```

---

## 2. Next.js App Router 패턴

### Server vs Client 컴포넌트 결정

```
Server Component (기본):
  - 데이터 fetch
  - 정적 렌더링
  - DB/파일 직접 접근
  - 시크릿 사용

Client Component ('use client'):
  - 이벤트 핸들러 (onClick, onChange)
  - useState, useEffect
  - 브라우저 API
  - 실시간 업데이트
```

### 레이아웃 구조

```
app/
├── layout.tsx              # 루트 레이아웃 (인증 프로바이더)
├── page.tsx                # 대시보드
├── (auth)/
│   ├── login/page.tsx
│   └── signup/page.tsx
├── sessions/
│   ├── layout.tsx          # 세션 목록 사이드바
│   ├── page.tsx            # 세션 선택 안내
│   └── [sessionId]/
│       ├── page.tsx        # 세션 대화
│       └── @sidebar/       # Parallel Route: 팀원 목록
│           └── page.tsx
└── api/
    └── sessions/
        └── route.ts        # Route Handler
```

### Server Actions

```typescript
// app/sessions/actions.ts
'use server';

import { revalidatePath } from 'next/cache';

export async function createSession(formData: FormData) {
  const title = formData.get('title') as string;
  const session = await db.session.create({ data: { title, userId: auth().userId } });
  revalidatePath('/sessions');
  redirect(`/sessions/${session.id}`);
}
```

### Streaming + Suspense

```tsx
// 세션 대화 페이지 — 메시지 목록은 스트리밍
export default function SessionPage({ params }: { params: { sessionId: string } }) {
  return (
    <div>
      <SessionHeader sessionId={params.sessionId} />
      <Suspense fallback={<MessagesSkeleton />}>
        <Messages sessionId={params.sessionId} />
      </Suspense>
      <MessageInput sessionId={params.sessionId} />
    </div>
  );
}
```

---

## 3. Tailwind 디자인 시스템

### Tailwind v4 CSS-First 설정

```css
/* app.css */
@import "tailwindcss";

@theme {
  /* OKLCH 색상 토큰 */
  --color-primary-50: oklch(0.97 0.02 250);
  --color-primary-500: oklch(0.55 0.18 250);
  --color-primary-900: oklch(0.25 0.10 250);

  --color-surface: oklch(0.99 0.00 0);
  --color-surface-elevated: oklch(1.00 0.00 0);

  /* 타이포그래피 */
  --font-sans: 'Inter', 'Pretendard', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;

  /* 간격 */
  --spacing-chat: 1rem;
  --radius-message: 0.75rem;
}

@custom-variant dark (&:where(.dark, .dark *));
```

### CVA 컴포넌트 (Class Variance Authority)

```typescript
import { cva, type VariantProps } from 'class-variance-authority';

const button = cva(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2',
  {
    variants: {
      variant: {
        primary: 'bg-primary-500 text-white hover:bg-primary-600',
        secondary: 'bg-surface-elevated border border-gray-200 hover:bg-gray-50',
        ghost: 'hover:bg-gray-100',
        danger: 'bg-red-500 text-white hover:bg-red-600',
      },
      size: {
        sm: 'h-8 px-3 text-sm',
        md: 'h-10 px-4 text-sm',
        lg: 'h-12 px-6 text-base',
      },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  }
);

type ButtonProps = React.ComponentProps<'button'> & VariantProps<typeof button>;

export function Button({ variant, size, className, ...props }: ButtonProps) {
  return <button className={button({ variant, size, className })} {...props} />;
}
```

---

## 4. React Native 아키텍처

### Expo Router 네비게이션

```
app/
├── _layout.tsx          # Stack Navigator
├── (tabs)/
│   ├── _layout.tsx      # Tab Navigator
│   ├── index.tsx         # 세션 목록
│   ├── explore.tsx       # 탐색
│   └── settings.tsx      # 설정
├── session/
│   └── [id].tsx          # 세션 대화
└── (auth)/
    ├── login.tsx
    └── signup.tsx
```

### 오프라인 우선 (React Query + AsyncStorage)

```typescript
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister';

const persister = createAsyncStoragePersister({
  storage: AsyncStorage,
  key: 'aice-query-cache',
});

// App.tsx
<PersistQueryClientProvider client={queryClient} persistOptions={{ persister }}>
  <App />
</PersistQueryClientProvider>
```

### 플랫폼별 코드

```typescript
// components/HapticButton.tsx
import { Platform } from 'react-native';
import * as Haptics from 'expo-haptics';

export function HapticButton({ onPress, ...props }) {
  const handlePress = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    onPress?.();
  };
  return <Pressable onPress={handlePress} {...props} />;
}
```

## 출처

wshobson/agents frontend-mobile-development 플러그인 4개 스킬 (react-state-management, nextjs-app-router-patterns, tailwind-design-system, react-native-architecture) 지식 추출 및 Aice harness 형태로 재구성.
