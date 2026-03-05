const PRERENDER_TOKEN = 'eLAPk9lbtNJ0B1kCoOFb';

const BOT_USER_AGENTS = [
  'googlebot',
  'bingbot',
  'yandex',
  'baiduspider',
  'facebookexternalhit',
  'twitterbot',
  'rogerbot',
  'linkedinbot',
  'embedly',
  'quora link preview',
  'showyoubot',
  'outbrain',
  'pinterest/0.',
  'developers.google.com/+/web/snippet',
  'slackbot',
  'vkshare',
  'w3c_validator',
  'redditbot',
  'applebot',
  'whatsapp',
  'flipboard',
  'tumblr',
  'bitlybot',
  'skypeuripreview',
  'nuzzel',
  'discordbot',
  'qwantify',
  'pinterestbot',
  'bitrix link preview',
  'xing-contenttabreceiver',
  'chrome-lighthouse',
  'telegrambot',
  'google-inspectiontool',
  'petalbot',
];

function isBot(userAgent: string): boolean {
  const ua = userAgent.toLowerCase();
  return BOT_USER_AGENTS.some(bot => ua.includes(bot));
}

export default async function middleware(request: Request) {
  const userAgent = request.headers.get('user-agent') || '';

  // Only proxy crawler requests to prerender.io
  if (!isBot(userAgent)) {
    return;
  }

  // Skip prerendering for static assets, API routes, and non-page resources
  const url = new URL(request.url);
  const { pathname } = url;
  if (
    pathname.startsWith('/static/') ||
    pathname.startsWith('/api/') ||
    pathname.match(/\.(js|css|xml|json|ico|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot|txt|map)$/)
  ) {
    return;
  }

  // Build the prerender.io URL
  const prerenderUrl = `https://service.prerender.io/${request.url}`;

  try {
    // Fetch pre-rendered page from prerender.io
    const response = await fetch(prerenderUrl, {
      headers: {
        'X-Prerender-Token': PRERENDER_TOKEN,
        'X-Prerender-Int-Type': 'visionary',
      },
      redirect: 'follow',
    });

    // Return the pre-rendered HTML
    return new Response(response.body, {
      status: response.status,
      headers: {
        'Content-Type': response.headers.get('Content-Type') || 'text/html',
        'Cache-Control': 'public, max-age=3600',
        'X-Prerendered': 'true',
      },
    });
  } catch {
    // If prerender.io fails, fall through to normal SPA
    return;
  }
}

export const config = {
  matcher: ['/((?!static|_next|api|favicon).*)'],
};
