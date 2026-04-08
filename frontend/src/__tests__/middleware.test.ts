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
