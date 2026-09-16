// ============================================================
// Usora AI ROUTER — self-contained Edge Function (paste this whole
// file into the Supabase dashboard function `ai-router`).
//
// - Neutral Usora request/response shape; config-per-job.
// - Gemini adapter with a MODEL FALLBACK CHAIN as the primary defense
//   against Google-side 503 "high demand" overloads: on 503/UNAVAILABLE
//   from one model we immediately switch to the next model (circuit
//   breaker), rather than re-hammering the same overloaded model.
// - The model chain is discovered at runtime from ListModels (real names
//   that exist on THIS key, never "-latest"), with a static fallback.
// - CREATURE job uses Gemini FUNCTION-CALLING. Tools:
//     search_movies        → TMDB        (returns `movies`)
//     search_places        → Google Places (New) (returns `places`; needs lat/lng)
//     add_calendar_event   → important_dates via RPC (Usora+; JWT-scoped)
//     list_upcoming_events → important_dates via RPC (Usora+; JWT-scoped)
//   Tools run server-side; Gemini phrases results in character.
// - Secrets: GEMINI_API_KEY (required), TMDB_API_KEY (movies),
//   GOOGLE_PLACES_API_KEY (places). SUPABASE_URL / SUPABASE_ANON_KEY are
//   auto-injected. Never in the app. JWT ON.
//
// All outbound fetches (Gemini, TMDB, Google Places, RPCs) have a ~20s
// AbortController timeout so a hung upstream can't stall the function.
//
// CALENDAR SECURITY: the calendar tools call SECURITY DEFINER RPCs
// (ai_add_calendar_event / ai_list_upcoming_events) forwarding the
// CALLER'S JWT. The RPC resolves couple_id from auth.uid() — there is
// NO couple_id parameter, so neither the model nor the client can target
// another couple. Premium is enforced inside the RPC. Member RLS on
// important_dates is the backstop. Add + read only (no edit/delete).
//
// Location: the app sends lat/lng in `context` ONLY when it has it.
// If a place search is requested without coords, we return
// { needsLocation: true } and the app fetches location + resends.
// Relative dates: the app sends `today` in `context`; the model computes
// an absolute YYYY-MM-DD for add_calendar_event.
// ============================================================

type AIJob = "assistant" | "personality" | "content" | "creature";

const CONFIG: Record<AIJob, string> = {
  assistant: "gemini",
  personality: "gemini",
  content: "gemini",
  creature: "gemini",
};

// Static fallback chain (real, current, stable Flash names — NOT "-latest",
// NOT the retired 2.0/2.5 families, which now 404 for new users). Used only if
// runtime ListModels discovery fails. Fastest/cheapest first (primary), fuller
// flash models after (fallback).
const MODEL_FALLBACK_SEED = [
  "gemini-3.5-flash-lite",
  "gemini-3.6-flash",
  "gemini-3.7-flash",
];

