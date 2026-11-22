import { createClient } from 'npm:@supabase/supabase-js@2';
import { Logger, Timer, validateRequired, toAppError, truncate, HUNTER_CONSTANTS } from '../_shared/core.ts';
import { handleCors, successResponse, errorResponse } from '../_shared/cors.ts';
import { searxngSearch, dedupeByDomain, filterJunkDomains, type SearxngResult } from '../_shared/searxng.ts';

const SEARCH_CONCURRENCY = 2;
const MAX_RESULTS_PER_QUERY = 10;
const INSERT_BATCH_SIZE = 50;
const STALE_LOCK_MS = 5 * 60 * 1000;

Deno.serve(async (req) => {
  const corsResult = handleCors(req);
  if (corsResult) return corsResult;

  const logger = new Logger({ function: 'hunter-extract' });
  const timer = new Timer();

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return errorResponse('Missing authorization header', 401);

    const supabaseUser = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse('Invalid session', 401);
    
    timer.mark('auth');

    let body: Record<string, unknown>;
    try { body = await req.json(); } catch { return errorResponse('Invalid JSON body', 400); }
    
    const jobId = validateRequired(body.job_id, 'job_id');
    timer.mark('validate');

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: job, error: jobError } = await supabase.from('hunter_jobs').select('*').eq('id', jobId).eq('user_id', user.id).single();

    if (jobError || !job) return errorResponse('Job not found', 404);

    const queries = normalizeStringArray(job.queries_generated);
    if (queries.length === 0) return errorResponse('Job has no queries. Run hunter-search first.', 400);

    if (job.status === 'completed') return errorResponse('Job already completed.', 400);
    if (job.status === 'scoring' || job.status === 'drafting') {
      return successResponse({ job_id: job.id, status: job.status, started: false, message: `Job already ${job.status}.` });
    }

    const startedAtMs = job.started_at ? new Date(job.started_at as string).getTime() : 0;
    const isStale = job.status === 'searching' && Date.now() - startedAtMs > STALE_LOCK_MS;

    if (job.status === 'searching' && !isStale) {
      return successResponse({ job_id: job.id, status: job.status, started: false, message: 'Extraction already in progress.' });
    }

    let claimQuery = supabase.from('hunter_jobs').update({ status: 'searching', progress: 15, started_at: new Date().toISOString(), error_message: null }).eq('id', job.id).eq('status', job.status);
    if (isStale && job.started_at) claimQuery = claimQuery.eq('started_at', job.started_at);

    const { data: claimed, error: claimError } = await claimQuery.select().maybeSingle();

    if (claimError || !claimed) return successResponse({ job_id: job.id, status: job.status, started: false, message: 'Job is being claimed.' });
    timer.mark('claimed');

    const background = runExtraction({ job: claimed, user, authHeader, supabase, logger }).catch(async (err) => {
      const appErr = toAppError(err);
      await supabase.from('hunter_jobs').update({ status: 'failed', error_message: truncate(appErr.message, 500), completed_at: new Date().toISOString() }).eq('id', job.id);
    });

    const er = (globalThis as any).EdgeRuntime;
    if (er?.waitUntil) er.waitUntil(background); else background.then(() => {});

    return successResponse({ job_id: job.id, status: 'searching', started: true, recovered_from_stale: isStale, queries_count: queries.length, chained_to: 'hunter-score' });
  } catch (err) {
    const appErr = toAppError(err);
    return errorResponse(appErr.message, appErr.statusCode);
  }
});

