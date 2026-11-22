import { createClient } from 'npm:@supabase/supabase-js@2';
import { getAIClient } from '../_shared/ai_client.ts';
import {
  handleCors,
  successResponse,
  errorResponse,
} from '../_shared/cors.ts';
import {
  Logger,
  Timer,
  validateRequired,
  toAppError,
  truncate,
} from '../_shared/core.ts';

// ── Batching ─────────────────────────────────
const SCORE_BATCH_SIZE = 8;
const MAX_TOKENS_PER_CHUNK = 2500;
const DELAY_BETWEEN_CHUNKS_MS = 200;

interface ScoreResult {
  id: string;
  score: number;
  breakdown: Record<string, number>;
  reasons?: string[];
}

const SYSTEM_PROMPT = `You are a B2B export sales lead-scoring expert.
Score each lead 0-100 using:
- industry_fit (0-30): same industry?
- product_fit (0-25): matching products?
- geo_fit (0-20): in target countries?
- company_type (0-15): 15=importer/distributor, 10=retailer, 5=manufacturer, 0=irrelevant
- reachability (0-10): website + contact?
Total = 100. Be strict. Also give 2-4 short reasons.

OUTPUT JSON ONLY:
{"results":[{"id":"...","score":0-100,"breakdown":{"industry_fit":0,"product_fit":0,"geo_fit":0,"company_type":0,"reachability":0},"reasons":["..."]}]}`;

// ============================================
// Helpers
// ============================================
function chunkArray<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
}

function buildChunkPrompt(
  leads: Array<{
    id: string;
    company_name: string;
    website: string | null;
    country: string | null;
    industry: string | null;
    description: string | null;
    source_snippet: string | null;
  }>,
  profile: {
    industry: string;
    products: string[];
    target_countries: string[];
    notes: string;
  },
): string {
  const compact = leads.map((l) => ({
    id: l.id,
    company_name: l.company_name,
    website: l.website,
    country: l.country,
    industry: l.industry,
    description: truncate(l.description ?? l.source_snippet ?? '', 300),
  }));

  return `PROFILE:
Industry: ${profile.industry}
Products: ${profile.products.join(', ') || 'general'}
Target countries: ${profile.target_countries.join(', ') || 'global'}
${profile.notes ? `Notes: ${profile.notes}` : ''}

LEADS (${leads.length}):
${JSON.stringify(compact, null, 2)}

Score every lead. JSON only.`;
}

