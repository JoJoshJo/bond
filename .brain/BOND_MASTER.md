# BOND — Master Brain

> Single source of truth for the BOND app. Read this at the start of every
> session. Update it at the end of every thinking session. This file is how
> future sessions pick up exactly where we left off.

**Last updated:** 2026-08-27 (added repo-check ground rule)
**Status:** Thinking / planning phase. Nothing built yet.
**Owner:** J (solo founder)

---

## THE WORKFLOW (how we work on BOND)

- **Claude chat** = the brain. All architecture and product thinking happens here first.
- **Claude Code** = writes the actual code on J's computer.
- **GitHub** = version control. Repo holds the app + this `.brain/` folder.
- **This file** = the memory. Updated at the end of every thinking session so
  nothing is ever lost between sessions.
- **Build rule:** layer by layer. Layer N is built AND tested on physical
  devices before Layer N+1 begins. No skipping test gates, even under time pressure.

---

## WHAT BOND IS

A couples app, mobile-first (iOS + Android). The core idea that makes it
different from every competitor (Paired, Between, Intimately Us):

> **Every other app treats a couple as two individuals sharing content.
> BOND treats the couple as ONE living entity — with a name, personality,
> story, health, and a future.**

The relationship isn't two people using an app. It's a living thing they
raise and grow together.

### Positioning vs competitors
- Paired (8M downloads, ~$9.99/mo): daily questions + therapist content, but
  no real-time games, no messaging, feels like homework.
- Between (10M downloads): private messaging + scrapbook, but no games, no AI,
  dated design.
- Intimately Us: game variety but too niche/spicy, no messaging, async only.
- Love Nudge: love-language focus, very limited scope.
- **The white space:** nobody combines messaging + live games + AI-personalized
  content + couple identity + beautiful design in ONE app.

---

## THE SOUL — BABY AI (signature feature)

A creature the couple raises together that IS their relationship, given a
living form. This is the emotional heart of the whole app and its hardest
technical build. It sits ON TOP of everything else.

### What it is
- A creature (Tamagotchi-style) with a face and personality.
- Fully personalizable — both partners shape its name, look, personality.
- It IS the couple entity: bond score, mood, connection, story all live in it.
- It's ALSO a helper/companion that nudges the couple toward each other.

### How it grows (all four forces locked in)
1. Daily connection — messages, games, prompts feed it.
2. How you treat each other — warmth/quality, not just activity volume.
3. Active care — feed it, play with it, dress it, like a pet.
4. Reflects mood — thrives when connected, rests when distant.

### THE NON-NEGOTIABLE RULE (protects zero-guilt principle)
- It rests, dims, sleeps when connection is low — it NEVER suffers, gets sick,
  or guilt-trips.
- It celebrates presence; it never punishes absence.
- Growth pauses when quiet; it never reverses. No decay of progress.
- Same soul as the bond score: only ever goes up.
- Long-distance aware: connection across distance feeds it MORE, not less.

### Life stages (tied to milestones)
Newly hatched (on link) → Growing (weeks/months) → Flourishing (milestones) →
Evolved forms (long-term couples unlock rare evolutions).

### Baby AI as the INTERFACE (key architectural decision)
The creature is also the front door to every feature. Natural-language "tool use":
- "find us dinner Friday" → Discover engine
- "what should we watch" → movies
- "add our anniversary" → planner
- "show us last June" → memory
- Falls back to web search when app data isn't enough.
- **Safety rule:** it FINDS and SUGGESTS; the couple always taps to confirm
  anything involving money, bookings, or sending. AI proposes, humans dispose.
- **Build note:** starts small (companion only), then we add tools one by one
  as underlying features get built. It's a Phase 2+ capability layered on.

### Still to decide on Baby AI
- Name for it (BOND fits — "grow your Bond")
- Same starting creature for all couples, or pick a species?
- Lives on home screen as centerpiece, or its own tab?
- How they talk to it: type, voice, or both?
- Exact MVP tool set

---

## FULL FEATURE UNIVERSE (23 features, all kept — grouped by job)

### Discover (answers "what should we do?")
1. Restaurants — find, filter, save, track visited
2. Movies + shows — shared watchlist, swipe-to-match, "we're watching" tracker
3. Attractions + things to do — AI date engine (city, weather, mood, budget)
4. Swipe-to-match decider — both swipe, match on shared pick (ends "I don't know" loop)
5. "Surprise us" button — one tap, AI picks something now
6. Bucket list — shared dreams, checked off together

### Play (fun + learning about each other)
7. Live games — Truth or Dare, Hot Take Battle, Would You Rather, Who Said It?, Couple Quiz
8. How well do you know me? — answer about each other, compare, share
9. Spicy mode (18+) — opt-in-by-both intimate games/prompts
10. Daily couple puzzle — one small thing solved together daily

