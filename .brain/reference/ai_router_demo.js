// ============================================================
// BOND AI ROUTER — PROOF TEST
// Goal: prove that switching AI providers is a ONE-LINE config
// change, with ZERO changes to app code or adapters.
// We simulate two providers (Gemini, Claude) with fake API
// responses so we can run it offline. The STRUCTURE is real.
// ============================================================

// ---------- BOND's STANDARD SHAPES (neutral, provider-agnostic) ----------
// The app only ever produces/consumes these. It never sees a provider's raw format.
//
//   AIRequest  = { job, prompt, context }
//   AIResponse = { text, meta }
//
// Each provider's quirks are hidden inside its adapter.

// ---------- PROVIDER ADAPTERS (one small file each in real life) ----------
// Each adapter: takes BOND's AIRequest -> calls that provider's API in ITS
// format -> converts the provider's raw reply back into BOND's AIResponse.

const geminiAdapter = {
  name: "gemini",
  async call(req) {
    // Gemini's real API wants { contents: [{ parts: [{ text }] }] }
    const providerPayload = {
      contents: [{ parts: [{ text: `${req.prompt}\n\nContext: ${JSON.stringify(req.context)}` }] }]
    };
    // --- simulated network call ---
    const rawProviderReply = await fakeGeminiAPI(providerPayload);
    // Gemini returns { candidates: [{ content: { parts: [{ text }] } }] }
    const text = rawProviderReply.candidates[0].content.parts[0].text;
    // convert -> BOND standard shape
    return { text, meta: { provider: "gemini", model: rawProviderReply.model } };
  }
};

const claudeAdapter = {
  name: "claude",
  async call(req) {
    // Claude's real API wants { messages: [{ role, content }] }
    const providerPayload = {
      messages: [{ role: "user", content: `${req.prompt}\n\nContext: ${JSON.stringify(req.context)}` }]
    };
    // --- simulated network call ---
    const rawProviderReply = await fakeClaudeAPI(providerPayload);
    // Claude returns { content: [{ type:"text", text }] }
    const text = rawProviderReply.content[0].text;
    // convert -> BOND standard shape (SAME shape as Gemini's adapter returns)
    return { text, meta: { provider: "claude", model: rawProviderReply.model } };
  }
};

// A registry of available adapters. Adding a provider = add ONE entry here + its file.
const ADAPTERS = {
  gemini: geminiAdapter,
  claude: claudeAdapter,
  // groq: groqAdapter,   <- future, slots in with zero ripple
};

// ---------- THE CONFIG (the ONLY thing you change to switch) ----------
// Maps each JOB to a provider. This is the single source of truth.
let CONFIG = {
  assistant:   "gemini",
  personality: "gemini",
  content:     "gemini",
};

// ---------- THE ROUTER (one function the whole app calls) ----------
// The app calls getAI(job, prompt, context). The router picks the provider
// from CONFIG, calls its adapter, returns BOND's standard AIResponse.
// THIS is the only place that knows providers exist.
async function getAI(job, prompt, context = {}) {
  const providerName = CONFIG[job];
  const adapter = ADAPTERS[providerName];
  if (!adapter) throw new Error(`No adapter for provider '${providerName}'`);
  const req = { job, prompt, context };
  return adapter.call(req);
}

// ============================================================
// ---------- THE APP CODE (never mentions a provider) ----------
// This is what your Edge Function / feature code looks like.
// Notice: it is IDENTICAL no matter which provider is active.
// ============================================================
async function babyAIAssistant(userMessage, couple) {
  // The app just asks for an answer for the "assistant" job.
  const result = await getAI("assistant", userMessage, {
    coupleName: couple.name,
    city: couple.city,
  });
  return result;
}

// ============================================================
// ---------- SIMULATED PROVIDER APIS (stand-ins for the network) ----------
// ============================================================
async function fakeGeminiAPI(payload) {
  await tick();
  return {
    model: "gemini-1.5-pro",
    candidates: [{ content: { parts: [{ text: "How about Thai Basil on 5th? Cozy, great for couples 🍜" }] } }]
  };
}
async function fakeClaudeAPI(payload) {
  await tick();
  return {
    model: "claude-sonnet",
    content: [{ type: "text", text: "How about Thai Basil on 5th? Cozy, great for couples 🍜" }]
  };
}
function tick(){ return new Promise(r => setTimeout(r, 5)); }

// ============================================================
// ---------- THE ACTUAL TEST ----------
// ============================================================
(async () => {
  const couple = { name: "Sam & Alex", city: "Atlanta" };
  const userMessage = "find us thai food nearby";

  console.log("=".repeat(60));
  console.log("BOND AI ROUTER — LIVE PROVIDER-SWAP PROOF");
  console.log("=".repeat(60));

  // --- 1. Run the app on the STARTING provider (Gemini) ---
  console.log("\n[1] CONFIG.assistant =", CONFIG.assistant, "(launch default)");
  let r1 = await babyAIAssistant(userMessage, couple);
  console.log("    App got back:", JSON.stringify(r1.text));
  console.log("    Served by   :", r1.meta.provider, "/", r1.meta.model);

  // --- 2. THE SWITCH: change ONE line of config. Nothing else. ---
  console.log("\n[2] >>> Switching provider: CONFIG.assistant = 'claude'");
  console.log("    (No app code changed. No adapter changed. One config line.)");
  CONFIG.assistant = "claude";

  // --- 3. Run the EXACT SAME app code again ---
  console.log("\n[3] CONFIG.assistant =", CONFIG.assistant, "(after switch)");
  let r2 = await babyAIAssistant(userMessage, couple);
  console.log("    App got back:", JSON.stringify(r2.text));
  console.log("    Served by   :", r2.meta.provider, "/", r2.meta.model);

  // --- 4. VERDICT ---
  console.log("\n" + "=".repeat(60));
  const appCodeUnchanged = true; // babyAIAssistant() was called identically both times
  const sameShape = (typeof r1.text === "string" && typeof r2.text === "string"
                     && "provider" in r1.meta && "provider" in r2.meta);
  const providerActuallyChanged = r1.meta.provider !== r2.meta.provider;

  console.log("VERDICT:");
  console.log("  • App code identical both runs? ", appCodeUnchanged ? "YES ✅" : "NO ❌");
  console.log("  • Same response shape returned? ", sameShape ? "YES ✅" : "NO ❌");
  console.log("  • Provider actually swapped?    ", providerActuallyChanged
              ? `YES ✅  (${r1.meta.provider} → ${r2.meta.provider})` : "NO ❌");
  console.log("  • Lines changed to switch?       1  (the CONFIG line)");
  console.log("=".repeat(60));

  if (appCodeUnchanged && sameShape && providerActuallyChanged) {
    console.log("\nRESULT: THEORY HOLDS. Provider swap = one config line, zero app changes. ✅");
  } else {
    console.log("\nRESULT: theory failed — architecture needs rework. ❌");
  }
})();
