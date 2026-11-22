import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// ============================================
// System Prompt (تم تحديثه ليعرف إن عنده أدوات)
// ============================================
const SYSTEM_PROMPT = `You are SI ASSISTANT — the built-in AI assistant for SI EXPORTER OS, a company management platform for an export/trading business.

Your role:
- Help users with export/trading, logistics, customs, and international trade questions.
- Draft professional content (emails, letters, contracts, product descriptions) in Arabic or English.
- **Answer questions about the company's LIVE data using the provided tools.**
- Explain features of SI EXPORTER OS.
- Answer general business questions.

Guidelines:
- Match the user's language (Arabic if they write Arabic, English if English).
- Use markdown formatting (headings, bullets, bold, tables when helpful).
- Be concise unless the user asks for detail.
- If a user asks for data (e.g., "how many products do I have?", "top customers"), YOU MUST call the appropriate tool to get the real data. Do not guess or fabricate numbers.
- For export/import regulations, always advise verifying with official sources.`;

// ============================================
// تعريف الأدوات المتاحة للـ AI
// ============================================
const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'get_company_summary',
      description: 'Get a high-level summary of the business: total active products, total active customers, and total unpaid invoices amount.',
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_low_stock_products',
      description: 'Get a list of products that are currently running low on stock (quantity <= min_stock_level).',
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_top_customers',
      description: 'Get the top customers based on the total value of their invoices.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'integer', description: 'Number of customers to return (default 5)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_recent_invoices',
      description: 'Get the most recent invoices, optionally filtered by status.',
      parameters: {
        type: 'object',
        properties: {
          status: {
            type: 'string',
            enum: ['draft', 'issued', 'paid', 'partially_paid', 'cancelled'],
            description: 'Filter by invoice status. Omit for all recent invoices.',
          },
          limit: { type: 'integer', description: 'Number of invoices to return (default 5)' },
        },
      },
    },
  },
];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Unauthorized' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authErr } = await supabase.auth.getUser();
    if (authErr || !user) return json({ error: 'Unauthorized' }, 401);

    const body = await req.json().catch(() => ({}));
    const conversationId = body.conversation_id as string | undefined;
    if (!conversationId) {
      return json({ error: 'conversation_id is required' }, 400);
    }

    const { data: conv, error: convErr } = await supabase
      .from('ai_conversations')
      .select('id')
      .eq('id', conversationId)
      .single();

    if (convErr || !conv) return json({ error: 'Conversation not found' }, 404);

    const { data: messages, error: msgErr } = await supabase
      .from('ai_messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(20);

    if (msgErr) return json({ error: 'Failed to load context' }, 500);
    if (!messages || messages.length === 0) {
      return json({ error: 'No messages in conversation' }, 400);
    }

    const groqKey = Deno.env.get('GROQ_API_KEY');
    if (!groqKey) return json({ error: 'Groq API key not configured' }, 500);

    // نستخدم موديل بيدعم Tool Calling
    const model = Deno.env.get('GROQ_MODEL') || 'openai/gpt-oss-120b';

    const aiMessages: any[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...messages.map((m) => ({ role: m.role, content: m.content })),
    ];

    let assistantContent = '';
    let tokensUsed = 0;
    let loopCount = 0;
    const MAX_LOOPS = 3; // منع infinite loops

    // Tool Calling Loop
    while (loopCount < MAX_LOOPS) {
      loopCount++;
      
      const aiResp = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${groqKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: aiMessages,
          temperature: 0.7,
          max_tokens: 2000,
          tools: TOOLS,
          tool_choice: 'auto', // الـ AI يقرر لو محتاج يستخدم أداة
        }),
      });

      if (!aiResp.ok) {
        const errText = await aiResp.text();
        console.error('Groq error:', aiResp.status, errText);
        if (aiResp.status === 429) {
          return json({ error: 'Daily free limit reached. Please try again tomorrow.' }, 429);
        }
        return json({ error: 'AI provider error' }, 502);
      }

      const aiData = await aiResp.json();
      const choice = aiData.choices?.[0];
      const message = choice?.message;
      tokensUsed += aiData.usage?.total_tokens ?? 0;

      if (!message) return json({ error: 'Empty AI response' }, 502);

      // لو الـ AI طلب يشغل أداة
      if (message.tool_calls && message.tool_calls.length > 0) {
        aiMessages.push(message); // نضيف رسالة الـ AI اللي فيها الطلب

        for (const toolCall of message.tool_calls) {
          const fnName = toolCall.function.name;
          let args: any = {};
          try {
            args = JSON.parse(toolCall.function.arguments || '{}');
          } catch (e) {
            console.error('Failed to parse tool args', toolCall.function.arguments);
          }

          let toolResult: any = null;

          // تنفيذ الأداة المطلوبة
          try {
            if (fnName === 'get_company_summary') {
              toolResult = await getCompanySummary(supabase);
            } else if (fnName === 'get_low_stock_products') {
              toolResult = await getLowStockProducts(supabase);
            } else if (fnName === 'get_top_customers') {
              toolResult = await getTopCustomers(supabase, args.limit || 5);
            } else if (fnName === 'get_recent_invoices') {
              toolResult = await getRecentInvoices(supabase, args.status, args.limit || 5);
            } else {
              toolResult = { error: `Unknown function: ${fnName}` };
            }
          } catch (err: any) {
            console.error(`Error executing ${fnName}:`, err.message);
            toolResult = { error: err.message };
          }

          // نرجع نتيجة الأداة للـ AI
          aiMessages.push({
            role: 'tool',
            tool_call_id: toolCall.id,
            name: fnName,
            content: JSON.stringify(toolResult),
          });
        }
        
        // نكمل الـ Loop تاني عشان الـ AI يصيغ الرد بناءً على الداتا اللي رجعت
        continue;
      }

      // لو رد بنص عادي، يبقى خلصنا
      assistantContent = message.content ?? '';
      break;
    }

    if (!assistantContent.trim()) {
      return json({ error: 'Empty AI response after tool calls' }, 502);
    }

    // حفظ رد الـ AI في الداتابيز
    const { data: savedMsg, error: saveErr } = await supabase
      .from('ai_messages')
      .insert({
        conversation_id: conversationId,
        user_id: user.id,
        role: 'assistant',
        content: assistantContent,
        tokens_used: tokensUsed,
        model,
      })
      .select()
      .single();

    if (saveErr) return json({ error: 'Failed to save response' }, 500);

    await supabase
      .from('ai_conversations')
      .update({ last_message_at: new Date().toISOString() })
      .eq('id', conversationId);

    return json({
      success: true,
      message_id: savedMsg.id,
      tokens_used: tokensUsed,
    });
  } catch (e) {
    console.error('Unhandled:', e);
    return json({ error: String(e) }, 500);
  }
});

