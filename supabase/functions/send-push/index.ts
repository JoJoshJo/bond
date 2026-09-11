// ============================================================
// USORA — send-push (paste this whole file into the Supabase dashboard function
// `send-push`, deploy with verify_jwt OFF, then point a Database Webhook at it).
//
// PURPOSE: a new chat message notifies the OTHER partner. Fired by a Supabase
// Database Webhook on `messages` INSERT. Sends an FCM HTTP v1 push to the
// recipient's device token.
//
// AUTH: verify_jwt is OFF; this function checks the `x-webhook-secret` header
// against SEND_PUSH_SECRET (set by J). Mirrors the revenuecat-webhook pattern.
//
// FCM v1 ONLY (no legacy server key): FCM_SERVICE_ACCOUNT (Firebase service
// account JSON) → signed JWT (RS256, Web Crypto) → OAuth2 access token →
// POST https://fcm.googleapis.com/v1/projects/<project_id>/messages:send.
//
// SECRETS: SEND_PUSH_SECRET (J adds), FCM_SERVICE_ACCOUNT (already set).
// Auto-injected: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
//
// Privacy: the push body is generic ("sent you a message") — never the content.
// Don't-notify-self: the sender is explicitly excluded (recipient != sender).
// ============================================================

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const ANDROID_CHANNEL_ID = "usora_default"; // must match lib/core/push/push_service.dart

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ---------- Google OAuth2 access token (service account, RS256) ----------
let cachedToken: { token: string; exp: number } | null = null;

function b64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlStr(s: string): string {
  return b64url(new TextEncoder().encode(s));
}
function pemToPkcs8(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

// deno-lint-ignore no-explicit-any
async function getAccessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.token;

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64urlStr(JSON.stringify(header))}.${b64urlStr(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`oauth token ${res.status}: ${await res.text()}`);
  const j = await res.json();
  cachedToken = { token: j.access_token, exp: now + (j.expires_in ?? 3600) };
  return cachedToken.token;
}

// ---------- router ----------
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // ---- webhook shared-secret auth ----
  const secret = Deno.env.get("SEND_PUSH_SECRET");
  if (!secret) return json({ error: "SEND_PUSH_SECRET not set" }, 500);
  if ((req.headers.get("x-webhook-secret") ?? "") !== secret) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!supabaseUrl || !serviceKey || !saRaw) {
    return json({ error: "env missing" }, 500);
  }
  const rest = {
    "apikey": serviceKey,
    "Authorization": `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
  };

  try {
    // ---- parse the message row ----
    // deno-lint-ignore no-explicit-any
    let payload: any;
    try {
      payload = await req.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
    const record = payload?.record ?? payload;
    const coupleId: string | undefined = record?.couple_id;
    const senderId: string | undefined = record?.sender_id;
    if (!coupleId || !senderId) {
      return json({ ok: true, skipped: "missing_couple_or_sender" });
    }

    // ---- resolve the OTHER member (never the sender) ----
    const memRes = await fetch(
      `${supabaseUrl}/rest/v1/couple_members?couple_id=eq.${coupleId}&user_id=neq.${senderId}&select=user_id&limit=1`,
      { headers: rest },
    );
    const members = await memRes.json();
    const recipientId: string | undefined =
      Array.isArray(members) && members.length ? members[0].user_id : undefined;
    if (!recipientId) return json({ ok: true, skipped: "no_partner" });

    // ---- recipient token ----
    const rcpRes = await fetch(
      `${supabaseUrl}/rest/v1/users?id=eq.${recipientId}&select=fcm_token&limit=1`,
      { headers: rest },
    );
    const rcpRows = await rcpRes.json();
    const token: string | null =
      Array.isArray(rcpRows) && rcpRows.length ? rcpRows[0].fcm_token : null;
    if (!token) return json({ ok: true, skipped: "no_token" });

    // ---- notification_prefs: skip only if explicitly OFF (missing = opted-in) ----
    const prefRes = await fetch(
      `${supabaseUrl}/rest/v1/notification_prefs?user_id=eq.${recipientId}&category=eq.partner_action&select=enabled&limit=1`,
      { headers: rest },
    );
    const prefRows = await prefRes.json();
    if (Array.isArray(prefRows) && prefRows.length && prefRows[0].enabled === false) {
      return json({ ok: true, skipped: "prefs_off" });
    }

    // ---- sender display name (title) ----
    const sndRes = await fetch(
      `${supabaseUrl}/rest/v1/users?id=eq.${senderId}&select=display_name&limit=1`,
      { headers: rest },
    );
    const sndRows = await sndRes.json();
    const senderName: string =
      (Array.isArray(sndRows) && sndRows.length && sndRows[0].display_name) ||
      "Your partner";

    // ---- send via FCM v1 ----
    const sa = JSON.parse(saRaw);
    const accessToken = await getAccessToken(sa);
    const fcmBody = {
      message: {
        token,
        notification: { title: senderName, body: "sent you a message" },
        data: { type: "message", couple_id: coupleId },
        android: { notification: { channel_id: ANDROID_CHANNEL_ID } },
        apns: { payload: { aps: { sound: "default" } } },
      },
    };
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmBody),
      },
    );

    if (fcmRes.ok) return json({ ok: true, sent: true, recipient: recipientId });

    const errText = await fcmRes.text();
    // Self-heal: a stale/unregistered token → clear it so we stop trying.
    if (fcmRes.status === 404 || errText.includes("UNREGISTERED")) {
      await fetch(`${supabaseUrl}/rest/v1/users?id=eq.${recipientId}`, {
        method: "PATCH",
        headers: rest,
        body: JSON.stringify({ fcm_token: null }),
      });
      return json({ ok: true, cleared_stale_token: true });
    }
    console.error("FCM send failed:", fcmRes.status, errText);
    return json({ ok: true, fcm_error: fcmRes.status }); // 200 so the webhook doesn't retry-storm
  } catch (err) {
    console.error("send-push error:", err);
    return json({ ok: true, error: String(err) }); // never throw uncaught
  }
});
