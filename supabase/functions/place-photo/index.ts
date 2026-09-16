// ============================================================
// Usora PLACE-PHOTO PROXY — public image proxy for Google Places photos.
// Paste into the Supabase dashboard function `place-photo`.
//
// ⚠️ DEPLOY THIS FUNCTION WITH JWT VERIFICATION *OFF* (public). The app loads
// place photos with a plain <img>/NetworkImage that cannot send an auth header,
// so this endpoint must be reachable unauthenticated. The main `ai-router`
// stays JWT-verified — only THIS tiny image proxy is public.
//
// Why a proxy: the Google Places photo `media` endpoint needs the API key, and
// putting the key in a client URL would leak it. Instead the app points at this
// proxy; the proxy adds X-Goog-Api-Key SERVER-SIDE, so GOOGLE_PLACES_API_KEY
// never leaves the server.
//
// Security: the only thing the caller controls is the photo resource `name`,
// which is strictly validated to Google's `places/<id>/photos/<ref>` shape. The
// upstream host is hardcoded, so this cannot be turned into an open proxy/SSRF.
//
// Secret used: GOOGLE_PLACES_API_KEY (same one ai-router uses).
// ============================================================

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};

// Google photo resource: "places/<PLACE_ID>/photos/<PHOTO_REF>".
const NAME_RE = /^places\/[A-Za-z0-9_-]+\/photos\/[A-Za-z0-9_-]+$/;

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "GET") {
    return new Response("method_not_allowed", { status: 405, headers: CORS });
  }

  const url = new URL(req.url);
  const name = url.searchParams.get("name") ?? "";
  if (!NAME_RE.test(name)) {
    return new Response("bad_photo_name", { status: 400, headers: CORS });
  }

  // Clamp the requested width to a sane range (default 400).
  const wRaw = parseInt(url.searchParams.get("w") ?? "400", 10);
  const maxWidthPx = Number.isFinite(wRaw) ? Math.min(Math.max(wRaw, 80), 800) : 400;

  const key = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!key) return new Response("no_api_key", { status: 500, headers: CORS });

  let upstream: Response;
  try {
    upstream = await fetch(
      `https://places.googleapis.com/v1/${name}/media?maxWidthPx=${maxWidthPx}`,
      { headers: { "X-Goog-Api-Key": key } }, // key stays server-side
    );
  } catch (e) {
    console.error("place-photo upstream error:", e);
    return new Response("upstream_error", { status: 502, headers: CORS });
  }
  if (!upstream.ok) {
    console.error(`place-photo upstream ${upstream.status}: ${await upstream.text()}`);
    return new Response("upstream_status", { status: upstream.status, headers: CORS });
  }

  // Stream the image bytes back with a long cache (photos are stable).
  return new Response(upstream.body, {
    status: 200,
    headers: {
      ...CORS,
      "Content-Type": upstream.headers.get("Content-Type") ?? "image/jpeg",
      "Cache-Control": "public, max-age=86400",
    },
  });
});