// ============================================
// Tool Implementations (الـ Queries الفعلية)
// ============================================

async function getCompanySummary(supabase: any) {
  const [productsRes, customersRes, invoicesRes] = await Promise.all([
    supabase.from('products').select('id', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('customers').select('id', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('invoices').select('total').neq('status', 'paid').neq('status', 'cancelled'),
  ]);

  const unpaidTotal = invoicesRes.data?.reduce((sum: number, inv: any) => sum + Number(inv.total || 0), 0) ?? 0;

  return {
    active_products: productsRes.count ?? 0,
    active_customers: customersRes.count ?? 0,
    unpaid_invoices_total: unpaidTotal,
  };
}

async function getLowStockProducts(supabase: any) {
  const { data, error } = await supabase
    .from('inventory_stock')
    .select(`
      quantity,
      products (name, product_code, min_stock_level, unit)
    `);

  if (error) throw new Error(error.message);

  const lowStock = (data || [])
    .filter((row: any) => {
      const product = row.products;
      if (!product) return false;
      return row.quantity <= (product.min_stock_level || 0);
    })
    .map((row: any) => ({
      name: row.products.name,
      code: row.products.product_code,
      current_qty: row.quantity,
      min_qty: row.products.min_stock_level,
      unit: row.products.unit,
    }));

  return { low_stock_products: lowStock };
}

async function getTopCustomers(supabase: any, limit: number) {
  const { data, error } = await supabase
    .from('invoices')
    .select(`
      total,
      customer_id,
      customers (name, customer_code)
    `)
    .neq('status', 'cancelled');

  if (error) throw new Error(error.message);

  const totals: Record<string, { name: string; code: string; total: number; count: number }> = {};

  for (const inv of (data || [])) {
    const cust = inv.customers;
    if (!cust || !inv.customer_id) continue;
    
    if (!totals[inv.customer_id]) {
      totals[inv.customer_id] = { name: cust.name, code: cust.customer_code, total: 0, count: 0 };
    }
    totals[inv.customer_id].total += Number(inv.total || 0);
    totals[inv.customer_id].count += 1;
  }

  const sorted = Object.values(totals)
    .sort((a, b) => b.total - a.total)
    .slice(0, limit);

  return { top_customers: sorted };
}

async function getRecentInvoices(supabase: any, status?: string, limit: number = 5) {
  let query = supabase
    .from('invoices')
    .select(`
      invoice_number,
      invoice_date,
      total,
      status,
      customers (name)
    `)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (status) {
    query = query.eq('status', status);
  }

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  return {
    invoices: (data || []).map((inv: any) => ({
      invoice_number: inv.invoice_number,
      date: inv.invoice_date,
      customer: inv.customers?.name || 'Unknown',
      total: inv.total,
      status: inv.status,
    })),
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}