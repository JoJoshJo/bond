# BOND — Master Brain

> Single source of truth for the BOND app. Read this at the start of every
> session. Update it at the end of every thinking session. This file is how
> future sessions pick up exactly where we left off.

**Last updated:** 2026-09-02 (safety pass — launch defaults locked)
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

### Baby AI — INTERACTION MODEL (locked)
The creature lives in THREE connected ways (NOT a floating chatbot — it's the
same creature everywhere, with its name/face/personality):
1. **Home presence** — greets you, emotional center, first thing you see on open.
2. **Dedicated room/page** — where you set it up, feed, play, dress, customize,
   watch it grow, see stats. Where you RAISE it. (MVP: simple room; grow over time.)
3. **Floating quick-access** — ALWAYS floats by default; tap from any screen to
   ask it something. This is where it acts as the ASSISTANT.

- **Floating toggle:** on by default, but a settings switch lets users turn
  floating OFF (cleaner screen). When off, reach it via home or its room.
- **Input:** BOTH type and voice — a little chat opens; type freely OR hold to
  speak. Natural language requests.
- **When it speaks:** ONLY when tapped. Never interrupts, never pops up on its
  own, no unsolicited thought bubbles. Quiet and respectful — waits for you.
- **Future revisit (not now):** may later allow rare, genuinely-timely
  reactions (milestone completion, care needs) — but tap-only is the safe
  default for MVP. Decide once it's built and can be felt.
- **Design note:** the floating assistant is how the "AI as interface" works
  naturally — same companion, reachable anywhere, helpful when you talk to it.
  NOT a generic chatbot bubble (that was explicitly rejected as cheapening it).

### Still to decide on Baby AI
- Name for it (BOND fits — "grow your Bond")
- Same starting creature for all couples, or pick a species?
- Exact MVP tool set (which "assistant" abilities ship in v1)
- Visual design of the creature itself (co-decided with girlfriend)
- DECIDED: placement (home + room + floating), input (type+voice), speaks-when-tapped

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

## FEATURE DEEP-DIVES

