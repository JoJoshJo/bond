-- ============================================================
-- 0012 — CHECK constraints capping user-entered text, matching
-- lib/shared/utils/input_limits.dart.
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
-- Usora — M9: length caps on user text, enforced in the DATABASE.
-- The app now stops typing at the same limits; these CHECKs are what a
-- modified client or a direct API call can't get past.
--
-- Limits (must match lib/shared/utils/input_limits.dart):
--   messages.content            2000
--   prompt_responses.response   2000
--   important_dates.label        100
--   important_dates.note         500
--   memories.caption             500
--   couples.name                  50
--   users.display_name            50
--
-- NULLs always pass (char_length(null) is null → the CHECK is not violated).
--
-- RUN SECTION 1 FIRST. If any count is > 0, DO NOT run that constraint yet —
-- tell me and we'll decide (trim the rows, raise the cap, or add the
-- constraint as NOT VALID so it only applies to new/updated rows).
-- Safe to re-run: each constraint is dropped first.
-- ============================================================

-- ------------------------------------------------------------
-- SECTION 1 — pre-check: existing rows that would FAIL. Expect all zeros.
-- ------------------------------------------------------------
select 'messages.content > 2000'          as col, count(*) from public.messages          where char_length(content) > 2000
union all select 'prompt_responses.response > 2000', count(*) from public.prompt_responses where char_length(response) > 2000
union all select 'important_dates.label > 100',      count(*) from public.important_dates  where char_length(label) > 100
union all select 'important_dates.note > 500',       count(*) from public.important_dates  where char_length(note) > 500
union all select 'memories.caption > 500',           count(*) from public.memories         where char_length(caption) > 500
union all select 'couples.name > 50',                count(*) from public.couples          where char_length(name) > 50
union all select 'users.display_name > 50',          count(*) from public.users            where char_length(display_name) > 50;

-- Longest current value per column, for context:
select max(char_length(content)) as max_message from public.messages;
select max(char_length(response)) as max_prompt_answer from public.prompt_responses;
select max(char_length(label)) as max_event_title, max(char_length(note)) as max_event_note from public.important_dates;
select max(char_length(caption)) as max_caption from public.memories;
select max(char_length(name)) as max_couple_name from public.couples;
select max(char_length(display_name)) as max_display_name from public.users;

-- ------------------------------------------------------------
-- SECTION 2 — the constraints (run once SECTION 1 is all zeros).
-- ------------------------------------------------------------
alter table public.messages          drop constraint if exists messages_content_len;
alter table public.messages          add  constraint messages_content_len
  check (char_length(content) <= 2000);

alter table public.prompt_responses  drop constraint if exists prompt_responses_response_len;
alter table public.prompt_responses  add  constraint prompt_responses_response_len
  check (char_length(response) <= 2000);

alter table public.important_dates   drop constraint if exists important_dates_label_len;
alter table public.important_dates   add  constraint important_dates_label_len
  check (char_length(label) <= 100);

alter table public.important_dates   drop constraint if exists important_dates_note_len;
alter table public.important_dates   add  constraint important_dates_note_len
  check (char_length(note) <= 500);

alter table public.memories          drop constraint if exists memories_caption_len;
alter table public.memories          add  constraint memories_caption_len
  check (char_length(caption) <= 500);

alter table public.couples           drop constraint if exists couples_name_len;
alter table public.couples           add  constraint couples_name_len
  check (char_length(name) <= 50);

alter table public.users             drop constraint if exists users_display_name_len;
alter table public.users             add  constraint users_display_name_len
  check (char_length(display_name) <= 50);

-- ------------------------------------------------------------
-- SECTION 3 — verify the constraints exist.
-- ------------------------------------------------------------
select rel.relname as table_name, con.conname, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace n on n.oid = rel.relnamespace
where n.nspname = 'public' and con.contype = 'c' and con.conname like '%_len'
order by 1, 2;

-- ------------------------------------------------------------
-- If SECTION 1 showed over-length rows, use this form instead for that column
-- (applies to new and updated rows only; existing rows are left alone):
--   alter table public.<t> add constraint <t>_<c>_len check (char_length(<c>) <= N) not valid;
-- and later, after cleaning the data:
--   alter table public.<t> validate constraint <t>_<c>_len;
-- ------------------------------------------------------------
