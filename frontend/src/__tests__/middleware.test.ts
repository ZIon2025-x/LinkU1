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

  // 微信分享扩展（链接预览爬虫）—— 仍走 SSR
  const WECHAT_UA =
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) ' +
    'Chrome/53.0.2785.116 Safari/537.36 WeChatShareExtension/8.0.0';

  // 微信内置浏览器（真实用户）—— 不应被中间件劫持
  const WECHAT_INAPP_BROWSER_UA =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 ' +
    '(KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.42(0x18002a3a) NetType/WIFI Language/zh_CN';

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
    const [fetchUrl, fetchOptions] = (global.fetch as jest.Mock).mock.calls[0];
    expect(fetchUrl).toBe('https://api.link2ur.com/zh/tasks/123');
    expect((fetchOptions as RequestInit).headers).toEqual({ 'user-agent': WECHAT_UA });
    expect((fetchOptions as RequestInit).redirect).toBe('error');
    expect((fetchOptions as RequestInit).signal).toBeInstanceOf(AbortSignal);
  });

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

  // 回归测试：微信 in-app 浏览器（MicroMessenger / WeChat / Weixin）是真实用户，
  // 会执行 JS。如果被中间件转发到 SSR，会因 SSR HTML 自跳转脚本陷入无限刷新。
  it('does NOT intercept WeChat in-app browser users (MicroMessenger UA)', async () => {
    global.fetch = jest.fn();
    const req = makeRequest(
      'https://www.link2ur.com/zh/tasks/123',
      WECHAT_INAPP_BROWSER_UA
    );

    const res = await middleware(req);

    expect(res).toBeUndefined();
    expect(global.fetch).not.toHaveBeenCalled();
  });

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
    global.fetch = jest.fn().mockImplementation(() => Promise.resolve(ok()));

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
      if (!(res instanceof Response)) {
        throw new Error(`path "${p}" was not proxied (returned ${res})`);
      }
      if (res.status !== 200) {
        throw new Error(`path "${p}" returned status ${res.status}, expected 200`);
      }
    }

    expect((global.fetch as jest.Mock).mock.calls.length).toBe(paths.length);
  });

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
    expect(res!.headers.get('x-ssr')).toBe('backend');
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

  it('intercepts all listed non-JS crawler User-Agents', async () => {
    const crawlerUAs = [
      'WeChatShareExtension/8.0.0',
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

    global.fetch = jest.fn().mockImplementation(() =>
      Promise.resolve(
        new Response('<html></html>', {
          status: 200,
          headers: { 'content-type': 'text/html' },
        })
      )
    );

    for (const ua of crawlerUAs) {
      const req = makeRequest('https://www.link2ur.com/zh/tasks/1', ua);
      const res = await middleware(req);
      if (!(res instanceof Response)) {
        throw new Error(`UA "${ua}" was not intercepted (returned ${res})`);
      }
    }

    expect((global.fetch as jest.Mock).mock.calls.length).toBe(crawlerUAs.length);
  });
});
