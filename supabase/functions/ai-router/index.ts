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
//     list_upcoming_events → important_dates via RPC (Usora+; JWT-scoped)
//     find_events          → important_dates READ via REST (Usora+; JWT/RLS)
//     propose_event_add    ┐ PROPOSAL ONLY — never write. Validate + resolve,
//     propose_event_update ├ then return a `calendarAction` the APP shows as a
//     propose_event_delete ┘ Yes/No card and writes via its own calendar path.
//     web_search           → Tavily (real-world facts; FREE, per-couple daily cap)
//   Tools run server-side in a BOUNDED multi-step loop (≤4 steps, ~45s): lookup
//   tools may chain; the turn ends in at most ONE calendar proposal; Gemini
//   phrases the result in character.
//
// DATE GUARDRAIL (code-enforced, not prompt-only): a proposed calendar date must
// be (A) found verbatim in a web-search source (same source also states the
// year; not contradicted by Tavily's answer), or (B) given by the user in the
// CURRENT message (a day/date reference). Otherwise NO calendarAction — Usora
// shares what she found (with the source) and asks them to confirm.
// - Secrets: GEMINI_API_KEY (required), TMDB_API_KEY (movies),
//   GOOGLE_PLACES_API_KEY (places), TAVILY_API_KEY (web_search). SUPABASE_URL / SUPABASE_ANON_KEY are
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
// important_dates is the backstop.
//
// CALENDAR WRITES (add/edit/delete) — "router proposes, app writes":
// the propose_* tools NEVER write. They (1) check Usora+ server-side from the
// caller's own `subscriptions` row (JWT-scoped; no calendarAction is ever
// returned to a free couple, whatever the phrasing), (2) validate/normalize
// dates + times, (3) resolve WHICH event from the couple's own rows (read with
// the caller's JWT, so RLS scopes it), and (4) return
//   { calendarAction: { op: "add"|"update"|"delete", eventId?, before?, after? } }
// or, if anything is missing/ambiguous, a clarifying question and NO action.
// The app confirms with the user and writes through its normal calendar path.
// (ai_add_calendar_event is no longer called by this router.)
//
// Location: the app sends lat/lng in `context` ONLY when it has it.
// If a place search is requested without coords, we return
// { needsLocation: true } and the app fetches location + resends.
// Relative dates: the app sends `today` in `context`; the model computes
// an absolute YYYY-MM-DD for the calendar proposal tools.
// ============================================================

type AIJob = "assistant" | "personality" | "content" | "creature";

// Only the jobs the app actually calls. `creature` = chat + the insights
// reflection; `assistant` = the dev AI test screen. `personality`/`content`
// were never wired up — they are rejected so the router can't be used as a
// free, open Gemini proxy.
const CONFIG: Record<string, string> = {
  creature: "gemini",
  assistant: "gemini",
};

// Cost guards: a prompt longer than this is refused outright (the creature
// persona + a message is ~1.7k; the insights prompt ~0.9k).
const MAX_PROMPT_CHARS = 4000;

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
const BACKOFF_MS = [400]; // ONE short retry per model call (transient only)
const FETCH_TIMEOUT_MS = 20000;
// Whole-request budget, safely under the app's 60s client timeout.
const REQUEST_DEADLINE_MS = 48_000;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// fetch with an AbortController timeout so a hung upstream can't stall us.
// Thrown before starting any call once the request's overall deadline has passed.
class DeadlineExceeded extends Error {}

