// BOND's neutral, provider-agnostic shapes. The app and router only ever see
// these; each provider's quirks are hidden inside its adapter.

export type AIJob = "assistant" | "personality" | "content";

export interface AIRequest {
  job: AIJob;
  prompt: string;
  context?: Record<string, unknown>;
}

export interface AIResponse {
  text: string;
  meta: {
    provider: string;
    model: string;
  };
}

// Every adapter implements this. Adding a provider = one new file that fulfils
// this interface + one registry line + one config line. Nothing else changes.
export interface Adapter {
  name: string;
  call(req: AIRequest, model: string): Promise<AIResponse>;
}