> The detailed launch-version + future-version spec for each feature lives in a
> separate file: **`.brain/FEATURES.md`**. Read that file for full feature detail.
> Status of each (as of this writing):
> - ✅ Messaging
> - ✅ Daily Prompts & Reveal (rhythm/expiry parked for girlfriend)
> - ✅ Live Games (per-game live/async parked for girlfriend)
> - ✅ Memory Vault
> - ✅ Mood / Bond Score / BOND Flame
> - ✅ Discover
> - ✅ Planner (mostly CUT — kept only shared important dates)
> - ✅ Monetization (one tier; paywall = creature depth/management)
> - ✅ Notifications (invite-never-scold; phone's own DND)
> - ★ ALL FEATURE DEEP-DIVES COMPLETE
> The build order, ground rules, and open decisions stay in THIS file.

## UNIFIED SCHEMA

> The full database schema (every table, with couple_id + RLS + indexes baked in
> per the scaling strategy) lives in **`.brain/SCHEMA.md`**. That file is the
> source of truth Claude Code will turn into Supabase migrations at build time.
> Scaling model (locked): couple = tenant, shared tables + couple_id, RLS on every
> table, index (couple_id, created_at) on scrollable tables, media in Storage,
> messages designed partition-ready (partition later at scale). Build it right, not heavy.


## BREAKUP / UNLINK FLOW (locked)

Either partner can initiate; humane 48-hour wind-down; clean deletion.

### The flow
1. Either partner taps "Break up" (buried in settings, NOT a prominent button).
2. Confirmation screen with clear warning: "This starts a 48-hour countdown."
3. **48-hour countdown begins.** Both partners notified in-app + email. Couple
   enters "winding down" state — app still works, softly.
4. During the 48h, BOTH can export their souvenirs/data (photos, messages) as a
   keepsake, and say goodbye to the baby AI.
5. **Cancel rule (anti-abuse):** EITHER partner can cancel — but ONLY ONCE each.
   Once both have used their one cancel, it proceeds no matter what. (Prevents
   endless tug-of-war AND stops a controlling partner from trapping someone who
   wants out, while still allowing reconciliation from a heated-moment decision.)
6. **At expiry — the fork:**
   - Premium couple → offered 3-YEAR data preservation (data frozen, both
     accounts closed; if they reunite within 3 years, their whole story restores).
     This is a real premium upgrade hook.
   - Free couple → straight to deletion.
7. **Deletion:** both BOND accounts fully deleted, couple gone, baby AI gone
   ("baby AI dies, bye bye"). To return, sign up fresh.
8. Follow-up email with support resources sent to both.

### Schema implications (build these in from the start)
couples table needs: a `winding_down` status, `breakup_initiated_by`,
`breakup_expires_at` timestamp, and a per-partner `cancels_used` counter.

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

### DESIGN IS CO-DECIDED WITH J'S GIRLFRIEND
Major visual decisions get her input (she's a real target user — most couples
apps are downloaded by women). Revisit big design calls with her before locking.

### Open design decisions (in progress)
- Light vs dark: leaning "adaptive theme that shifts with mood/baby AI" — but
  REVISIT with girlfriend before locking.
- Roundness: chose "cleaner + tighter (less round, modern-minimal)."
- Fun vs elegant lead: THREE directions mocked up for J + girlfriend to pick:
  (01) Warm+Playful — rosy, Cormorant, most romantic;
  (02) Elegant+Calm — Fraunces, gold, premium/keepsake;
  (03) Modern+Fresh — Space Grotesk, coral pop, clean/current.
  Not yet chosen. Mix-and-match allowed (e.g. "01 warmth + 03 cleaner cards").

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

### Monetization  [UPDATED — see Monetization deep-dive in FEATURES.md: now ONE tier]
- Free forever tier (messaging, limited prompts/games, basic vault).
- BOND+ ~$7.99/mo per couple (unlimited, both partners on one sub).
- BOND Premium ~$14.99/mo (+ therapist programs, AI insights).
- Additional: gift subscriptions, one-time challenge packs.
- No ads, ever.
- Infra cost at launch: under ~$120/mo for 1,000 couples. AI ~$0.12/couple/mo.

---

## SAFETY PASS [partial — launch defaults locked; deeper work deferred]

BOND holds the most intimate data a person has. Safety = protecting users AND not
getting rejected by the app stores. Most abuse-resistance here is the ABSENCE of
risky features (cheap to honor now, expensive to retrofit) — so the safe defaults
are locked at design time, not "added later."

**LOCKED — launch safety defaults:**
- SPICY MODE (18+ content): NOT at launch. Real app-store-rejection risk (Apple/
  Google adult-content rules; could force 17+ or rejection) and not core. Added in a
  FUTURE version, deliberately, after proper store-compliance research. Idea kept, not
  near launch.
- LOCATION: NO location tracking at launch, EVER (as a default). Location-sharing is
  the #1 way controlling partners weaponize couple apps. FUTURE version may add
  OPT-IN, user-controlled location sharing (WhatsApp-style — "I'm sharing right now
  because I choose to") as a SECURITY feature. The distinction is everything:
  user-initiated opt-in = empowering; always-on background tracking = dangerous.
  Never the latter.
- PRESENCE: NO "online now" / "active" / "last seen", EVER. It's two people, not a
  contact list — presence indicators are pointless here AND remove an anxiety/control
  vector for free. (Also settles a girlfriend-list item; can still confirm with her.)
- DISCREET EXIT: the existing BREAKUP flow IS the exit (48h countdown, either can
  cancel once each, then everything destroyed — accounts, couple, baby AI; premium
  couples' data preserved 3 years for reconciliation). Stands as-is for launch.

**DEFERRED — deeper abuse-resistance pass (next version, needs real thought):**
- Is a 48h countdown that NOTIFIES the other partner safe in a genuinely abusive
  situation? (It could alert a controlling partner that someone is leaving.) May need
  a faster/quieter emergency exit. Think through before it matters.
- Safety resources, coercion edge cases, a genuinely dangerous-situation flow.
- Opt-in location sharing design (when added) must be built abuse-aware.

**STILL OPEN in the safety pass (not yet done this session):**
- Real age verification (not just a checkbox) — becomes critical when spicy mode
  arrives; basic 18+ gate at signup for launch.
- Full App Store / Play Store compliance review before submission (privacy policy,
  terms, data-handling disclosures, content rating).

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
- DON'T REINVENT THE WHEEL: integrate proven tech for solved problems (calendar,
  auth, payments, maps, movies, places, realtime); build custom ONLY for BOND's
  unique magic (creature, prompts, couple-entity model). Integrate commodity, build magic.

### Lessons carried from Turf & Ardor (do not repeat)
- Verify every RLS policy + trigger (SECURITY INVOKER, not DEFINER) before moving on —
  a silent DEFINER no-op bug cost a full session on Turf.
- Monetization gets its own full layer with sandbox testing on BOTH platforms
  before shipping — Turf had a purchase-attribution failure from unverified linkage.
- App Store description must match actual shipped features — Turf got rejected for mismatch.
- Auth/onboarding must be airtight before anything builds on it.

---

## NEXT SESSION — START HERE

★ MILESTONE: ALL 9 FEATURE DEEP-DIVES ARE COMPLETE (see FEATURES.md).
The feature-thinking chapter is closed. What remains before "cooking" (building)
is CROSS-CUTTING synthesis work — a different kind of thinking:

1. ✅ UNIFIED DATABASE SCHEMA — DONE (first full draft in SCHEMA.md). Scaling model
   locked (couple=tenant, RLS everywhere, indexes, media in Storage, messages
   partition-ready). Revisit only as open items resolve (prompt expiry, storage limits).
2. ◐ SAFETY PASS — launch defaults LOCKED (no spicy mode, no location, no presence,
   breakup=exit). See SAFETY PASS section. Still open: real age verification, full
   store-compliance review. Deeper abuse-resistance work deferred to next version.
3. AI PROVIDER + PRIVACY PROMISE — decide. Options mapped (Claude/Gemini/Groq/
   OpenRouter/Llama). Recommendation on file: build provider-agnostic router / use
   OpenRouter, start on Gemini student discount, apply for Anthropic credits, keep
   Llama-on-device as future privacy upgrade. Plus decide the actual privacy promise.
4. DESIGN DIRECTION — pick with girlfriend (warm / elegant / modern mockups exist).
5. RETENTION PLAN — first-7-days journey, the both-partners-must-engage problem
   (named as risks, no plan yet).

STANDING GIRLFRIEND-LIST ITEMS to resolve: typing indicators/presence; design
direction; daily-prompt rhythm & expiry (options a/b/c ready); game ideas +
live-vs-async per game + which games launch.

After cross-cutting work is done → thinking phase truly closes → COOKING BEGINS
(Layer 1: Supabase + auth + couple linking, per the Layer Build Plan).
## SESSION LOG

### 2026-08-27 — Planning session (part 1)
- Locked the whole product vision, feature universe (23 features), and Layer 1 spec.
- Defined the Baby AI concept + the "AI as interface" architecture.
- Locked design direction and tech stack.
- Set up this brain file + the git/Claude Code workflow.
- Nothing built yet — still in planning.

### 2026-08-28 — Planning session (part 3): feature deep-dives begin
- Adopted new method (vs Turf): every feature gets a LAUNCH version + FUTURE
  version, thought through fully BEFORE building. No rough MVP-then-iterate.
  Keep launch versions lean so "done thinking" doesn't mean "build everything."
- Assessed thinking progress honestly: ~35% done. Hardest structural pieces
  (couple system, breakup, baby AI) locked; most features still need deep pass.
- Explored AI provider landscape: Claude (if credits), Gemini (student discount),
  self-hosted Llama, + Groq/OpenRouter/DeepSeek/Together. Recommendation: build
  provider-agnostic ROUTER (or use OpenRouter), start on Gemini (free-ish), apply
  for Anthropic credits, keep Llama-on-device as future privacy upgrade. NOT chosen yet.
- Clarified baby AI "brain" = 4 jobs: assistant (smart tier), personality (cheap),
  content (mid), state/mood/growth (NOT AI — plain code, free).
- DEEP-DIVE DONE: MESSAGING (see Feature Deep-Dives). Diagnosed Turf's chat
  problems (2-3min send delay from waiting for echo; unverified end-to-end) and
  baked in fixes: optimistic send, dedupe, delivery states, clean channel
  lifecycle, two-device test gate.

### 2026-08-28 — Planning session (part 2)
- Locked the BREAKUP/UNLINK flow (48h wind-down, once-each cancel, premium
  3-year preservation, clean deletion). Added schema implications.
- Locked the Baby AI INTERACTION MODEL (home + room + always-floating assistant
  with off-toggle; type+voice; speaks only when tapped). Rejected pure floating
  chatbot as cheapening it.
- Explored founder capacity honestly — J is running Turf + GhostCheck + school
  (12 credits) + a funding campaign, and wants to go solo-full-send on BOND like
  Turf. Flagged that "all equal priority" is the real risk; J acknowledged, wants
  to proceed solo. Protections: brain file (no lost context), layer discipline
  (never broken half-state), and a tight MVP for a close finish line.
- Design flagged as CO-DECIDED with girlfriend; mocked up 3 visual directions
  for them to choose (warm/playful, elegant/calm, modern/fresh). Not yet picked.
- Still no code — planning. MVP line still the top open decision.
