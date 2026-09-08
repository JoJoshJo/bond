// BOND AI ROUTER — Supabase Edge Function.
// The ONLY place that talks to AI providers. The app calls this function
// (never a provider directly). Keys live as Supabase secrets, never in the app.
//
// Request  : { job, prompt, context? }
// Response : { text, meta: { provider, model } }   (BOND's neutral shape)
//
// JWT verification is enforced by the platform (deploy default), so only
// signed-in users can reach it.

import { CONFIG, MODELS } from "./config.ts";
import { ADAPTERS } from "./adapters/registry.ts";
import type { AIJob, AIRequest } from "./adapters/types.ts";

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

  // Route: pick the provider for this job from CONFIG, then its adapter.
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
    console.error("ai-router error:", err);
    return json({ error: "ai_call_failed", detail: String(err) }, 502);
  }
});
