import type { Adapter, AIRequest, AIResponse } from "./types.ts";

// Retry transient overload/rate-limit responses. Free-tier Gemini returns 503
// "high demand" / 429 fairly often; retrying with short backoff makes these
// invisible to the user most of the time.
const RETRYABLE = new Set([429, 500, 502, 503, 504]);
const BACKOFF_MS = [500, 1000, 2000]; // attempts: 1 initial + 3 retries

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Google Gemini adapter. Translates BOND's AIRequest -> Gemini's request format,
// calls the real API with the GEMINI_API_KEY secret, and converts Gemini's raw
// reply back into BOND's AIResponse. The rest of the system never sees this shape.
export const geminiAdapter: Adapter = {
  name: "gemini",

  async call(req: AIRequest, model: string): Promise<AIResponse> {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY secret is not set");

    // Fold any context into the prompt (minimal — we send only what's needed).
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
        // Network blip — treat as retryable.
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

      // Non-retryable (e.g. 400 bad model, 401/403 auth) → fail fast.
      if (!RETRYABLE.has(res.status)) break;
      // Out of retries.
      if (attempt >= BACKOFF_MS.length) break;
      await sleep(BACKOFF_MS[attempt]);
    }

    // Exhausted retries or hit a hard error — surface a clean message the app
    // can later turn into the creature's "foggy brain" fallback.
    throw new Error(lastError || "Gemini call failed");
  },
};
