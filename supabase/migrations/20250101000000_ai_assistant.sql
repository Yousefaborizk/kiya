-- =====================================================
-- AI Assistant: conversations + messages
-- =====================================================

CREATE TABLE public.ai_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT 'New Chat',
  last_message_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_conversations_user_updated
  ON public.ai_conversations(user_id, updated_at DESC);

CREATE TABLE public.ai_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content text NOT NULL,
  tokens_used integer NOT NULL DEFAULT 0,
  model text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_messages_conversation_created
  ON public.ai_messages(conversation_id, created_at ASC);

-- =====================================================
-- RLS
-- =====================================================
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages      ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own_conversations_select" ON public.ai_conversations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "own_conversations_insert" ON public.ai_conversations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "own_conversations_update" ON public.ai_conversations
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "own_conversations_delete" ON public.ai_conversations
  FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "own_messages_select" ON public.ai_messages
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "own_messages_insert" ON public.ai_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "own_messages_delete" ON public.ai_messages
  FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- updated_at trigger
-- =====================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ai_conversations_updated_at
  BEFORE UPDATE ON public.ai_conversations
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =====================================================
-- Realtime
-- =====================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_conversations;