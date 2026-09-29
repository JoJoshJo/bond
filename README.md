# Usora

A shared space for two people. Usora gives a couple one private place for their
messages, photos, plans and small daily rituals — and an AI creature they raise
together by actually showing up for each other.

Built for the **RevenueCat Shipaton 2026** — submitted for the **Next Gen** award.

## What's in it

- **Your space** — private chat (text, photos, voice notes), a shared memory
  vault, a shared calendar, and a daily question you both answer before either
  answer is revealed.
- **A creature you raise together** — its mood and growth come from real
  activity between you, not a tap-to-feed timer. Talk to it and it can search
  for a film or a place nearby, look something up on the web, and add or change
  events on your shared calendar.
- **Games for two** — 11 async games: Would You Rather, This or That, Couple
  Quiz, Four in a Row, Tic-Tac-Toe, Dots & Boxes, Target Shot, Free Throws, plus
  opt-in spicy variants. Play on your own time; the grid shows whose move it is.
- **Six themes** — Mint (free), Sunset, Ocean, Lavender and Charcoal, plus a
  dark "red room" palette that takes over while spicy mode is on.

## Built with

| Layer | Tech |
|---|---|
| App | Flutter / Dart (Riverpod, Dart SDK ^3.12) |
| Backend | Supabase — Postgres, row-level security, Realtime, Storage |
| Server logic | 5 Supabase Edge Functions (Deno/TypeScript) |
| AI | Google Gemini, with a runtime model-fallback chain |
| Web search | Tavily |
| Places & film data | Google Places (New), TMDB |
| Payments | RevenueCat |
| Push | Firebase Cloud Messaging |

## Engineering notes

The parts we'd point a reviewer at:

- **Premium is enforced in the database, not the UI.** Paid features are gated
  by row-level-security policies and triggers keyed to the couple's
  subscription: calendar writes require an active entitlement, the free memory
  vault is capped by an insert trigger, and the insights RPC refuses non-paying
  couples. A patched client can't unlock them.

- **Account deletion really deletes.** One `SECURITY DEFINER` function clears
  every table holding the couple's data and removes the couple row itself (no
  tombstone), while the Edge Function deletes the couple's Storage objects
  first, so a failure can't orphan photos and voice notes. Guideline 5.1.1(v),
  done properly.

- **The AI can't spend your budget or invent facts.** Every router call goes
  through a per-couple daily cap (200 AI calls, 10 web searches), enforced by a
  Postgres function the client can't reach. A whole request shares one ~48s
  deadline so nothing hangs. Prompts are length-capped and unused job types are
  rejected.

- **The calendar assistant proposes; it never writes.** When the creature offers
  to add or change an event, the date must either be one the user actually said
  (resolved to a real date — "friday" means *this* Friday, not any date) or be
  found in a live web-search result next to the event's own name. Otherwise it
  asks instead of guessing. The write happens only after the user taps Yes, on
  the same path the manual calendar editor uses.

- **Contrast checked, not eyeballed.** Every tinted surface, chat bubble and
  themed screen was measured against WCAG 4.5:1 on all six palettes; text on
  tints uses each theme's ink rather than a muted grey that fails on colour.

- **No secrets in the client.** The app only ever holds the Supabase URL and
  anon key (public, RLS-protected), supplied at build time. Provider keys live
  in Supabase secrets, travel as headers where the API allows, and every log
  line is run through a redactor.

## Running locally

```bash
flutter pub get
cp env.example.json env.json      # fill in your own values
flutter run --dart-define-from-file=env.json
```

`env.json` is gitignored. See [`env.example.json`](env.example.json) for the
shape — two values, both from your own Supabase project:

| Variable | What it is |
|---|---|
| `SUPABASE_URL` | Your project URL |
| `SUPABASE_ANON_KEY` | The anon (public) key — safe in a client, protected by RLS |

Optional, only if you're wiring up payments:

| Variable | What it is |
|---|---|
| `REVENUECAT_APPLE_KEY` | RevenueCat public SDK key (`appl_…`) |

Dev tools (a style gallery, an AI router test screen, a premium override) are
compiled in by default and stripped from release builds with
`--dart-define=USORA_DEV=false`.

### Server side

The backend isn't provisioned by this repo. `supabase/functions/` holds the five
Edge Functions, and `supabase/migrations/` holds the SQL — schema, policies,
`SECURITY DEFINER` functions and the gates described above. Everything was
applied by hand in the Supabase dashboard; the migration files are a record, not
an automated runner, and each one says so in its header. Running your own copy
means creating a Supabase project, applying that SQL, deploying the functions,
and setting the provider keys as function secrets (`GEMINI_API_KEY`,
`TMDB_API_KEY`, `GOOGLE_PLACES_API_KEY`, `TAVILY_API_KEY`).

## Status

Shipped to TestFlight. Submitted to the App Store (currently in review). This
is a real product under active development, not a demo — expect rough edges in
the corners we haven't polished yet.
