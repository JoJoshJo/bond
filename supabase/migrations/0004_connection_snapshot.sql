-- ============================================================
-- 0004 — get_connection_snapshot(): the couple's derived connection stats.
--
-- The client calls this RPC (creature_repository.dart + insights_repository.dart)
-- but it was never deployed, so the creature is frozen at the neutral fallback
-- (content / hatchling / flame 0). This defines it.
--
-- ONE function serves BOTH consumers:
--   - CreatureRepository reads bond_score, last_connected_at, active_days_7.
--   - InsightsRepository reads bond_score, active_days_7, relationship_start_date,
--     days_together, memories_count, prompts_answered, games_played,
--     messages_count.
-- Extra columns are ignored by whichever caller doesn't need them.
--
-- Resolves the CALLER's couple from auth.uid() via couple_members (never a
-- parameter). SECURITY DEFINER so it can read the couple's rows regardless of
-- the caller's row-level scope, but it only ever reports the caller's OWN couple.
--
-- bond_score = messages (1 each, capped 10/calendar-day)
--            + prompt_responses (5 each)
--            + completed game_sessions (5 each)
--            + memories (3 each);  clamped >= 0.
-- last_connected_at = most recent activity timestamp across those sources.
-- active_days_7 = distinct calendar days (UTC) with any activity in the last 7d.
--
-- NOTE for review: day bucketing uses UTC (date_trunc('day', ts)); the couple's
-- home_timezone is not applied here. Fine for the mood thresholds; say if you
-- want tz-aware buckets. `messages_count` is the RAW total (uncapped); the cap
-- only applies to the bond_score contribution. `games_played` counts COMPLETED
-- sessions (matches the scoring).
-- ============================================================

-- ------------------------------------------------------------
-- STATEMENT 1 — the function
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- STATEMENT 2 — grant
-- ------------------------------------------------------------
grant execute on function public.get_connection_snapshot() to authenticated;
