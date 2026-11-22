import { createClient } from 'npm:@supabase/supabase-js@2';
import { getAIClient } from '../_shared/ai_client.ts';
import { handleCors, successResponse, errorResponse } from '../_shared/cors.ts';
import { Logger, Timer, validateRequired, validateStringArray, validateOptionalString, toAppError, truncate, HUNTER_CONSTANTS } from '../_shared/core.ts';

const SYSTEM_PROMPT = `You are a B2B export sales research expert.
Convert a company profile into 5-8 highly targeted web search queries
that will find REAL COMPANIES (potential customers), NOT articles or directories.

RULES:
1. Each query targets REAL COMPANIES (buyers, importers, distributors)
2. Use industry-specific buyer terminology
3. Include target country in most queries
4. Vary query types
5. REJECT queries that return: Directories, News, Top 10 lists, Wikipedia, Job boards.
6. Avoid generic queries.
7. IMPORTANT: Generate the search queries in the requested language.

OUTPUT — JSON only, no markdown: { "queries": ["query1", "query2", ...] }`;

interface QueriesResponse { queries: string[]; }

const BAD_PATTERNS = [/\btop\s+\d+\b/i, /\bwikipedia\b/i, /\bwhat\s+is\b/i, /\bhow\s+to\b/i, /^best\s+/i, /\bdefinition\b/i, /\bmeaning\b/i, /\bvs\.?\b/i];
function isBadQuery(q: string): boolean { return BAD_PATTERNS.some((p) => p.test(q)); }

function cleanQueries(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const q of raw) {
    if (typeof q !== 'string') continue;
    const t = q.trim().replace(/\s+/g, ' ');
    if (t.length < HUNTER_CONSTANTS.MIN_QUERY_LENGTH || t.length > HUNTER_CONSTANTS.MAX_QUERY_LENGTH) continue;
    if (isBadQuery(t)) continue;
    const key = t.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(t);
    if (out.length >= HUNTER_CONSTANTS.MAX_QUERIES) break;
  }
  return out;
}

Deno.serve(async (req) => {
  const corsResult = handleCors(req);
  if (corsResult) return corsResult;

  const logger = new Logger({ function: 'hunter-search' });
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

    const industry = validateRequired(body.industry, 'industry', 3);
    const products = validateStringArray(body.products, 'products', 20, 100);
    const targetCountries = validateStringArray(body.target_countries, 'target_countries', 20, 100);
    const notes = validateOptionalString(body.notes, 'notes', 1000);
    
    // استقبال اللغة (افتراضي: الإنجليزية)
    const language = validateOptionalString(body.language, 'language', 10) ?? 'en';

    if (products.length === 0) return errorResponse('At least one product is required', 400);
    if (targetCountries.length === 0) return errorResponse('At least one target country is required', 400);

    timer.mark('validate');

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: job, error: jobError } = await supabase
      .from('hunter_jobs')
      .insert({
        user_id: user.id,
        industry,
        products,
        target_countries: targetCountries,
        notes,
        language, // ← حفظ اللغة في الـ Job
        status: 'pending',
        progress: 0,
      })
      .select()
      .single();

    if (jobError || !job) return errorResponse(`Failed to create job: ${jobError?.message ?? 'unknown'}`, 500);
    timer.mark('job_created');

    const userPrompt = `Company profile:
- Industry: ${industry}
- Products: ${products.join(', ') || 'general'}
- Target countries: ${targetCountries.join(', ') || 'global'}
${notes ? `- Notes: ${notes}` : ''}
- Output Language: ${language}

Generate 5-8 search queries in the requested language. Output JSON only.`;

    const ai = getAIClient();
    let aiResult;
    try {
      aiResult = await ai.chatJSON<QueriesResponse>(
        [{ role: 'system', content: SYSTEM_PROMPT }, { role: 'user', content: userPrompt }],
        { temperature: 0.4, maxTokens: 800, jsonMode: true },
      );
    } catch (aiErr) {
      const msg = (aiErr as Error).message;
      await supabase.from('hunter_jobs').update({ status: 'failed', error_message: truncate(`AI failed: ${msg}`, 500), completed_at: new Date().toISOString() }).eq('id', job.id);
      return errorResponse(`AI generation failed: ${msg}`, 500);
    }

    timer.mark('ai_generated');

    const queries = cleanQueries(aiResult.data?.queries);

    if (queries.length === 0) {
      await supabase.from('hunter_jobs').update({ status: 'failed', error_message: 'AI returned no valid queries', completed_at: new Date().toISOString() }).eq('id', job.id);
      return errorResponse('AI returned no valid queries', 500);
    }

    await supabase.from('hunter_jobs').update({
      queries_generated: queries,
      provider_used: aiResult.provider,
      progress: 10,
    }).eq('id', job.id);

    timer.mark('done');

    return successResponse({
      job_id: job.id,
      status: 'pending',
      queries,
      queries_count: queries.length,
      provider: aiResult.provider,
      total_ms: timer.elapsed(),
    });
  } catch (err) {
    const appErr = toAppError(err);
    logger.error('Unhandled error', { error: appErr.message });
    return errorResponse(appErr.message, appErr.statusCode);
  }
});