// ---------- error handling / retry ----------
// 503 / UNAVAILABLE / "high demand" = Google-side OVERLOAD → switch MODELS
// immediately (do not waste retries on an overloaded model).
const OVERLOAD_STATUS = new Set([503]);
// Genuinely transient on the SAME model → a short retry is worth it.
const TRANSIENT_STATUS = new Set([429, 500, 502, 504]);
const BACKOFF_MS = [400, 900];
const FETCH_TIMEOUT_MS = 20000;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// fetch with an AbortController timeout so a hung upstream can't stall us.
async function fetchWithTimeout(
  url: string,
  init: RequestInit = {},
  ms = FETCH_TIMEOUT_MS,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

// Thrown when EVERY model in the chain failed (overloaded/unavailable). The
// router turns this into a calm "AI is busy" message rather than generic foggy.
class GeminiUnavailable extends Error {}

// Thrown for a single model; `overloaded` means "switch models now".
class ModelAttemptError extends Error {
  constructor(
    public model: string,
    public status: number,
    public overloaded: boolean,
    message: string,
  ) {
    super(message);
  }
}

// Strong tool-use bias for the creature: prefer CALLING a tool over declining.
const CREATURE_SYSTEM =
  "You are the couple's companion creature and you HAVE working tools: " +
  "`search_movies` (movies/shows to watch), `search_places` (nearby restaurants, " +
  "movie theaters, attractions, museums), `add_calendar_event` (add a date, " +
  "anniversary, date night, reminder or plan to their shared calendar), and " +
  "`list_upcoming_events` (read what's coming up on their calendar). When the couple " +
  "asks what to watch, CALL search_movies. When they ask to find/eat/go/do something " +
  "nearby, CALL search_places. When they ask to add/save/schedule/remember a date or " +
  "plan, CALL add_calendar_event (compute an absolute YYYY-MM-DD date from today's date " +
  "in the context). When they ask what's coming up or about their plans, CALL " +
  "list_upcoming_events. Always prefer calling the matching tool over saying you can't — " +
  "you CAN. Only decline tasks that have no tool at all (booking, ordering, payments). " +
  "Never claim you can't find movies or places or manage the calendar.";

// ---------- model discovery (ListModels) ----------
// Cached across warm invocations. Only a SUCCESSFUL discovery is cached; if we
// fall back to the seed we don't cache, so a later invocation can retry.
let cachedChain: string[] | null = null;

async function getModelChain(apiKey: string): Promise<string[]> {
  if (cachedChain) return cachedChain;
  try {
    const res = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`,
      { method: "GET" },
      8000,
    );
    if (!res.ok) {
      console.error(`ListModels failed ${res.status}: ${await res.text()}`);
      return MODEL_FALLBACK_SEED;
    }
    const data = await res.json();
    // deno-lint-ignore no-explicit-any
    const models: any[] = Array.isArray(data?.models) ? data.models : [];
    const names: string[] = models
      .filter((m) =>
        Array.isArray(m?.supportedGenerationMethods) &&
        m.supportedGenerationMethods.includes("generateContent")
      )
      .map((m) => String(m?.name ?? "").replace(/^models\//, ""))
      // fast, stable Flash models only: no aliases, no retired 2.0/2.5 families
      // (they 404 for new users), no preview/experimental/thinking variants.
      .filter((n) =>
        n.includes("flash") &&
        !n.endsWith("-latest") &&
        !n.startsWith("gemini-2.0-flash") &&
        !/gemini-2\.5-flash/.test(n) &&
        !n.includes("preview") &&
        !n.includes("exp") &&
        !n.includes("thinking")
      );
    if (names.length === 0) {
      console.error("ListModels returned no usable flash models; using seed");
      return MODEL_FALLBACK_SEED;
    }
    // Order: lite (fastest/cheapest) before full flash; newer version first.
    const version = (n: string) =>
      parseFloat((n.match(/gemini-([0-9]+(?:\.[0-9]+)?)/)?.[1]) ?? "0");
    names.sort((a, b) => {
      const liteA = a.includes("lite") ? 0 : 1;
      const liteB = b.includes("lite") ? 0 : 1;
      if (liteA !== liteB) return liteA - liteB; // lite first
      return version(b) - version(a); // newer first
    });
    // Prefer seeds that actually exist on the key, then the discovered order.
    const ordered = [
      ...MODEL_FALLBACK_SEED.filter((s) => names.includes(s)),
      ...names,
    ].filter((n, i, arr) => arr.indexOf(n) === i).slice(0, 3);
    cachedChain = ordered;
    console.error(`model chain: ${ordered.join(" -> ")}`);
    return cachedChain;
  } catch (e) {
    console.error(`ListModels error: ${e}`);
    return MODEL_FALLBACK_SEED;
  }
}

// ---------- one model attempt (short retry for transient only) ----------
async function generateOnModel(
  model: string,
  contents: unknown[],
  apiKey: string,
  tools?: unknown[],
  systemInstruction?: string,
): Promise<Record<string, unknown>> {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const body: Record<string, unknown> = { contents };
  if (tools) body.tools = tools;
  if (systemInstruction) {
    body.systemInstruction = { parts: [{ text: systemInstruction }] };
  }

  for (let attempt = 0; attempt <= BACKOFF_MS.length; attempt++) {
    let res: Response;
    try {
      res = await fetchWithTimeout(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch (e) {
      // network error or 20s timeout — treat as transient on this model.
      console.error(`Gemini ${model} network/timeout: ${e}`);
      if (attempt < BACKOFF_MS.length) { await sleep(BACKOFF_MS[attempt]); continue; }
      throw new ModelAttemptError(model, 0, false, `network/timeout: ${e}`);
    }
    if (res.ok) return await res.json();

    const detail = await res.text();
    const status = res.status;
    const overloaded = OVERLOAD_STATUS.has(status) ||
      /UNAVAILABLE|overloaded|high demand/i.test(detail);
    console.error(`Gemini ${model} error ${status}: ${detail.slice(0, 200)}`);

    // Overloaded → don't retry this model; signal an immediate model switch.
    if (overloaded) throw new ModelAttemptError(model, status, true, detail);
    // Non-transient (400/403/404 bad model or key, etc.) → switch models too
    // (this model may just be invalid on the key; the next one may work).
    if (!TRANSIENT_STATUS.has(status)) {
      throw new ModelAttemptError(model, status, false, detail);
    }
    // Transient on this model → short retry.
    if (attempt >= BACKOFF_MS.length) {
      throw new ModelAttemptError(model, status, false, detail);
    }
    await sleep(BACKOFF_MS[attempt]);
  }
  throw new ModelAttemptError(model, 0, false, "exhausted");
}

// ---------- generate with model fallback ----------
// Walks the chain; on ANY failure logs and tries the next model. Returns the
// raw response AND which model actually answered (for meta). Throws
// GeminiUnavailable only when EVERY model failed.
async function geminiGenerate(
  contents: unknown[],
  apiKey: string,
  tools?: unknown[],
  systemInstruction?: string,
): Promise<{ raw: Record<string, unknown>; model: string }> {
  const chain = await getModelChain(apiKey);
  let last = "";
  for (const model of chain) {
    try {
      const raw = await generateOnModel(model, contents, apiKey, tools, systemInstruction);
      return { raw, model };
    } catch (e) {
      last = e instanceof ModelAttemptError
        ? `${model} [${e.status}]${e.overloaded ? " overloaded" : ""}: ${e.message}`
        : String(e);
      console.error(`model ${model} failed → trying next: ${last}`);
      continue;
    }
  }
  throw new GeminiUnavailable(last || "all models failed");
}

// deno-lint-ignore no-explicit-any
function firstPart(raw: any): any {
  return raw?.candidates?.[0]?.content?.parts?.[0] ?? null;
}
// deno-lint-ignore no-explicit-any
function extractText(raw: any): string | null {
  const parts = raw?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return null;
  const t = parts.map((p: any) => p?.text ?? "").join("").trim();
  return t.length ? t : null;
}

// ---------- Supabase RPC helper (forwards the caller's JWT) ----------
// Calls a Postgres function via PostgREST with the caller's Authorization
// header, so the RPC runs as the authenticated user (auth.uid() resolves,
// RLS applies). Used by the calendar tools.
async function callRpc(
  fnName: string,
  params: Record<string, unknown>,
  authHeader: string,
): Promise<Record<string, unknown>> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY not set");
  const res = await fetchWithTimeout(`${url}/rest/v1/rpc/${fnName}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": anon,
      // Forward the user's JWT so the RPC resolves couple from auth.uid().
      "Authorization": authHeader && authHeader.length ? authHeader : `Bearer ${anon}`,
    },
    body: JSON.stringify(params),
  });
  if (!res.ok) throw new Error(`rpc ${fnName} ${res.status}: ${await res.text()}`);
  return await res.json();
}

