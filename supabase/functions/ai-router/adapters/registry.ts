import type { Adapter } from "./types.ts";
import { geminiAdapter } from "./gemini.ts";

// The registry of available adapters. Adding a provider = import its adapter and
// add ONE entry here (e.g. `claude: claudeAdapter`). Nothing existing changes.
export const ADAPTERS: Record<string, Adapter> = {
  gemini: geminiAdapter,
  // claude: claudeAdapter,   <- future: one new file + this line + a config line
};
