// ============================================================
// Usora AI ROUTER — self-contained Edge Function (paste this whole
// file into the Supabase dashboard function `ai-router`).
//
// - Neutral Usora request/response shape; config-per-job.
// - Gemini adapter with retry/backoff (503/429 absorbed).
// - CREATURE job uses Gemini FUNCTION-CALLING. Tools:
//     search_movies        → TMDB        (returns `movies`)
//     search_places        → Foursquare  (returns `places`; needs lat/lng)
//     add_calendar_event   → important_dates via RPC (Usora+; JWT-scoped)
//     list_upcoming_events → important_dates via RPC (Usora+; JWT-scoped)
//   Tools run server-side; Gemini phrases results in character.
// - Secrets: GEMINI_API_KEY (required), TMDB_API_KEY (movies),
//   FOURSQUARE_API_KEY (places). SUPABASE_URL / SUPABASE_ANON_KEY are
//   auto-injected. Never in the app. JWT ON.
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
const MODELS: Record<string, string> = { gemini: "gemini-flash-latest" };

// ---------- retry ----------
const RETRYABLE = new Set([429, 500, 502, 503, 504]);
const BACKOFF_MS = [500, 1000, 2000];
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

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

async function geminiGenerate(
  contents: unknown[],
  model: string,
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

  let lastError = "";
  for (let attempt = 0; attempt <= BACKOFF_MS.length; attempt++) {
    let res: Response;
    try {
      res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch (e) {
      lastError = `network error: ${e}`;
      if (attempt < BACKOFF_MS.length) { await sleep(BACKOFF_MS[attempt]); continue; }
      break;
    }
    if (res.ok) return await res.json();
    lastError = `Gemini API error ${res.status}: ${await res.text()}`;
    if (!RETRYABLE.has(res.status)) break;
    if (attempt >= BACKOFF_MS.length) break;
    await sleep(BACKOFF_MS[attempt]);
  }
  throw new Error(lastError || "Gemini call failed");
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
  const res = await fetch(`${url}/rest/v1/rpc/${fnName}`, {
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
  const res = await fetch(url);
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
// TOOL 2 — PLACES (Foursquare Places API, new places-api host)
// ============================================================
const PLACE_CATEGORIES: Record<string, string> = {
  restaurant: "13065",     // Restaurant
  movie_theater: "10024",  // Movie Theater
  museum: "10027",         // Museum
  attraction: "16000",     // Landmarks & Outdoors
};
const searchPlacesDeclaration = {
  name: "search_places",
  description:
    "Find real places near the couple to go out: restaurants, movie theaters, attractions/things to do, or museums. Use whenever they ask to find somewhere to eat/go/do nearby.",
  parameters: {
    type: "object",
    properties: {
      category: {
        type: "string",
        enum: Object.keys(PLACE_CATEGORIES),
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
// deno-lint-ignore no-explicit-any
function mapPlace(p: any): PlaceCard {
  const photo = p?.photos?.[0];
  const photoUrl = photo?.prefix && photo?.suffix
    ? `${photo.prefix}original${photo.suffix}`
    : null;
  return {
    name: p?.name ?? "Somewhere",
    category: p?.categories?.[0]?.name ?? "",
    address: p?.location?.formatted_address ?? p?.location?.address ?? "",
    distance: typeof p?.distance === "number" ? p.distance : null,
    rating: typeof p?.rating === "number" ? p.rating : null,
    photoUrl,
    lat: p?.latitude ?? p?.geocodes?.main?.latitude ?? null,
    lng: p?.longitude ?? p?.geocodes?.main?.longitude ?? null,
  };
}
async function executePlaceSearch(
  args: { category?: string; query?: string },
  lat: number,
  lng: number,
): Promise<PlaceCard[]> {
  const key = Deno.env.get("FOURSQUARE_API_KEY");
  if (!key) throw new Error("FOURSQUARE_API_KEY secret is not set");

  const params = new URLSearchParams({ ll: `${lat},${lng}`, limit: "8", sort: "DISTANCE" });
  if (args.query && args.query.trim().length) params.set("query", args.query);
  if (args.category && PLACE_CATEGORIES[args.category]) {
    params.set("fsq_category_ids", PLACE_CATEGORIES[args.category]);
  }
  params.set("fields", "name,location,categories,distance,latitude,longitude,rating,photos");

  const res = await fetch(`https://places-api.foursquare.com/places/search?${params}`, {
    headers: {
      "Authorization": `Bearer ${key}`,
      "X-Places-Api-Version": "2025-06-17",
      "accept": "application/json",
    },
  });
  if (!res.ok) throw new Error(`Foursquare error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const results = Array.isArray(data?.results) ? data.results : [];
  return results.slice(0, 8).map(mapPlace);
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
  const model = MODELS[providerName] ?? "";
  const meta = { provider: "gemini", model };

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
      const r1 = await geminiGenerate(contents, model, apiKey, tools, CREATURE_SYSTEM);
      const part = firstPart(r1);
      const fc = part?.functionCall;

      // ---- movies ----
      if (fc?.name === "search_movies") {
        let movies: MovieCard[] = [];
        try {
          movies = await executeMovieSearch(fc.args ?? {});
        } catch (_) {
          return json({ text: "I reached for the movie shelf but it's a little foggy right now — try me again in a bit? 🌫️", meta });
        }
        return json({ text: await secondTurn(contents, part, "search_movies", movies.map((m) => ({ title: m.title, year: m.year })), model, apiKey, tools) ?? "Ooh, movie night? Here are a few I think you two would love 🍿", meta, movies });
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
        } catch (_) {
          return json({ text: "I peeked out the window but it's a bit foggy right now — try me again in a bit? 🌫️", meta });
        }
        if (places.length === 0) {
          return json({ text: "Hmm, I couldn't spot anything good nearby right now — want to try a different vibe?", meta, places: [] });
        }
        return json({ text: await secondTurn(contents, part, "search_places", places.map((p) => ({ name: p.name, category: p.category })), model, apiKey, tools) ?? "Here are a few spots near you two 🤍", meta, places });
      }

      // ---- calendar: add (Usora+; couple resolved from JWT in the RPC) ----
      if (fc?.name === "add_calendar_event") {
        // deno-lint-ignore no-explicit-any
        let result: any;
        try {
          result = await executeAddCalendarEvent(fc.args ?? {}, authHeader);
        } catch (_) {
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
        return json({ text: await secondTurn(contents, part, "add_calendar_event", summary, model, apiKey, tools) ?? fallback, meta, calendarChanged: ok });
      }

      // ---- calendar: list upcoming (Usora+) ----
      if (fc?.name === "list_upcoming_events") {
        // deno-lint-ignore no-explicit-any
        let result: any;
        try {
          result = await executeListUpcoming(fc.args ?? {}, authHeader);
        } catch (_) {
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
        return json({ text: await secondTurn(contents, part, "list_upcoming_events", summary, model, apiKey, tools) ?? fallback, meta });
      }

      // ---- plain chat ----
      return json({ text: part?.text ?? extractText(r1) ?? "🤍", meta });
    }

    // ---- other jobs ----
    const contents = [{ role: "user", parts: [{ text }] }];
    const raw = await geminiGenerate(contents, model, apiKey);
    const out = extractText(raw);
    if (out == null) throw new Error("Unexpected Gemini response");
    return json({ text: out, meta });
  } catch (err) {
    console.error("ai-router error:", err);
    return json({ error: "ai_call_failed", detail: String(err) }, 502);
  }
});

// Second Gemini turn: feed the tool result back so it phrases in character.
async function secondTurn(
  contents: unknown[],
  // deno-lint-ignore no-explicit-any
  fcPart: any,
  toolName: string,
  resultSummary: unknown,
  model: string,
  apiKey: string,
  tools: unknown[],
): Promise<string | null> {
  try {
    contents.push({ role: "model", parts: [fcPart] });
    contents.push({
      role: "user",
      parts: [{ functionResponse: { name: toolName, response: { results: resultSummary } } }],
    });
    const r2 = await geminiGenerate(contents, model, apiKey, tools, CREATURE_SYSTEM);
    return extractText(r2);
  } catch (_) {
    return null;
  }
}