### Connect (the direct line between two people)
11. Private messaging — text, voice, photos, reactions
12. Soft ping + thinking of you — wordless gestures, unique haptics
13. Status / availability — "in a meeting," "driving," kills response anxiety
14. Daily prompts + reveal moment — both answer privately, simultaneous reveal (emotional core)

### Grow together (direction, goals, habits, plans)
15. Challenges + quests + goals — themed series, daily quests, long-term goals
16. Shared planner — calendar for two, syncs with discover
17. Shared to-do / errands — couple logistics, the daily-utility hook
18. Shared savings goals — visual tracker (tracking, not banking)
19. Custom milestones — your own dates, can evolve the baby AI

### Remember (keepsake layer)
20. Memory vault — photo/video journal, "1 year ago today" flashbacks
21. Relationship chapters — each month auto-becomes a story chapter
22. Time capsules — letters to future selves, sealed and opened later
23. Our soundtrack — our song, songs tied to memories, AI year playlist

### NOTE ON SCOPE
This is a big app — bigger than Turf. Everything above stays in the VISION.
But the FIRST VERSION we ship is a slice of this. NEXT MAJOR TODO: sort all 23
into MVP / Phase 2 / Later so we ship fast and build the rest on something alive.
Not yet done.

---

## LAYER BUILD PLAN (the "stronger base" strategy)

Build order, each with a test gate that must pass on PHYSICAL devices before moving on.

- **Layer 1 — Foundation:** Supabase (prod + dev), auth, couple creation + linking. [SPEC LOCKED — see below]
- **Layer 2 — Design system:** theme, glass components, nav shell. Locked before feature screens.
- **Layer 3 — Messaging:** realtime chat, voice, soft ping.
- **Layer 4 — AI prompts:** Claude Edge Function, daily flow, reveal moment.
- **Layer 5 — Live games:** realtime multiplayer sessions.
- **Layer 6 — Memory vault:** photos, timeline, flashbacks.
- **Layer 7 — Mood sync + bond score + date night engine.**
- **Layer 8 — Chapters + secret missions + milestones.**
- **Layer 9 — Monetization:** RevenueCat, entitlements, paywalls.
- **Layer 10 — Push notifications:** FCM, all triggers.
- **Layer 11 — Polish + edge cases + store submission.**
- **Baby AI** — layered on top once underlying features exist to feed it.

(Discover, planner, to-dos, and the other newer features need to be slotted
into this layer plan — NOT yet done. Do this alongside the MVP scoping.)

---

## LAYER 1 — LOCKED SPEC (onboarding + couple linking)

### First open + sign up
- First screen: logo + one couple image, brief preload, sign-up on same screen (no intro carousel).
- Sign-up methods: Email/password + Apple + Google.
- Required at signup: email verification + password + age gate (18+) + terms agreement.
- Onboarding depth: minimal. Everything else (love languages, personality) happens progressively inside the app.

### Couple linking
- Link methods: QR code (in person) + shareable link (long distance).
- Invite token baked into the link/QR — Partner B joins with zero typing.
- Couple name: auto-generated cute name, editable anytime.
- While Partner A waits: solo preview — can explore the app + set couple name.
- Unlock moment: Supabase Realtime broadcast on couple:{id} — BOTH devices
  unlock simultaneously the instant B joins. This is the shared reveal.

### Invite security (the tricky part — fully solved)
- One-time use: token dies the moment B joins.
- Timer expiry: 48 hours after A generates it.
- Regeneration: A can generate a new link anytime; old one dies instantly (revoked).
- **THE VAULT RULE (enforced at DATABASE level, not just app logic):**
  A join only succeeds if token is active AND couple status is pending AND
  member count is 1. Once active/sealed, NO token (valid, old, screenshotted,
  or forged) can ever add a third person. Hard constraint: max 2 rows in
  couple_members per couple, ever.

### Token states
active → consumed (B joins) / revoked (A regenerates) / expired (48h timeout)

### Couple states
pending (A waiting, can accept B) → active (2 linked, unlocked) → sealed (2 max, locked forever)

### Dead-link messages
- consumed → "This couple is already complete"
- revoked → "This invite link is no longer active — ask for a new one"
- expired → "This invite has expired — ask [name] to send a fresh link"

---

## DESIGN DIRECTION (locked)

Modern, transparent, fun + elegant. Light-first glassmorphism.

### Aesthetic
- Cream-white warm base (NOT pure white). ~#FEF9F5 / #FAF7F2.
- Real frosted glass cards: rgba(255,255,255,0.60) + backdrop-filter blur(28px).
  Strong enough that ambient background bleeds through.
