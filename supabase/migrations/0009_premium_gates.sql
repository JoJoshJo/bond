-- ============================================================
-- 0009 — Usora+ enforced in the DB: couple_has_plus() helper, the 30-memory free cap
-- trigger, and premium-checked write policies on important_dates.
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
-- Usora — M2: enforce Usora+ at the DATABASE, not just in the app.
-- Run AFTER 01_ai_call_cap.sql (order between these two doesn't matter, but
-- this file must run BEFORE you rely on the gates).
--
-- Premium = the couple's subscriptions row is bond_plus + active + unexpired —
-- the SAME rule the app (SubscriptionRepository) and the ai-router use.
-- Safe to re-run.
-- ============================================================

-- ---------- 0. Shared premium helper ----------
-- SECURITY DEFINER so it can read `subscriptions` from inside policies and
-- triggers regardless of the caller's own read rights. It takes a couple_id so
-- the memory trigger can check the row being inserted.
create or replace function public.couple_has_plus(p_couple uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.subscriptions s
    where s.couple_id = p_couple
      and s.entitlement = 'bond_plus'
      and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  );
$$;
revoke all on function public.couple_has_plus(uuid) from public, anon;
grant execute on function public.couple_has_plus(uuid) to authenticated;

-- ---------- 1. Free vault cap: 30 memories (matches kFreeMemoryCap) ----------
create or replace function public.enforce_memory_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  c_free_cap constant int := 30;
  v_count int;
begin
  if public.couple_has_plus(new.couple_id) then
    return new;                                   -- Usora+ = unlimited
  end if;
  select count(*) into v_count from public.memories where couple_id = new.couple_id;
  if v_count >= c_free_cap then
    raise exception 'memory_cap_reached'
      using errcode = 'P0001',
            hint = 'Free vaults hold 30 memories. Usora+ is unlimited.';
  end if;
  return new;
end;
$$;

drop trigger if exists memories_free_cap on public.memories;
create trigger memories_free_cap
  before insert on public.memories
  for each row execute function public.enforce_memory_cap();

-- ---------- 2. Calendar writes are Usora+ (reads stay free) ----------
-- Drops ONLY the existing INSERT/UPDATE/DELETE policies on important_dates
-- (whatever they are named) and recreates them as couple-scoped AND premium.
-- The SELECT policy is left exactly as it is, so a lapsed couple still SEES
-- their events but can't add, edit or delete.
do $$
declare r record;
begin
  for r in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'important_dates'
      and cmd in ('INSERT', 'UPDATE', 'DELETE')
  loop
    execute format('drop policy %I on public.important_dates', r.policyname);
  end loop;
end $$;

create policy "important_dates insert own couple plus" on public.important_dates
  for insert to authenticated
  with check (couple_id = public.current_couple_id() and public.couple_has_plus(couple_id));

create policy "important_dates update own couple plus" on public.important_dates
  for update to authenticated
  using (couple_id = public.current_couple_id() and public.couple_has_plus(couple_id))
  with check (couple_id = public.current_couple_id() and public.couple_has_plus(couple_id));

create policy "important_dates delete own couple plus" on public.important_dates
  for delete to authenticated
  using (couple_id = public.current_couple_id() and public.couple_has_plus(couple_id));

notify pgrst, 'reload schema';

-- ---------- Verify ----------
-- Policies: SELECT untouched, the three write policies premium-checked.
select policyname, cmd, qual, with_check from pg_policies
where schemaname = 'public' and tablename = 'important_dates' order by cmd;
-- Trigger present:
select trigger_name, action_timing, event_manipulation
from information_schema.triggers
where trigger_schema = 'public' and event_object_table = 'memories';