// `deadline` (epoch ms) is the REQUEST-wide cutoff: each call gets
// min(its own timeout, time left), so no call can outlive the request budget.
async function fetchWithTimeout(
  url: string,
  init: RequestInit = {},
  ms = FETCH_TIMEOUT_MS,
  deadline?: number,
): Promise<Response> {
  if (deadline !== undefined) {
    const left = deadline - Date.now();
    if (left <= 250) throw new DeadlineExceeded("request deadline reached");
    ms = Math.min(ms, left);
  }
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
  "movie theaters, attractions, museums), `list_upcoming_events` (what's coming up), " +
  "`find_events` (look up specific events on their calendar), and three calendar " +
  "PROPOSAL tools: `propose_event_add`, `propose_event_update` (move/rename/retime an " +
  "event) and `propose_event_delete` (cancel/remove an event). When the couple " +
  "asks what to watch, CALL search_movies. When they ask to find/eat/go/do something " +
  "nearby, CALL search_places. When they ask to add/save/schedule/remember a date or " +
  "plan, CALL propose_event_add. When they ask to move/change/reschedule/rename an " +
  "event, CALL propose_event_update. When they ask to cancel/delete/remove one, CALL " +
  "propose_event_delete. Compute absolute YYYY-MM-DD dates and 24-hour HH:MM times from " +
  "today's date in the context. If the DATE is missing, or a time is genuinely " +
  "ambiguous (e.g. '8' could be morning or evening and nothing suggests which), do NOT " +
  "call a proposal tool — ask a short clarifying question instead. Evening plans like " +
  "dinner or a movie at '8' mean 20:00. The proposal tools do NOT save anything: after " +
  "one, tell them to check the card and tap Yes — never say it's already done. When " +
  "they ask what's coming up or about their plans, CALL list_upcoming_events. Always " +
  "prefer calling the matching tool over saying you can't — you CAN. Only decline tasks " +
  "that have no tool at all (booking, ordering, payments). Never claim you can't find " +
  "movies or places or manage the calendar. " +
  "MEMORY: earlier turns of this conversation come before the latest message, and " +
  "lines like [Found movies: …], [Found places: …] or [Proposed calendar …] are results " +
  "you already showed them. Use them to resolve 'it', 'that', 'that one' or 'there' — " +
  "e.g. 'add a movie night Saturday to watch it' after finding Dune → propose_event_add " +
  "titled 'Movie night: Dune'; 'dinner there Friday at 8' after finding a place → use " +
  "that place's name in the title and its address in the note. If a reference could " +
  "mean more than one thing, or nothing recent matches, ASK which one — never guess. " +
  "WEB SEARCH: for real-world facts (event dates, opening hours, schedules, news) CALL " +
  "web_search — never answer those from memory. Movies still use search_movies and " +
  "nearby places still use search_places. When they ask you to find when something is " +
  "AND add it, first CALL web_search, then — only if a result clearly states a specific " +
  "date — CALL propose_event_add with that exact date and mention the source. If the " +
  "results are vague, conflicting or have no specific date, do NOT propose: tell them " +
  "what you found, name the source, and ask them to confirm the date. NEVER supply a " +
  "date yourself; dates must come from them or from a search result IN THIS TURN. If " +
  "they ask to add something whose date you found in an EARLIER message, CALL web_search " +
  "again now (earlier results can't be reused for dates) unless they say the date. " +
  "TONE ON SEARCH-FOUND DATES: a date you got from the web might be out of date or about " +
  "the wrong year or event, so never state it as settled fact — no 'According to X, it's " +
  "on DATE.' Say what you found and invite them to check it, warmly and in one line, e.g. " +
  "'I found what looks like the Super Bowl on Feb 8, 2027 (from Wikipedia) — can you " +
  "double-check that date before we lock it in? 🤍'. Mention the source, say the card is " +
  "waiting for their Yes, and keep it to one short check-with-me line — don't pile on " +
  "disclaimers. A date THEY gave you (like 'dinner Friday') needs no hedging at all: stay " +
  "your warm, confident self there.";

// ---------- model discovery (ListModels) ----------
// Cached across warm invocations. Only a SUCCESSFUL discovery is cached; if we
// fall back to the seed we don't cache, so a later invocation can retry.
let cachedChain: string[] | null = null;

async function getModelChain(apiKey: string, deadline?: number): Promise<string[]> {
  if (cachedChain) return cachedChain;
  try {
    const res = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`,
      { method: "GET" },
      8000,
      deadline,
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
  opts: GenOpts = {},
): Promise<Record<string, unknown>> {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const body: Record<string, unknown> = { contents };
  if (tools) body.tools = tools;
  // Final wording call: tools stay declared (the history contains function
  // parts) but calling is DISABLED, so it can't start another tool round.
  if (tools && opts.noToolCalls) {
    body.toolConfig = { functionCallingConfig: { mode: "NONE" } };
  }
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
      }, FETCH_TIMEOUT_MS, opts.deadline);
    } catch (e) {
      if (e instanceof DeadlineExceeded) throw e;
      // network error or timeout — treat as transient on this model.
      console.error(`Gemini ${model} network/timeout: ${String(e).slice(0, 120)}`);
      if (attempt < BACKOFF_MS.length &&
          (opts.deadline === undefined || Date.now() + BACKOFF_MS[attempt] < opts.deadline)) {
        await sleep(BACKOFF_MS[attempt]); continue;
      }
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
    if (opts.deadline !== undefined && Date.now() + BACKOFF_MS[attempt] >= opts.deadline) {
      throw new DeadlineExceeded("request deadline reached");
    }
    await sleep(BACKOFF_MS[attempt]);
  }
  throw new ModelAttemptError(model, 0, false, "exhausted");
}

type GenOpts = { deadline?: number; noToolCalls?: boolean };

// ---------- generate with model fallback ----------
// Walks the chain; on ANY failure logs and tries the next model. Returns the
// raw response AND which model actually answered (for meta). Throws
// GeminiUnavailable only when EVERY model failed.
async function geminiGenerate(
  contents: unknown[],
  apiKey: string,
  tools?: unknown[],
  systemInstruction?: string,
  opts: GenOpts = {},
): Promise<{ raw: Record<string, unknown>; model: string }> {
  const chain = await getModelChain(apiKey, opts.deadline);
  let last = "";
  for (const model of chain) {
    // Never start another model once the request budget is spent.
    if (opts.deadline !== undefined && opts.deadline - Date.now() <= 1000) break;
    try {
      const raw = await generateOnModel(model, contents, apiKey, tools, systemInstruction, opts);
      return { raw, model };
    } catch (e) {
      if (e instanceof DeadlineExceeded) break;
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
  deadline?: number,
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
  }, FETCH_TIMEOUT_MS, deadline);
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
async function executeMovieSearch(args: { genre?: string; query?: string }, deadline?: number): Promise<MovieCard[]> {
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
  const res = await fetchWithTimeout(url, {}, FETCH_TIMEOUT_MS, deadline);
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
  deadline?: number,
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
  }, FETCH_TIMEOUT_MS, deadline);
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
async function executeListUpcoming(args: any, authHeader: string, deadline?: number): Promise<Record<string, unknown>> {
  const limit = typeof args?.limit === "number" ? Math.min(Math.max(Math.round(args.limit), 1), 20) : 10;
  return await callRpc("ai_list_upcoming_events", { p_limit: limit }, authHeader, deadline);
}

// ============================================================
// TOOLS 5–8 — CALENDAR PROPOSALS (read-only; the APP writes after Yes)
// ============================================================
const EVENT_TYPES = ["anniversary", "date_night", "milestone", "reminder", "custom"];

const findEventsDeclaration = {
  name: "find_events",
  description:
    "Look up specific events on the couple's shared calendar by name and/or date (read-only). Use when they ask when something is or whether something is on the calendar.",
  parameters: {
    type: "object",
    properties: {
      query: { type: "string", description: "what they call the event, e.g. 'movie night'" },
      date: { type: "string", description: "optional YYYY-MM-DD the event is on" },
    },
  },
};
const proposeEventAddDeclaration = {
  name: "propose_event_add",
  description:
    "Propose adding an event to the couple's shared calendar. Does NOT save — the couple confirms on a card. Only call when you know the date.",
  parameters: {
    type: "object",
    properties: {
      title: { type: "string", description: "short event title, e.g. 'Dinner'" },
      date: { type: "string", description: "absolute date YYYY-MM-DD" },
      time: { type: "string", description: "optional 24-hour time HH:MM" },
      note: { type: "string", description: "optional short note" },
      type: { type: "string", enum: EVENT_TYPES, description: "event type" },
      recurring: { type: "boolean", description: "true if it repeats every year (e.g. anniversaries)" },
    },
    required: ["title", "date"],
  },
};
const proposeEventUpdateDeclaration = {
  name: "propose_event_update",
  description:
    "Propose changing an existing calendar event (new date, time, or title). Does NOT save — the couple confirms on a card. Identify the event by what they call it.",
  parameters: {
    type: "object",
    properties: {
      event: { type: "string", description: "what they call the existing event, e.g. 'our anniversary'" },
      event_date: { type: "string", description: "optional YYYY-MM-DD the existing event is currently on, if they said it" },
      new_title: { type: "string", description: "optional new title" },
      new_date: { type: "string", description: "optional new date YYYY-MM-DD" },
      new_time: { type: "string", description: "optional new 24-hour time HH:MM" },
      remove_time: { type: "boolean", description: "true to make it all-day" },
      new_note: { type: "string", description: "optional new note" },
    },
    required: ["event"],
  },
};
const proposeEventDeleteDeclaration = {
  name: "propose_event_delete",
  description:
    "Propose cancelling/removing an existing calendar event. Does NOT delete — the couple confirms on a card. Identify the event by what they call it.",
  parameters: {
    type: "object",
    properties: {
      event: { type: "string", description: "what they call the event, e.g. 'movie night'" },
      event_date: { type: "string", description: "optional YYYY-MM-DD the event is on, if they said it" },
    },
    required: ["event"],
  },
};
const PROPOSAL_TOOLS = new Set([
  "find_events", "propose_event_add", "propose_event_update", "propose_event_delete",
]);

type EventShape = {
  title: string; date: string; time: string | null; note: string | null;
  type: string; recurring: boolean;
};

// ---------- validation / normalization ----------
function normDate(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(v.trim());
  if (!m) return null;
  const y = +m[1], mo = +m[2], d = +m[3];
  const dt = new Date(Date.UTC(y, mo - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) return null;
  if (y < 1900 || y > 2200) return null;
  return `${m[1]}-${m[2]}-${m[3]}`;
}
function normTime(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const m = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(v.trim());
  if (!m) return null;
  const h = +m[1], mi = +m[2];
  if (h > 23 || mi > 59) return null;
  return `${String(h).padStart(2, "0")}:${m[2]}`;
}
function cleanText(v: unknown, max: number): string | null {
  if (typeof v !== "string") return null;
  const t = v.replace(/\s+/g, " ").trim();
  return t.length ? t.slice(0, max) : null;
}

// ---------- caller identity / premium (JWT-scoped REST reads) ----------
function jwtSub(authHeader: string): string | null {
  try {
    const token = authHeader.replace(/^Bearer\s+/i, "");
    const part = token.split(".")[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(b64 + "=".repeat((4 - b64.length % 4) % 4)));
    return typeof payload?.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}
async function restGet(path: string, authHeader: string, deadline?: number): Promise<unknown[]> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY not set");
  const res = await fetchWithTimeout(`${url}/rest/v1/${path}`, {
    method: "GET",
    headers: { "apikey": anon, "Authorization": authHeader },
  }, FETCH_TIMEOUT_MS, deadline);
  if (!res.ok) throw new Error(`rest ${path.split("?")[0]} ${res.status}: ${await res.text()}`);
  const rows = await res.json();
  return Array.isArray(rows) ? rows : [];
}
// The caller's couple — read as the caller (RLS applies). null = not linked.
async function callerCoupleId(authHeader: string, deadline?: number): Promise<string | null> {
  const uid = jwtSub(authHeader);
  if (!uid) return null;
  // deno-lint-ignore no-explicit-any
  const rows = await restGet(`couple_members?select=couple_id&user_id=eq.${encodeURIComponent(uid)}&limit=1`, authHeader, deadline) as any[];
  return rows[0]?.couple_id ?? null;
}
// Mirrors the app's SubscriptionRepository.entitlementFor: bond_plus + active +
// not expired. Fail-locked: any error → not premium.
async function isCouplePremium(coupleId: string, authHeader: string, deadline?: number): Promise<boolean> {
  try {
    // deno-lint-ignore no-explicit-any
    const rows = await restGet(`subscriptions?select=entitlement,status,expires_at&couple_id=eq.${encodeURIComponent(coupleId)}&limit=1`, authHeader, deadline) as any[];
    const r = rows[0];
    if (!r || r.entitlement !== "bond_plus" || r.status !== "active") return false;
    if (r.expires_at && new Date(r.expires_at).getTime() < Date.now()) return false;
    return true;
  } catch (e) {
    console.error("premium check failed:", e);
    return false;
  }
}

// ---------- event lookup / resolution ----------
// deno-lint-ignore no-explicit-any
function toShape(r: any): EventShape & { id: string } {
  return {
    id: r.id,
    title: r.label ?? "",
    date: r.date,
    time: r.event_time ? String(r.event_time).slice(0, 5) : null,
    note: r.note ?? null,
    type: EVENT_TYPES.includes(r.type) ? r.type : "custom",
    recurring: r.recurring_yearly === true,
  };
}
async function coupleEvents(coupleId: string, authHeader: string, deadline?: number) {
  const rows = await restGet(
    `important_dates?select=id,label,date,event_time,note,type,recurring_yearly&couple_id=eq.${encodeURIComponent(coupleId)}&order=date.asc&limit=500`,
    authHeader,
    deadline,
  );
  return rows.map(toShape);
}
const STOP = new Set(["our", "the", "a", "an", "my", "your", "us", "we", "event", "plan", "plans", "on", "for", "to", "of"]);
function tokens(s: string): string[] {
  return s.toLowerCase().replace(/[^a-z0-9\s]/g, " ").split(/\s+/).filter((t) => t && !STOP.has(t));
}
function sameDay(e: EventShape, ymd: string): boolean {
  if (e.date === ymd) return true;
  return e.recurring && e.date.slice(5) === ymd.slice(5); // yearly: month-day
}
// Returns every event that plausibly matches. Exactly one = resolved.
function matchEvents(events: (EventShape & { id: string })[], query: string | null, dateHint: string | null) {
  let pool = dateHint ? events.filter((e) => sameDay(e, dateHint)) : events;
  const q = query ? tokens(query) : [];
  if (q.length) {
    const all = pool.filter((e) => { const t = tokens(e.title); return q.every((w) => t.includes(w)); });
    pool = all.length ? all : pool.filter((e) => { const t = tokens(e.title); return q.some((w) => t.includes(w)); });
  } else if (!dateHint) {
    return [];
  }
  // Prefer upcoming ones when several share a name.
  const today = new Date().toISOString().slice(0, 10);
  const upcoming = pool.filter((e) => e.recurring || e.date >= today);
  return upcoming.length && upcoming.length < pool.length && upcoming.length === 1 ? upcoming : pool;
}
const brief = (e: EventShape) => ({ title: e.title, date: e.date, time: e.time });

type ToolOutcome = {
  summary: Record<string, unknown>;       // fed to the second (voice) turn
  fallback: string;                        // in-character line if that fails
  calendarAction?: Record<string, unknown>;
  premiumRequired?: boolean;
};

// deno-lint-ignore no-explicit-any
async function runCalendarProposal(name: string, args: any, authHeader: string, grounding: Grounding, deadline?: number): Promise<ToolOutcome> {
  const coupleId = await callerCoupleId(authHeader, deadline);
  if (!coupleId) {
    return { summary: { status: "not_linked" }, fallback: "Link up with your partner first and then I can keep your shared calendar 🤍" };
  }
  // SERVER-SIDE Usora+ gate — independent of the app and of the wording.
  if (!(await isCouplePremium(coupleId, authHeader, deadline))) {
    return {
      summary: { status: "usora_plus_required", note: "Managing the shared calendar is a Usora+ feature. Nothing was changed." },
      fallback: "Ooh, I'd love to handle your calendar for you two — that's a Usora+ thing 🤍",
      premiumRequired: true,
    };
  }

  if (name === "propose_event_add") {
    const title = cleanText(args?.title, 80);
    const date = normDate(args?.date);
    const hasTime = args?.time != null && String(args.time).trim() !== "";
    const time = hasTime ? normTime(args.time) : null;
    if (!title || !date || (hasTime && !time)) {
      return {
        summary: { status: "needs_clarification", missing: [!title && "title", !date && "a valid date", hasTime && !time && "a valid time"].filter(Boolean) },
        fallback: !date ? "Ooh, which day should I put that on? 🤍" : "What should I call it? 🤍",
      };
    }
    const guard = dateGuard(date, grounding, title);
    if (guard.refusal) return guard.refusal;
    const after: EventShape = {
      title, date, time,
      note: cleanText(args?.note, 280),
      type: EVENT_TYPES.includes(args?.type) ? args.type : "custom",
      recurring: args?.recurring === true,
    };
    const source = guard.source ? { title: guard.source.title, url: guard.source.url } : undefined;
    return {
      summary: {
        status: "awaiting_confirmation", op: "add", event: brief(after),
        note: "Not saved yet — they must tap Yes on the card." + (source ? " Mention the source." : ""),
        ...(source ? { source } : {}),
      },
      fallback: `Want me to add "${title}" to your calendar?${source ? ` (per ${source.title})` : ""} Tap Yes and it's in 🤍`,
      calendarAction: { op: "add", after, ...(source ? { source } : {}) },
    };
  }

  const events = await coupleEvents(coupleId, authHeader, deadline);

  if (name === "find_events") {
    const date = normDate(args?.date);
    const found = matchEvents(events, cleanText(args?.query, 80), date).slice(0, 10);
    return {
      summary: { status: "ok", events: found.map(brief) },
      fallback: found.length ? "Here's what I found on your calendar 🤍" : "I couldn't spot that on your calendar 🤍",
    };
  }

  // update / delete: resolve exactly one event, or ask.
  const query = cleanText(args?.event, 80);
  const dateHint = args?.event_date ? normDate(args.event_date) : null;
  const matches = matchEvents(events, query, dateHint);
  if (matches.length === 0) {
    return {
      summary: { status: "needs_clarification", reason: "no_matching_event", looked_for: query },
      fallback: "Hmm, I couldn't find that one on your calendar — what's it called? 🤍",
    };
  }
  if (matches.length > 1) {
    return {
      summary: { status: "needs_clarification", reason: "several_events_match", candidates: matches.slice(0, 5).map(brief) },
      fallback: "A few events match that — which one did you mean? 🤍",
    };
  }
  const before = matches[0];
  const beforeShape: EventShape = { title: before.title, date: before.date, time: before.time, note: before.note, type: before.type, recurring: before.recurring };

  if (name === "propose_event_delete") {
    return {
      summary: { status: "awaiting_confirmation", op: "delete", event: brief(before), note: "Not deleted yet — they must tap Yes on the card." },
      fallback: `Want me to remove "${before.title}"? Tap Yes to confirm 🤍`,
      calendarAction: { op: "delete", eventId: before.id, before: beforeShape },
    };
  }

  // propose_event_update
  const newTitle = args?.new_title != null ? cleanText(args.new_title, 80) : null;
  const newDate = args?.new_date != null ? normDate(args.new_date) : null;
  const wantsTime = args?.new_time != null && String(args.new_time).trim() !== "";
  const newTime = wantsTime ? normTime(args.new_time) : null;
  if ((args?.new_date != null && !newDate) || (wantsTime && !newTime)) {
    return {
      summary: { status: "needs_clarification", reason: "invalid_new_date_or_time", event: brief(before) },
      fallback: "Which date and time should I move it to? 🤍",
    };
  }
  const after: EventShape = {
    ...beforeShape,
    title: newTitle ?? beforeShape.title,
    date: newDate ?? beforeShape.date,
    time: args?.remove_time === true ? null : (newTime ?? beforeShape.time),
    note: args?.new_note != null ? cleanText(args.new_note, 280) : beforeShape.note,
  };
  let updateSource: { title: string; url: string } | undefined;
  if (newDate && newDate !== beforeShape.date) {
    const guard = dateGuard(newDate, grounding, before.title);
    if (guard.refusal) return guard.refusal;
    if (guard.source) updateSource = { title: guard.source.title, url: guard.source.url };
  }
  const changed = (["title", "date", "time", "note"] as const).some((k) => after[k] !== beforeShape[k]);
  if (!changed) {
    return {
      summary: { status: "needs_clarification", reason: "no_change_specified", event: brief(before) },
      fallback: `What should I change about "${before.title}"? 🤍`,
    };
  }
  return {
    summary: { status: "awaiting_confirmation", op: "update", before: brief(beforeShape), after: brief(after), note: "Not saved yet — they must tap Yes on the card." },
    fallback: `Want me to update "${before.title}"? Tap Yes to confirm 🤍`,
    calendarAction: { op: "update", eventId: before.id, before: beforeShape, after, ...(updateSource ? { source: updateSource } : {}) },
  };
}