- Photography bleeds to card edges (image IS the background, text floats over
  soft scrim) — not image-in-a-box.
- Never dark, never clinical, never cold.

### Reference images (J provided 6)
- Primary refs: plant app (glass system) + floral cards (photo-forward, minimal chrome).
- Also: Daylog fashion (editorial serif typography, gold CTA), food app (bottom-sheet detail pattern).

### Color palette
- Background: warm cream (#FEF9F5 / #FAF7F2)
- Rose accent (fun/loving): #F4839A
- Gold accent (elegant/premium): #C9964A
- Mint: #6CC5A8
- Text primary: #1C1C1E

### Typography
- Display/headings: Cormorant Garamond, light weight (300), editorial, breathing room.
- Body/UI: DM Sans.
- Code/timestamps: JetBrains Mono.

### Motion
- Breathing animations, satisfying reveal moments, soft haptics.
- Fun comes from content + animation. Elegance from restraint in the UI.

### Hard design rules
- Zero hardcoded colors/fonts/spacing anywhere — everything through theme.dart.
- Design system locked in Layer 2, doesn't change mid-build.

---

## TECH STACK (locked)

- Mobile: Flutter (Dart) — single codebase iOS + Android.
- Backend: Supabase — Auth, PostgreSQL, Realtime (live chat + games), Storage
  (memory vault), Edge Functions (Deno).
- AI: Claude API — via Supabase Edge Functions ONLY. Never called from Flutter.
- Push: Firebase Cloud Messaging (FCM).
- Payments: RevenueCat — one subscription covers both partners.
- Weather (date engine): Open-Meteo (free, no key).
- Music (soundtrack): Spotify API previews.
- Version control: GitHub.
- IDE: Claude Code + Antigravity.

### Two Supabase projects
- bond-prod (owner access only)
- bond-dev (team/development work)

### Monetization
- Free forever tier (messaging, limited prompts/games, basic vault).
- BOND+ ~$7.99/mo per couple (unlimited, both partners on one sub).
- BOND Premium ~$14.99/mo (+ therapist programs, AI insights).
- Additional: gift subscriptions, one-time challenge packs.
- No ads, ever.
- Infra cost at launch: under ~$120/mo for 1,000 couples. AI ~$0.12/couple/mo.

---

## GROUND RULES (never break)

- NEVER call Claude API directly from Flutter — Edge Functions only.
- NEVER commit .env or secrets to GitHub — use Supabase CLI secrets.
- NEVER hardcode colors/fonts/spacing — theme.dart only.
- NEVER skip a layer's test gate — physical devices, no exceptions.
- NEVER write to subscriptions table from Flutter — RevenueCat webhook is sole writer.
- NEVER let the baby AI suffer/guilt — it rests, never punishes.
- NEVER let the AI confirm money/bookings/sends — human taps to confirm.
- ALWAYS run a repo check before any Claude Code file/commit action:
  confirm git repo, confirm remote points to BOND (not Turf/GhostCheck), confirm branch. Stop if anything looks wrong.
- ALWAYS verify RLS at the start of every data session.
- ALWAYS test on physical devices (Realtime, FCM, RevenueCat, haptics differ from simulator).
- ALWAYS generate a session handoff and update this file at session end.
- Bond score NEVER decreases.

### Lessons carried from Turf & Ardor (do not repeat)
- Verify every RLS policy + trigger (SECURITY INVOKER, not DEFINER) before moving on —
  a silent DEFINER no-op bug cost a full session on Turf.
- Monetization gets its own full layer with sandbox testing on BOTH platforms
  before shipping — Turf had a purchase-attribution failure from unverified linkage.
- App Store description must match actual shipped features — Turf got rejected for mismatch.
- Auth/onboarding must be airtight before anything builds on it.

---

## NEXT SESSION — START HERE

Open todos, in priority order:
1. **Sort all 23 features into MVP / Phase 2 / Later** (biggest open decision — ship fast).
2. Slot the newer features (discover, planner, to-dos, etc.) into the layer build plan.
3. Design the solo preview (what A sees/does before B joins).
4. Design the home screen (the daily ritual — most important screen, not yet designed).
5. Design the reveal moment UX (countdown, animation, reaction system).
6. Write notification copy guide (all notification types, warm not transactional).
7. Decide the open Baby AI questions (name, species, placement, input method, MVP tools).

---

## SESSION LOG

### 2026-08-27 — Planning session
- Locked the whole product vision, feature universe (23 features), and Layer 1 spec.
- Defined the Baby AI concept + the "AI as interface" architecture.
- Locked design direction and tech stack.
- Set up this brain file + the git/Claude Code workflow.
- Nothing built yet — still in planning.
