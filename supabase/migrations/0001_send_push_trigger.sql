-- ============================================================
-- send-push wiring: notify the OTHER partner on a new chat message.
--
-- On INSERT into public.messages, a trigger POSTs the new row to the deployed
-- `send-push` Edge Function via pg_net (async / fire-and-forget, so it never
-- blocks the insert). The function decides the recipient and sends FCM.
--
-- MANUAL PREREQUISITE (one-time, NOT in this migration — no secret lives here):
--   The trigger reads the webhook shared-secret from Supabase Vault. Store the
--   SAME value that is set in the `SEND_PUSH_SECRET` Edge Function secret:
--
--     create extension if not exists supabase_vault with schema vault;
--     select vault.create_secret('<hex value>', 'send_push_secret',
--                                'x-webhook-secret for the send-push trigger');
--
--   The function below references that secret BY NAME only ('send_push_secret').
--
-- Requires: pg_net enabled (net.http_post). send-push deployed with verify_jwt OFF.
-- ============================================================

-- Statement 1 — trigger function (reads the secret from Vault at runtime).
create or replace function public.notify_send_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, net, vault
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
    from vault.decrypted_secrets
    where name = 'send_push_secret';

  perform net.http_post(
    url     := 'https://hzvxqafbcxpncuuukrpd.supabase.co/functions/v1/send-push',
    body    := jsonb_build_object('record', to_jsonb(NEW)),
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-webhook-secret', coalesce(v_secret, '')
               )
  );
  return NEW;
end;
$$;

-- Statement 2 — fire it on every new message.
create trigger trg_messages_send_push
  after insert on public.messages
  for each row execute function public.notify_send_push();