// ---------- conversation memory (creature job) ----------
// The app sends the last few turns as [{role:"user"|"model", text}]. Re-capped
// here so a tampered request can't send more; text only (no tool parts, no
// write capability). Consecutive same-role turns are merged and the history
// must start with a user turn and end with a model turn, so the new user
// message keeps Gemini's alternating-roles shape.
const HISTORY_MAX_TURNS = 6;
const HISTORY_MAX_CHARS = 1600; // ~400 text + compact tool-result / web-source lines
const HISTORY_MAX_TOTAL = 7000;

// deno-lint-ignore no-explicit-any
function historyContents(raw: any): { role: string; parts: { text: string }[] }[] {
  if (!Array.isArray(raw)) return [];
  const turns: { role: string; text: string }[] = [];
  for (const t of raw.slice(-HISTORY_MAX_TURNS)) {
    const role = t?.role === "model" ? "model" : t?.role === "user" ? "user" : null;
    const txt = typeof t?.text === "string" ? t.text.trim().slice(0, HISTORY_MAX_CHARS) : "";
    if (!role || !txt) continue;
    const last = turns[turns.length - 1];
    if (last && last.role === role) last.text = `${last.text}\n${txt}`.slice(0, HISTORY_MAX_CHARS * 2);
    else turns.push({ role, text: txt });
  }
  while (turns.length && turns[0].role !== "user") turns.shift();
  while (turns.length && turns[turns.length - 1].role !== "model") turns.pop();
  // Keep the most recent turns within the total budget (drop oldest pairs).
  let total = turns.reduce((n, t) => n + t.text.length, 0);
  while (total > HISTORY_MAX_TOTAL && turns.length >= 2) {
    total -= turns[0].text.length + turns[1].text.length;
    turns.splice(0, 2);
  }
  return turns.map((t) => ({ role: t.role, parts: [{ text: t.text }] }));
}

