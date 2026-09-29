-- ============================================================
-- 0011 — Invite-code brute-force protection: join_attempts ledger, a per-code failure
-- counter, and attempt limits inside join_couple(). Supersedes join_couple in 0003.
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
-- Usora — M1: make invite-code brute force infeasible (SQL ONLY).
--
-- Codes stay EXACTLY as they are: 6-digit numeric, 48h expiry, single-use.
-- The app needs NO changes. What changes is join_couple(): failed attempts are
-- counted server-side and guessing is locked out.
--
--   * 5 failed attempts per USER per 15 minutes  -> 'too_many_attempts'
--   * 10 failed attempts against ONE CODE        -> that code is revoked
--   * a successful join clears the user's counter
--
-- A failure = a code that could not be used (invalid / expired / revoked /
-- consumed / the couple is no longer joinable). 'not_authenticated' and
-- 'already_in_couple' are NOT failures — they are the caller's own state.
--
-- Identity still comes from auth.uid() only. Single-use consume, pending-couple
-- and exactly-one-member guards, and the raw token_status reason pattern the
-- Dart dialogs depend on, are all preserved from migration 0003.
--
-- join_couple(text) returns jsonb — the signature is UNCHANGED, so
-- `create or replace` is enough: no DROP needed.
-- Safe to re-run.
-- ============================================================

-- ---------- 1. Attempt ledger (server-only) ----------
create table if not exists public.join_attempts (
  user_id      uuid primary key,
  window_start timestamptz not null default now(),
  fails        int not null default 0
);
alter table public.join_attempts enable row level security;
-- Intentionally NO policies: the app can neither read nor reset its counter.
revoke all on public.join_attempts from anon, authenticated;

-- Per-code failure counter (additive column; existing invites start at 0).
alter table public.couple_invites
  add column if not exists failed_attempts int not null default 0;

-- ---------- 2. join_couple with attempt limiting ----------
CREATE OR REPLACE FUNCTION public.join_couple(p_token text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','auth','extensions'
AS $function$
declare
  c_user_max     constant int      := 5;                    -- failures per user
  c_user_window  constant interval := interval '15 minutes'; -- ...per this window
  c_code_max     constant int      := 10;                   -- failures per code
  v_uid    uuid := auth.uid();
  v_code   text := regexp_replace(coalesce(p_token, ''), '\D', '', 'g');
  v_invite couple_invites;
  v_couple couples;
  v_member_count int;
  v_fails  int;
  v_reason text;
begin
  -- Caller-state checks: never counted as failed guesses.
  if v_uid is null then return jsonb_build_object('ok', false, 'reason', 'not_authenticated'); end if;
  if exists (select 1 from couple_members where user_id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'already_in_couple');
  end if;

  -- Lockout check + window roll, under a row lock so parallel guesses can't
  -- race past the limit.
  insert into join_attempts (user_id, window_start, fails)
  values (v_uid, now(), 0)
  on conflict (user_id) do nothing;

  select fails into v_fails
  from join_attempts
  where user_id = v_uid and window_start > now() - c_user_window
  for update;

  if found and v_fails >= c_user_max then
    return jsonb_build_object('ok', false, 'reason', 'too_many_attempts');
  end if;
  if not found then                       -- window expired (or first use): reset
    update join_attempts set window_start = now(), fails = 0 where user_id = v_uid;
  end if;

  -- ---- the original join logic, unchanged apart from counting failures ----
  select * into v_invite from couple_invites where token = v_code for update;

  if not found then
    v_reason := 'invalid';
  elsif v_invite.token_status = 'active' and v_invite.expires_at <= now() then
    update couple_invites set token_status = 'expired' where id = v_invite.id;
    v_reason := 'expired';
  elsif v_invite.token_status <> 'active' then
    v_reason := v_invite.token_status;    -- revoked / consumed / expired (raw, as before)
  else
    select * into v_couple from couples where id = v_invite.couple_id for update;
    if not found or v_couple.status <> 'pending' then
      v_reason := 'already_complete';
    else
      select count(*) into v_member_count from couple_members where couple_id = v_couple.id;
      if v_member_count <> 1 then
        v_reason := 'already_complete';
      end if;
    end if;
  end if;

  -- ---- failure path: count it (user + code), maybe revoke the code ----
  if v_reason is not null then
    update join_attempts set fails = fails + 1 where user_id = v_uid;
    if v_invite.id is not null then
      update couple_invites
         set failed_attempts = failed_attempts + 1,
             token_status = case
               when failed_attempts + 1 >= c_code_max and token_status = 'active'
                 then 'revoked' else token_status end
       where id = v_invite.id;
    end if;
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  -- ---- success: join, consume the code, clear the user's counter ----
  insert into couple_members (couple_id, user_id) values (v_couple.id, v_uid);
  update couples        set status = 'active'        where id = v_couple.id;
  update couple_invites set token_status = 'consumed' where id = v_invite.id;
  delete from join_attempts where user_id = v_uid;
  return jsonb_build_object('ok', true, 'couple_id', v_couple.id);
end; $function$;

grant execute on function public.join_couple(text) to authenticated;

notify pgrst, 'reload schema';   -- not strictly needed (same signature), harmless

-- ---------- 3. Verify ----------
select p.proname, pg_get_function_identity_arguments(p.oid) args,
       pg_get_function_result(p.oid) returns, p.prosecdef
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'join_couple';

select relname, relrowsecurity from pg_class where relname = 'join_attempts';
select count(*) as policies_should_be_zero from pg_policies
where schemaname = 'public' and tablename = 'join_attempts';

-- Handy during testing:
-- select * from public.join_attempts;                       -- current lockouts
-- delete from public.join_attempts where user_id = '<uid>';  -- clear a lockout
-- select token, token_status, failed_attempts, expires_at from public.couple_invites
--   order by expires_at desc limit 10;
