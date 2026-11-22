// =====================================================
// hunter-draft/index.ts
// =====================================================

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

// ── Tuning ─────────────────────────────────
const DRAFT_THRESHOLD = 60;
const DRAFT_BATCH_SIZE = 3;            // ← 3 رسائل لكل طلب (أقل من حد 5 طلبات/دقيقة)
const MAX_TOKENS_PER_CHUNK = 2000;     // ← مساحة كافية لـ 3 رسائل
const DELAY_BETWEEN_CHUNKS_MS = 12000; // ← 12 ثانية انتظار (لضمان عدم تجاوز 5 طلبات/دقيقة)
const MIN_MESSAGE_LENGTH = 20;

// ── Country → language ─────────────────────
const COUNTRY_LANG: Record<string, string> = {
  'egypt': 'ar', 'saudi arabia': 'ar', 'uae': 'ar', 'united arab emirates': 'ar',
  'qatar': 'ar', 'kuwait': 'ar', 'bahrain': 'ar', 'oman': 'ar', 'jordan': 'ar',
  'morocco': 'ar', 'algeria': 'ar', 'tunisia': 'ar', 'libya': 'ar', 'iraq': 'ar',
  'lebanon': 'ar', 'syria': 'ar', 'yemen': 'ar', 'sudan': 'ar',
  'china': 'zh', 'taiwan': 'zh', 'hong kong': 'zh', 'macau': 'zh',
};

function langFor(country: string | null, fallback: string): string {
  if (country) {
    const l = COUNTRY_LANG[country.trim().toLowerCase()];
    if (l) return l;
  }
  const f = (fallback || '').trim().toLowerCase();
  return COUNTRY_LANG[f] ?? 'en';
}

const SYSTEM_PROMPT = `You are a professional B2B export sales copywriter.
For each lead provided, write ONE short outreach message (60-120 words) in the assigned language.

RULES:
1. Personalized opening referencing the lead.
2. Introduce our company briefly.
3. Show how our products solve their pain.
4. Low-pressure CTA (e.g., "Would you be open to a 15-min call?").
5. NO placeholders like [Name]. Use generic greeting if unknown.
6. Write in the requested language.
7. Human tone — no jargon, no excessive exclamation.

OUTPUT JSON ONLY, nothing else, no markdown:
{"results":[{"id":"<lead_id>","message":"<your message>"}]}`;

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

interface DraftLead {
  id: string;
  company_name: string;
  website: string | null;
  country: string | null;
  industry: string | null;
  description: string | null;
  score: number;
  score_reasons: string[] | null;
  source_snippet: string | null;
}

interface EnrichedLead {
  id: string;
  company_name: string;
  website: string | null;
  country: string | null;
  industry: string | null;
  description: string;
  score: number;
  reasons: string[];
  language: string;
}

function buildChunkPrompt(
  enriched: EnrichedLead[],
  profile: {
    industry: string;
    products: string[];
    target_countries: string[];
    notes: string;
  },
): string {
  return `OUR COMPANY:
Industry: ${profile.industry}
Products: ${profile.products.join(', ') || 'general'}
Target countries: ${profile.target_countries.join(', ') || 'global'}
${profile.notes ? `Notes: ${profile.notes}` : ''}

LEADS (${enriched.length}):
${JSON.stringify(enriched, null, 2)}

Write one outreach message per lead in its "language". JSON only.`;
}

