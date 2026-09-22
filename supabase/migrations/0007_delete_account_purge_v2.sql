-- ============================================================
-- 0007 — Account deletion, full coverage: replaces purge_couple_and_user_data() so it
-- clears every couple/user table, deletes the couples row (no tombstone) and
-- skips tables that do not exist. Supersedes the purge in 0002.
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
-- Usora — account deletion, DB cleanup (Apple Guideline 5.1.1(v)).  v2
--
-- FIXES the live error:
--   purge failed: 404 PGRST202 "Searched for the function
--   public.purge_couple_and_user_data without parameters ... no matches"
-- i.e. the function is missing from the schema (an earlier DROP succeeded but
-- the CREATE did not — `create or replace` CANNOT change a function's return
-- type, so replacing the old `returns void` with `returns uuid` fails unless
-- the old one is dropped first), or PostgREST's schema cache is stale.
--
-- This file is self-contained and idempotent:
--   * drops BOTH possible signatures first,
--   * recreates it with the ORIGINAL contract: no parameters, RETURNS VOID —
--     the Edge Function ignores the return value (it reads couple_id itself
--     before deleting storage), so there is nothing to gain from returning it
--     and no signature to drift again,
--   * reloads the PostgREST schema cache at the end.
--
-- Deletion coverage is unchanged from v1: every couple/user table (guarded with
-- to_regclass so a missing optional table can't abort it), the couples row
-- itself (no tombstone, no leftover name / start date / persona), and identity
-- taken only from auth.uid(). One transaction: all-or-nothing.
--
-- Run this WHOLE file in the SQL editor. The Edge Function needs NO change.
-- ============================================================

-- 1. Remove any existing version (either return type).
drop function if exists public.purge_couple_and_user_data();

-- 2. Recreate: no parameters, returns void.
create function public.purge_couple_and_user_data()
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_uid    uuid := auth.uid();
  v_couple uuid;
  t        text;
  -- Couple-scoped tables, children BEFORE parents.
  couple_tables constant text[] := array[
    'message_reactions', 'messages',
    'prompt_response_reactions', 'prompt_responses', 'prompts',
    'game_moves', 'game_sessions',
    'memories', 'important_dates', 'mood_checkins', 'spicy_mode',
    'subscriptions', 'promo_redemptions', 'web_search_usage',
    'couple_invites', 'calendar_links', 'notification_prefs',
    'couple_members'
  ];
  -- User-scoped leftovers (the partner keeps their own).
  user_tables constant text[] := array[
    'notification_prefs', 'calendar_links',
    'message_reactions', 'prompt_response_reactions', 'prompt_responses', 'game_moves'
  ];
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select couple_id into v_couple
  from couple_members where user_id = v_uid limit 1;

  if v_couple is not null then
    -- Join-scoped children first: these tables may key off the parent, not the
    -- couple, so delete by parent id. Each is skipped if the table is absent.
    if to_regclass('public.message_reactions') is not null then
      delete from message_reactions
        where message_id in (select id from messages where couple_id = v_couple);
    end if;
    if to_regclass('public.prompt_response_reactions') is not null then
      delete from prompt_response_reactions
        where response_id in (
          select r.id from prompt_responses r
          join prompts p on p.id = r.prompt_id
          where p.couple_id = v_couple);
    end if;
    if to_regclass('public.prompt_responses') is not null then
      delete from prompt_responses
        where prompt_id in (select id from prompts where couple_id = v_couple);
    end if;
    if to_regclass('public.game_moves') is not null then
      delete from game_moves
        where session_id in (select id from game_sessions where couple_id = v_couple);
    end if;

    -- Everything with a couple_id column.
    foreach t in array couple_tables loop
      if to_regclass('public.' || t) is not null
         and exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = t
                       and column_name = 'couple_id') then
        execute format('delete from public.%I where couple_id = $1', t) using v_couple;
      end if;
    end loop;

    -- The shared space itself: fully deleted, so no name / start date /
    -- persona survives. Safe now that every child row above is gone.
    delete from couples where id = v_couple;
  end if;

  -- The deleting user's own rows (by user_id), wherever such a column exists.
  foreach t in array user_tables loop
    if to_regclass('public.' || t) is not null
       and exists (select 1 from information_schema.columns
                   where table_schema = 'public' and table_name = t
                     and column_name = 'user_id') then
      execute format('delete from public.%I where user_id = $1', t) using v_uid;
    end if;
  end loop;

  -- Public profile row (auth.users is deleted by the Edge Function next).
  delete from public.users where id = v_uid;
end;
$$;

revoke all on function public.purge_couple_and_user_data() from public, anon;
grant execute on function public.purge_couple_and_user_data() to authenticated;

-- 3. Make PostgREST pick the function up immediately (fixes PGRST202 caching).
notify pgrst, 'reload schema';

-- ---------- 4. Verify (expect exactly one row: prosecdef = t) ----------
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       pg_get_function_result(p.oid)             as returns,
       p.prosecdef                               as security_definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_run
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'purge_couple_and_user_data';

-- Optional coverage check — every table with a couple_id / user_id column
-- should be handled above:
-- select table_name from information_schema.columns
-- where table_schema='public' and column_name='couple_id' order by 1;
-- select table_name from information_schema.columns
-- where table_schema='public' and column_name='user_id' order by 1;
