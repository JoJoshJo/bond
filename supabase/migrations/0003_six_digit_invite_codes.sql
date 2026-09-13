-- ============================================================
-- 0003 — Switch couple invite tokens from 32-char hex to unique 6-digit codes.
--
-- Run in the Supabase dashboard ONE STATEMENT AT A TIME.
--
-- ONLY the token generation changes. Everything else in create_couple /
-- join_couple / regenerate_invite is preserved EXACTLY as the live functions:
--   - create_couple keeps the home_timezone copy from users and the 4-column
--     RETURNS TABLE(couple_id, invite_token, couple_name, expires_at).
--   - join_couple keeps its exact guards and the reason pattern that returns the
--     raw token_status on a bad status (the Dart error dialogs depend on it);
--     the ONLY change is defensive digit-stripping of p_token at the top.
--   - regenerate_invite keeps its RETURNS TABLE(invite_token, expires_at).
-- SECURITY DEFINER and the same `set search_path` are preserved on all three.
-- ============================================================

-- ------------------------------------------------------------
-- STATEMENT 1 — helper: a 6-digit code not already present in couple_invites.
-- (Global uniqueness against every stored token means the existing
-- `token UNIQUE` constraint can never be violated — no collision handling
-- needed in the callers.)
-- ------------------------------------------------------------
create or replace function public._gen_invite_code()
returns text
language plpgsql
as $$
declare
  v_code text;
  i int := 0;
begin
  loop
    i := i + 1;
    v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
    exit when not exists (
      select 1 from couple_invites where token = v_code
    );
    if i > 100 then
      raise exception 'code_generation_failed';
    end if;
  end loop;
  return v_code;
end;
$$;

-- ------------------------------------------------------------
-- STATEMENT 2 — create_couple
-- Live function, unchanged EXCEPT the token line (hex → _gen_invite_code()).
-- home_timezone copy and RETURNS TABLE(couple_id, invite_token, couple_name,
-- expires_at) preserved exactly.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_couple(p_name text)
 RETURNS TABLE(couple_id uuid, invite_token text, couple_name text, expires_at timestamp with time zone)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','auth','extensions'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_couple_id uuid;
  v_token text;
  v_exp timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if exists (select 1 from couple_members where user_id = v_uid) then
    raise exception 'already_in_couple';
  end if;
  insert into couples (name, status, home_timezone)
    values (p_name, 'pending', (select home_timezone from users where id = v_uid))
    returning id into v_couple_id;
  insert into couple_members (couple_id, user_id) values (v_couple_id, v_uid);
  v_token := public._gen_invite_code();
  v_exp   := now() + interval '48 hours';
  insert into couple_invites (couple_id, token, token_status, expires_at)
    values (v_couple_id, v_token, 'active', v_exp);
  return query select v_couple_id, v_token, p_name, v_exp;
end; $function$;

-- ------------------------------------------------------------
-- STATEMENT 3 — join_couple
-- Live function, unchanged EXCEPT: v_code strips non-digits from p_token, and
-- the invite lookup matches on v_code. The raw-token_status reason pattern and
-- every other guard are preserved exactly.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_couple(p_token text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','auth','extensions'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_code text := regexp_replace(coalesce(p_token, ''), '\D', '', 'g');
  v_invite couple_invites;
  v_couple couples;
  v_member_count int;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'reason', 'not_authenticated'); end if;
  if exists (select 1 from couple_members where user_id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'already_in_couple');
  end if;
  select * into v_invite from couple_invites where token = v_code for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if v_invite.token_status = 'active' and v_invite.expires_at <= now() then
    update couple_invites set token_status = 'expired' where id = v_invite.id;
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;
  if v_invite.token_status <> 'active' then
    return jsonb_build_object('ok', false, 'reason', v_invite.token_status);
  end if;
  select * into v_couple from couples where id = v_invite.couple_id for update;
  if not found or v_couple.status <> 'pending' then
    return jsonb_build_object('ok', false, 'reason', 'already_complete');
  end if;
  select count(*) into v_member_count from couple_members where couple_id = v_couple.id;
  if v_member_count <> 1 then return jsonb_build_object('ok', false, 'reason', 'already_complete'); end if;
  insert into couple_members (couple_id, user_id) values (v_couple.id, v_uid);
  update couples        set status = 'active'        where id = v_couple.id;
  update couple_invites set token_status = 'consumed' where id = v_invite.id;
  return jsonb_build_object('ok', true, 'couple_id', v_couple.id);
end; $function$;

-- ------------------------------------------------------------
-- STATEMENT 4 — regenerate_invite
-- Live function, unchanged EXCEPT the token line (hex → _gen_invite_code()).
-- RETURNS TABLE(invite_token, expires_at) preserved exactly.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.regenerate_invite()
 RETURNS TABLE(invite_token text, expires_at timestamp with time zone)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','auth','extensions'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_couple_id uuid;
  v_status text;
  v_token text;
  v_exp timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select cm.couple_id, c.status into v_couple_id, v_status
  from couple_members cm join couples c on c.id = cm.couple_id
  where cm.user_id = v_uid;
  if v_couple_id is null then raise exception 'not_in_couple'; end if;
  if v_status <> 'pending' then raise exception 'couple_not_pending'; end if;
  update couple_invites set token_status = 'revoked'
    where couple_id = v_couple_id and token_status = 'active';
  v_token := public._gen_invite_code();
  v_exp   := now() + interval '48 hours';
  insert into couple_invites (couple_id, token, token_status, expires_at)
    values (v_couple_id, v_token, 'active', v_exp);
  return query select v_token, v_exp;
end; $function$;

-- ------------------------------------------------------------
-- STATEMENT 5 — grants (match the signatures of the live functions)
-- ------------------------------------------------------------
grant execute on function public._gen_invite_code() to authenticated;
grant execute on function public.create_couple(text) to authenticated;
grant execute on function public.join_couple(text) to authenticated;
grant execute on function public.regenerate_invite() to authenticated;
