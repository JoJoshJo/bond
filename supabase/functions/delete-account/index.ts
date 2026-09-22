// ============================================================
// USORA — delete-account (Apple Guideline 5.1.1(v): in-app account deletion).
// Paste into the Supabase dashboard function `delete-account`; deploy with
// verify_jwt ON (only a signed-in user may delete their own account).
//
// Flow (uid resolved SERVER-SIDE from the caller's JWT — NEVER a parameter):
//   1) Resolve the caller's uid from their JWT via /auth/v1/user.
//   2) Read their couple_id AS THE CALLER (RLS applies) — needed for storage.
//   3) Delete every object under `couple-media/{couple_id}/` (service role,
//      recursive). Done BEFORE the DB purge: if storage fails we abort with
//      nothing deleted yet, rather than leaving orphaned photos/voice notes.
//   4) Call the SECURITY DEFINER RPC purge_couple_and_user_data() WITH the
//      caller's JWT, so auth.uid() = the caller — deletes their couple's shared
//      data (and the couples row itself), frees the partner, and removes their
//      public.users row (atomic).
//   5) Delete the auth.users row via the Auth Admin API (service role).
//   6) Return ok — the app then signs out locally and routes to Welcome.
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

const BUCKET = "couple-media";

// Every object under `prefix` (Storage list is per-folder, so walk it).
// Depth-capped for safety; the app only writes {couple}/memories|voice|photos/.
async function listObjects(
  url: string, service: string, prefix: string, depth = 0,
): Promise<string[]> {
  if (depth > 4) return [];
  const out: string[] = [];
  for (let offset = 0; ; offset += 100) {
    const res = await fetch(`${url}/storage/v1/object/list/${BUCKET}`, {
      method: "POST",
      headers: {
        "apikey": service,
        "Authorization": `Bearer ${service}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ prefix, limit: 100, offset, sortBy: { column: "name", order: "asc" } }),
    });
    if (!res.ok) throw new Error(`storage list ${res.status}: ${await res.text()}`);
    const rows = await res.json();
    if (!Array.isArray(rows) || rows.length === 0) break;
    for (const r of rows) {
      const name = String(r?.name ?? "");
      if (!name) continue;
      const path = `${prefix}${name}`;
      // A row with no id is a folder placeholder → recurse into it.
      if (r?.id == null) out.push(...await listObjects(url, service, `${path}/`, depth + 1));
      else out.push(path);
    }
    if (rows.length < 100) break;
  }
  return out;
}

async function deleteCoupleMedia(url: string, service: string, coupleId: string): Promise<number> {
  const paths = await listObjects(url, service, `${coupleId}/`);
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    const res = await fetch(`${url}/storage/v1/object/${BUCKET}`, {
      method: "DELETE",
      headers: {
        "apikey": service,
        "Authorization": `Bearer ${service}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ prefixes: batch }),
    });
    if (!res.ok) throw new Error(`storage delete ${res.status}: ${await res.text()}`);
  }
  return paths.length;
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

    // 2) The caller's couple (read AS the caller; RLS scopes it).
    let coupleId: string | null = null;
    const mem = await fetch(
      `${url}/rest/v1/couple_members?select=couple_id&user_id=eq.${encodeURIComponent(uid)}&limit=1`,
      { headers: { "apikey": anon, "Authorization": authHeader } },
    );
    if (mem.ok) {
      const rows = await mem.json();
      coupleId = Array.isArray(rows) && rows.length ? rows[0]?.couple_id ?? null : null;
    } else {
      console.error("couple lookup failed:", mem.status);
    }

    // 3) Storage FIRST — photos + voice notes under couple-media/{couple}/.
    //    Abort on failure so we never delete the DB rows that point at them.
    if (coupleId) {
      try {
        const removed = await deleteCoupleMedia(url, service, coupleId);
        console.log(`deleted ${removed} storage objects for couple ${coupleId}`);
      } catch (e) {
        console.error("storage purge failed:", e);
        return json({ error: "storage_purge_failed" }, 500);
      }
    }

    // 4) DB cleanup as the caller (auth.uid() resolves inside the RPC).
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
      return json({ error: "purge_failed" }, 500);
    }

    // 5) Delete the auth.users row (service role / Admin API).
    const del = await fetch(`${url}/auth/v1/admin/users/${uid}`, {
      method: "DELETE",
      headers: { "apikey": service, "Authorization": `Bearer ${service}` },
    });
    if (!del.ok) {
      const detail = await del.text();
      console.error("auth delete failed:", del.status, detail);
      return json({ error: "auth_delete_failed" }, 500);
    }

    return json({ ok: true });
  } catch (err) {
    console.error("delete-account error:", err);
    return json({ error: "delete_failed" }, 500);
  }
});
