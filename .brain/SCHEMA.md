# BOND — Unified Database Schema

> The single coherent schema, pulled together from all 9 feature deep-dives in
> FEATURES.md. This is the bridge from thinking to building. Companion to
> BOND_MASTER.md (index) and FEATURES.md (feature specs).
>
> STATUS: design spec, not yet built. When we stand up Layer 1, Claude Code turns
> this into Supabase migrations. This file is the source of truth for that.

**Last updated:** 2026-09-02 (first unified schema)

---

## STRUCTURAL PRINCIPLES (locked — from the scaling research)

1. **Couple = tenant.** Shared tables + a `couple_id` on every couple-owned row.
   Multi-tenant by row isolation, NOT schema-per-couple. Scales to millions of
   small tenants.
2. **RLS on every table, no exceptions.** A user can only ever read/write rows for
   the couple they belong to. Enforced at the DB level so an app bug can't leak
   data. service_role (Edge Functions) bypasses RLS for admin/webhook writes.
3. **Index for how we query.** `couple_id` on everything; `(couple_id, created_at)`
   on anything scrollable (messages, memories, game history).
4. **Media in Storage, URLs in DB.** Never store photo/video blobs in Postgres.
5. **messages is designed partition-ready** (has `created_at`); actually partition
   by time later, only when it crosses tens of millions of rows.
6. **UUID primary keys** everywhere (`gen_random_uuid()`).
7. **Migrations in git**, applied bond-dev → bond-prod.

## HELPER: how RLS knows your couple
A user belongs to exactly one active couple via `couple_members`. RLS policies use a
helper (SQL function or a join) to resolve `auth.uid()` → their `couple_id`, then
gate every couple-owned row by it. (Exact helper written at build time; noted here
so every policy below can assume "current user's couple_id" exists.)

---

## CORE IDENTITY

### users
Extends Supabase `auth.users` (1:1). Auth itself handled by Supabase.
| column | type | notes |
|---|---|---|
| id | uuid PK | = auth.users.id |
| email | text | from auth |
| display_name | text | |
| avatar_url | text | Storage URL |
| home_timezone | text | set at account setup — drives couple shared clock |
| fcm_token | text | refreshed each app open; for push |
| created_at | timestamptz | default now() |
- RLS: a user can read/update only their own row.

### couples  (the tenant root)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| name | text | auto-generated cute name, editable |
| status | text | `pending` \| `active` \| `sealed` \| `winding_down` |
| relationship_start_date | date | |
| bond_score | int | default 0, MONOTONIC — only ever increases |
| creature_persona | jsonb | baby AI: name, look, personality, customization |
| home_timezone | text | the couple's shared clock (from initiator; used for prompts) |
| breakup_initiated_by | uuid FK→users | null unless winding_down |
| breakup_expires_at | timestamptz | 48h countdown end |
| created_at | timestamptz | default now() |
- RLS: readable/updatable only by members of this couple.
- HARD RULE: max 2 members ever (enforced via couple_members + trigger/constraint).

### couple_members  (links users ↔ couple; the tenant membership)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| user_id | uuid FK→users | |
| cancels_used | int | default 0 — breakup once-each-cancel counter |
| joined_at | timestamptz | default now() |
- UNIQUE(couple_id, user_id). 
- CONSTRAINT: no more than 2 rows per couple_id (the "vault rule", DB-enforced).
- Index: user_id (resolve a user → their couple fast).
- RLS: a user sees membership rows for their own couple only.

### couple_invites  (the linking tokens)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| token | text UNIQUE | baked into QR + link |
| token_status | text | `active` \| `consumed` \| `revoked` \| `expired` |
| expires_at | timestamptz | 48h after generation |
| created_at | timestamptz | default now() |
- Join succeeds ONLY if token active AND couple.status = pending AND member count = 1.
- Regenerate → old token `revoked`, new one `active`.
- Index: token (lookup on join).

---

## MESSAGING  (partition-ready)

### messages
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| sender_id | uuid FK→users | |
| type | text | `text` \| `voice` \| `image` \| `soft_ping` |
| content | text | text body, or Storage URL for voice/image, null for soft_ping |
| reply_to_id | uuid FK→messages | null unless replying to a specific message |
| deleted_for | jsonb/text[] | user ids who "deleted for me"; empty = visible to both |
| unsent | bool | default false — "unsend for both" |
| delivery_state | text | `sending`\|`sent`\|`delivered`\|`read` (optimistic-send support) |
| created_at | timestamptz | default now() |
- **Index: (couple_id, created_at DESC)** — the core chat scroll query.
- PARTITION-READY: keep created_at; convert to time-partitioned later at scale.
- Media (voice/image) in Supabase Storage, private bucket, signed URLs only.
- RLS: only couple members read/write; respects deleted_for / unsent in queries.

### message_reactions
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| message_id | uuid FK→messages | |
| user_id | uuid FK→users | |
| emoji | text | |
| created_at | timestamptz | |
- UNIQUE(message_id, user_id, emoji). Index: message_id.

---

## DAILY PROMPTS & REVEAL

### prompts
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| content | text | the question |
| category | text | communication \| intimacy \| adventure \| gratitude \| ... |
| generated_at | timestamptz | on the couple's shared clock |
| expires_at | timestamptz | rhythm/expiry PARKED for girlfriend (shared-clock options a/b/c) |
- Index: (couple_id, generated_at DESC).
- RLS: couple members only.