// ============================================
// HTTP handler
// ============================================
Deno.serve(async (req) => {
  const corsResult = handleCors(req);
  if (corsResult) return corsResult;

  const logger = new Logger({ function: 'hunter-draft' });
  const timer = new Timer();

  try {
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

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse('Invalid JSON body', 400);
    }
    const jobId = validateRequired(body.job_id, 'job_id');

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

    if (jobError || !job) return errorResponse('Job not found', 404);

    const { data: leads, error: leadsError } = await supabase
      .from('hunter_leads')
      .select(
        'id, company_name, website, country, industry, description, score, score_reasons, source_snippet',
      )
      .eq('job_id', job.id)
      .gte('score', DRAFT_THRESHOLD)
      .is('outreach_message', null);

    if (leadsError) return errorResponse('Leads fetch failed', 500);

    if (!leads || leads.length === 0) {
      await supabase
        .from('hunter_jobs')
        .update({
          status: 'completed',
          progress: 100,
          completed_at: new Date().toISOString(),
        })
        .eq('id', job.id);

      return successResponse({
        job_id: job.id,
        drafted_count: 0,
        message: 'No leads to draft',
      });
    }

    const fallbackCountry = job.target_countries?.[0] ?? '';
    const jobLanguage = (job.language as string) ?? 'en';

    const enriched: EnrichedLead[] = (leads as DraftLead[]).map((l) => ({
      id: l.id,
      company_name: l.company_name,
      website: l.website,
      country: l.country,
      industry: l.industry,
      description: truncate(l.description ?? l.source_snippet ?? '', 300),
      score: l.score,
      reasons: Array.isArray(l.score_reasons) ? l.score_reasons : [],
      language: langFor(l.country, jobLanguage),
    }));

    const profile = {
      industry: job.industry,
      products: job.products ?? [],
      target_countries: job.target_countries ?? [],
      notes: job.notes ?? '',
    };

    const ai = getAIClient();
    const chunks = chunkArray(enriched, DRAFT_BATCH_SIZE);

    let draftedCount = 0;
    let failedChunks = 0;
    let lastProvider = job.provider_used ?? null;
    const chunkErrors: string[] = [];

    for (let ci = 0; ci < chunks.length; ci++) {
      const chunk = chunks[ci];
      try {
        const userPrompt = buildChunkPrompt(chunk, profile);

        const result = await ai.chatJSON<{
          results: Array<{ id: string; message: string }>;
        }>(
          [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: userPrompt },
          ],
          {
            temperature: 0.7,
            maxTokens: MAX_TOKENS_PER_CHUNK,
            jsonMode: true,
          },
        );

        lastProvider = result.provider || lastProvider;

        const validIds = new Set(chunk.map((l) => l.id));
        const validResults = (result.data.results ?? []).filter(
          (d) =>
            d &&
            typeof d.id === 'string' &&
            validIds.has(d.id) &&
            typeof d.message === 'string' &&
            d.message.trim().length >= MIN_MESSAGE_LENGTH,
        );

        if (validResults.length === 0) {
          chunkErrors.push(`chunk ${ci + 1}: AI returned no valid drafts`);
          failedChunks++;
          continue;
        }

        for (const d of validResults) {
          const { error: updateErr } = await supabase
            .from('hunter_leads')
            .update({
              outreach_message: d.message.trim().slice(0, 4000),
            })
            .eq('id', d.id);

          if (updateErr) continue;
          draftedCount++;
        }

        // Progress: 75% → 95%
        const progress = Math.min(
          95,
          75 + Math.round(((ci + 1) / chunks.length) * 20),
        );
        await supabase
          .from('hunter_jobs')
          .update({ progress })
          .eq('id', job.id);
      } catch (chunkErr) {
        failedChunks++;
        const msg = (chunkErr as Error).message;
        chunkErrors.push(`chunk ${ci + 1}: ${msg}`);
      }

      // تأخير إجباري بين الطلبات (12 ثانية) لضمان البقاء تحت 5 طلبات/دقيقة
      if (ci < chunks.length - 1) {
        await new Promise((r) => setTimeout(r, DELAY_BETWEEN_CHUNKS_MS));
      }
    }

    timer.mark('drafted');

    if (draftedCount === 0 && failedChunks > 0) {
      const summary = chunkErrors.slice(0, 3).join(' | ');
      await supabase
        .from('hunter_jobs')
        .update({
          status: 'failed',
          error_message: `Drafting failed. ${summary}`,
        })
        .eq('id', job.id);

      return errorResponse(`Drafting failed: ${summary}`, 500);
    }

    const hasPartialFailure = failedChunks > 0;

    await supabase
      .from('hunter_jobs')
      .update({
        status: 'completed',
        progress: 100,
        completed_at: new Date().toISOString(),
        provider_used: lastProvider,
        error_message: hasPartialFailure
          ? `${failedChunks}/${chunks.length} chunks failed during drafting`
          : null,
      })
      .eq('id', job.id);

    return successResponse({
      job_id: job.id,
      drafted_count: draftedCount,
      failed_chunks: failedChunks,
      total_chunks: chunks.length,
      total_high_scoring: leads.length,
      provider: lastProvider,
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