// ============================================
// CORE — Shared utilities for all Edge Functions
// ============================================

// ============================================
// TYPES
// ============================================

export type JobStatus =
  | 'pending'
  | 'searching'
  | 'scoring'
  | 'drafting'
  | 'completed'
  | 'failed';

export type LeadStatus = 'new' | 'saved' | 'ignored' | 'contacted';

export interface HunterJob {
  id: string;
  user_id: string;
  industry: string;
  products: string[];
  target_countries: string[];
  notes: string | null;
  status: JobStatus;
  progress: number;
  error_message: string | null;
  queries_generated: string[];
  raw_results_count: number;
  leads_count: number;
  provider_used: string | null;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface HunterLead {
  id: string;
  job_id: string;
  user_id: string;
  company_name: string;
  website: string | null;
  country: string | null;
  industry: string | null;
  description: string | null;
  contact_url: string | null;
  source_url: string;
  source_title: string | null;
  source_snippet: string | null;
  score: number;
  score_breakdown: Record<string, number>;
  score_reasons: string[];
  outreach_message: string | null;
  status: LeadStatus;
  created_at: string;
  updated_at: string;
}

// ============================================
// LOGGER
// ============================================

export interface LogContext {
  request_id?: string;
  function?: string;
  user_id?: string;
  job_id?: string;
  [key: string]: unknown;
}

export class Logger {
  private context: LogContext;

  constructor(context: LogContext = {}) {
    this.context = {
      request_id: crypto.randomUUID().slice(0, 8),
      timestamp: new Date().toISOString(),
      ...context,
    };
  }

  private _log(level: string, message: string, extra?: Record<string, unknown>) {
    const entry = {
      level,
      message,
      ...this.context,
      ...extra,
      ts: new Date().toISOString(),
    };
    console.log(JSON.stringify(entry));
  }

  info(message: string, extra?: Record<string, unknown>) {
    this._log('INFO', message, extra);
  }

  warn(message: string, extra?: Record<string, unknown>) {
    this._log('WARN', message, extra);
  }

  error(message: string, extra?: Record<string, unknown>) {
    this._log('ERROR', message, extra);
  }

  debug(message: string, extra?: Record<string, unknown>) {
    this._log('DEBUG', message, extra);
  }

  child(extra: LogContext): Logger {
    return new Logger({ ...this.context, ...extra });
  }

  get requestId(): string {
    return this.context.request_id as string;
  }
}

// ============================================
// VALIDATION HELPERS
// ============================================

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export function validateRequired(
  value: unknown,
  fieldName: string,
  minLength = 1,
): string {
  if (typeof value !== 'string') {
    throw new ValidationError(`${fieldName} must be a string`);
  }
  const trimmed = value.trim();
  if (trimmed.length < minLength) {
    throw new ValidationError(
      `${fieldName} is required (minimum ${minLength} characters)`,
    );
  }
  return trimmed;
}

export function validateOptionalString(
  value: unknown,
  fieldName: string,
  maxLength = 2000,
): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string') {
    throw new ValidationError(`${fieldName} must be a string`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > maxLength) {
    throw new ValidationError(
      `${fieldName} must be at most ${maxLength} characters`,
    );
  }
  return trimmed;
}

export function validateStringArray(
  value: unknown,
  fieldName: string,
  maxItems = 20,
  maxItemLength = 200,
): string[] {
  if (value === null || value === undefined) return [];
  if (!Array.isArray(value)) {
    throw new ValidationError(`${fieldName} must be an array`);
  }
  if (value.length > maxItems) {
    throw new ValidationError(
      `${fieldName} can have at most ${maxItems} items`,
    );
  }
  return value
    .filter((v): v is string => typeof v === 'string')
    .map((v) => v.trim())
    .filter((v) => v.length > 0 && v.length <= maxItemLength);
}

// ============================================
// SAFE JSON PARSING
// ============================================

export function safeJsonParse<T = unknown>(text: string): T {
  if (!text || typeof text !== 'string') {
    throw new Error('safeJsonParse: input is empty');
  }

  let cleaned = text.trim();

  const fenced = cleaned.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenced) {
    cleaned = fenced[1].trim();
  }

  try {
    return JSON.parse(cleaned) as T;
  } catch {
    cleaned = cleaned.replace(/,\s*([}\]])/g, '$1');
    try {
      return JSON.parse(cleaned) as T;
    } catch (err) {
      throw new Error(
        `safeJsonParse: failed after cleanup. ` +
          `First 200 chars: ${cleaned.slice(0, 200)}. ` +
          `Error: ${(err as Error).message}`,
      );
    }
  }
}

// ============================================
// TIMER
// ============================================

export class Timer {
  private startTime: number;
  private marks: Map<string, number> = new Map();

  constructor() {
    this.startTime = Date.now();
  }

  mark(name: string) {
    this.marks.set(name, Date.now() - this.startTime);
  }

  elapsed(): number {
    return Date.now() - this.startTime;
  }

  getMarks(): Record<string, number> {
    return Object.fromEntries(this.marks);
  }

  reset() {
    this.startTime = Date.now();
    this.marks.clear();
  }
}

// ============================================
// UTILITIES
// ============================================

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function extractDomain(url: string): string | null {
  try {
    return new URL(url).hostname.replace(/^www\./, '').toLowerCase();
  } catch {
    return null;
  }
}

export function truncate(text: string, maxLen = 200): string {
  if (!text) return '';
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen) + '...';
}

export function normalizeCompanyName(name: string): string {
  return name
    .toLowerCase()
    .replace(/\b(gmbh|ag|inc|ltd|llc|co|corp|corporation|company|group|holding|holdings)\b/g, '')
    .replace(/[^\w\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

// ============================================
// CONSTANTS
// ============================================

export const HUNTER_CONSTANTS = {
  MAX_QUERIES: 8,
  MIN_QUERY_LENGTH: 8,
  MAX_QUERY_LENGTH: 200,
  MAX_LEADS_PER_JOB: 50,
  MAX_SCORE: 100,
  MIN_SCORE: 0,
  AI_TIMEOUT_MS: 30_000,
  SEARCH_TIMEOUT_MS: 15_000,
} as const;

// ============================================
// ERROR HANDLING
// ============================================

export class AppError extends Error {
  constructor(
    message: string,
    public code: string = 'APP_ERROR',
    public statusCode = 500,
    public details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export function toAppError(err: unknown): AppError {
  if (err instanceof AppError) return err;
  if (err instanceof ValidationError) {
    return new AppError(err.message, 'VALIDATION_ERROR', 400);
  }
  if (err instanceof Error) {
    return new AppError(err.message, 'INTERNAL_ERROR', 500);
  }
  return new AppError('Unknown error occurred', 'UNKNOWN_ERROR', 500);
}