-- ============================================================
-- Account deletion — DB cleanup (Apple Guideline 5.1.1(v)).
--
-- purge_couple_and_user_data(): SECURITY DEFINER, resolves the CALLER from
-- auth.uid() (never a parameter). Called by the `delete-account` Edge Function
-- with the caller's JWT, so auth.uid() = the deleting user. It:
--   - deletes the couple's shared data (the space is CLOSED on deletion),
--   - removes BOTH couple_members rows so the partner is freed to re-invite
--     (their getMyMembership -> null -> CreateOrJoinScreen),
--   - marks the couple `winding_down` (closed tombstone),
--   - deletes the deleting user's own user-scoped rows + their public.users row.
-- It does NOT touch auth.users — the Edge Function does that via the Auth Admin
-- API after this returns. Runs in one transaction (atomic: all-or-nothing).
--
-- Join-scoped children (message_reactions, prompt_responses, game_moves) use
-- subquery deletes so they're removed whether or not FK cascades exist.
--
-- NOTE for review: `mood_checkins` and `calendar_links` are in SCHEMA.md but I
-- could not verify they exist in the live DB. If either is not actually created,
-- remove its delete line before running (a missing table errors at call time).
-- ============================================================

create or replace function public.purge_couple_and_user_data()
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_uid    uuid := auth.uid();
  v_couple uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select couple_id into v_couple
  from couple_members where user_id = v_uid limit 1;

  if v_couple is not null then
    -- Couple-scoped children first, then parents.
    delete from message_reactions
      where message_id in (select id from messages where couple_id = v_couple);
    delete from messages where couple_id = v_couple;

    delete from prompt_responses
      where prompt_id in (select id from prompts where couple_id = v_couple);
    delete from prompts where couple_id = v_couple;

    delete from game_moves
      where session_id in (select id from game_sessions where couple_id = v_couple);
    delete from game_sessions where couple_id = v_couple;

    delete from memories        where couple_id = v_couple;
    delete from important_dates  where couple_id = v_couple;
    delete from mood_checkins    where couple_id = v_couple;
    delete from spicy_mode       where couple_id = v_couple;
    delete from subscriptions    where couple_id = v_couple;
    delete from couple_invites   where couple_id = v_couple;

    -- Free BOTH partners and close the shared space.
    delete from couple_members where couple_id = v_couple;
    update couples
      set status = 'winding_down', breakup_initiated_by = null
      where id = v_couple;
  end if;

  -- The deleting user's own user-scoped rows (partner keeps theirs).
  delete from notification_prefs where user_id = v_uid;
  delete from calendar_links     where user_id = v_uid;
  -- Defensive: any stray user-authored rows not tied to the couple above.
  delete from message_reactions  where user_id = v_uid;
  delete from prompt_responses   where user_id = v_uid;
  delete from game_moves         where user_id = v_uid;

  -- Public profile row (auth.users itself is deleted by the Edge Function next).
  delete from public.users where id = v_uid;
end;
$$;

grant execute on function public.purge_couple_and_user_data() to authenticated;