// ============================================
// HTTP handler
// ============================================
Deno.serve(async (req) => {
  const corsResult = handleCors(req);
  if (corsResult) return corsResult;

  const logger = new Logger({ function: 'hunter-score' });
  const timer = new Timer();

  try {
    // ── Auth ────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return errorResponse('Missing auth', 401);

    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse('Invalid session', 401);
    timer.mark('auth');

    // ── Parse body ──────────────────────────
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse('Invalid JSON body', 400);
    }
    const jobId = validateRequired(body.job_id, 'job_id');

    // ── Load job ────────────────────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: job, error: jobError } = await supabase
      .from('hunter_jobs')
      .select('*')
      .eq('id', jobId)
      .eq('user_id', user.id)
      .single();

    if (jobError || !job) {
      logger.error('Job not found', { job_id: jobId, error: jobError?.message });
      return errorResponse('Job not found', 404);
    }

    // ── Load leads to score ─────────────────
    const { data: leads, error: leadsError } = await supabase
      .from('hunter_leads')
      .select(
        'id, company_name, website, country, industry, description, source_snippet',
      )
      .eq('job_id', job.id)
      .eq('score', 0);

    if (leadsError) {
      logger.error('Leads fetch failed', { error: leadsError.message });
      return errorResponse('Leads fetch failed', 500);
    }

    // ── No leads to score → chain to draft ──
    if (!leads || leads.length === 0) {
      await supabase
        .from('hunter_jobs')
        .update({
          status: 'drafting',
          progress: 75,
        })
        .eq('id', job.id);

      chainToDraft(authHeader, job.id, logger, supabase);
      return successResponse({
        job_id: job.id,
        scored_count: 0,
        chained_to: 'hunter-draft',
        message: 'No unscored leads. Chained to draft.',
      });
    }

    logger.info('Scoring started', {
      job_id: job.id,
      leads_count: leads.length,
      chunks: Math.ceil(leads.length / SCORE_BATCH_SIZE),
    });

    const profile = {
      industry: job.industry,
      products: job.products ?? [],
      target_countries: job.target_countries ?? [],
      notes: job.notes ?? '',
    };

    // ── Batch process ───────────────────────
    const ai = getAIClient();
    const chunks = chunkArray(leads, SCORE_BATCH_SIZE);

    let scoredCount = 0;
    let failedChunks = 0;
    let lastProvider = job.provider_used ?? null;

    for (let ci = 0; ci < chunks.length; ci++) {
      const chunk = chunks[ci];
      try {
        const userPrompt = buildChunkPrompt(chunk, profile);

        const result = await ai.chatJSON<{ results: ScoreResult[] }>(
          [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: userPrompt },
          ],
          {
            temperature: 0.2,
            maxTokens: MAX_TOKENS_PER_CHUNK,
            jsonMode: true,
          },
        );

        lastProvider = result.provider || lastProvider;

        // Filter results to valid lead IDs in this chunk
        const validIds = new Set(chunk.map((l) => l.id));
        const validResults = (result.data.results ?? []).filter(
          (r) => r && typeof r.id === 'string' && validIds.has(r.id),
        );

        if (validResults.length < chunk.length) {
          logger.warn('AI returned fewer results than input', {
            chunk_index: ci + 1,
            sent: chunk.length,
            received: validResults.length,
          });
        }

        // Persist scores
        for (const s of validResults) {
          const b = s.breakdown ?? {};
          const computed =
            (b.industry_fit ?? 0) +
            (b.product_fit ?? 0) +
            (b.geo_fit ?? 0) +
            (b.company_type ?? 0) +
            (b.reachability ?? 0);

          const finalScore = Math.max(
            0,
            Math.min(100, Math.round(s.score ?? computed)),
          );

          const { error: updateErr } = await supabase
            .from('hunter_leads')
            .update({
              score: finalScore,
              score_breakdown: b,
              score_reasons: Array.isArray(s.reasons) ? s.reasons : [],
            })
            .eq('id', s.id);

          if (updateErr) {
            logger.error('Lead update failed', {
              lead_id: s.id,
              error: updateErr.message,
            });
            continue;
          }

          scoredCount++;
        }

        logger.info('Chunk scored', {
          chunk_index: ci + 1,
          total_chunks: chunks.length,
          chunk_size: chunk.length,
          results_count: validResults.length,
          provider: result.provider,
        });

        // Progress: 40% → 75% proportional to chunks completed
        const progress = Math.min(
          75,
          40 + Math.round(((ci + 1) / chunks.length) * 35),
        );
        await supabase
          .from('hunter_jobs')
          .update({ progress })
          .eq('id', job.id);
      } catch (chunkErr) {
        failedChunks++;
        logger.error('Chunk scoring failed', {
          chunk_index: ci + 1,
          total_chunks: chunks.length,
          error: (chunkErr as Error).message,
        });
        // Continue with remaining chunks
      }

      // Small delay to avoid rate limits
      if (ci < chunks.length - 1) {
        await new Promise((r) => setTimeout(r, DELAY_BETWEEN_CHUNKS_MS));
      }
    }

    timer.mark('scored');

    // ── Failure handling ────────────────────
    if (scoredCount === 0 && failedChunks > 0) {
      await supabase
        .from('hunter_jobs')
        .update({
          status: 'failed',
          error_message: `Scoring failed on all ${failedChunks} chunk(s)`,
        })
        .eq('id', job.id);

      return errorResponse('Scoring failed on all chunks', 500);
    }

    // ── Update job → drafting ───────────────
    await supabase
      .from('hunter_jobs')
      .update({
        status: 'drafting',
        progress: 75,
        provider_used: lastProvider,
      })
      .eq('id', job.id);

    logger.info('Scoring complete', {
      job_id: job.id,
      scored: scoredCount,
      failed_chunks: failedChunks,
      total_chunks: chunks.length,
      provider: lastProvider,
      duration_ms: timer.elapsed(),
    });

    // ── Chain to draft ──────────────────────
    chainToDraft(authHeader, job.id, logger, supabase);

    return successResponse({
      job_id: job.id,
      scored_count: scoredCount,
      failed_chunks: failedChunks,
      total_chunks: chunks.length,
      provider: lastProvider,
      chained_to: 'hunter-draft',
      duration_ms: timer.elapsed(),
    });
  } catch (err) {
    const appErr = toAppError(err);
    logger.error('Unhandled error', {
      error: appErr.message,
      stack: appErr.stack?.slice(0, 500),
    });
    return errorResponse(appErr.message, appErr.statusCode);
  }
});

// ============================================
// Chain to hunter-draft
// ============================================
function chainToDraft(
  authHeader: string,
  jobId: string,
  logger: Logger,
  supabase: ReturnType<typeof createClient>,
): void {
  const promise = fetch(
    `${Deno.env.get('SUPABASE_URL')}/functions/v1/hunter-draft`,
    {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ job_id: jobId }),
    },
  ).catch(async (err) => {
    logger.error('Chain to draft failed', {
      error: (err as Error).message,
    });
    await supabase
      .from('hunter_jobs')
      .update({
        status: 'failed',
        error_message: `Chain to draft failed: ${(err as Error).message}`,
      })
      .eq('id', jobId);
  });

  const er = (
    globalThis as {
      EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void };
    }
  ).EdgeRuntime;

  if (er?.waitUntil) er.waitUntil(promise);
  else promise.then(() => {});
}