// ============================================================
// BOND AI ROUTER — single-file build (paste into the Supabase
// Edge Functions browser editor as `ai-router`).
//
// Functionally identical to the multi-file version in this folder:
// router + Gemini adapter (with retry) + config-per-job + neutral
// {text, meta} shape, reads GEMINI_API_KEY from Deno.env, CORS + errors.
//
// The app calls THIS function (never a provider directly). Keys live as a
// Supabase secret, never in the app. Deploy keeps JWT verification ON.
//
// Add a provider later = add its adapter to ADAPTERS + a MODELS entry +
// switch a CONFIG line. Nothing else changes.
// ============================================================

// ---------- Neutral shapes ----------
type AIJob = "assistant" | "personality" | "content";

interface AIRequest {
  job: AIJob;
  prompt: string;
  context?: Record<string, unknown>;
}

interface AIResponse {
  text: string;
  meta: { provider: string; model: string };
}

interface Adapter {
  name: string;
  call(req: AIRequest, model: string): Promise<AIResponse>;
}

// ---------- CONFIG (the only thing you change to switch providers) ----------
const CONFIG: Record<AIJob, string> = {
  assistant: "gemini",
  personality: "gemini",
  content: "gemini",
};

// gemini-flash-latest = floating alias tracking Google's current stable flash
// model (won't 404 on deprecation). Paired with the adapter's retry to absorb
// transient free-tier 503/429 "high demand" blips.
const MODELS: Record<string, string> = {
  gemini: "gemini-flash-latest",
  // claude: "claude-sonnet-4-...",
};

// ---------- Gemini adapter (with retry) ----------
// Free-tier Gemini returns 503 "high demand" / 429 fairly often; retry with
// short backoff so transient overloads are invisible to the user most of the time.
const RETRYABLE = new Set([429, 500, 502, 503, 504]);
const BACKOFF_MS = [500, 1000, 2000]; // 1 initial attempt + 3 retries
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const geminiAdapter: Adapter = {
  name: "gemini",
  async call(req: AIRequest, model: string): Promise<AIResponse> {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY secret is not set");

    const hasContext = req.context && Object.keys(req.context).length > 0;
    const text = hasContext
      ? `${req.prompt}\n\nContext: ${JSON.stringify(req.context)}`
      : req.prompt;

    const endpoint =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const payload = { contents: [{ parts: [{ text }] }] };

    let lastError = "";
    for (let attempt = 0; attempt <= BACKOFF_MS.length; attempt++) {
      let res: Response;
      try {
        res = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } catch (netErr) {
        lastError = `network error: ${netErr}`;
        if (attempt < BACKOFF_MS.length) {
          await sleep(BACKOFF_MS[attempt]);
          continue;
        }
        break;
      }

      if (res.ok) {
        const raw = await res.json();
        const out = raw?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (typeof out !== "string") {
          throw new Error(`Unexpected Gemini response: ${JSON.stringify(raw)}`);
        }
        return { text: out, meta: { provider: "gemini", model } };
      }

      const body = await res.text();
      lastError = `Gemini API error ${res.status}: ${body}`;
      if (!RETRYABLE.has(res.status)) break;   // hard error (400/401/403) → fail fast
      if (attempt >= BACKOFF_MS.length) break;  // out of retries
      await sleep(BACKOFF_MS[attempt]);
    }

    throw new Error(lastError || "Gemini call failed");
  },
};

// ---------- Adapter registry ----------
const ADAPTERS: Record<string, Adapter> = {
  gemini: geminiAdapter,
  // claude: claudeAdapter,
};

// ---------- HTTP plumbing ----------
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ---------- The router ----------
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let payload: AIRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const job = payload.job as AIJob;
  const prompt = payload.prompt;
  if (!job || typeof prompt !== "string" || prompt.trim().length === 0) {
    return json({ error: "job and prompt are required" }, 400);
  }

  const providerName = CONFIG[job];
  if (!providerName) return json({ error: `unknown_job: ${job}` }, 400);
  const adapter = ADAPTERS[providerName];
  if (!adapter) {
    return json({ error: `no_adapter_for_provider: ${providerName}` }, 500);
  }
  const model = MODELS[providerName] ?? "";

  try {
    const result = await adapter.call(
      { job, prompt, context: payload.context ?? {} },
      model,
    );
    return json(result);
  } catch (err) {
    // Clean error the app can later turn into the creature's "foggy brain".
    console.error("ai-router error:", err);
    return json({ error: "ai_call_failed", detail: String(err) }, 502);
  }
});
