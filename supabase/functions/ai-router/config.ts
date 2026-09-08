import type { AIJob } from "./adapters/types.ts";

// ============================================================
// THE CONFIG — the ONLY thing you change to switch providers.
// Maps each JOB to a provider (must exist in the adapter registry).
// Switching a job to Claude later = change one word here.
// ============================================================
export const CONFIG: Record<AIJob, string> = {
  assistant: "gemini",
  personality: "gemini",
  content: "gemini",
};

// Per-provider model. Change here if a model is deprecated/renamed.
// gemini-flash-latest = floating alias that tracks Google's current stable flash
// model, so it won't 404 on deprecation. Paired with the adapter's retry to
// absorb transient free-tier 503/429 "high demand" blips.
export const MODELS: Record<string, string> = {
  gemini: "gemini-flash-latest",
  // claude: "claude-sonnet-4-...",   <- future
};
