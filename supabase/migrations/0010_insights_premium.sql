-- ============================================================
-- 0010 — Insights behind Usora+: get_connection_snapshot() from 0004 plus a
-- couple_has_plus() guard. Supersedes the function body in 0004.
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
-- Usora — M2 (3/3): Insights behind Usora+.
-- Run AFTER 02_premium_helper_and_gates.sql (it needs couple_has_plus()).
--
-- This is the EXISTING get_connection_snapshot() from migration 0004 with ONE
-- addition: a premium check placed AFTER the couple lookup (so an unlinked user
-- still gets the neutral empty row) and BEFORE any stats are computed.
-- Nothing else in the function is changed.
--
-- BEFORE RUNNING, confirm the live function matches the repo version so this
-- replace can't drop a later edit:
--   select prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public' and p.proname = 'get_connection_snapshot';
-- If the live body differs, paste ONLY the `if not public.couple_has_plus(...)`
-- block below into your live version instead of running this whole file.
-- ============================================================

create or replace function public.get_connection_snapshot()
returns table(
  bond_score integer,
  last_connected_at timestamptz,
  active_days_7 integer,
  relationship_start_date date,
  days_together integer,
  memories_count integer,
  prompts_answered integer,
  games_played integer,
  messages_count integer
)
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_uid    uuid := auth.uid();
  v_couple uuid;
  v_start  date;
  v_msg_pts    integer := 0;
  v_prompt_cnt integer := 0;
  v_game_cnt   integer := 0;
  v_mem_cnt    integer := 0;
  v_msg_cnt    integer := 0;
  v_score      integer := 0;
  v_last       timestamptz;
  v_active     integer := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select couple_id into v_couple
  from couple_members where user_id = v_uid limit 1;

  -- No couple yet: return a single neutral row (client reads rows.first).
  if v_couple is null then
    return query select 0, null::timestamptz, 0, null::date, null::integer,
                        0, 0, 0, 0;
    return;
  end if;

  -- Usora+ gate: Insights is a paid feature (it is listed on the paywall).
  -- Free couples get nothing to render, which also stops the free AI
  -- reflection the app writes over these stats.
  if not public.couple_has_plus(v_couple) then
    raise exception 'usora_plus_required'
      using errcode = 'P0001', hint = 'Insights is part of Usora+.';
  end if;

  select relationship_start_date into v_start from couples where id = v_couple;

  -- messages: 1 pt each, capped at 10 per calendar day (UTC); raw total too.
  select coalesce(sum(least(daily, 10)), 0), coalesce(sum(daily), 0)
    into v_msg_pts, v_msg_cnt
  from (
    select count(*)::int as daily
    from messages
    where couple_id = v_couple
    group by date_trunc('day', created_at)
  ) m;

  -- prompt_responses: 5 pts each (join prompts for the couple).
  select coalesce(count(*), 0)
    into v_prompt_cnt
  from prompt_responses pr
  join prompts p on p.id = pr.prompt_id
  where p.couple_id = v_couple;

  -- completed games: 5 pts each.
  select coalesce(count(*), 0)
    into v_game_cnt
  from game_sessions
  where couple_id = v_couple and status = 'completed';

  -- memories: 3 pts each.
  select coalesce(count(*), 0)
    into v_mem_cnt
  from memories
  where couple_id = v_couple;

  v_score := greatest(
    v_msg_pts + (v_prompt_cnt * 5) + (v_game_cnt * 5) + (v_mem_cnt * 3), 0);

  -- last activity across all sources.
  select max(ts) into v_last from (
    select max(created_at) as ts from messages where couple_id = v_couple
    union all
    select max(pr.answered_at) from prompt_responses pr
      join prompts p on p.id = pr.prompt_id where p.couple_id = v_couple
    union all
    select max(coalesce(ended_at, started_at)) from game_sessions
      where couple_id = v_couple and status = 'completed'
    union all
    select max(created_at) from memories where couple_id = v_couple
  ) t;

  -- distinct active days in the last 7 days (UTC day buckets).
  select count(distinct d) into v_active from (
    select date_trunc('day', created_at) as d from messages
      where couple_id = v_couple and created_at >= now() - interval '7 days'
    union
    select date_trunc('day', pr.answered_at) from prompt_responses pr
      join prompts p on p.id = pr.prompt_id
      where p.couple_id = v_couple and pr.answered_at >= now() - interval '7 days'
    union
    select date_trunc('day', coalesce(ended_at, started_at)) from game_sessions
      where couple_id = v_couple and status = 'completed'
        and coalesce(ended_at, started_at) >= now() - interval '7 days'
    union
    select date_trunc('day', created_at) from memories
      where couple_id = v_couple and created_at >= now() - interval '7 days'
  ) days;

  return query select
    v_score,
    v_last,
    v_active,
    v_start,
    case when v_start is null then null
         else greatest((current_date - v_start), 0) end,
    v_mem_cnt,
    v_prompt_cnt,
    v_game_cnt,
    v_msg_cnt;
end;
$$;

notify pgrst, 'reload schema';

-- Verify: free couple → error 'usora_plus_required'; bond_plus couple → 1 row.
-- select * from public.get_connection_snapshot();