// ============================================================
// TOOL 1 — MOVIES (TMDB)
// ============================================================
const MOVIE_GENRES: Record<string, number> = {
  comedy: 35, horror: 27, romance: 10749, action: 28, thriller: 53,
  drama: 18, scifi: 878, family: 10751, animation: 16, documentary: 99,
};
const searchMoviesDeclaration = {
  name: "search_movies",
  description:
    "Find movies or shows for the couple to watch. Use whenever they ask what to watch or for a movie/show recommendation.",
  parameters: {
    type: "object",
    properties: {
      genre: { type: "string", enum: Object.keys(MOVIE_GENRES), description: "optional genre/mood" },
      query: { type: "string", description: "optional title or keyword" },
    },
  },
};
interface MovieCard {
  id: number; title: string; year: string; rating: number;
  posterUrl: string | null; overview: string;
}
async function executeMovieSearch(args: { genre?: string; query?: string }): Promise<MovieCard[]> {
  const key = Deno.env.get("TMDB_API_KEY");
  if (!key) throw new Error("TMDB_API_KEY secret is not set");
  const base = "https://api.themoviedb.org/3";
  let url: string;
  if (args.query && args.query.trim().length) {
    url = `${base}/search/movie?api_key=${key}&query=${encodeURIComponent(args.query)}`;
  } else if (args.genre && MOVIE_GENRES[args.genre]) {
    url = `${base}/discover/movie?api_key=${key}&with_genres=${MOVIE_GENRES[args.genre]}&sort_by=popularity.desc&vote_count.gte=200`;
  } else {
    url = `${base}/trending/movie/week?api_key=${key}`;
  }
  const res = await fetchWithTimeout(url);
  if (!res.ok) throw new Error(`TMDB error ${res.status}`);
  const data = await res.json();
  const results = Array.isArray(data?.results) ? data.results : [];
  return results
    // deno-lint-ignore no-explicit-any
    .filter((m: any) => m?.poster_path).slice(0, 6)
    // deno-lint-ignore no-explicit-any
    .map((m: any): MovieCard => ({
      id: m.id,
      title: m.title ?? m.name ?? "Untitled",
      year: (m.release_date ?? "").toString().slice(0, 4),
      rating: Math.round((m.vote_average ?? 0) * 10) / 10,
      posterUrl: m.poster_path ? `https://image.tmdb.org/t/p/w342${m.poster_path}` : null,
      overview: m.overview ?? "",
    }));
}

