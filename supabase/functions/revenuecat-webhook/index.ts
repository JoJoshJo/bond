// ============================================================
// USORA — RevenueCat webhook (paste this whole file into the Supabase
// dashboard function `revenuecat-webhook`, then set the webhook in RC).
//
// PURPOSE: one Usora+ subscription covers the COUPLE. RevenueCat tracks the
// purchase against the individual buyer (RC App User ID = the Supabase user id,
// set via Purchases.logIn). This webhook maps that user → their couple and
// writes the couple-level entitlement to `subscriptions`, so BOTH partners get
// premium (the app reads couple premium from that table + realtime).
//
// SECURITY:
//   - Shared secret: the request's Authorization header MUST equal
//     RC_WEBHOOK_SECRET. RevenueCat is the only party that knows it, so only RC
//     can trigger a write.
//   - The couple is resolved SERVER-SIDE from event.app_user_id via
//     couple_members (service role). There is no couple_id in the request to
//     spoof; a forged body still has to resolve to a real membership.
//   - Anonymous ($RCAnonymousID…) app_user_ids (pre-login) are ignored.
//   - Service role key stays in the function env, never in the app.
//
// SECRETS: RC_WEBHOOK_SECRET (you set); SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
// (auto-injected).
// ============================================================

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
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

  // ---- 1. Shared-secret auth (only RevenueCat can trigger this) ----
  const secret = Deno.env.get("RC_WEBHOOK_SECRET");
  if (!secret) return json({ error: "RC_WEBHOOK_SECRET not set" }, 500);
  const auth = req.headers.get("Authorization") ?? "";
  if (auth !== secret && auth !== `Bearer ${secret}`) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return json({ error: "supabase env missing" }, 500);
  }
  const restHeaders = {
    "apikey": serviceKey,
    "Authorization": `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
  };

  // ---- 2. Parse the event ----
  // deno-lint-ignore no-explicit-any
  let event: any;
  try {
    const body = await req.json();
    event = body?.event ?? body;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const appUserId: string | undefined = event?.app_user_id;
  const type: string = event?.type ?? "";
  // 200 on benign skips so RC doesn't retry-storm.
  if (!appUserId || appUserId.startsWith("$RCAnonymousID")) {
    return json({ ok: true, skipped: "no_identified_user" });
  }

  // ---- 3. Resolve the couple from the buyer's user id (service role) ----
  let coupleId: string | null = null;
  try {
    const res = await fetch(
      `${supabaseUrl}/rest/v1/couple_members?user_id=eq.${appUserId}&select=couple_id&limit=1`,
      { headers: restHeaders },
    );
    const rows = await res.json();
    coupleId = Array.isArray(rows) && rows.length ? rows[0].couple_id : null;
  } catch (_) {
    coupleId = null;
  }
  if (!coupleId) return json({ ok: true, skipped: "no_couple_for_user" });

  // ---- 4. Compute couple entitlement from the event ----
  // Active iff the subscription's expiration is in the future. This handles all
  // event types with one rule: purchase/renewal/uncancellation/product_change →
  // future expiry → active; CANCELLATION keeps a future expiry → stays active
  // until it lapses; EXPIRATION/BILLING_ISSUE → past/absent → expired.
  const expMs: number | null =
    typeof event?.expiration_at_ms === "number" ? event.expiration_at_ms : null;
  const active = expMs != null && expMs > Date.now();
  const status = active ? "active" : "expired";
  const expiresIso = expMs != null ? new Date(expMs).toISOString() : null;
  const rcId: string =
    event?.original_transaction_id ?? event?.transaction_id ?? event?.id ??
      appUserId;

  // ---- 5. Upsert the couple's subscription row (on conflict couple_id) ----
  try {
    const res = await fetch(
      `${supabaseUrl}/rest/v1/subscriptions?on_conflict=couple_id`,
      {
        method: "POST",
        headers: { ...restHeaders, "Prefer": "resolution=merge-duplicates" },
        body: JSON.stringify({
          couple_id: coupleId,
          entitlement: "bond_plus",
          status,
          expires_at: expiresIso,
          revenuecat_id: rcId,
          updated_at: new Date().toISOString(),
        }),
      },
    );
    if (!res.ok) {
      const detail = await res.text();
      console.error("subscriptions upsert failed:", res.status, detail);
      return json({ error: "upsert_failed", detail }, 500);
    }
  } catch (err) {
    console.error("revenuecat-webhook error:", err);
    return json({ error: "upsert_error", detail: String(err) }, 500);
  }

  return json({ ok: true, couple_id: coupleId, status, type });
});
