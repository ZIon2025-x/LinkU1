# Social Crawler SSR Wiring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Vercel Edge Middleware to forward non-JS social crawler requests to the existing backend SSR endpoints, replacing the broken prerender.io integration.

**Architecture:** Single-file rewrite of `frontend/middleware.ts`. Detect non-JS social crawler User-Agents (WeChat/Facebook/Twitter/WhatsApp/Telegram/etc.) AND a whitelisted SSR path, then `fetch` the corresponding `api.link2ur.com` URL and return its HTML body. Any error or non-allowed status falls back to the SPA — never propagates errors to crawlers.

**Tech Stack:** TypeScript, Vercel Edge Runtime (Web standard `Request`/`Response`/`fetch`), Jest (via `react-scripts test`).

**Spec:** `docs/superpowers/specs/2026-04-08-social-crawler-ssr-wiring-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `frontend/middleware.ts` | **Rewrite** (~80 lines) | Edge middleware: detect crawler+path, fetch backend SSR, fallback on errors |
| `frontend/src/__tests__/middleware.test.ts` | **Create** | Jest unit tests for middleware behavior with mocked `fetch` |

**Note on test location:** CRA's Jest config picks up `src/**/__tests__/*.test.ts`. The middleware file lives at `frontend/middleware.ts` (project root, required by Vercel), but tests must live under `src/` to be discovered. The test imports the middleware via relative path `../../middleware`.

---

## Task 1: Write the failing test for non-JS crawler routing

**Files:**
- Create: `frontend/src/__tests__/middleware.test.ts`

- [ ] **Step 1: Create the test file with the first failing test**

```ts
// frontend/src/__tests__/middleware.test.ts
import middleware from '../../middleware';

// Polyfill Response for jest-jsdom environment if needed
// (CRA's jest-environment-jsdom already provides Request/Response/fetch globals via jsdom or whatwg-fetch)

describe('middleware', () => {
  const realFetch = global.fetch;

  afterEach(() => {
    global.fetch = realFetch;
    jest.resetAllMocks();
  });

  function makeRequest(url: string, ua: string): Request {
    return new Request(url, { headers: { 'user-agent': ua } });
  }

  const WECHAT_UA =
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) ' +
    'Chrome/53.0.2785.116 Safari/537.36 MicroMessenger/6.5.2.501 NetType/WIFI WindowsWechat';

  it('forwards WeChat crawler requests on whitelisted task path to backend SSR', async () => {
    const backendHtml = '<html><head><meta property="og:title" content="Real Task"></head></html>';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(backendHtml, {
        status: 200,
        headers: { 'content-type': 'text/html; charset=utf-8' },
      })
    );

    const req = makeRequest('https://www.link2ur.com/zh/tasks/123', WECHAT_UA);
    const res = await middleware(req);

    expect(res).toBeInstanceOf(Response);
    expect(res!.status).toBe(200);
    expect(res!.headers.get('x-ssr')).toBe('backend');
    expect(await res!.text()).toBe(backendHtml);

    expect(global.fetch).toHaveBeenCalledTimes(1);
    const fetchUrl = (global.fetch as jest.Mock).mock.calls[0][0];
    expect(fetchUrl).toBe('https://api.link2ur.com/zh/tasks/123');
  });
});
```

- [ ] **Step 2: Run test, verify it fails**

Run from `frontend/`:
```bash
npm test -- --watchAll=false src/__tests__/middleware.test.ts
```

Expected: FAIL — current `middleware.ts` has prerender.io logic, will not call `api.link2ur.com`. Likely error: "Expected `https://api.link2ur.com/zh/tasks/123`, received `https://service.prerender.io/...`" or returns `undefined`.

- [ ] **Step 3: Commit the failing test**

```bash
cd F:/python_work/LinkU
git add frontend/src/__tests__/middleware.test.ts
git commit -m "test(middleware): add failing test for non-JS crawler SSR routing"
```

---

## Task 2: Implement minimal middleware to pass the first test

**Files:**
- Modify: `frontend/middleware.ts` (full rewrite)

- [ ] **Step 1: Replace `frontend/middleware.ts` entirely**

```ts
// frontend/middleware.ts
//
// Vercel Edge Middleware: forward non-JS social crawler requests to the
// backend SSR endpoints (api.link2ur.com) so crawlers get real OG/Twitter
// Card meta tags. Googlebot/Bingbot and normal users fall through to the
// SPA. Any backend error or unexpected response also falls through — we
// never propagate failures to crawlers.

const NON_JS_CRAWLERS: RegExp[] = [
  /MicroMessenger/i,
  /WeChat/i,
  /Weixin/i,
  /WeChatShareExtension/i,
  /facebookexternalhit/i,
  /Facebot/i,
  /Twitterbot/i,
  /LinkedInBot/i,
  /Slackbot/i,
  /TelegramBot/i,
  /WhatsApp/i,
  /Discordbot/i,
  /Pinterest/i,
  /Baiduspider/i,
  /YandexBot/i,
  /CCBot/i,
];

const SSR_PATH_PATTERNS: RegExp[] = [
  /^\/(zh|en)?\/?$/,                                  // home
  /^\/(zh\/|en\/)?tasks\/\d+\/?$/,                    // task detail
  /^\/(zh\/|en\/)?forum\/post\/\d+\/?$/,              // forum post detail
  /^\/(zh\/|en\/)?leaderboard\/custom\/\d+\/?$/,      // leaderboard detail
  /^\/(zh\/|en\/)?activities\/\d+\/?$/,               // activity detail
];

const BACKEND_ORIGIN = 'https://api.link2ur.com';
const FETCH_TIMEOUT_MS = 5000;
const ALLOWED_PASSTHROUGH_STATUSES = new Set([200, 404, 410]);

function isNonJsCrawler(ua: string): boolean {
  return NON_JS_CRAWLERS.some((re) => re.test(ua));
}

function isSsrPath(pathname: string): boolean {
  return SSR_PATH_PATTERNS.some((re) => re.test(pathname));
}

export default async function middleware(request: Request): Promise<Response | undefined> {
  const userAgent = request.headers.get('user-agent') || '';
  if (!isNonJsCrawler(userAgent)) return;

  const url = new URL(request.url);
  if (!isSsrPath(url.pathname)) return;

  const backendUrl = `${BACKEND_ORIGIN}${url.pathname}${url.search}`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const upstream = await fetch(backendUrl, {
      headers: { 'user-agent': userAgent },
      redirect: 'follow',
      signal: controller.signal,
    });

    if (!ALLOWED_PASSTHROUGH_STATUSES.has(upstream.status)) return;

    const contentType = upstream.headers.get('content-type') || '';
    if (!contentType.includes('text/html')) return;

    const body = await upstream.text();
    return new Response(body, {
      status: upstream.status,
      headers: {
        'content-type': contentType,
        'cache-control': 'public, s-maxage=3600, stale-while-revalidate=86400',
        'x-ssr': 'backend',
      },
    });
  } catch {
    return;
  } finally {
    clearTimeout(timeoutId);
  }
}

export const config = {
  matcher: ['/((?!static|_next|api|favicon).*)'],
};
```

- [ ] **Step 2: Run the test, verify it passes**

```bash
cd frontend
npm test -- --watchAll=false src/__tests__/middleware.test.ts
```

Expected: PASS (1 test).

- [ ] **Step 3: Commit**

```bash
cd F:/python_work/LinkU
git add frontend/middleware.ts
git commit -m "feat(middleware): forward non-JS social crawlers to backend SSR

Replaces the broken prerender.io integration. Detects WeChat/Facebook/
Twitter/WhatsApp/Telegram/etc. and a whitelist of SSR paths, then proxies
to api.link2ur.com which already implements complete SSR with OG/Twitter
Card meta. Backend errors and non-HTML responses fall through to SPA."
```

---

## Task 3: Add test for JS-capable crawler bypass

**Files:**
- Modify: `frontend/src/__tests__/middleware.test.ts`

- [ ] **Step 1: Append the failing test**

Add inside the `describe` block:

```ts
  it('does NOT intercept Googlebot — falls through to SPA', async () => {
    global.fetch = jest.fn();
    const req = makeRequest(
      'https://www.link2ur.com/zh/tasks/123',
      'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
    );

    const res = await middleware(req);

    expect(res).toBeUndefined();
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('does NOT intercept normal browser users', async () => {
    global.fetch = jest.fn();
    const req = makeRequest(
      'https://www.link2ur.com/zh/tasks/123',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 ' +
        '(KHTML, like Gecko) Version/17.0 Safari/605.1.15'
    );

    const res = await middleware(req);

    expect(res).toBeUndefined();
    expect(global.fetch).not.toHaveBeenCalled();
  });
```

- [ ] **Step 2: Run all tests, verify all pass**

```bash
cd frontend
npm test -- --watchAll=false src/__tests__/middleware.test.ts
```

Expected: PASS (3 tests). Implementation already handles these via the early-return at the top of `middleware()`.

- [ ] **Step 3: Commit**

```bash
cd F:/python_work/LinkU
git add frontend/src/__tests__/middleware.test.ts
git commit -m "test(middleware): verify JS-capable crawlers and users bypass SSR"
```

---

## Task 4: Add test for path whitelist

**Files:**
- Modify: `frontend/src/__tests__/middleware.test.ts`

- [ ] **Step 1: Append the test**

```ts
  it('does NOT proxy unsupported paths even for crawlers', async () => {
    global.fetch = jest.fn();
    // /profile/me is a real SPA route but has no backend SSR endpoint
    const req = makeRequest('https://www.link2ur.com/profile/me', WECHAT_UA);

    const res = await middleware(req);

    expect(res).toBeUndefined();
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('proxies all supported SSR paths for non-JS crawlers', async () => {
    const ok = (body = '<html></html>') =>
      new Response(body, { status: 200, headers: { 'content-type': 'text/html' } });
    global.fetch = jest.fn().mockResolvedValue(ok());

    const paths = [
      '/',
      '/zh',
      '/en',
      '/tasks/1',
      '/zh/tasks/42',
      '/en/tasks/999',
      '/forum/post/1',
      '/zh/forum/post/42',
      '/en/forum/post/999',
      '/leaderboard/custom/1',
      '/zh/leaderboard/custom/42',
      '/en/leaderboard/custom/999',
      '/activities/1',
      '/zh/activities/42',
      '/en/activities/999',
    ];

    for (const p of paths) {
      const req = makeRequest(`https://www.link2ur.com${p}`, WECHAT_UA);
      const res = await middleware(req);
      expect(res).toBeInstanceOf(Response);
      expect(res!.status).toBe(200);
    }

    expect((global.fetch as jest.Mock).mock.calls.length).toBe(paths.length);
  });
```

- [ ] **Step 2: Run, verify all pass**

```bash
cd frontend
npm test -- --watchAll=false src/__tests__/middleware.test.ts
```

Expected: PASS (5 tests).

- [ ] **Step 3: Commit**

```bash
cd F:/python_work/LinkU
git add frontend/src/__tests__/middleware.test.ts
git commit -m "test(middleware): verify path whitelist behavior for all SSR routes"
```

---

## Task 5: Add tests for backend error fallback

**Files:**
- Modify: `frontend/src/__tests__/middleware.test.ts`

- [ ] **Step 1: Append the tests**

```ts
  it('falls through to SPA when backend returns 500', async () => {
    global.fetch = jest.fn().mockResolvedValue(
      new Response('upstream error', {
        status: 500,
        headers: { 'content-type': 'text/html' },
      })
    );

    const req = makeRequest('https://www.link2ur.com/zh/tasks/123', WECHAT_UA);
    const res = await middleware(req);

    expect(res).toBeUndefined();
  });

  it('falls through to SPA when backend returns 502/503/504', async () => {
    for (const status of [502, 503, 504]) {
      global.fetch = jest.fn().mockResolvedValue(
        new Response('', { status, headers: { 'content-type': 'text/html' } })
      );
      const req = makeRequest('https://www.link2ur.com/zh/tasks/123', WECHAT_UA);
      const res = await middleware(req);
      expect(res).toBeUndefined();
    }
  });

  it('passes through 404 from backend (e.g. task does not exist)', async () => {
    global.fetch = jest.fn().mockResolvedValue(
      new Response('<html><head><title>Not found</title></head></html>', {
        status: 404,
        headers: { 'content-type': 'text/html' },
      })
    );

    const req = makeRequest('https://www.link2ur.com/zh/tasks/99999', WECHAT_UA);
    const res = await middleware(req);

    expect(res).toBeInstanceOf(Response);
    expect(res!.status).toBe(404);
    expect(res!.headers.get('x-ssr')).toBe('backend');
  });

  it('passes through 410 from backend (e.g. cancelled task)', async () => {
    global.fetch = jest.fn().mockResolvedValue(
      new Response('<html></html>', {
        status: 410,
        headers: { 'content-type': 'text/html' },
      })
    );

    const req = makeRequest('https://www.link2ur.com/zh/tasks/55', WECHAT_UA);
    const res = await middleware(req);

    expect(res).toBeInstanceOf(Response);
    expect(res!.status).toBe(410);
  });

  it('falls through when backend returns non-HTML content-type', async () => {
    global.fetch = jest.fn().mockResolvedValue(
      new Response('{"error":"oops"}', {
        status: 200,
        headers: { 'content-type': 'application/json' },
      })
    );

    const req = makeRequest('https://www.link2ur.com/zh/tasks/123', WECHAT_UA);
    const res = await middleware(req);

    expect(res).toBeUndefined();
  });

  it('falls through when fetch throws (network error)', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('ECONNREFUSED'));

    const req = makeRequest('https://www.link2ur.com/zh/tasks/123', WECHAT_UA);
    const res = await middleware(req);

    expect(res).toBeUndefined();
  });
```

- [ ] **Step 2: Run, verify all pass**

```bash
cd frontend
npm test -- --watchAll=false src/__tests__/middleware.test.ts
```

Expected: PASS (11 tests). All should pass against the existing implementation from Task 2.

- [ ] **Step 3: Commit**

```bash
cd F:/python_work/LinkU
git add frontend/src/__tests__/middleware.test.ts
git commit -m "test(middleware): cover backend error fallback paths"
```

---

## Task 6: Add tests for crawler UA coverage

**Files:**
- Modify: `frontend/src/__tests__/middleware.test.ts`

- [ ] **Step 1: Append the test**

```ts
  it('intercepts all listed non-JS crawler User-Agents', async () => {
    const crawlerUAs = [
      'MicroMessenger/6.5.2',
      'Mozilla/5.0 WeChat/8.0',
      'Weixin/1.0',
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
      'Facebot/1.0',
      'Twitterbot/1.0',
      'LinkedInBot/1.0 (compatible; Mozilla/5.0; Apache-HttpClient +http://www.linkedin.com)',
      'Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)',
      'TelegramBot (like TwitterBot)',
      'WhatsApp/2.21.12.21 A',
      'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
      'Pinterest/0.2 (+http://www.pinterest.com/)',
      'Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)',
      'Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)',
      'CCBot/2.0 (https://commoncrawl.org/faq/)',
    ];

    for (const ua of crawlerUAs) {
      global.fetch = jest.fn().mockResolvedValue(
        new Response('<html></html>', {
          status: 200,
          headers: { 'content-type': 'text/html' },
        })
      );

      const req = makeRequest('https://www.link2ur.com/zh/tasks/1', ua);
      const res = await middleware(req);

      expect(res).toBeInstanceOf(Response);
      expect((global.fetch as jest.Mock)).toHaveBeenCalledTimes(1);
    }
  });
```

- [ ] **Step 2: Run, verify pass**

```bash
cd frontend
npm test -- --watchAll=false src/__tests__/middleware.test.ts
```

Expected: PASS (12 tests).

- [ ] **Step 3: Commit**

```bash
cd F:/python_work/LinkU
git add frontend/src/__tests__/middleware.test.ts
git commit -m "test(middleware): verify all listed crawler UAs are intercepted"
```

---

## Task 7: TypeScript build sanity check

**Files:** none (verification only)

- [ ] **Step 1: Run TypeScript compile check on the middleware**

```bash
cd frontend
npx tsc --noEmit middleware.ts
```

Expected: no output (0 errors). If `tsc` complains about lib (e.g. `Request`/`Response` not found), add an inline directive at the top of `middleware.ts`:

```ts
/// <reference lib="dom" />
```

Then re-run.

- [ ] **Step 2: Run the full frontend build to confirm Vercel will accept it**

```bash
cd frontend
npm run build
```

Expected: build succeeds (CRA only builds `src/`, but a TypeScript error in middleware.ts referenced from anywhere would surface). Vercel detects `middleware.ts` automatically — no extra config needed.

- [ ] **Step 3: If any change was needed in step 1, commit**

```bash
cd F:/python_work/LinkU
git add frontend/middleware.ts
git commit -m "build(middleware): add dom lib reference for Request/Response globals"
```

(Skip this step if no changes were needed.)

---

## Task 8: Deploy and verify against production

**Files:** none (operational)

- [ ] **Step 1: Push to remote (Vercel auto-deploys)**

Confirm with the user before pushing:

```bash
cd F:/python_work/LinkU
git push
```

- [ ] **Step 2: Wait for Vercel deployment to complete**

Check Vercel dashboard or run:
```bash
curl -sI https://www.link2ur.com/ | head -5
```

Wait until the deployment is live (Vercel typically takes 1-3 minutes).

- [ ] **Step 3: Verify WeChat crawler gets backend SSR**

```bash
curl -sI -A "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36 MicroMessenger/6.5.2.501 NetType/WIFI WindowsWechat" https://www.link2ur.com/zh/tasks/1
```

Expected: `HTTP/1.1 200`, header `x-ssr: backend` present.

- [ ] **Step 4: Verify the body actually contains a task-specific OG title**

```bash
curl -s -A "facebookexternalhit/1.1" https://www.link2ur.com/en/tasks/1 | grep -i 'og:title'
```

Expected: an `<meta property="og:title" content="...Link²Ur任务平台">` line containing a real task title (not the default site title).

- [ ] **Step 5: Verify Googlebot is NOT intercepted (still gets SPA)**

```bash
curl -sI -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" https://www.link2ur.com/en/tasks/1
```

Expected: `HTTP/1.1 200`, header `x-ssr` is **absent**.

- [ ] **Step 6: Verify normal user gets SPA**

```bash
curl -sI -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120.0.0.0 Safari/537.36" https://www.link2ur.com/en/tasks/1
```

Expected: `HTTP/1.1 200`, header `x-ssr` is **absent**.

- [ ] **Step 7: Verify a non-existent task returns 404 (passes through)**

```bash
curl -sI -A "Twitterbot/1.0" https://www.link2ur.com/en/tasks/99999999
```

Expected: `HTTP/1.1 404` with `x-ssr: backend` header.

If any of these fail, investigate before proceeding to Task 9.

---

## Task 9: Clean up PRERENDER_TOKEN environment variable

**Files:** none (Vercel dashboard)

- [ ] **Step 1: Inform the user to manually delete `PRERENDER_TOKEN`**

This step requires Vercel dashboard access, which the agent does not have. Output the following instruction to the user:

> Go to **Vercel Dashboard → frontend project → Settings → Environment Variables** and **delete `PRERENDER_TOKEN`** (Production, Preview, and Development scopes). The middleware no longer reads it, but removing it documents the cleanup and prevents confusion later.

Wait for user confirmation that this is done.

---

## Task 10: Request reindexing in Google Search Console

**Files:** none (operational)

- [ ] **Step 1: Inform the user to request reindexing**

Output the following instruction:

> In **Google Search Console**:
> 1. Go to "URL Inspection"
> 2. Paste a previously-erroring URL (e.g. `https://www.link2ur.com/en/tasks/1`)
> 3. Click "Test Live URL" → confirm it returns 200
> 4. Click "Request Indexing"
> 5. Repeat for a few representative URLs from the 5xx report
>
> The 5xx count in the "Page indexing" report should drop within a few days as Google re-crawls.

---

## Self-Review

**Spec coverage check** — every spec section maps to a task:

| Spec section | Implementing tasks |
|---|---|
| Background / root cause analysis | (informational only — no code) |
| Goals (4 page types + home, social crawlers get OG meta) | Task 2 (`SSR_PATH_PATTERNS`), Task 4 (path tests), Task 6 (UA tests) |
| Non-goals (no Googlebot SSR, no backend changes) | Task 3 (Googlebot bypass test), no backend tasks present ✓ |
| `frontend/middleware.ts` rewrite | Task 2 |
| `NON_JS_CRAWLERS` aligned with backend | Task 2 (list), Task 6 (verification) |
| Path whitelist for 5 categories | Task 2 (regex list), Task 4 (tests) |
| Backend compatibility (no `X-Forwarded-Host` needed) | Implemented in Task 2 — fetch only sends `user-agent` |
| Error handling rules (5xx fallback, 404/410 passthrough) | Task 5 |
| Cache headers `s-maxage=3600` | Task 2 |
| 5-second timeout | Task 2 |
| `og:url` consistency | Implicit — middleware does not rewrite URL, only proxies body |
| Verification curl commands | Task 8 |
| `PRERENDER_TOKEN` cleanup | Task 9 |
| Search Console reindexing | Task 10 |
| Rollback (`git revert`) | Implicit — single-commit revert works because each task commits independently |

No gaps.

**Placeholder scan**: searched for "TBD", "TODO", "later", "appropriate", "similar to" — none present. All tasks contain complete code or exact commands.

**Type/name consistency**:
- `middleware()` exported as default ✓ (Task 2 + tests in Tasks 1, 3-6)
- `NON_JS_CRAWLERS` / `SSR_PATH_PATTERNS` / `BACKEND_ORIGIN` / `FETCH_TIMEOUT_MS` / `ALLOWED_PASSTHROUGH_STATUSES` — all defined in Task 2, not referenced by name in tests (tests test behavior, not internals) ✓
- Header name `x-ssr: backend` — emitted in Task 2, asserted in Tasks 1, 3, 5, 8 (all match lowercase, since `Headers.get` is case-insensitive) ✓
- 200/404/410 in `ALLOWED_PASSTHROUGH_STATUSES` matches the spec's "最终规则" table ✓

Plan is consistent and complete.