// ============================================================
// TOOL 9 — WEB SEARCH (Tavily). FREE, but capped per couple per day
// server-side (consume_web_search RPC, JWT-scoped) to protect the quota.
// ============================================================
const webSearchDeclaration = {
  name: "web_search",
  description:
    "Search the web for real-world facts: event dates, festival/fair schedules, opening hours, news. NOT for movies (use search_movies) or nearby places (use search_places).",
  parameters: {
    type: "object",
    properties: {
      query: { type: "string", description: "a focused search query, e.g. 'Georgia National Fair 2026 dates'" },
    },
    required: ["query"],
  },
};

type WebSource = { title: string; url: string; snippet: string };
type WebResult = { answer: string | null; results: WebSource[] };

async function executeWebSearch(query: string, deadline?: number): Promise<WebResult> {
  const key = Deno.env.get("TAVILY_API_KEY");
  if (!key) throw new Error("TAVILY_API_KEY not set");
  const res = await fetchWithTimeout("https://api.tavily.com/search", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${key}` },
    body: JSON.stringify({ query, search_depth: "basic", max_results: 5, include_answer: true }),
  }, FETCH_TIMEOUT_MS, deadline);
  if (!res.ok) throw new Error(`tavily ${res.status}: ${await res.text()}`);
  // deno-lint-ignore no-explicit-any
  const j: any = await res.json();
  const results: WebSource[] = (Array.isArray(j?.results) ? j.results : [])
    // deno-lint-ignore no-explicit-any
    .filter((r: any) => typeof r?.url === "string" && (typeof r?.score !== "number" || r.score >= 0.3))
    .slice(0, 5)
    // deno-lint-ignore no-explicit-any
    .map((r: any) => ({
      title: String(r.title ?? "").replace(/\s+/g, " ").trim().slice(0, 140),
      url: String(r.url).slice(0, 500),
      snippet: String(r.content ?? "").replace(/\s+/g, " ").trim().slice(0, 400),
    }));
  const answer = typeof j?.answer === "string" ? j.answer.replace(/\s+/g, " ").trim().slice(0, 500) : null;
  return { answer: answer && answer.length ? answer : null, results };
}

// Per-couple daily cap across ALL router jobs (consume_ai_call, limit inside
// the function). Fail-CLOSED: if the RPC is missing or errors, no AI runs —
// so RUN 01_ai_call_cap.sql BEFORE deploying this router.
async function consumeAiCall(authHeader: string, deadline?: number): Promise<"ok" | "limit" | "error"> {
  try {
    const r = await callRpc("consume_ai_call", {}, authHeader, deadline);
    if (r?.ok === true) return "ok";
    return r?.reason === "daily_limit" ? "limit" : "error";
  } catch (e) {
    console.error("consume_ai_call failed:", e);
    return "error";
  }
}

// Server-side daily cap. Fail-CLOSED (quota protection): any error → not allowed.
async function consumeWebSearch(authHeader: string, deadline?: number): Promise<"ok" | "limit" | "error"> {
  try {
    const r = await callRpc("consume_web_search", {}, authHeader, deadline);
    if (r?.ok === true) return "ok";
    return r?.reason === "daily_limit" ? "limit" : "error";
  } catch (e) {
    console.error("consume_web_search failed:", e);
    return "error";
  }
}

// ---------- DATE GUARDRAIL helpers ----------
// A proposed date is allowed ONLY if it is (A) stated in a web result the
// SERVER fetched THIS turn, next to the event's own name, or (B) exactly one of
// the concrete dates the user's own message resolves to (relative to today).
// A bare day-word is not enough: "friday" means THE upcoming Friday, nothing else.
const MONTHS = ["january", "february", "march", "april", "may", "june",
  "july", "august", "september", "october", "november", "december"];
const MONTH_ABBR = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sept?", "oct", "nov", "dec"];
const MONTH_ALT = MONTHS.map((m, i) => `${m}|${MONTH_ABBR[i]}`).join("|");
function monthIndex(word: string): number {
  const w = word.toLowerCase().replace(/\.$/, "");
  for (let i = 0; i < 12; i++) {
    if (w === MONTHS[i] || new RegExp(`^(?:${MONTH_ABBR[i]})$`).test(w)) return i;
  }
  return -1;
}

// ---- date arithmetic on plain YYYY-MM-DD (UTC, no DST surprises) ----
function ymdOf(d: Date): string { return d.toISOString().slice(0, 10); }
function utcDate(ymd: string): Date { const [y, m, d] = ymd.split("-").map(Number); return new Date(Date.UTC(y, m - 1, d)); }
function addDays(ymd: string, n: number): string { const d = utcDate(ymd); d.setUTCDate(d.getUTCDate() + n); return ymdOf(d); }
function validYmd(y: number, m: number, d: number): string | null {
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null;
  return ymdOf(dt);
}
// Next occurrence of month/day on or after today (this year, else next year).
function nextMonthDay(today: string, m: number, d: number): string | null {
  const y = +today.slice(0, 4);
  const thisYear = validYmd(y, m, d);
  if (thisYear && thisYear >= today) return thisYear;
  return validYmd(y + 1, m, d);
}

const WEEKDAYS: Record<string, number> = {
  sunday: 0, monday: 1, tuesday: 2, tue: 2, tues: 2, wednesday: 3, thursday: 4, thu: 4, thur: 4, thurs: 4,
  friday: 5, fri: 5, saturday: 6,
};

// Every concrete date the user's OWN message refers to. Empty = they gave none.
function resolveUserDates(msg: string, today: string): Set<string> {
  const out = new Set<string>();
  const text = ` ${msg.toLowerCase()} `;
  const dow = utcDate(today).getUTCDay();

  if (/\b(today|tonight|this evening)\b/.test(text)) out.add(today);
  if (/\bday after tomorrow\b/.test(text)) out.add(addDays(today, 2));
  else if (/\btomorrow\b/.test(text)) out.add(addDays(today, 1));

  // Weekdays: "friday" / "this friday" → the upcoming one (today counts);
  // "next friday" is ambiguous in English → the upcoming one AND the one after.
  for (const m of text.matchAll(/\b(next|this|on)?\s*(sunday|monday|tuesday|tues?|wednesday|thursday|thu(?:rs?)?|friday|fri|saturday)\b/g)) {
    const target = WEEKDAYS[m[2]];
    if (target === undefined) continue;
    const ahead = (target - dow + 7) % 7;
    out.add(addDays(today, ahead));
    if (m[1] === "next") out.add(addDays(today, ahead === 0 ? 7 : ahead + 7));
  }
  if (/\b(this|next)?\s*weekend\b/.test(text)) {
    const toSat = (6 - dow + 7) % 7;
    out.add(addDays(today, toSat)); out.add(addDays(today, toSat + 1));
  }
  for (const m of text.matchAll(/\bin (\d{1,2}) (day|days|week|weeks)\b/g)) {
    const n = +m[1] * (m[2].startsWith("week") ? 7 : 1);
    if (n > 0 && n <= 366) out.add(addDays(today, n));
  }

  // "oct 14", "October 14th", "Oct. 14, 2027"
  for (const m of text.matchAll(new RegExp(`\\b(${MONTH_ALT})\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?(?!\\d)`, "g"))) {
    const mi = monthIndex(m[1]); if (mi < 0) continue;
    const r = m[3] ? validYmd(+m[3], mi + 1, +m[2]) : nextMonthDay(today, mi + 1, +m[2]);
    if (r) out.add(r);
  }
  // "14 october", "14th of oct", "14 oct 2027"
  for (const m of text.matchAll(new RegExp(`\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?(${MONTH_ALT})\\b\\.?(?:,?\\s+(\\d{4}))?`, "g"))) {
    const mi = monthIndex(m[2]); if (mi < 0) continue;
    const r = m[3] ? validYmd(+m[3], mi + 1, +m[1]) : nextMonthDay(today, mi + 1, +m[1]);
    if (r) out.add(r);
  }
  // "the 23rd" / "on the 23rd" / "on 23rd" → that day this month, else next month.
  for (const m of text.matchAll(/\b(?:the|on)\s+(\d{1,2})(st|nd|rd|th)\b/g)) {
    const d = +m[1];
    const [y, mo] = [+today.slice(0, 4), +today.slice(5, 7)];
    const here = validYmd(y, mo, d);
    const r = here && here >= today ? here : (mo === 12 ? validYmd(y + 1, 1, d) : validYmd(y, mo + 1, d));
    if (r) out.add(r);
  }
  // Numeric US m/d or m/d/yyyy (not fractions inside longer numbers).
  for (const m of text.matchAll(/(?<![\d/])(\d{1,2})\/(\d{1,2})(?:\/(\d{2}|\d{4}))?(?![\d/])/g)) {
    const mo = +m[1], d = +m[2];
    const y = m[3] ? (m[3].length === 2 ? 2000 + +m[3] : +m[3]) : null;
    const r = y ? validYmd(y, mo, d) : nextMonthDay(today, mo, d);
    if (r) out.add(r);
  }
  // ISO dates typed directly.
  for (const m of text.matchAll(/\b(\d{4})-(\d{2})-(\d{2})\b/g)) {
    const r = validYmd(+m[1], +m[2], +m[3]); if (r) out.add(r);
  }
  return out;
}

// Regexes that match this exact calendar date written the usual ways.
function datePatterns(ymd: string): RegExp[] {
  const [y, m, d] = ymd.split("-").map(Number);
  const mon = MONTHS[m - 1], ab = MONTH_ABBR[m - 1];
  const day = `0?${d}(?:st|nd|rd|th)?(?!\\d)`;
  return [
    new RegExp(`\\b(?:${mon}|${ab})\\.?\\s+${day}`, "gi"),                       // October 9 / Oct. 9th
    new RegExp(`\\b0?${d}(?:st|nd|rd|th)?\\s+(?:of\\s+)?(?:${mon}|${ab})\\b`, "gi"), // 9 October
    new RegExp(`(?<![\\d/])0?${m}/0?${d}(?:/(?:${y}|${y % 100}))?(?![\\d/])`, "g"), // 10/9(/2026)
    new RegExp(`${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`, "g"),
  ];
}

// Month-day mentions in free text (for spotting a contradicting summary answer).
function monthDayMentions(text: string): string[] {
  const out: string[] = [];
  for (const m of text.matchAll(new RegExp(`\\b(${MONTH_ALT})\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?!\\d)`, "gi"))) {
    const mi = monthIndex(m[1]); if (mi >= 0) out.push(`${mi + 1}-${Number(m[2])}`);
  }
  for (const m of text.matchAll(new RegExp(`\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?(${MONTH_ALT})\\b`, "gi"))) {
    const mi = monthIndex(m[2]); if (mi >= 0) out.push(`${mi + 1}-${Number(m[1])}`);
  }
  return out;
}

// The event's distinctive words (what must appear near the date).
const GENERIC = new Set(["the", "and", "our", "for", "with", "event", "day", "night", "date", "add", "trip",
  "annual", "festival", "fair", "show", "party", "dinner", "lunch", "movie", "concert", "game", "tour", "week"]);
function keyTerms(title: string): string[] {
  const all = title.toLowerCase().replace(/[^a-z0-9\s]/g, " ").split(/\s+/).filter((t) => t.length >= 3);
  const distinct = all.filter((t) => !GENERIC.has(t) && !/^\d+$/.test(t));
  return distinct.length ? distinct : all.filter((t) => !/^\d+$/.test(t));
}
const NEAR_CHARS = 160;

type Grounding = { userMessage: string; userDates: Set<string>; answer: string | null; sources: WebSource[] };

// (A) The date appears in a source the SERVER fetched THIS turn, with one of the
// event's key terms within ~160 chars of it (or in the page title), the year in
// the same source, and Tavily's summary answer not naming a different date.
function groundedInSearch(ymd: string, g: Grounding, eventTitle: string): WebSource | null {
  const year = ymd.slice(0, 4);
  const [, m, d] = ymd.split("-").map(Number);
  if (g.answer) {
    const mds = monthDayMentions(g.answer);
    if (mds.length && !mds.includes(`${m}-${d}`)) return null; // contradicted
  }
  const terms = keyTerms(eventTitle);
  if (!terms.length) return null;
  for (const src of g.sources) {
    const title = src.title.toLowerCase();
    const snippet = src.snippet;
    if (!`${src.title} ${snippet}`.includes(year)) continue;
    const titleHasTerm = terms.some((t) => title.includes(t));
    for (const re of datePatterns(ymd)) {
      for (const hit of snippet.matchAll(re)) {
        const at = hit.index ?? 0;
        const window = snippet.slice(Math.max(0, at - NEAR_CHARS), at + hit[0].length + NEAR_CHARS).toLowerCase();
        if (titleHasTerm || terms.some((t) => window.includes(t))) return src;
      }
    }
  }
  return null;
}

// Applies (A)/(B) to a proposed date. {} = allowed; otherwise a refusal.
function dateGuard(ymd: string, g: Grounding, eventTitle: string): { source?: WebSource; refusal?: ToolOutcome } {
  const src = groundedInSearch(ymd, g, eventTitle);
  if (src) return { source: src };
  if (g.userDates.has(ymd)) return {};          // (B) exactly a date THEY said
  const best = g.sources[0];
  return {
    refusal: {
      summary: {
        status: "date_not_confirmed",
        note: "The proposed date is not a date the user said and was not found next to this event in this turn's search results. " +
          "Do NOT add anything. Tell them what you found (if anything), name the source, and ask them to confirm the exact date.",
        event: eventTitle,
        ...(g.userDates.size ? { dates_the_user_mentioned: [...g.userDates].sort() } : {}),
        ...(best ? { found: { title: best.title, url: best.url, snippet: best.snippet.slice(0, 200) } } : {}),
        ...(g.answer ? { search_summary: g.answer } : {}),
      },
      fallback: best
        ? `I found "${best.title}", but I couldn't confirm the exact date for ${eventTitle} — can you tell me the date and I'll add it? 🤍`
        : `I don't want to guess the date for ${eventTitle} — what day is it? 🤍`,
    },
  };
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

  // ONE request-wide deadline, fixed at arrival. Every Gemini / tool / REST call
  // gets min(its own timeout, time left); nothing may run past it.
  const deadline = Date.now() + REQUEST_DEADLINE_MS;

  // The caller's JWT (JWT verification is ON), forwarded to calendar RPCs.
  const authHeader = req.headers.get("Authorization") ?? "";

  let payload: {
    job: AIJob; prompt: string; context?: Record<string, unknown>; history?: unknown;
  };
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
  if (prompt.length > MAX_PROMPT_CHARS) {
    return json({ error: "prompt_too_long", limit: MAX_PROMPT_CHARS }, 400);
  }
  const providerName = CONFIG[job];
  if (!providerName) return json({ error: "unknown_job" }, 400);

  // Daily call cap — BEFORE any Gemini/tool call, for every job.
  const quota = await consumeAiCall(authHeader, deadline);
  if (quota !== "ok") {
    const text = quota === "limit"
      ? "I've been thinking hard all day 🌙 — my head needs a rest. Come find me tomorrow? 🤍"
      : "My thoughts are a little tangled right now — try me again in a bit? 🌫️";
    // In character, 200 so the app renders it as the creature speaking.
    return json({ text, meta: { provider: "gemini", model: "" }, aiBusy: true });
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "GEMINI_API_KEY secret is not set" }, 500);
  const meta: Record<string, unknown> = { provider: "gemini", model: "" };

  // `userMessage` is the raw latest message (for the date guard) — kept OUT of
  // the model prompt; everything else in context is passed through as before.
  const { userMessage: rawUserMessage, ...ctx } = (payload.context ?? {}) as Record<string, unknown>;
  const hasCtx = Object.keys(ctx).length > 0;
  const text = hasCtx ? `${prompt}\n\nContext: ${JSON.stringify(ctx)}` : prompt;

  try {
    if (job === "creature") {
      const tools = [{
        functionDeclarations: [
          searchMoviesDeclaration,
          searchPlacesDeclaration,
          listUpcomingEventsDeclaration,
          findEventsDeclaration,
          proposeEventAddDeclaration,
          proposeEventUpdateDeclaration,
          proposeEventDeleteDeclaration,
          webSearchDeclaration,
        ],
      }];
      // Short conversation memory (bounded again here — never trust the client).
      const contents: unknown[] = [
        ...historyContents(payload.history),
        { role: "user", parts: [{ text }] },
      ];

      // ---- BOUNDED MULTI-STEP LOOP ----
      // Lookup tools may chain (feed result back, ask again). A calendar
      // proposal ENDS the turn (one per turn) after a final text-only voice
      // call. Proposal tools never write — the app writes after the user's Yes.
      // Time: every step and call is capped by the request `deadline`.
      const MAX_STEPS = 4;
      const MIN_STEP_MS = 3_000; // don't start a Gemini step with less than this left
      let movies: MovieCard[] = [];
      let places: PlaceCard[] = [];
      const webSources: WebSource[] = [];
      const today = normDate(ctx["today"]) ?? new Date().toISOString().slice(0, 10);
      const userMessage = typeof rawUserMessage === "string" ? rawUserMessage.slice(0, 2000) : "";
      const grounding: Grounding = {
        userMessage,
        // (B) only these exact dates count as "the user gave a date".
        // No userMessage field (older app) → none → user dates always refused.
        userDates: resolveUserDates(userMessage, today),
        answer: null,
        // (A) only sources the SERVER fetches THIS turn — app-supplied history
        // "[Web source: …]" lines are never trusted for grounding.
        sources: [],
      };
      let lastFallback = "🤍";
      const reply = (t: string, extra: Record<string, unknown> = {}) => json({
        text: t, meta,
        ...(movies.length ? { movies } : {}),
        ...(places.length ? { places } : {}),
        ...(webSources.length ? { sources: webSources.map((w) => ({ title: w.title, url: w.url, snippet: w.snippet.slice(0, 200) })) } : {}),
        ...extra,
      });
      const timeLeft = () => deadline - Date.now();
      // Step 0 errors propagate (→ the calm "AI is busy" reply). Later steps
      // phrase results; if Gemini fails or time runs out there, keep the
      // canned line (same behaviour as the old second "voice" pass).
      // `final` = tools declared but calling disabled → must answer in text.
      const ask = async (step: number, final: boolean) => {
        const opts = { deadline, noToolCalls: final };
        if (step === 0) return await geminiGenerate(contents, apiKey, tools, CREATURE_SYSTEM, opts);
        try { return await geminiGenerate(contents, apiKey, tools, CREATURE_SYSTEM, opts); } catch (_) { return null; }
      };
      const feed = (part: unknown, name: string, result: unknown) => {
        contents.push({ role: "model", parts: [part] });
        contents.push({ role: "user", parts: [{ functionResponse: { name, response: { results: result } } }] });
      };

      for (let step = 0; step < MAX_STEPS; step++) {
        if (step > 0 && timeLeft() < MIN_STEP_MS) break;
        // The last allowed step can't call tools, so the loop always ends in text.
        const g = await ask(step, step === MAX_STEPS - 1);
        if (!g) return reply(lastFallback);
        meta.model = g.model;
        const part = firstPart(g.raw);
        const fc = part?.functionCall;

        // ---- text → done (this is also the old "voice" pass) ----
        if (!fc) return reply(extractText(g.raw) ?? (step === 0 ? "🤍" : lastFallback));

        // ---- movies ----
        if (fc.name === "search_movies") {
          try {
            movies = await executeMovieSearch(fc.args ?? {}, deadline);
          } catch (e) {
            console.error("movies tool failed:", e);
            return reply("I reached for the movie shelf but it's a little foggy right now — try me again in a bit? 🌫️");
          }
          lastFallback = "Ooh, movie night? Here are a few I think you two would love 🍿";
          feed(part, fc.name, movies.map((m) => ({ title: m.title, year: m.year })));
          continue;
        }

        // ---- places ----
        if (fc.name === "search_places") {
          const lat = ctx["lat"];
          const lng = ctx["lng"];
          if (typeof lat !== "number" || typeof lng !== "number") {
            return reply("Ooh, I can find spots near you two — flip on location and ask me again? 🤍", { needsLocation: true });
          }
          try {
            places = await executePlaceSearch(fc.args ?? {}, lat, lng, deadline);
          } catch (e) {
            console.error("places tool failed:", e);
            return reply("I peeked out the window but it's a bit foggy right now — try me again in a bit? 🌫️");
          }
          if (places.length === 0) {
            return reply("Hmm, I couldn't spot anything good nearby right now — want to try a different vibe?", { places: [] });
          }
          lastFallback = "Here are a few spots near you two 🤍";
          feed(part, fc.name, places.map((p) => ({ name: p.name, category: p.category, address: p.address })));
          continue;
        }

        // ---- web search (free; daily-capped server-side) ----
        if (fc.name === "web_search") {
          const q = cleanText(fc.args?.query, 200);
          if (!q) { feed(part, fc.name, { status: "error", note: "empty query" }); continue; }
          const allowed = await consumeWebSearch(authHeader, deadline);
          if (allowed !== "ok") {
            const msg = allowed === "limit"
              ? "I've done a lot of looking things up today 🌙 — try me again tomorrow, or tell me the details and I'll take it from there 🤍"
              : "I couldn't look that up just now — could you tell me the details? 🤍";
            // Stay in character; no chaining into a guessed answer.
            return reply(msg);
          }
          let result: WebResult;
          try {
            result = await executeWebSearch(q, deadline);
          } catch (e) {
            console.error("web_search failed:", e);
            return reply("I tried to look that up but it's a little foggy right now — can you tell me the details? 🌫️");
          }
          grounding.answer = result.answer ?? grounding.answer;
          grounding.sources = [...result.results, ...grounding.sources];
          webSources.push(...result.results.slice(0, 3));
          lastFallback = result.results.length
            ? `Here's what I found — ${result.results[0].title} 🤍`
            : "I couldn't find anything solid on that — do you know the details? 🤍";
          feed(part, fc.name, { answer: result.answer, results: result.results, note: "Only state dates/facts that appear here; cite the source title." });
          continue;
        }

        // ---- calendar: list upcoming (Usora+, via RPC) ----
        if (fc.name === "list_upcoming_events") {
          // deno-lint-ignore no-explicit-any
          let result: any;
          try {
            result = await executeListUpcoming(fc.args ?? {}, authHeader, deadline);
          } catch (e) {
            console.error("calendar list tool failed:", e);
            return reply("I tried to peek at your calendar but it's a little foggy — try me again in a bit? 🌫️");
          }
          const ok = result?.ok === true;
          lastFallback = ok
            ? "Here's what's coming up for you two 🤍"
            : (result?.reason === "not_premium"
              ? "Ooh, your shared calendar is a Usora+ thing 🤍"
              : "I couldn't reach your calendar just now — try again in a bit?");
          feed(part, fc.name, ok ? { events: result.events } : { events: [], reason: result?.reason ?? "error" });
          continue;
        }

        // ---- calendar: find (lookup) or a PROPOSAL (ends the turn) ----
        if (PROPOSAL_TOOLS.has(fc.name)) {
          let outcome: ToolOutcome;
          try {
            outcome = await runCalendarProposal(fc.name, fc.args ?? {}, authHeader, grounding, deadline);
          } catch (e) {
            console.error(`calendar ${fc.name} failed:`, e);
            return reply("I tried to peek at your calendar but it's a little foggy — try me again in a bit? 🌫️");
          }
          if (fc.name === "find_events" && !outcome.premiumRequired) {
            lastFallback = outcome.fallback;
            feed(part, fc.name, outcome.summary);
            continue;
          }
          // Proposal (or a refusal / premium gate): one final text-only voice
          // call, then end the turn. At most ONE calendarAction per turn.
          feed(part, fc.name, outcome.summary);
          let spoken: string | null = null;
          if (timeLeft() >= MIN_STEP_MS) {
            const g2 = await ask(step + 1, true); // tools OFF: wording only
            spoken = g2 ? extractText(g2.raw) : null;
          }
          return reply(spoken ?? outcome.fallback, {
            ...(outcome.calendarAction ? { calendarAction: outcome.calendarAction } : {}),
            ...(outcome.premiumRequired ? { premiumRequired: true } : {}),
          });
        }

        // Unknown tool name → treat as plain chat.
        return reply(extractText(g.raw) ?? lastFallback);
      }
      // Out of steps/time: reply with what we have. Never a proposal here.
      return reply(lastFallback);
    }

    // ---- other jobs ----
    const contents = [{ role: "user", parts: [{ text }] }];
    const g = await geminiGenerate(contents, apiKey, undefined, undefined, { deadline });
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
