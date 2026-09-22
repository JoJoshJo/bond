-- ============================================================
-- 0013 — Members may UPDATE only couples.name and couples.relationship_start_date
-- (column-level grants); bond_score, status, persona and the breakup fields
-- become non-user-writable.
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
-- Usora — H5: members may update ONLY the two columns the app edits.
--
-- Today the `couples update own` RLS policy scopes updates to the caller's own
-- couple but says nothing about WHICH columns, so a member can rewrite
-- bond_score, creature_persona, status, or the breakup fields on their couple.
--
-- Fix: column-level privileges. The RLS policy still decides WHICH ROW;
-- these grants decide WHICH COLUMNS. An update touching anything else fails
-- with 42501 (permission denied for column ...).
--
-- NO APP CHANGES NEEDED — the app only writes name + relationship_start_date.
-- SECURITY DEFINER functions (create_couple, join_couple, regenerate_invite,
-- purge_couple_and_user_data) run as the table owner and are NOT affected.
-- Safe to re-run.
-- ============================================================

-- ---------- 1. Before: what can authenticated do today? ----------
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'couples'
  and grantee in ('anon', 'authenticated')
order by grantee, privilege_type;

-- ---------- 2. Restrict UPDATE to two columns ----------
revoke update on public.couples from authenticated;
grant  update (name, relationship_start_date) on public.couples to authenticated;

-- Leave SELECT as it is (the app reads the row; RLS scopes it to the couple).
-- Anonymous callers should hold nothing here:
revoke all on public.couples from anon;

-- ---------- 3. After: verify ----------
-- Expect: NO table-wide UPDATE row for authenticated...
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'couples'
  and grantee in ('anon', 'authenticated')
order by grantee, privilege_type;

-- ...and exactly two UPDATE columns (plus whatever SELECT columns exist):
select column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'couples'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
order by column_name;

-- The RLS policy is unchanged and still scopes the row:
select policyname, cmd, qual, with_check from pg_policies
where schemaname = 'public' and tablename = 'couples' order by cmd;

-- ---------- Rollback, if ever needed ----------
-- grant update on public.couples to authenticated;
