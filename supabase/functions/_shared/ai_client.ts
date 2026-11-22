// ============================================
// AI CLIENT — Cerebras (primary) + Google AI Studio (fallback)
// ============================================

import { safeJsonParse } from './core.ts';

export interface AIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface AIOptions {
  temperature?: number;
  maxTokens?: number;
  jsonMode?: boolean;
}

export interface AIResult {
  text: string;
  provider: 'cerebras' | 'google';
  latencyMs: number;
}

// ============================================
// Retry helper (مع تحسين لـ 429)
// ============================================
function isRetryable(err: Error): boolean {
  const msg = err.message;
  if (/\b(429|500|502|503|504)\b/.test(msg)) return true;
  if (/timeout|timed out|fetch failed|network|aborted|econnreset/i.test(msg)) {
    return true;
  }
  return false;
}

async function withRetry<T>(
  fn: () => Promise<T>,
  label: string,
  attempts = 3, // زيادة المحاولات
  baseDelayMs = 2000, // بداية أطول
): Promise<T> {
  let lastErr: Error | null = null;

  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err instanceof Error ? err : new Error(String(err));
      const retryable = isRetryable(lastErr);
      const isLast = i === attempts - 1;

      if (!retryable || isLast) {
        throw lastErr;
      }

      // تأخير تصاعدي أطول لأخطاء 429
      const is429 = /429/.test(lastErr.message);
      const delay = is429
        ? Math.max(5000, baseDelayMs * Math.pow(2, i)) // 5s, 10s, 20s
        : baseDelayMs * Math.pow(2, i);

      console.warn(
        `[AI] ${label} attempt ${i + 1}/${attempts} failed, retrying in ${delay}ms: ${lastErr.message}`,
      );
      await new Promise((r) => setTimeout(r, delay));
    }
  }

  throw lastErr ?? new Error(`${label} failed after ${attempts} attempts`);
}

// ============================================
// JSON Repair Helper
// ============================================
function _repairTruncatedJson(text: string): string | null {
  let depth = 0;
  let inString = false;
  let escape = false;
  let lastValidIdx = -1;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (escape) { escape = false; continue; }
    if (ch === '\\') { escape = true; continue; }
    if (ch === '"') { inString = !inString; continue; }
    if (inString) continue;

    if (ch === '{' || ch === '[') depth++;
    if (ch === '}' || ch === ']') {
      depth--;
      if (depth === 0) lastValidIdx = i;
    }
  }

  if (depth === 0 && lastValidIdx === text.length - 1) return null;

  let truncated = lastValidIdx >= 0
    ? text.slice(0, lastValidIdx + 1)
    : text;

  const stack: string[] = [];
  inString = false;
  escape = false;
  for (let i = 0; i < truncated.length; i++) {
    const ch = truncated[i];
    if (escape) { escape = false; continue; }
    if (ch === '\\') { escape = true; continue; }
    if (ch === '"') { inString = !inString; continue; }
    if (inString) continue;

    if (ch === '{') stack.push('}');
    else if (ch === '[') stack.push(']');
    else if (ch === '}' || ch === ']') stack.pop();
  }

  if (inString) truncated += '"';
  truncated = truncated.replace(/,\s*$/, '');

  while (stack.length > 0) {
    truncated += stack.pop();
  }

  return truncated;
}

// ============================================
// AIClient
// ============================================
export class AIClient {
  private cerebrasKey: string | null;
  private googleKey: string | null;

  private static readonly CEREBRAS_URL =
    'https://api.cerebras.ai/v1/chat/completions';
  private static readonly CEREBRAS_MODEL = 'gpt-oss-120b';
  private static readonly GOOGLE_URL =
    'https://generativelanguage.googleapis.com/v1beta/models';
  private static readonly GOOGLE_MODEL = 'gemini-3.8-flash';

  private static readonly DEFAULT_TIMEOUT_MS = 45_000;

  constructor() {
    this.cerebrasKey = Deno.env.get('CEREBRAS_API_KEY') ?? null;
    this.googleKey = Deno.env.get('GOOGLE_AI_KEY') ?? null;

    if (!this.cerebrasKey && !this.googleKey) {
      throw new Error(
        'No AI provider configured. Set CEREBRAS_API_KEY or GOOGLE_AI_KEY.',
      );
    }
  }