### prompt_responses
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| prompt_id | uuid FK→prompts | |
| user_id | uuid FK→users | |
| response | text | |
| answered_at | timestamptz | |
- UNIQUE(prompt_id, user_id).
- MUTUAL LOCK: neither user's response is readable by the partner until BOTH rows
  exist. Enforced in RLS/read logic (not just app). Reveal = broadcast when 2nd lands.
- Index: prompt_id.

---

## LIVE GAMES

### game_sessions
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| game_type | text | would_you_rather \| truth_or_dare \| hot_take \| who_said_it \| couple_quiz |
| mode | text | `live` \| `async` (per-game property; engine supports both) |
| status | text | waiting \| active \| paused \| completed |
| started_at | timestamptz | |
| ended_at | timestamptz | |
- Paused sessions persist (resume, nothing lost). On completion → award bond XP +
  trigger creature reaction (app/Edge logic).
- Index: (couple_id, started_at DESC).

### game_moves
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| session_id | uuid FK→game_sessions | |
| user_id | uuid FK→users | |
| move_data | jsonb | flexible per game type |
| created_at | timestamptz | |
- Realtime syncs moves to both devices; simultaneous reveal via broadcast.
- Index: session_id.

---

## MEMORY VAULT

### memories
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| media_url | text | Supabase Storage URL (private bucket, signed URLs) |
| media_type | text | `photo` \| `video` |
| caption | text | |
| taken_at | date | for timeline + "1 year ago today" |
| created_at | timestamptz | |
- Fully shared (couple-owned, not user-owned).
- **Index: (couple_id, taken_at DESC)** — timeline scroll.
- Flashback = scheduled daily check for taken_at matching today's month/day in prior
  years → FCM push (Edge Function).
- Storage limits (free vs BOND+) STILL OPEN; video = main cost driver.

---

## IMPORTANT DATES  (the kept sliver of the cut planner)

### important_dates
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| label | text | |
| date | date | |
| recurring_yearly | bool | anniversaries recur |
| type | text | anniversary \| first_kiss \| milestone \| custom |
| created_at | timestamptz | |
- Feeds: creature reminders, anniversary prompt selection, milestone → creature
  evolution triggers. Index: couple_id.

---

## MOOD / CONNECTION  (flame + creature mood are DERIVED, not stored)

### mood_checkins
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| user_id | uuid FK→users | |
| mood_emoji | text | |
| note | text | optional one-word |
| created_at | timestamptz | |
- Index: (couple_id, created_at DESC).

### NOTE — flame & creature mood are NOT tables
- bond_score lives on `couples` (monotonic).
- Flame level + creature mood are COMPUTED (plain code) from recent activity
  timestamps across messages/prompts/games/memories/checkins. "Recent connection"
  is derived at read time; the flame count never decrements. No stored mood value.
- This is the baby-AI "state" job = free logic, no AI model calls.

---

## MONETIZATION

### subscriptions
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| couple_id | uuid FK→couples | |
| entitlement | text | `free` \| `bond_plus` (one paid tier for now) |
| status | text | active \| expired \| cancelled |
| expires_at | timestamptz | |
| revenuecat_id | text | |
| updated_at | timestamptz | |
- WRITTEN ONLY by the RevenueCat webhook Edge Function (ground rule). One sub
  unlocks BOTH partners (keyed to couple_id).
- Feature-gating checks entitlement before serving premium creature abilities
  (customization, calendar management, richer assistant).
- Index: couple_id.

### calendar_links  (day-one premium; proven calendar API, not built)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK→users | |
| provider | text | `google` \| `apple` |
| oauth_tokens | jsonb | stored securely; premium-gated |
| created_at | timestamptz | |
- We integrate a proven calendar API; build only the creature's VOICE around dates.
- RLS: user's own links only. Premium-gated.

---

## NOTIFICATIONS

### notification_prefs
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK→users | |
| category | text | partner_action \| daily_nudge \| flashback \| milestone \| ... |
| enabled | bool | default true |
- Per-user, per-category toggles; respected before any push.
- All pushes fired from Edge Functions → FCM. No push while app foregrounded.
- Quiet hours = phone's own DND (we build none).

---

## DISCOVER — no tables
Discover lives entirely through the baby AI. Results fetched live via Edge Function
→ external API (TMDB / Google Places / Foursquare) → rendered as cards in the creature
chat. Add a CACHE table later for places results (by area+query) to cut cost:
### places_cache  (optional, add when cost warrants)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| query_key | text | e.g. "thai|atlanta" (normalized) |
| results | jsonb | cached API response |
| fetched_at | timestamptz | expire after N days |
- Index: query_key. NOT couple-owned (shared cache) → its own RLS (read-only to app).

---

## TABLE INVENTORY (launch)
Core: users, couples, couple_members, couple_invites
Messaging: messages, message_reactions
Prompts: prompts, prompt_responses
Games: game_sessions, game_moves
Memory: memories
Dates: important_dates
Mood: mood_checkins
Money: subscriptions, calendar_links
Notifications: notification_prefs
(Deferred/optional: places_cache)

## OPEN ITEMS THAT TOUCH SCHEMA (resolve before/at build)
- Prompt rhythm & expiry (girlfriend) — affects prompts.expires_at semantics.
- Storage limits per tier — affects enforcement around memories/messages media.
- Exact RLS helper function for couple resolution — written at build time.
- Whether creature customization needs its own table vs the couples.creature_persona
  jsonb (start with jsonb; split out only if it grows complex).

## FUTURE (not launch) tables — noted so they're anticipated
- relationship chapters (monthly story) — needs months of data + AI layer.
- swipe-to-match rounds. gift subscriptions. higher premium tier content.
- messages PARTITIONS (time-based) once large.
