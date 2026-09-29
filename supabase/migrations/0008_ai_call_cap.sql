-- ============================================================
-- 0008 — Per-couple daily cap across ALL ai-router jobs: ai_usage + consume_ai_call().
-- The router fails closed, so this must exist before that router is deployed.
--
-- RECORD ONLY — this file was written for, and applied by hand in, the Supabase
-- dashboard SQL editor. It is NOT run by any migration tool, and the repo has
-- no automated runner. DO NOT re-run it blindly: check the live state first
-- (pg_policies / pg_proc / information_schema) and confirm with the owner.
-- Whether every statement here is live was not verified from this repo.
-- Kept in git for version control and documentation.
-- Added 2026-09-22.
-- ============================================================

-- ============================================================
-- Usora — H3 (1/3): per-couple DAILY cap on ALL ai-router calls.
-- RUN THIS BEFORE DEPLOYING THE NEW ROUTER — the router fails CLOSED, so if
-- this function is missing every AI call is refused.
--
-- Same pattern as consume_web_search: couple derived server-side from
-- auth.uid(), the limit lives HERE (never in the request), the table has RLS on
-- with NO policies, so the app can neither read nor reset its counter.
-- The 10/day web_search cap still applies ON TOP of this.
-- Safe to re-run.
-- ============================================================

create table if not exists public.ai_usage (
  couple_id uuid not null references public.couples(id) on delete cascade,
  day       date not null,                        -- UTC day
  count     int  not null default 0,
  primary key (couple_id, day)
);
alter table public.ai_usage enable row level security;
-- Intentionally NO policies.
revoke all on public.ai_usage from anon, authenticated;

create or replace function public.consume_ai_call()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c_limit  constant int := 200;                   -- router calls per couple per UTC day
  v_couple uuid;
  v_day    date := (now() at time zone 'utc')::date;
  v_count  int;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  v_couple := public.current_couple_id();
  -- Not linked yet: allow (no couple row to count against; nothing premium is
  -- reachable either). Remove this branch to refuse unlinked users entirely.
  if v_couple is null then
    return jsonb_build_object('ok', true, 'used', 0, 'limit', c_limit);
  end if;

  insert into public.ai_usage as u (couple_id, day, count)
  values (v_couple, v_day, 1)
  on conflict (couple_id, day) do update
    set count = u.count + 1
    where u.count < c_limit
  returning u.count into v_count;

  if v_count is null then                         -- already at the limit
    return jsonb_build_object('ok', false, 'reason', 'daily_limit', 'limit', c_limit);
  end if;
  return jsonb_build_object('ok', true, 'used', v_count, 'limit', c_limit);
end;
$$;

revoke all on function public.consume_ai_call() from public, anon;
grant execute on function public.consume_ai_call() to authenticated;

notify pgrst, 'reload schema';

-- Verify (expect one row, prosecdef = t, authenticated_can_run = t):
select p.proname, pg_get_function_identity_arguments(p.oid) args,
       p.prosecdef, has_function_privilege('authenticated', p.oid, 'execute') authenticated_can_run
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'consume_ai_call';

-- Day-to-day: see usage / change the cap by editing c_limit and re-running.
-- select * from public.ai_usage order by day desc, count desc limit 20;
