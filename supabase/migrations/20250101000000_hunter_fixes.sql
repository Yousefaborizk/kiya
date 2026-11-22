-- =====================================================
-- HUNTER FIXES — Critical schema migration
-- =====================================================
-- Fixes:
--   1. ARRAY → text[] column types (blocker for inserts)
--   2. UNIQUE constraint on (job_id, source_url) (blocker for upsert)
--   3. Missing indexes (performance)
--   4. updated_at triggers
--   5. Row Level Security + policies (security)
--   6. Realtime publication (blocker for Flutter streams)
-- =====================================================

-- ─────────────────────────────────────────────────────
-- 1) Fix column types: ARRAY → text[]
-- ─────────────────────────────────────────────────────
ALTER TABLE public.hunter_jobs
  ALTER COLUMN products TYPE text[] USING products::text[],
  ALTER COLUMN target_countries TYPE text[] USING target_countries::text[];

-- Customers.tags had the same issue
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'customers'
      AND column_name = 'tags'
      AND data_type = 'ARRAY'
  ) THEN
    ALTER TABLE public.customers
      ALTER COLUMN tags TYPE text[] USING tags::text[];
  END IF;
END $$;

-- ─────────────────────────────────────────────────────
-- 2) UNIQUE constraint needed for upsert onConflict
-- ─────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hunter_leads_job_source_unique'
  ) THEN
    ALTER TABLE public.hunter_leads
      ADD CONSTRAINT hunter_leads_job_source_unique
      UNIQUE (job_id, source_url);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────
-- 3) Indexes (performance for filters/streams)
-- ─────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_hunter_jobs_user_id
  ON public.hunter_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_hunter_jobs_user_status
  ON public.hunter_jobs(user_id, status);
CREATE INDEX IF NOT EXISTS idx_hunter_jobs_created_at
  ON public.hunter_jobs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hunter_leads_job_id
  ON public.hunter_leads(job_id);
CREATE INDEX IF NOT EXISTS idx_hunter_leads_score
  ON public.hunter_leads(score DESC);
CREATE INDEX IF NOT EXISTS idx_hunter_leads_job_score
  ON public.hunter_leads(job_id, score DESC);
CREATE INDEX IF NOT EXISTS idx_hunter_leads_job_score_msg
  ON public.hunter_leads(job_id, score DESC)
  WHERE outreach_message IS NULL;
CREATE INDEX IF NOT EXISTS idx_hunter_leads_status
  ON public.hunter_leads(status);

-- ─────────────────────────────────────────────────────
-- 4) updated_at triggers
-- ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_hunter_jobs_updated_at ON public.hunter_jobs;
CREATE TRIGGER trg_hunter_jobs_updated_at
  BEFORE UPDATE ON public.hunter_jobs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_hunter_leads_updated_at ON public.hunter_leads;
CREATE TRIGGER trg_hunter_leads_updated_at
  BEFORE UPDATE ON public.hunter_leads
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────
-- 5) Row Level Security + policies
-- ─────────────────────────────────────────────────────
ALTER TABLE public.hunter_jobs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hunter_leads ENABLE ROW LEVEL SECURITY;

-- ── hunter_jobs policies ──────────────────────────────
DROP POLICY IF EXISTS "hunter_jobs_select_own" ON public.hunter_jobs;
CREATE POLICY "hunter_jobs_select_own" ON public.hunter_jobs
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "hunter_jobs_insert_own" ON public.hunter_jobs;
CREATE POLICY "hunter_jobs_insert_own" ON public.hunter_jobs
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "hunter_jobs_update_own" ON public.hunter_jobs;
CREATE POLICY "hunter_jobs_update_own" ON public.hunter_jobs
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "hunter_jobs_delete_own" ON public.hunter_jobs;
CREATE POLICY "hunter_jobs_delete_own" ON public.hunter_jobs
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ── hunter_leads policies ─────────────────────────────
DROP POLICY IF EXISTS "hunter_leads_select_own" ON public.hunter_leads;
CREATE POLICY "hunter_leads_select_own" ON public.hunter_leads
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "hunter_leads_insert_own" ON public.hunter_leads;
CREATE POLICY "hunter_leads_insert_own" ON public.hunter_leads
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "hunter_leads_update_own" ON public.hunter_leads;
CREATE POLICY "hunter_leads_update_own" ON public.hunter_leads
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "hunter_leads_delete_own" ON public.hunter_leads;
CREATE POLICY "hunter_leads_delete_own" ON public.hunter_leads
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────
-- 6) Enable Realtime publication
-- ─────────────────────────────────────────────────────
DO $$
BEGIN
  -- Add tables to realtime publication if not already added
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'hunter_jobs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.hunter_jobs;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'hunter_leads'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.hunter_leads;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────
-- 7) (Optional) Column addition for provider tracking
-- ─────────────────────────────────────────────────────
ALTER TABLE public.hunter_jobs
  ADD COLUMN IF NOT EXISTS providers_used jsonb DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.hunter_jobs.providers_used
  IS 'Per-step provider tracking: {"search":"cerebras","score":"google","draft":"cerebras"}';

-- ─────────────────────────────────────────────────────
-- 8) Verify
-- ─────────────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE '✅ Hunter migration applied successfully';
END $$;