// ============================================================
// USORA — delete-account (Apple Guideline 5.1.1(v): in-app account deletion).
// Paste into the Supabase dashboard function `delete-account`; deploy with
// verify_jwt ON (only a signed-in user may delete their own account).
//
// Flow (uid resolved SERVER-SIDE from the caller's JWT — NEVER a parameter):
//   1) Resolve the caller's uid from their JWT via /auth/v1/user.
//   2) Call the SECURITY DEFINER RPC purge_couple_and_user_data() WITH the
//      caller's JWT, so auth.uid() = the caller — deletes their couple's shared
//      data, frees the partner, and removes their public.users row (atomic).
//   3) Delete the auth.users row via the Auth Admin API (service role).
//   4) Return ok — the app then signs out locally and routes to Welcome.
//
// Auto-injected: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
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

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return json({ error: "env missing" }, 500);

  // The caller's JWT (attached automatically by supabase.functions.invoke).
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return json({ error: "unauthorized" }, 401);

  try {
    // 1) Resolve uid from the caller's token (verifies it too).
    const who = await fetch(`${url}/auth/v1/user`, {
      headers: { "apikey": anon, "Authorization": authHeader },
    });
    if (!who.ok) return json({ error: "unauthorized" }, 401);
    const uid = (await who.json())?.id as string | undefined;
    if (!uid) return json({ error: "no_user" }, 401);

    // 2) DB cleanup as the caller (auth.uid() resolves inside the RPC).
    const purge = await fetch(`${url}/rest/v1/rpc/purge_couple_and_user_data`, {
      method: "POST",
      headers: {
        "apikey": anon,
        "Authorization": authHeader, // caller's JWT → auth.uid() = caller
        "Content-Type": "application/json",
      },
      body: "{}",
    });
    if (!purge.ok) {
      const detail = await purge.text();
      console.error("purge failed:", purge.status, detail);
      return json({ error: "purge_failed", detail }, 500);
    }

    // 3) Delete the auth.users row (service role / Admin API).
    const del = await fetch(`${url}/auth/v1/admin/users/${uid}`, {
      method: "DELETE",
      headers: { "apikey": service, "Authorization": `Bearer ${service}` },
    });
    if (!del.ok) {
      const detail = await del.text();
      console.error("auth delete failed:", del.status, detail);
      return json({ error: "auth_delete_failed", detail }, 500);
    }

    return json({ ok: true });
  } catch (err) {
    console.error("delete-account error:", err);
    return json({ error: "delete_failed", detail: String(err) }, 500);
  }
});
