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
