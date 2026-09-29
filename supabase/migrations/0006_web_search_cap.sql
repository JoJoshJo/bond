-- ============================================================
-- 0006 — Per-couple daily cap on ai-router web_search (Tavily): web_search_usage
-- table + consume_web_search().
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
-- Usora — per-couple DAILY cap on web_search (Tavily). Run in the Supabase
-- SQL editor BEFORE deploying the new ai-router. Safe to re-run.
--
-- The router calls consume_web_search() with the caller's JWT before every
-- Tavily request. The couple is derived server-side (current_couple_id()), the
-- limit lives HERE (not in the client or the request), and the table has no
-- policies — so the app can neither read nor reset its counter.
-- The router fails CLOSED: if this function is missing/errors, no search runs.
-- ============================================================

create table if not exists public.web_search_usage (
  couple_id uuid not null references public.couples(id) on delete cascade,
  day       date not null,                       -- UTC day
  count     int  not null default 0,
  primary key (couple_id, day)
);
alter table public.web_search_usage enable row level security;
-- Intentionally NO policies.
revoke all on public.web_search_usage from anon, authenticated;

create or replace function public.consume_web_search()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c_limit  constant int := 10;                   -- searches per couple per UTC day
  v_couple uuid;
  v_day    date := (now() at time zone 'utc')::date;
  v_count  int;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  v_couple := public.current_couple_id();
  if v_couple is null then
    return jsonb_build_object('ok', false, 'reason', 'not_linked');
  end if;

  -- Atomic increment, but never past the limit.
  insert into public.web_search_usage as u (couple_id, day, count)
  values (v_couple, v_day, 1)
  on conflict (couple_id, day) do update
    set count = u.count + 1
    where u.count < c_limit
  returning u.count into v_count;

  if v_count is null then                         -- conflict row was at the limit
    return jsonb_build_object('ok', false, 'reason', 'daily_limit', 'limit', c_limit);
  end if;
  return jsonb_build_object('ok', true, 'used', v_count, 'limit', c_limit);
end;
$$;

revoke all on function public.consume_web_search() from public, anon;
grant execute on function public.consume_web_search() to authenticated;

-- Optional housekeeping (read-only check / old-row cleanup):
-- select * from public.web_search_usage order by day desc limit 20;
-- delete from public.web_search_usage where day < (now() at time zone 'utc')::date - 30;
-- To change the cap: edit c_limit above and re-run this file.
