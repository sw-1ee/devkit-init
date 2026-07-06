---
name: auth-patterns
description: 인증/인가 구현 확장 스킬. JWT, OAuth2, 세션, RBAC/ABAC, MFA 패턴. harness backend-dev가 Aice 인증 구현 시 참조.
---

# Auth Patterns — 인증/인가 구현 확장 스킬

harness의 backend-dev가 인증 시스템 구현 시 참조.
wshobson/agents developer-essentials auth-implementation-patterns 스킬에서 추출.

## 트리거

- 인증/인가 시스템 설계, 구현 시
- "로그인", "JWT", "OAuth", "권한", "RBAC"
- 보안 리뷰에서 인증 관련 이슈 시

---

## 1. JWT 인증

### 토큰 구조

```typescript
// Access Token (짧은 수명: 15분)
interface AccessTokenPayload {
  sub: string;      // userId
  email: string;
  roles: string[];
  iat: number;
  exp: number;      // 15분
}

// Refresh Token (긴 수명: 7일, DB 저장)
interface RefreshToken {
  id: string;
  userId: string;
  token: string;     // 해시 저장
  expiresAt: Date;
  revokedAt?: Date;
  userAgent: string;
  ip: string;
}
```

### 구현 패턴

```typescript
import jwt from 'jsonwebtoken';

// 토큰 발급
function issueTokens(user: User): { accessToken: string; refreshToken: string } {
  const accessToken = jwt.sign(
    { sub: user.id, email: user.email, roles: user.roles },
    process.env.JWT_SECRET!,
    { expiresIn: '15m', algorithm: 'HS256' }
  );

  const refreshToken = crypto.randomBytes(32).toString('hex');
  // DB에 해시 저장
  await db.refreshToken.create({
    userId: user.id,
    token: hash(refreshToken),
    expiresAt: addDays(new Date(), 7),
  });

  return { accessToken, refreshToken };
}

// 미들웨어
function authenticate(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as AccessTokenPayload;
    req.user = payload;
    next();
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// Refresh 흐름
async function refreshTokens(refreshToken: string) {
  const stored = await db.refreshToken.findByHash(hash(refreshToken));
  if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
    throw new AuthError('Invalid refresh token');
  }
  // Rotation: 기존 무효화 + 새로 발급
  await db.refreshToken.revoke(stored.id);
  const user = await db.user.findById(stored.userId);
  return issueTokens(user);
}
```

---

## 2. OAuth2 / 소셜 로그인

### 흐름 (Authorization Code + PKCE)

```
1. 클라이언트 → code_verifier 생성, code_challenge = SHA256(verifier)
2. 클라이언트 → 인가 서버: /authorize?response_type=code&code_challenge=...
3. 사용자 → 로그인 + 동의
4. 인가 서버 → 클라이언트: redirect_uri?code=AUTH_CODE
5. 클라이언트 → 서버: { code, code_verifier }
6. 서버 → 인가 서버: { code, code_verifier, client_secret }
7. 인가 서버 → 서버: { access_token, id_token }
8. 서버 → 사용자 조회/생성 → JWT 발급
```

### Next.js + NextAuth 패턴

```typescript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';
import GitHubProvider from 'next-auth/providers/github';

export const authOptions = {
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHubProvider({
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    }),
  ],
  callbacks: {
    async jwt({ token, account, profile }) {
      if (account) {
        token.provider = account.provider;
        // DB에 사용자 upsert
        const user = await upsertUser({ email: profile.email, provider: account.provider });
        token.userId = user.id;
        token.roles = user.roles;
      }
      return token;
    },
    async session({ session, token }) {
      session.user.id = token.userId;
      session.user.roles = token.roles;
      return session;
    },
  },
  pages: { signIn: '/login', error: '/login' },
};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
```

---

## 3. 인가 (RBAC / ABAC)

### RBAC (역할 기반)

```typescript
// 역할 정의
const ROLES = {
  owner: ['session:*', 'team:*', 'billing:*', 'settings:*'],
  admin: ['session:*', 'team:manage', 'settings:read'],
  member: ['session:own', 'team:read'],
  viewer: ['session:read'],
} as const;

// 인가 미들웨어
function authorize(...permissions: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const userPerms = ROLES[req.user.role] || [];
    const hasPermission = permissions.every(p =>
      userPerms.some(up => up === p || up === p.split(':')[0] + ':*')
    );
    if (!hasPermission) return res.status(403).json({ error: 'Forbidden' });
    next();
  };
}

// 사용
app.delete('/api/sessions/:id', authenticate, authorize('session:own'), deleteSession);
```

### 리소스 소유권 확인

```typescript
// 세션 소유권 (Aice 핵심: 자기 세션만 접근)
async function authorizeSessionAccess(req: Request, res: Response, next: NextFunction) {
  const session = await db.session.findById(req.params.id);
  if (!session) return res.status(404).json({ error: 'Not found' });

  // 루트 세션 소유자 확인 (트리 전체에 적용)
  const rootSession = await findRootSession(session);
  if (rootSession.userId !== req.user.sub) {
    return res.status(403).json({ error: 'Not your session' });
  }

  req.session = session;
  next();
}
```

---

## 4. 보안 체크리스트

- [ ] 비밀번호: bcrypt/argon2 해시 (최소 12라운드)
- [ ] JWT: 짧은 수명 (15분), refresh rotation
- [ ] HTTPS 전용 (HSTS)
- [ ] CSRF 보호 (SameSite=Lax 쿠키 또는 토큰)
- [ ] Rate limiting: 로그인 5회/분, API 100회/분
- [ ] 에러 메시지에 내부 정보 미노출
- [ ] Refresh token DB 저장 + 해시
- [ ] 로그아웃 시 refresh token 무효화
- [ ] OAuth state/PKCE 파라미터 검증

## 출처

wshobson/agents developer-essentials 플러그인 auth-implementation-patterns 스킬 지식 추출 + Aice Session Tree 인가 패턴 추가.