async function runExtraction(args: any): Promise<void> {
  const { job, user, authHeader, supabase, logger } = args;
  const queries = normalizeStringArray(job.queries_generated);
  const language = (job.language as string) || 'en'; // ← قراءة اللغة من الـ Job
  const timer = new Timer();

  try {
    const allResults: SearxngResult[] = [];

    for (let i = 0; i < queries.length; i += SEARCH_CONCURRENCY) {
      const batch = queries.slice(i, i + SEARCH_CONCURRENCY);
      const batchResults = await Promise.all(batch.map(async (query: string) => {
        try {
          return await searxngSearch({ query, numResults: MAX_RESULTS_PER_QUERY, language, categories: 'general' }, logger);
        } catch (err) {
          logger.warn('Query failed', { query, error: (err as Error).message });
          return [];
        }
      }));
      allResults.push(...batchResults.flat());
      await supabase.from('hunter_jobs').update({ progress: Math.min(35, 15 + Math.round(((i + SEARCH_CONCURRENCY) / queries.length) * 20)) }).eq('id', job.id);
    }

    timer.mark('searches_done');

    const filtered = filterJunkDomains(allResults);
    const unique = dedupeByDomain(filtered).slice(0, HUNTER_CONSTANTS.MAX_LEADS_PER_JOB);

    if (unique.length === 0) {
      await supabase.from('hunter_jobs').update({ status: 'failed', error_message: 'No valid results after filtering', completed_at: new Date().toISOString() }).eq('id', job.id);
      return;
    }

    timer.mark('filter_done');
    const saved = await saveLeads({ supabase, jobId: job.id, userId: user.id, unique, logger });
    
    if (saved.total === 0) {
      await supabase.from('hunter_jobs').update({ status: 'failed', error_message: 'Failed to save leads', completed_at: new Date().toISOString() }).eq('id', job.id);
      return;
    }

    timer.mark('saved');

    await supabase.from('hunter_jobs').update({ status: 'scoring', progress: 40, raw_results_count: unique.length, leads_count: saved.total }).eq('id', job.id);

    chainToScore(authHeader, job.id, logger, supabase);
  } catch (err) {
    throw err;
  }
}

async function saveLeads(args: any) {
  const { supabase, jobId, userId, unique, logger } = args;
  const { data: existingRows, error: fetchErr } = await supabase.from('hunter_leads').select('id, source_url').eq('job_id', jobId);
  if (fetchErr) throw new Error(fetchErr.message);

  const existingByUrl = new Map((existingRows ?? []).map((r: any) => [r.source_url, r.id]));
  const toInsert: any[] = [];
  const toUpdate: any[] = [];

  for (const r of unique) {
    if (existingByUrl.has(r.url)) {
      toUpdate.push({ id: existingByUrl.get(r.url), payload: { company_name: r.title.slice(0, 200), website: r.url, source_title: r.title, source_snippet: r.content } });
    } else {
      toInsert.push({ job_id: jobId, user_id: userId, company_name: r.title.slice(0, 200), website: r.url, source_url: r.url, source_title: r.title, source_snippet: r.content, score: 0, score_breakdown: {}, score_reasons: [], status: 'new' });
    }
  }

  let inserted = 0;
  if (toInsert.length > 0) {
    for (let i = 0; i < toInsert.length; i += INSERT_BATCH_SIZE) {
      const chunk = toInsert.slice(i, i + INSERT_BATCH_SIZE);
      const { data, error } = await supabase.from('hunter_leads').insert(chunk).select('id');
      if (error) throw new Error(`Batch insert failed: ${error.message}`);
      inserted += data?.length ?? 0;
    }
  }

  let updated = 0;
  for (const u of toUpdate) {
    const { error } = await supabase.from('hunter_leads').update(u.payload).eq('id', u.id);
    if (!error) updated++;
  }

  const { count } = await supabase.from('hunter_leads').select('id', { count: 'exact', head: true }).eq('job_id', jobId);
  return { inserted, updated, total: count ?? inserted + toUpdate.length };
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((v): v is string => typeof v === 'string').map((v) => v.trim()).filter((v) => v.length > 0);
}

function chainToScore(authHeader: string, jobId: string, logger: Logger, supabase: any): void {
  const promise = fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/hunter-score`, { method: 'POST', headers: { Authorization: authHeader, 'Content-Type': 'application/json' }, body: JSON.stringify({ job_id: jobId }) }).catch(async (err) => {
    await supabase.from('hunter_jobs').update({ status: 'failed', error_message: `Chain failed: ${err.message}`, completed_at: new Date().toISOString() }).eq('id', jobId);
  });
  const er = (globalThis as any).EdgeRuntime;
  if (er?.waitUntil) er.waitUntil(promise); else promise.then(() => {});
}