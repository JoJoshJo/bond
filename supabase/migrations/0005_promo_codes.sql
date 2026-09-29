-- ============================================================
-- 0005 — Promo-code redemption: promo_codes + promo_redemptions tables and the
-- SECURITY DEFINER redeem_promo_code() that grants 30 days of Usora+.
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
-- Usora — promo-code redemption (run in the Supabase SQL editor, in order).
-- Grants Usora+ SERVER-SIDE only: the app sends just the code text; this
-- SECURITY DEFINER function validates it and writes `subscriptions`, which
-- clients cannot write (RLS: SELECT-only policy).
-- Safe to re-run: tables/policies use IF NOT EXISTS / OR REPLACE, the seed
-- uses ON CONFLICT DO NOTHING.
-- ============================================================

-- ---------- 1. promo_codes (only the function touches it) ----------
create table if not exists public.promo_codes (
  code                text primary key check (code = upper(btrim(code)) and length(code) between 4 and 64),
  active              boolean not null default true,
  expires_at          timestamptz not null,                 -- the CODE's own expiry
  grant_duration_days int not null default 30 check (grant_duration_days between 1 and 365),
  max_redemptions     int null check (max_redemptions is null or max_redemptions > 0),
  redemption_count    int not null default 0,
  note                text,
  created_at          timestamptz not null default now()
);
alter table public.promo_codes enable row level security;
-- Intentionally NO policies: clients can't list, read, or modify codes.
revoke all on public.promo_codes from anon, authenticated;

-- ---------- 2. promo_redemptions (one grant per couple per code) ----------
create table if not exists public.promo_redemptions (
  id            uuid primary key default gen_random_uuid(),
  code          text not null references public.promo_codes(code) on delete cascade,
  couple_id     uuid not null references public.couples(id) on delete cascade,
  redeemed_by   uuid not null,
  redeemed_at   timestamptz not null default now(),
  granted_until timestamptz not null,
  unique (code, couple_id)
);
alter table public.promo_redemptions enable row level security;
-- Intentionally NO policies.
revoke all on public.promo_redemptions from anon, authenticated;

-- ---------- 3. redeem_promo_code ----------
create or replace function public.redeem_promo_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_couple  uuid;
  v_code    text := upper(btrim(coalesce(p_code, '')));
  v_promo   public.promo_codes%rowtype;
  v_sub     public.subscriptions%rowtype;
  v_until   timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_linked');
  end if;

  -- Same couple resolution the existing RLS policies use.
  v_couple := public.current_couple_id();
  if v_couple is null then
    return jsonb_build_object('ok', false, 'reason', 'not_linked');
  end if;

  if length(v_code) = 0 or length(v_code) > 64 then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  -- Lock the code row so concurrent redemptions serialize.
  select * into v_promo from public.promo_codes where code = v_code for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  if not v_promo.active then
    return jsonb_build_object('ok', false, 'reason', 'inactive');
  end if;
  if v_promo.expires_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;
  if v_promo.max_redemptions is not null
     and v_promo.redemption_count >= v_promo.max_redemptions then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;
  if exists (select 1 from public.promo_redemptions
             where code = v_code and couple_id = v_couple) then
    return jsonb_build_object('ok', false, 'reason', 'already_redeemed');
  end if;

  -- Duration ALWAYS comes from the code row, never from the client.
  v_until := now() + make_interval(days => v_promo.grant_duration_days);

  -- Never shorten a longer (e.g. paid) active subscription.
  select * into v_sub from public.subscriptions where couple_id = v_couple for update;
  if found
     and v_sub.entitlement = 'bond_plus'
     and v_sub.status = 'active'
     and (v_sub.expires_at is null or v_sub.expires_at >= v_until) then
    return jsonb_build_object('ok', false, 'reason', 'already_premium',
                              'expires_at', v_sub.expires_at);
  end if;

  begin
    insert into public.subscriptions
      (couple_id, entitlement, status, expires_at, revenuecat_id, updated_at)
    values
      (v_couple, 'bond_plus', 'active', v_until, 'promo:' || v_code, now())
    on conflict (couple_id) do update
      set entitlement   = excluded.entitlement,
          status        = excluded.status,
          expires_at    = excluded.expires_at,
          revenuecat_id = excluded.revenuecat_id,
          updated_at    = excluded.updated_at;

    insert into public.promo_redemptions (code, couple_id, redeemed_by, granted_until)
    values (v_code, v_couple, v_uid, v_until);

    update public.promo_codes
       set redemption_count = redemption_count + 1
     where code = v_code;
  exception when unique_violation then
    -- Partner redeemed at the same instant: this sub-block is rolled back.
    return jsonb_build_object('ok', false, 'reason', 'already_redeemed');
  end;

  return jsonb_build_object('ok', true, 'expires_at', v_until,
                            'days', v_promo.grant_duration_days);
end;
$$;

revoke all on function public.redeem_promo_code(text) from public, anon;
grant execute on function public.redeem_promo_code(text) to authenticated;

-- ---------- 4. seed the shared code ----------
insert into public.promo_codes (code, active, expires_at, grant_duration_days, max_redemptions, note)
values ('USORACE2026', true, '2026-10-20 23:59:00+00', 30, null, 'Testers / judges')
on conflict (code) do nothing;

-- ---------- 5. (optional) sanity checks, read-only ----------
-- select code, active, expires_at, grant_duration_days, redemption_count from public.promo_codes;
-- select polname, cmd from pg_policies where tablename in ('promo_codes','promo_redemptions','subscriptions');
--
-- Later: change the code's expiry / switch it off
-- update public.promo_codes set expires_at = '2026-11-30 23:59:00+00' where code = 'USORACE2026';
-- update public.promo_codes set active = false where code = 'USORACE2026';