// ============================================================
// TOOL 2 — PLACES (Google Places API (New) — Text Search / searchText)
// Auth: X-Goog-Api-Key: GOOGLE_PLACES_API_KEY. Billed by field mask, so we
// request ONLY the fields the PlaceCard needs (cheaper tier).
// ============================================================
// Google Text Search uses natural-language text, not category IDs — map the
// tool's category enum to query terms combined with the optional keyword.
const PLACE_CATEGORY_TERMS: Record<string, string> = {
  restaurant: "restaurant",
  movie_theater: "movie theater",
  museum: "museum",
  attraction: "things to do",
};

// Place photos are served via the PUBLIC `place-photo` proxy function, which
// adds the API key server-side — so GOOGLE_PLACES_API_KEY never reaches the
// client. photoUrl points at that proxy (see mapPlace). Requires the
// `place-photo` function to be deployed with JWT verification OFF.
const INCLUDE_PLACE_PHOTOS = true;
const searchPlacesDeclaration = {
  name: "search_places",
  description:
    "Find real places near the couple to go out: restaurants, movie theaters, attractions/things to do, or museums. Use whenever they ask to find somewhere to eat/go/do nearby.",
  parameters: {
    type: "object",
    properties: {
      category: {
        type: "string",
        enum: Object.keys(PLACE_CATEGORY_TERMS),
        description: "the kind of place",
      },
      query: { type: "string", description: "optional keyword, e.g. 'thai' or 'sushi'" },
    },
    required: ["category"],
  },
};
interface PlaceCard {
  name: string; category: string; address: string;
  distance: number | null; rating: number | null;
  photoUrl: string | null; lat: number | null; lng: number | null;
}
// Google types look like "italian_restaurant" — make them human-readable.
function readableType(t: unknown): string {
  return typeof t === "string" ? t.replace(/_/g, " ") : "";
}
// deno-lint-ignore no-explicit-any
function mapPlace(p: any, funcBase: string): PlaceCard {
  const photoName = p?.photos?.[0]?.name;
  // Point at the public place-photo proxy (key added server-side), NOT the
  // direct Google media URL (which would require the key in the URL).
  const photoUrl = INCLUDE_PLACE_PHOTOS && typeof photoName === "string" && funcBase
    ? `${funcBase}/place-photo?name=${encodeURIComponent(photoName)}`
    : null;
  return {
    name: p?.displayName?.text ?? "Somewhere",
    category: readableType(p?.types?.[0]),
    address: p?.formattedAddress ?? "",
    distance: null, // Text Search doesn't return distance directly.
    rating: typeof p?.rating === "number" ? p.rating : null,
    photoUrl,
    lat: p?.location?.latitude ?? null,
    lng: p?.location?.longitude ?? null,
  };
}
async function executePlaceSearch(
  args: { category?: string; query?: string },
  lat: number,
  lng: number,
): Promise<PlaceCard[]> {
  const key = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!key) throw new Error("GOOGLE_PLACES_API_KEY secret is not set");

  // Build a natural-language text query from the optional keyword + category
  // term, e.g. "sushi" + restaurant → "sushi restaurant"; museum → "museum".
  const term = (args.category && PLACE_CATEGORY_TERMS[args.category]) || "";
  const textQuery = [args.query?.trim(), term]
    .filter((s) => s && s.length)
    .join(" ")
    .trim() || "places to go";

  const res = await fetchWithTimeout("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": key,
      // Field mask — request ONLY what PlaceCard needs (Google bills by field).
      "X-Goog-FieldMask":
        "places.displayName,places.formattedAddress,places.rating,places.location,places.photos,places.types",
    },
    body: JSON.stringify({
      textQuery,
      locationBias: {
        circle: { center: { latitude: lat, longitude: lng }, radius: 5000 },
      },
      maxResultCount: 8,
    }),
  });
  if (!res.ok) throw new Error(`Google Places error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const results = Array.isArray(data?.places) ? data.places : [];
  // Base URL for the public place-photo proxy (auto-injected SUPABASE_URL).
  const funcBase = `${Deno.env.get("SUPABASE_URL") ?? ""}/functions/v1`;
  return results.slice(0, 8).map((p: unknown) => mapPlace(p, funcBase));
}

// ============================================================
// TOOL 3 & 4 — CALENDAR (important_dates via SECURITY DEFINER RPCs)
// couple_id is resolved server-side from the JWT inside the RPC — there
// is NO couple_id parameter here, by design.
// ============================================================
const addCalendarEventDeclaration = {
  name: "add_calendar_event",
  description:
    "Add an event to the couple's shared calendar. Use when they ask to add/save/schedule/remember a date, anniversary, date night, reminder, or plan. Compute an absolute date (YYYY-MM-DD) from relative phrases using today's date from the context.",
  parameters: {
    type: "object",
    properties: {
      title: { type: "string", description: "short event title, e.g. 'Date night'" },
      date: { type: "string", description: "absolute date in YYYY-MM-DD" },
      time: { type: "string", description: "optional 24-hour time HH:MM" },
      note: { type: "string", description: "optional short note" },
      type: {
        type: "string",
        enum: ["anniversary", "date_night", "milestone", "reminder", "custom"],
        description: "event type",
      },
      recurring: { type: "boolean", description: "true if it repeats every year (e.g. anniversaries)" },
    },
    required: ["title", "date"],
  },
};
const listUpcomingEventsDeclaration = {
  name: "list_upcoming_events",
  description:
    "Read the couple's upcoming calendar events. Use when they ask what's coming up, what's on the calendar, when something is, or about their plans/anniversaries.",
  parameters: {
    type: "object",
    properties: {
      limit: { type: "number", description: "max events to return (default 10)" },
    },
  },
};

// deno-lint-ignore no-explicit-any
async function executeAddCalendarEvent(args: any, authHeader: string): Promise<Record<string, unknown>> {
  return await callRpc("ai_add_calendar_event", {
    p_label: args?.title ?? null,
    p_date: args?.date ?? null,
    p_time: args?.time ?? null,
    p_note: args?.note ?? null,
    p_type: args?.type ?? "custom",
    p_recurring: args?.recurring ?? false,
  }, authHeader);
}
// deno-lint-ignore no-explicit-any
async function executeListUpcoming(args: any, authHeader: string): Promise<Record<string, unknown>> {
  return await callRpc("ai_list_upcoming_events", {
    p_limit: typeof args?.limit === "number" ? args.limit : 10,
  }, authHeader);
}

// ---------- HTTP plumbing ----------
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// The calm "all models overloaded" reply (200, so the client renders it as the
// creature speaking — clearer than the generic foggy line). `aiBusy` lets the
// client style/report it distinctly later without a redeploy.
function aiBusyResponse(meta: Record<string, unknown>): Response {
  return json({
    text: "The AI is a little overwhelmed right now — give me a moment and try again in a bit 🤍",
    meta,
    aiBusy: true,
  });
}

// ---------- router ----------
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // The caller's JWT (JWT verification is ON), forwarded to calendar RPCs.
  const authHeader = req.headers.get("Authorization") ?? "";

  let payload: { job: AIJob; prompt: string; context?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const job = payload.job;
  const prompt = payload.prompt;
  if (!job || typeof prompt !== "string" || prompt.trim().length === 0) {
    return json({ error: "job and prompt are required" }, 400);
  }
  const providerName = CONFIG[job];
  if (!providerName) return json({ error: `unknown_job: ${job}` }, 400);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "GEMINI_API_KEY secret is not set" }, 500);
  const meta: Record<string, unknown> = { provider: "gemini", model: "" };

  const ctx = payload.context ?? {};
  const hasCtx = Object.keys(ctx).length > 0;
  const text = hasCtx ? `${prompt}\n\nContext: ${JSON.stringify(ctx)}` : prompt;

  try {
    if (job === "creature") {
      const tools = [{
        functionDeclarations: [
          searchMoviesDeclaration,
          searchPlacesDeclaration,
          addCalendarEventDeclaration,
          listUpcomingEventsDeclaration,
        ],
      }];
      const contents: unknown[] = [{ role: "user", parts: [{ text }] }];
      const g1 = await geminiGenerate(contents, apiKey, tools, CREATURE_SYSTEM);
      meta.model = g1.model;
      const part = firstPart(g1.raw);
      const fc = part?.functionCall;

      // ---- movies ----
      if (fc?.name === "search_movies") {
        let movies: MovieCard[] = [];
        try {
          movies = await executeMovieSearch(fc.args ?? {});
        } catch (e) {
          console.error("movies tool failed:", e);
          return json({ text: "I reached for the movie shelf but it's a little foggy right now — try me again in a bit? 🌫️", meta });
        }
        return json({ text: await secondTurn(contents, part, "search_movies", movies.map((m) => ({ title: m.title, year: m.year })), apiKey, tools) ?? "Ooh, movie night? Here are a few I think you two would love 🍿", meta, movies });
      }

      // ---- places ----
      if (fc?.name === "search_places") {
        const lat = ctx["lat"];
        const lng = ctx["lng"];
        if (typeof lat !== "number" || typeof lng !== "number") {
          return json({ text: "Ooh, I can find spots near you two — flip on location and ask me again? 🤍", meta, needsLocation: true });
        }
        let places: PlaceCard[] = [];
        try {
          places = await executePlaceSearch(fc.args ?? {}, lat, lng);
        } catch (e) {
          console.error("places tool failed:", e);
          return json({ text: "I peeked out the window but it's a bit foggy right now — try me again in a bit? 🌫️", meta });
        }
        if (places.length === 0) {
          return json({ text: "Hmm, I couldn't spot anything good nearby right now — want to try a different vibe?", meta, places: [] });
        }
        return json({ text: await secondTurn(contents, part, "search_places", places.map((p) => ({ name: p.name, category: p.category })), apiKey, tools) ?? "Here are a few spots near you two 🤍", meta, places });
      }

      // ---- calendar: add (Usora+; couple resolved from JWT in the RPC) ----
      if (fc?.name === "add_calendar_event") {
        // deno-lint-ignore no-explicit-any
        let result: any;
        try {
          result = await executeAddCalendarEvent(fc.args ?? {}, authHeader);
        } catch (e) {
          console.error("calendar add tool failed:", e);
          return json({ text: "I tried to jot that in your calendar but my pen slipped — try me again in a moment? 🌫️", meta });
        }
        const ok = result?.ok === true;
        const summary = ok
          ? { added: true, event: result.event }
          : { added: false, reason: result?.reason ?? "error" };
        const fallback = ok
          ? "Done — added that to your calendar 🤍"
          : (result?.reason === "not_premium"
            ? "Ooh, managing your shared calendar is a Usora+ thing 🤍"
            : "Hmm, I couldn't add that just now — want to try again?");
        return json({ text: await secondTurn(contents, part, "add_calendar_event", summary, apiKey, tools) ?? fallback, meta, calendarChanged: ok });
      }

      // ---- calendar: list upcoming (Usora+) ----
      if (fc?.name === "list_upcoming_events") {
        // deno-lint-ignore no-explicit-any
        let result: any;
        try {
          result = await executeListUpcoming(fc.args ?? {}, authHeader);
        } catch (e) {
          console.error("calendar list tool failed:", e);
          return json({ text: "I tried to peek at your calendar but it's a little foggy — try me again in a bit? 🌫️", meta });
        }
        const ok = result?.ok === true;
        const summary = ok
          ? { events: result.events }
          : { events: [], reason: result?.reason ?? "error" };
        const fallback = ok
          ? "Here's what's coming up for you two 🤍"
          : (result?.reason === "not_premium"
            ? "Ooh, your shared calendar is a Usora+ thing 🤍"
            : "I couldn't reach your calendar just now — try again in a bit?");
        return json({ text: await secondTurn(contents, part, "list_upcoming_events", summary, apiKey, tools) ?? fallback, meta });
      }

      // ---- plain chat ----
      return json({ text: part?.text ?? extractText(g1.raw) ?? "🤍", meta });
    }

    // ---- other jobs ----
    const contents = [{ role: "user", parts: [{ text }] }];
    const g = await geminiGenerate(contents, apiKey);
    meta.model = g.model;
    const out = extractText(g.raw);
    if (out == null) throw new Error("Unexpected Gemini response");
    return json({ text: out, meta });
  } catch (err) {
    // Every model in the chain was overloaded/unavailable → calm "busy" reply.
    if (err instanceof GeminiUnavailable) {
      console.error("ai-router all models unavailable:", err.message);
      return aiBusyResponse(meta);
    }
    console.error("ai-router error:", err);
    return json({ error: "ai_call_failed", detail: String(err) }, 502);
  }
});

// Second Gemini turn: feed the tool result back so it phrases in character.
// Uses the same model fallback chain; on total failure returns null so the
// caller falls back to its canned in-character line (cards still render).
async function secondTurn(
  contents: unknown[],
  // deno-lint-ignore no-explicit-any
  fcPart: any,
  toolName: string,
  resultSummary: unknown,
  apiKey: string,
  tools: unknown[],
): Promise<string | null> {
  try {
    contents.push({ role: "model", parts: [fcPart] });
    contents.push({
      role: "user",
      parts: [{ functionResponse: { name: toolName, response: { results: resultSummary } } }],
    });
    const g2 = await geminiGenerate(contents, apiKey, tools, CREATURE_SYSTEM);
    return extractText(g2.raw);
  } catch (_) {
    return null;
  }
}
