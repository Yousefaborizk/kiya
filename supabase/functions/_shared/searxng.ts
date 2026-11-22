// ============================================
// _shared/searxng.ts
// ============================================
import { Logger, truncate } from './core.ts';

const PUBLIC_INSTANCES = [
  'https://searx.be',
  'https://search.inetol.net',
  'https://baresearch.org',
];

// خريطة تحويل اللغات إلى أكواد Google (hl) والدول (gl)
const LANG_MAP: Record<string, { hl: string; gl: string }> = {
  'en': { hl: 'en', gl: 'us' },
  'ar': { hl: 'ar', gl: 'eg' },
  'zh': { hl: 'zh-CN', gl: 'cn' },
};

export interface SearxngResult {
  url: string;
  title: string;
  content: string;
  engine: string;
  score?: number;
}

export interface SearxngSearchOptions {
  query: string;
  numResults?: number;
  language?: string;
  categories?: string;
  timeRange?: string;
  timeoutMs?: number;
}

export async function searxngSearch(
  opts: SearxngSearchOptions,
  logger?: Logger,
): Promise<SearxngResult[]> {
  const serperKey = Deno.env.get('SERPER_API_KEY');
  
  // 1. Try Serper
  if (serperKey) {
    try {
      const results = await _serperSearch(opts, serperKey, logger);
      if (results.length > 0) return results;
    } catch (err) {
      logger?.warn('Serper failed, falling back to SearXNG', {
        error: (err as Error).message,
      });
    }
  }

  // 2. Fallback to SearXNG
  const envUrl = Deno.env.get('SEARXNG_URL');
  const instances = envUrl ? [envUrl, ...PUBLIC_INSTANCES] : PUBLIC_INSTANCES;
  const errors: string[] = [];

  for (const instance of instances) {
    try {
      const results = await _searxngSearch(opts, instance, logger);
      if (results.length > 0) return results;
    } catch (err) {
      errors.push(`${instance} → ${(err as Error).message}`);
    }
  }

  throw new Error(`All search providers failed. Last errors: ${errors.join(' | ')}`);
}

async function _serperSearch(
  opts: SearxngSearchOptions,
  apiKey: string,
  logger?: Logger,
): Promise<SearxngResult[]> {
  const { query, numResults = 10, timeoutMs = 12_000, language = 'en' } = opts;
  const langInfo = LANG_MAP[language] || LANG_MAP['en'];

  const res = await fetch('https://google.serper.dev/search', {
    method: 'POST',
    headers: { 'X-API-KEY': apiKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      q: query,
      num: numResults,
      gl: langInfo.gl,
      hl: langInfo.hl,
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!res.ok) throw new Error(`Serper ${res.status}`);
  const data = await res.json();
  
  return (data.organic ?? [])
    .filter((r: any) => r.link && r.title)
    .map((r: any) => ({
      url: r.link,
      title: r.title.trim(),
      content: (r.snippet ?? '').trim(),
      engine: 'serper-google',
    }))
    .slice(0, numResults);
}

async function _searxngSearch(
  opts: SearxngSearchOptions,
  instance: string,
  logger?: Logger,
): Promise<SearxngResult[]> {
  const { query, numResults = 10, language = 'en', categories = 'general', timeRange, timeoutMs = 12_000 } = opts;

  const params = new URLSearchParams({
    q: query,
    format: 'json',
    categories,
    language,
    safesearch: '0',
    pageno: '1',
  });
  if (timeRange) params.set('time_range', timeRange);

  const res = await fetch(`${instance}/search?${params.toString()}`, {
    headers: { 'Accept': 'application/json' },
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  
  return (data.results ?? [])
    .filter((r: any) => r.url && r.title)
    .map((r: any) => ({
      url: r.url,
      title: r.title.trim(),
      content: (r.content ?? '').trim(),
      engine: r.engine ?? 'searxng',
    }))
    .slice(0, numResults);
}

export function dedupeByDomain(results: SearxngResult[]): SearxngResult[] {
  const seen = new Set<string>();
  return results.filter(r => {
    try {
      const domain = new URL(r.url).hostname.replace(/^www\./, '').toLowerCase();
      if (seen.has(domain)) return false;
      seen.add(domain);
      return true;
    } catch { return false; }
  });
}

const BLOCKED_DOMAINS = [
  'wikipedia.org', 'youtube.com', 'facebook.com', 'twitter.com', 'x.com',
  'instagram.com', 'linkedin.com', 'pinterest.com', 'reddit.com', 'quora.com',
  'medium.com', 'yelp.com', 'yellowpages.com', 'tripadvisor.com',
  'amazon.com', 'ebay.com', 'alibaba.com', 'aliexpress.com', 'indiamart.com',
  'tradeindia.com', 'made-in-china.com', 'globalsources.com',
  'glassdoor.com', 'indeed.com', 'monster.com', 'bayt.com', 'wuzzuf.net',
  'crunchbase.com', 'bloomberg.com', 'reuters.com', 'forbes.com',
  'bbc.com', 'cnn.com', 'nytimes.com', 'theguardian.com',
];

export function filterJunkDomains(results: SearxngResult[]): SearxngResult[] {
  return results.filter((r) => {
    try {
      const domain = new URL(r.url).hostname.replace(/^www\./, '').toLowerCase();
      return !BLOCKED_DOMAINS.some((b) => domain === b || domain.endsWith(`.${b}`));
    } catch { return false; }
  });
}