  async chat(
    messages: AIMessage[],
    opts: AIOptions = {},
  ): Promise<AIResult> {
    const start = Date.now();
    const errors: string[] = [];

    if (this.cerebrasKey) {
      try {
        const text = await withRetry(
          () => this._callCerebras(messages, opts),
          'cerebras',
        );
        return {
          text,
          provider: 'cerebras',
          latencyMs: Date.now() - start,
        };
      } catch (err) {
        const msg = (err as Error).message;
        console.warn(`[AI] Cerebras failed: ${msg}`);
        errors.push(`cerebras: ${msg}`);
      }
    }

    if (this.googleKey) {
      try {
        const text = await withRetry(
          () => this._callGoogle(messages, opts),
          'google',
        );
        return {
          text,
          provider: 'google',
          latencyMs: Date.now() - start,
        };
      } catch (err) {
        const msg = (err as Error).message;
        console.error(`[AI] Google failed: ${msg}`);
        errors.push(`google: ${msg}`);
      }
    }

    throw new Error(`All AI providers failed. ${errors.join(' | ')}`);
  }

  async chatJSON<T = unknown>(
    messages: AIMessage[],
    opts: AIOptions = {},
  ): Promise<{
    data: T;
    provider: string;
    latencyMs: number;
  }> {
    const result = await this.chat(messages, {
      ...opts,
      jsonMode: true,
    });

    let cleanedText = result.text.trim();

    const jsonMatch = cleanedText.match(/(\{[\s\S]*\}|\[[\s\S]*\])/);
    if (jsonMatch) {
      cleanedText = jsonMatch[0];
    }

    try {
      const data = safeJsonParse<T>(cleanedText);
      return {
        data,
        provider: result.provider,
        latencyMs: result.latencyMs,
      };
    } catch (err) {
      const repaired = _repairTruncatedJson(cleanedText);
      if (repaired) {
        try {
          const data = safeJsonParse<T>(repaired);
          console.warn('[AI] JSON was truncated — auto-repaired successfully');
          return {
            data,
            provider: result.provider,
            latencyMs: result.latencyMs,
          };
        } catch {
          // فشل الإصلاح
        }
      }

      console.error(
        '[AI] JSON parse failed. Raw:',
        result.text.slice(0, 500),
      );
      throw new Error(
        `AI returned invalid JSON: ${(err as Error).message}. ` +
          `First 200 chars: ${result.text.slice(0, 200)}`,
      );
    }
  }

  private async _callCerebras(
    messages: AIMessage[],
    opts: AIOptions,
  ): Promise<string> {
    const body: Record<string, unknown> = {
      model: AIClient.CEREBRAS_MODEL,
      messages,
      temperature: opts.temperature ?? 0.3,
      max_tokens: opts.maxTokens ?? 3000,
      stream: false,
    };

    if (opts.jsonMode) {
      body.response_format = { type: 'json_object' };
    }

    const res = await fetch(AIClient.CEREBRAS_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.cerebrasKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(AIClient.DEFAULT_TIMEOUT_MS),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Cerebras ${res.status}: ${errText.slice(0, 200)}`);
    }

    const data = await res.json();
    const text = data.choices?.[0]?.message?.content;

    if (!text || typeof text !== 'string') {
      throw new Error('Cerebras returned empty response');
    }

    return text;
  }

  private async _callGoogle(
    messages: AIMessage[],
    opts: AIOptions,
  ): Promise<string> {
    const systemMsg = messages.find((m) => m.role === 'system');
    const conversation = messages.filter((m) => m.role !== 'system');

    const contents = conversation.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    }));

    const body: Record<string, unknown> = {
      contents,
      generationConfig: {
        temperature: opts.temperature ?? 0.3,
        maxOutputTokens: opts.maxTokens ?? 3000,
        ...(opts.jsonMode ? { responseMimeType: 'application/json' } : {}),
      },
    };

    if (systemMsg) {
      body.systemInstruction = {
        parts: [{ text: systemMsg.content }],
      };
    }

    const url = `${AIClient.GOOGLE_URL}/${AIClient.GOOGLE_MODEL}:generateContent?key=${this.googleKey}`;

    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(AIClient.DEFAULT_TIMEOUT_MS),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Google ${res.status}: ${errText.slice(0, 200)}`);
    }

    const data = await res.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text || typeof text !== 'string') {
      throw new Error('Google returned empty response');
    }

    return text;
  }
}

let _shared: AIClient | null = null;

export function getAIClient(): AIClient {
  if (!_shared) {
    _shared = new AIClient();
  }
  return _shared;
}