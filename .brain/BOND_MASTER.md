# BOND — Master Brain

> Single source of truth for the BOND app. Read this at the start of every
> session. Update it at the end of every thinking session. This file is how
> future sessions pick up exactly where we left off.

**Last updated:** 2026-09-02 (★ LAYER 1 CODE COMPLETE — scaffold+auth+linking committed fbebf85)
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

## DESIGN DIRECTION [LOCKED 2026-09-02]

**Overall vibe: MODERN & FRESH** — clean, a little bold, current and alive (chosen
over "warm & playful" and "elegant & calm"). NOTE: this SUPERSEDES the earlier
cream-glass / rose+gold / Cormorant direction. Modern & Fresh doesn't mean cold —
keep it warm and alive via the creature, soft rounded cards, gentle shadows, and
little moments of life.

### Color scheme: WHITE + MINT [LOCKED]
- Base: bright, minimal WHITE / off-white (~#FCFDFC / #F0F6F3). (NOT the old cream.)
- Signature accent: MINT (~#4CAF8E, with soft #A8D8C4) — matches the mint creature,
  so app + creature feel unified and intentional.
- Text primary: dark near-black (~#22302B).
- WATCH-OUT (build lens): white+mint done SOFT = fresh & lovely; done HARD = clinical/
  medical. Keep it warm — rounded cards, gentle shadows (no hard edges), creature glow,
  soft animations. It's a LOVE app; warmth matters more than in most apps.

### Creature color: MINT (default) [LOCKED]
Soft glowing blob, mint default. Couples can customize; mint is just the default.
(See Creature Visual Design section.)

### Roundness: cleaner + tighter [LOCKED]
Less round / modern-minimal (but still soft enough to feel friendly, per watch-out above).

### Typography
- Display/headings: SPACE GROTESK (the Modern & Fresh font — crisp, geometric).
  (Supersedes the earlier Cormorant Garamond.)
- Body/UI: DM Sans.
- Code/timestamps: JetBrains Mono.

### DESIGN IS CO-DECIDED WITH J'S GIRLFRIEND
Major visual calls get her input (real target user). She can still adjust the above —
these are J's locked picks, changeable if she has strong instincts. Colour/warmth is
squarely her call to weigh in on.

### Reference images (J provided 6, earlier)
Plant app (glass/clean), floral cards (photo-forward minimal chrome), Daylog fashion
(editorial type), food app (bottom-sheet pattern). Use for layout/feel inspiration;
palette + font now locked to white+mint + Space Grotesk above.

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

## AI PROVIDER + STRATEGY [decision LOCKED]

**DECISION: provider-agnostic from day one. Start on Gemini, be Claude-ready, switch
when Anthropic credits land — as a ONE-LINE config change.**

- Build the AI ROUTER from day one (see reference impl: `.brain/reference/ai_router_demo.js`,
  a working proof that swapping providers = 1 config line, 0 app changes).
- START on GEMINI (J has a student discount → effectively free while proving the app).
- APPLY for Anthropic startup credits in parallel.
- SWITCH the assistant to Claude if/when credits land — one config line, no app update.

**ARCHITECTURE (build it this way — proven by the reference demo):**
1. ONE entry point: all AI calls go through `getAI(job, input)`. Never call a
   provider SDK directly anywhere else.
2. STANDARD request/response shape (BOND's neutral format). Adapters translate to/from
   each provider's quirks. App only ever sees BOND's shape.
3. Provider chosen by CONFIG, PER JOB (assistant/personality/content). Switch = change
   one config line.
4. Keys in Supabase secrets (GEMINI_API_KEY, CLAUDE_API_KEY), never in code.
5. Adapters are ADDITIVE — adding a provider = one new small adapter file; nothing
   existing changes.
6. Router + adapters live in Edge Functions (never Flutter). Keys never reach client;
   switching never needs an app update.

**THE 4 JOBS (recap) — route each independently:**
assistant (smart tier — the tool-use "find us dinner" job), personality (cheap —
short warm lines), content (mid — prompts/date ideas), state/mood/growth (NOT AI —
plain code, free).

**PROVEN:** ran a live test — same app code, switched gemini→claude via one config
line, identical clean result, provider actually swapped. Engineering pain of switching
is eliminated. (Caveat: still write each real adapter once, and re-test prompt QUALITY
on a new model — but the structural switch is trivial.)

**PRIVACY PROMISE [LOCKED]:** "We never sell your data, we never train AI on it, and
only the two of you can see your stuff." Made VISIBLE to couples (a clear privacy
explainer — what we do and don't do) so it's a trust feature, not just fine print.
100% honest — we promise exactly what we deliver (the messaging rule applied). This is
achievable today: messaging is row-level-secured + encrypted in transit/at rest; API
data (Gemini/Claude) is NOT used to train models; we send the AI the MINIMUM per
request, never the couple's whole history; no location/presence/surveillance.
True end-to-end encryption stays on the V2 backlog (can't be promised honestly at
launch, so we don't claim it yet).

## RETENTION PLAN [decision LOCKED — tune with real users post-launch]

An app people forget is a dead app. Two retention problems are unique to a couples
app and were designed against deliberately.

**PROBLEM 1 — "both partners must engage" (the #1 killer of couples apps):**
BOND only works if BOTH are in. Classic failure: one's engaged, one isn't → engaged
one churns → whole couple lost. LOCKED defense = LAYERED (all of):
- (a) SAFETY NET: the engaged partner still gets value solo (creature, memories,
  prompts waiting) so they don't give up while the other warms up.
- (b) *THE PRIMARY LEVER* — WARMTH-BASED PULL: the best "come back" signal is your
  PARTNER did something, not the app nagging. "Sam left you something 🤍." A pull the
  person you love creates. (Ties to notifications: invite never scold.)
- (c) THE CREATURE as shared pull: its flourishing depends on both showing up — BUT
  carefully, never "your neglect is hurting it" (guilt = banned).

**PROBLEM 2 — the first 7 days (retention is won/lost in week one):**
Most apps lose the majority of users in ~3 days. Danger with a feature-rich app: dump
someone in, they don't know what to DO, they leave. LOCKED fix = a DESIGNED first-week
experience (not features just sitting there), all of:
- (a) FRONT-LOAD the magic: the moment both partners link → immediate emotional
  payoff (meeting the creature together, a first reveal). The onboarding IS the hook.
- (b) GENTLE FIRST-WEEK ARC: each day offers one small delightful thing (first prompt,
  first game, first memory, creature reacting) → a reason to return tomorrow while the
  habit forms. Not a rigid tutorial — a light "here's one lovely thing today."
- (c) FAST SHARED "AHA": get them to their first SHARED moment (first prompt reveal /
  first game together) within MINUTES of both joining, not days.

**IMPORTANT:** this is the piece MOST worth revisiting with REAL user behavior. Lock a
strong v1, then TUNE post-launch by watching what actually hooks couples. Don't
over-engineer the first-week arc before real data.

## COMPETITIVE LANDSCAPE [researched 2026-09-02]

Full audit done (web research). The honest picture:

**THE ONE-LINE TRUTH:** competitors have a PRODUCT; BOND has a PLAN. That is the
entire real gap. BOND is AHEAD on concept, BEHIND only on existing/being-built.

**WHERE BOND WINS (concept — genuinely uncontested):**
- The baby-AI CREATURE you raise together — NOBODY has this. The core differentiator.
- ALL-IN-ONE world — rivals each do ONE thing (games OR messaging OR AI coaching);
  BOND combines them.
- ZERO-GUILT design — rivals use breakable streaks/guilt; BOND's flame never punishes.
- Creature-as-ASSISTANT — ask it to do things vs tapping menus.
- The MOAT is the COMBINATION, not any single feature.

**WHERE BOND LACKS (all execution/traction, not vision):**
- NOT BUILT YET — every competitor already exists and works. The big one.
- No users, no trust — Flamme has 100k+ couples; Paired is a known brand; BOND = zero.
- No real-use learning on games/AI/design yet; rivals have iterated for years.
- Less ready content (question libraries, polished design, languages).

**KEY RIVALS:**
- FLAMME — the BENCHMARK & closest rival. 100k+ couples, already ships games + AI
  coach + Connection Score + widgets. IMPORTANT: if BOND ever drops the creature,
  it's "just another Flamme" and they're years ahead. The creature is the separation.
- PAIRED — market leader; therapist-designed daily Qs + quizzes; owns the private-
  answer-then-reveal mechanic (now widely copied); strong brand, but no games/
  messaging/creature ("feels like homework").
- AMORA — rising; gorgeous "liquid glass" design, 2,500+ Qs, offline-first, widgets,
  8 languages. Questions-only.
- BETWEEN — since 2012; the OG private couple space (messaging + memory timeline);
  dated, no games/AI/creature.
- CONNECTED / STAYCLOSE — games-first apps; prove "games as bonding" works.
- AI-COACH WAVE (2026, new category) — Maia, Ember, CoupleWork, Resolve, dvoe,
  Bonds/heybonds (NB: shares our name AND has a context-aware assistant). These are
  therapy-ish repair tools, a different job than BOND's everyday shared world.

**NAME CLASH (known, decision OPEN):** "Bond"/"Bonds" is used by 4+ couples apps
(Bond: Couples Games & Insights; Bond: Couples Games & Quizzes; Bond44; Bonds/
heybonds — which also shares the AI-assistant concept). Real App-Store-search / SEO /
trademark risk. J aware; NAME NOT YET DECIDED — to brainstorm later, before launch.

**NAMING PROGRESS (2026-09-02 brainstorm — still OPEN):**
- Direction J wants: an INVENTED/ownable word, feeling warm+playful+elegant+clever all
  at once. The COUPLE names their own creature separately, so the APP name only needs
  to be a nice "home," not carry the creature's identity.
- Checked & TAKEN (avoid): Nuvo, Piko (marketplace w/ AI), Solene (AI makeup app),
  Enara (smart-home + health), Twine (device + fiction tool). Twindle = a LIVE couples
  app, near-clone of BOND (see below).
- CANDIDATE ON THE TABLE: "TWINDLOO" — appears fully AVAILABLE, playful, "twin" reads
  as two. BUT flagged: collides with "Twindle" (one letter off) and sits in a crowded
  "twin-" cluster. Kept as an option, leaning away from it for that reason.
- Untaken directions to explore next (no couples-app collision found yet): Oomi,
  Nestra, Wisp, Orenda, Aluma, Duvo. (Batch-2 name list.)
- LESSON: short pretty invented words are mostly taken (often by AI apps); more
  distinctive/invented spellings are the realistic path.

**COMPETITOR TO STUDY LATER — "Twindle" (Google Play, updated Feb 2026):** near-clone of
BOND's vision — private couple chat (voice/photo/reactions), shared love diary/
scrapbook, daily questions & quizzes, mood tracking, private media vault, dark-mode
premium design, connection STREAK. Closest thing to a direct BOND clone found. Worth a
proper features/reviews/weaknesses dig before launch.

**STRATEGIC CALLS:** (1) protect the creature above all — it's the only thing no one
has; (2) win on the combination, don't out-feature specialists; (3) crowding = proof
of real demand ($1.3B market), not a dead end; (4) execution is now the whole game.

## WHAT COUPLES ACTUALLY SAY + ADJUSTMENTS [2026-09-02]

Studied real reviews across the category (Twindle finding + cross-app pattern).
Verdict: BOND's VISION already answers the category's complaints better than rivals.
Research VALIDATED the plan — only 1 sequencing flag + 2 small content principles.

**Twindle finding:** near-clone of BOND (private chat, diary, daily Qs, mood, vault,
streak) but TINY + barely reviewed → having the feature list ISN'T winning. Missing
BOND's edge: no creature, no games pillar, no AI assistant, breakable guilt-streak,
dark "premium" look (opposite of our warm cream-glass). Easy to differentiate.

**What couples PRAISE (BOND already has all 4):** daily ritual that sparks real
conversation (= our prompt+reveal); private-answer-then-reveal (= our mutual lock);
warm non-clinical design + fun (= creature + games + cream-glass); fits EVERY kind of
couple (LDR/non-mono/no-kids).

**What couples COMPLAIN about → BOND's status:**
- "Content repeats fast" (THE #1 category complaint) → our AI prompts solve it. *GAP:*
  MVP planned to START with curated bank + light personalization. ADJUSTMENT → treat
  "never gets stale" as a NEAR-LAUNCH priority, not "someday" — it fixes the biggest
  category weakness, so freshness must be real close to launch.
- Pushy paywalls → answered ("connection free, depth paid" + generous free + one honest tier). ✅
- Invasive signup (phone #) → answered (email/Apple/Google, no phone; visible privacy). ✅
- Streak guilt → answered (flame never resets; zero-guilt). ✅ (felt win vs Twindle)
- Feels abandoned/stale → answered (evolving creature keeps it alive). ✅

**THREE ADJUSTMENTS TO BAKE IN (vision unchanged):**
1. SEQUENCING: fresh/non-repetitive content matters NEAR LAUNCH (not deferred) — it's
   the fix for the #1 category complaint, so don't ship the very weakness everyone hates.
2. CONTENT PRINCIPLE — INCLUSIVE BY DEFAULT: write prompts, creature dialogue, and copy
   to fit ANY relationship (not married/kids/hetero-assumed). Costs nothing; easy to
   violate by accident. A lens to build through.
3. PROMISE IT OUT LOUD: make "it never gets stale" an explicit, stated promise (couples
   burned by repetition look for that reassurance) — not just an internal capability.

**Bottom line:** vision needs NO change; it answers the complaints better than rivals.
The gap is EXECUTION, not strategy. Build it and BOND is straightforwardly better —
by fixing what everyone complains about, wrapped around a creature no one else has.

## ANALYTICS [decision LOCKED]

How we'll know if BOND is actually working. NOT vanity metrics — a small focused
dashboard where each number drives a real decision.

**NORTH STAR: "Both partners active"** — % of couples where BOTH people used the app
this week. The truest heartbeat for BOND: everything depends on two people showing up;
a couple where only one engages is a dying couple regardless of that one's activity.
Directly measures the #1 killer of couples apps (asymmetric engagement).

**FOUR SUPPORTING METRICS (the whole dashboard = north star + these 4):**
1. ACTIVATION — % of couples who link BOTH partners and finish onboarding (does the
   top of the funnel work / do they get in the door?).
2. RETENTION — Day-7 & Day-30: are couples still here after a week / month (the
   novelty-fade problem the whole category has).
3. FEATURE ENGAGEMENT — which features get used (prompts vs games vs creature vs
   memories) → tells a solo dev what to build more of and what to cut.
4. FREE → PAID CONVERSION — % of couples upgrading to BOND+ (is the money model working?).

**HOW (locked):**
- DESIGN THE APP TO FIRE THESE EVENTS FROM DAY ONE. The trap is building everything
  then realizing you never logged when a couple links / both go active → can't measure
  your own north star. Every one of the 5 metrics needs its underlying event in the
  code from the start.
- TOOL: PostHog. Free tier = 1M events/month, NO credit card, stable pricing (~33k
  events/day, covers 10k-50k MAU → effectively free through all early growth; 97% of
  companies never leave free). Set a hard spending cap when eventually on paid.
- SAFE / fits privacy promise: open-source, US/EU data residency, GDPR-friendly,
  self-hostable if ever wanted.
- KEEP TRACKING LEAN: only track events tied to the 5 metrics, NOT every tap. This
  keeps the dashboard focused AND keeps you inside the free tier basically forever
  (consumer apps can rack up events fast — the 5-metric discipline protects against it).
- "Don't reinvent the wheel": integrate PostHog, don't build analytics.

## CREATURE VISUAL DESIGN [direction + art path PROVEN]

The signature feature's LOOK — explored and de-risked via Gemini image generation.

**DIRECTION (locked as leaning):**
- Style: Tamagotchi-style, SOFT MODERN BLOB (chosen over retro-pixel and animal-ish).
  A simple round blob with big friendly eyes, rosy cheeks, tiny stubby feet, gentle
  glow + gold sparkles. Gender-NEUTRAL (no eyelashes; friendly not "pretty").
- Fits BOND's cream-glass aesthetic; simple = easy to animate + ownable.
- Signature traits to keep consistent: round body, big dark eyes, rosy cheeks, cream
  belly, soft glow, gold sparkles, optional floating heart.

**COLOR (default not final — couples CUSTOMIZE their creature, so this is just the
starting/default look):**
- Tested mint, lavender, blue, peach. Peach + lavender read most "couples/romantic";
  mint/blue read more "wellness." Peach used in the consistency test.
- Idea worth keeping: creature could START neutral cream and GAIN color as the couple
  bonds (color as a reward for connection). Not decided.
- DEFAULT COLOR still open — a creature-layer decision, far off.

**ART PATH (proven — this was the big de-risk):**
- Path = AI GENERATION via GEMINI (J has Gemini access). NOT hand-drawn by J.
  Alternatives if ever wanted: commission an artist (Fiverr/Upwork ~$50-few hundred),
  girlfriend if she's creative, or licensed game assets. Start scrappy (AI), polish
  later (commission) if BOND grows.
- CONSISTENCY PROVEN: generated the SAME creature across states — egg form, sleeping/
  resting (curled, content, "z" — matches zero-guilt "rests never suffers"), and
  thriving (beaming, hearts, sparkles = high-connection joy). Gemini held the
  character across all three. So the full egg→hatched→resting→thriving→evolved
  pipeline is generatable, consistently, ~free.
- METHOD that worked: nail the hero creature first, then in the SAME chat say "the
  same creature, now [state]" referencing the original. Keep it simple = stays consistent.
- Ready-to-use prompts saved (see the creature-prompts doc from this session).

**STATUS:** art is NOT a Layer-1 problem — creature comes late in the build order.
This exploration just DE-RISKED the signature feature (proved the art is achievable
and cheap) and gave a strong starting design. Final creature + default color decided
at the creature layer, likely with girlfriend.

## ONBOARDING CONTENT / FIRST-RUN [structure LOCKED; final copy = near launch]

How a couple's first minutes + first week actually feel. Structure decided now (it
shapes the build); the polished WORDS come near launch.

**THE FIRST SHARED MOMENT (order locked): MEET THE CREATURE → THEN SET UP YOUR WORLD.**
1. The instant both partners link + app unlocks → the EGG HATCHES, the creature
   appears, they NAME IT TOGETHER, it greets them. Lead with the signature magic in
   the first ~60 seconds — the "oh wow," screenshot-worthy moment. It's the thing no
   other app has, so it goes FIRST.
2. THEN "set up your world" — name the couple, add the important date. Now it feels
   warm/meaningful (they just met the creature they're doing it for) instead of a
   boring setup form.
- WHY this order: EARN the setup by leading with delight (opposite of apps that
  front-load forms/permissions). Payoff first → couple is emotionally in → they
  happily do setup. Also narratively: meet creature → build the world around it →
  reinforces "creature is the heart of BOND" from minute one. Directly attacks the
  "downloaded, poked around, left" problem.

**TEACHING / DISCOVERY (locked): the CREATURE guides, gently, over the FIRST WEEK.**
- No formal tutorial / no tooltips-and-arrows. The creature — as its natural ASSISTANT
  self — introduces ONE thing at a time across the first 7 days ("today, want to try
  your first game together? 🎮").
- WHY: reuses the creature (no separate tutorial system to build); spreads "aha"
  moments across the 7-day RETENTION window (a reason to return tomorrow); never feels
  like homework (it's your warm creature inviting, not a robotic walkthrough). Unifies
  ONBOARDING + RETENTION + creature-as-assistant into one thing.

**STILL FOR NEAR-LAUNCH:** the actual COPY — creature's greeting words, the naming
flow wording, each day's gentle invitation, first-prompt selection. Write when
building the onboarding/creature layers. Must follow the locked content principles:
INCLUSIVE by default, warm/invite-never-scold, "never gets stale."

## AI FALLBACK BEHAVIOR [decision LOCKED]

What happens when the AI (Gemini/Claude via the router) is down, slow, or returns junk.

**LOCKED: the creature STAYS IN CHARACTER — it never feels broken, just momentarily
"foggy."** e.g. "Hmm, my brain's a little foggy right now — try me again in a bit? 🌫️"
Even a failure becomes a moment of personality (a sleepy creature), NEVER a cold error
screen. Protects the magic/illusion.
- NEVER show a raw/technical error to the couple — it shatters the creature illusion.

**Thoughtful additions (free, make it better):**
- DAILY PROMPT specifically: silently pull from the curated backup prompt BANK (which
  exists anyway per the "never gets stale" plan) if the AI is down — no foggy message
  needed there, since a real fallback exists.
- LIVE ASSISTANT ("find us dinner") where there's no pre-written answer → the
  in-character "foggy" response.
- ROUTER can try an alternate provider before falling back (ties to the provider-
  agnostic router; a failure on one provider isn't necessarily a user-visible failure).

**STATUS:** principle locked now; implemented at the AI layer (~Layer 4). Exact foggy
copy = near-launch, following the warm/in-character voice.

## MODERATION / REPORTING [decision LOCKED for launch]

Even for two private people: a way to report problems + flag bad AI. Also a store
requirement.

**LOCKED (launch):**
- SUPPORT / REPORT: a simple "report a problem / contact support" option in settings.
  Non-negotiable — app stores REQUIRE a way for users to report/contact you.
- AI FEEDBACK: a thumbs-down (or similar) to flag a bad AI/creature response. Cheap,
  and valuable BECAUSE the creature is AI-generated — gives a feedback loop to improve
  it AND a safety net if it ever says something off/weird.

**DEFERRED (to the abuse-resistance pass, NOT half-done now):**
- A quiet "get help" safety resource for someone in a genuinely bad/abusive situation.
  Important, but belongs with the deeper abuse-resistance work already deferred to a
  proper future session (see Safety Pass), so it's done thoughtfully, not partially.

**STATUS:** launch scope locked. Full store-compliance review (privacy policy, terms,
content rating, data disclosures) still happens right before submission.

## V2 BACKLOG (intentionally deferred to a future version — NOT cut)

One place for everything we deliberately pushed past launch, so nothing quietly
disappears. These are DECIDED "laters," not open questions.

- **Spicy mode** (18+ games/prompts) — THE #1 V2 MONETIZATION PRIORITY (research
  shows intimacy content is the biggest money lever in the category; tiered escalation
  Soft→Hot→Hard→Extreme behind Premium is the winning pattern). Reconsidered for launch
  2026-09-02, kept in V2 — reason below.
  COMPLIANCE RESEARCH DONE (Apple, ready for when we build it):
  * Apple's BRIGHT LINE: bans "overtly sexual/pornographic" = explicit
    descriptions/displays of sex organs or acts meant to arouse. Instant rejection.
    Also bans hook-up apps facilitating that.
  * ALLOWED lane: "suggestive/mature" content IS permitted at higher ratings (16+ =
    "frequent mature or suggestive"; 18+ = "sexual content or nudity"). Coral etc. live
    here: SUGGESTIVE/ROMANTIC, NOT explicit. That's the winning pattern.
  * HARD REQUIREMENTS (Apple guideline 1.2.1(a), added Feb 2026): (1) a REAL age gate —
    verified or declared age — to keep minors out; (2) clearly MARK mature content;
    (3) complete Apple's age-rating questionnaire honestly + rate app 17+/18+.
  * TRADE-OFF (why kept in v2, not launch): rating the WHOLE app 17+/18+ from day one
    shrinks audience + hurts discoverability. Better as a big PAID UPDATE post-launch,
    after a clean easy-to-discover approval, when there's an audience to convert.
    France note: 17+ shows as 18+ there.
  * OPEN for v2: research whether spicy can be a SEPARATE age-gated section so the main
    app keeps a lower rating (vs rating the whole app up).
- **Opt-in location sharing** (WhatsApp-style, user-initiated) — as a SECURITY
  feature; must be built abuse-aware. Never always-on tracking.
- **Relationship Chapters** (monthly AI story recap) — needs months of data + the
  AI layer; natural post-launch feature.
- **Swipe-to-match** (both partners converge on a choice) — creature could set up a
  round; it's an interaction, not a question.
- **Full planner / calendar depth** — beyond the day-one premium calendar link;
  only if couples actually ask for it.
- **Deeper abuse-resistance pass** — quiet/emergency exit for dangerous situations
  (the 48h-countdown-notifies-partner problem), safety resources, coercion edges.
- **Higher premium tier** — therapist-style content, deeper insights, priority AI,
  the 3-year breakup preservation as a named perk — only if demand appears.
- **Messages table partitioning** — time-based, only once it hits tens of millions
  of rows (schema is already designed partition-ready).
- **True end-to-end encryption** for messaging — as a premium/privacy upgrade.
- **Message search**, centralized media hub, more gesture types.
- **Custom albums / milestone auto-tagging / voice notes on memories** (memory vault).
- **Apple Watch / Wear OS**, home-screen widgets — engagement surfaces.

## GROUND RULES (never break)

- NEVER call Claude API directly from Flutter — Edge Functions only.
- NEVER commit .env or secrets to GitHub — use Supabase CLI secrets.
- NEVER hardcode colors/fonts/spacing — theme.dart only.
- NEVER skip a layer's test gate — physical devices, no exceptions.
- NEVER write to subscriptions table from Flutter — RevenueCat webhook is sole writer.
- NEVER let the baby AI suffer/guilt — it rests, never punishes.
- NEVER let the AI confirm money/bookings/sends — human taps to confirm.
- ALWAYS run a repo check as the FIRST STEP of EVERY Claude Code prompt (not just
  commits — any prompt, every time, no exceptions): confirm inside a git work tree,
  confirm remote = BOND (git@github.com:JoJoshJo/bond.git, NOT Turf/GhostCheck),
  confirm pwd + branch. STOP and report if anything looks wrong before doing anything.
  Rationale: J runs multiple repos; one command in the wrong repo causes real damage.
- ALWAYS verify RLS at the start of every data session.
- ALWAYS test on physical devices (Realtime, FCM, RevenueCat, haptics differ from simulator).
- TESTING = APK ON J'S REAL DEVICE. Claude Code builds the APK; J installs + tests. Do
  NOT use the emulator/simulator unless genuinely required (J's locked preference).
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

★★★ BUILD HAS STARTED — LAYER 1 IN PROGRESS ★★★

**BOND Supabase project (free org):** https://hzvxqafbcxpncuuukrpd.supabase.co
(Single DB for now; prod split happens near launch — don't need it yet.)

**LAYER 1 PROGRESS:**
- ✅ DATABASE BUILT & VERIFIED — all 16 tables live in Supabase, created via 4 SQL
  migration parts run in the SQL Editor:
  Part 1 core identity (users + auto-profile trigger, couples, couple_members,
  couple_invites); Part 2 core RLS (current_couple_id() helper + vault-rule policies);
  Part 3 feature tables (messages, message_reactions, prompts, prompt_responses,
  game_sessions, game_moves, memories, important_dates, mood_checkins, subscriptions,
  calendar_links, notification_prefs); Part 4 feature RLS (incl. DB-level mutual prompt
  lock, subscriptions read-only for RevenueCat webhook). Verified: 16 tables present.
- ✅ FLUTTER SCAFFOLD + SUPABASE CONNECTION — DONE & COMMITTED (commit 34913c5, 78
  files). Flutter project (package 'bond', app id com.bond.app WORKING-TITLE — finalize
  before submission once name locks). supabase_flutter + google_fonts. Feature-first
  lib/ structure (core/config, core/supabase, shared/theme, shared/widgets, empty
  features/auth + features/couple placeholders). White+Mint theme scaffold (Space
  Grotesk/DM Sans). Keys via --dart-define-from-file: env.json GITIGNORED + verified
  clean (NOT in repo); env.example.json committed as template. Verified: analyze clean
  (1 info re anonKey deprecation, left as-is), tests pass, RUNS + CONNECTS to Supabase
  ('Supabase init completed', foundation screen renders).
- ✅ AUTH FLOW (email/password) — BUILT & COMMITTED (e0b432c, 16 files), NOT yet
  device-tested (batched testing before Layer 2). Welcome screen (Sign In/Sign Up
  toggle, no carousel), signup w/ 18+ gate + terms, check-email/verify + resend,
  sign-in, forgot-password (send only; set-new-password deferred to OAuth task w/ deep
  links). Riverpod auth-state stream = source of truth; auth_repository wraps Supabase.
  Silent home_timezone capture on first sign-in. Placeholder home screen. INTERNET
  permission fixed in release manifest. Apple/Google sign-in = LATER task (needs OAuth
  config; will also bring deep-links + password-reset completion).
- ✅ COUPLE-LINKING — BUILT & COMMITTED (fbebf85). Backend: create_couple /
  regenerate_invite / join_couple (SECURITY DEFINER, row-locked, race-safe, vault-rule
  enforced) + enforce_two_members trigger backstop — all live & VERIFIED in Supabase
  (ran individually after the batch-paste silently didn't run — verify-don't-assume
  caught it). Realtime enabled on couples table. App: couple_repository (RPCs +
  realtime watch), CreateOrJoin / InviteWaiting (QR + share link + regenerate +
  realtime waiting→connected) / JoinScreen (scan QR or paste code + dead-link
  messages), AuthGate→CoupleGate→Home wiring, cute couple-name generator, CAMERA perm
  verified. Packages: qr_flutter, mobile_scanner, share_plus. Deep-link auto-open still
  deferred to OAuth task (paste-code fallback for now).

★ LAYER 1 CODE COMPLETE. Commits: 34913c5 (scaffold+Supabase), e0b432c (auth),
  fbebf85 (couple-linking). Database 16 tables + full RLS/vault ✅, auth ✅, linking ✅.

- ⏭️ THE GATE BEFORE LAYER 2: BATCH DEVICE TEST of the full Layer 1 flow on real
  device(s) — sign up → verify → sign in → create couple → (2nd account/device) join
  via QR or paste-code → watch SIMULTANEOUS unlock → dead-link cases. Needs TWO accounts
  (couple = 2 people). APK is 69.5MB (grab via local-wifi/adb/cloud). NOT device-tested
  yet. Do NOT build Layer 2 until this passes.
- STILL DEFERRED within Layer 1 scope: Apple/Google sign-in (OAuth task — also brings
  deep-links + password-reset completion). Could be done as part of finishing L1 or
  early L2 — decide later.

**TESTING RULE (J's preference, locked):** Do NOT use the Flutter emulator/simulator
unless truly necessary. Claude Code should BUILD THE APK for J to install + test on his
own real device. (Real-device testing is the real test anyway, per ground rules — and
avoids the iOS-sim hassle hit during scaffold.)
- NOTE for the linking flow: the join step needs a controlled path for Partner B to
  read an invite/couple they're not yet a member of (RLS baseline is strict on purpose).
  Handle via a SECURITY DEFINER function (join_couple(token)) — flagged during Part 2.

**STILL OPEN (none block the build):**
- THE NAME — "Bond" taken by 4+ apps; brainstorm a distinct one before launch.
- GIRLFRIEND-LIST (mostly settled by J as his calls, changeable): daily-prompt rhythm
  & expiry (chose generous window), which games launch (J leaning all 6). Design +
  colors now LOCKED (Modern & Fresh, white+mint, Space Grotesk, mint creature).
- First-users strategy (own session, nearer launch). Anthropic credits (apply anytime).
- Storage limits per tier (numbers at build time). Store-compliance + age gate (pre-submission).

WORKFLOW: J runs Supabase SQL in browser + Claude Code does repo/app code; Claude(brain)
writes prompts + holds plan. Build layer-by-layer, verify each step (don't trust —
check), test on two physical devices before advancing a layer.

## SESSION LOG

### 2026-09-02 — BUILD SESSION (part 30): couple-linking built — ★ LAYER 1 CODE COMPLETE
- Ran the couple-linking SQL (3 SECURITY DEFINER fns + enforce_two_members trigger +
  Realtime on couples). NOTE: the batch paste silently didn't run (SQL Editor quirk) —
  the verification query caught only current_couple_id existed, so ran each function
  INDIVIDUALLY and verified all 4 present. Classic verify-don't-assume save.
- Built the couple-linking app side (create/join/invite, QR scan+generate, share link
  w/ paste-code fallback, realtime simultaneous unlock, dead-link messages). Committed
  fbebf85. CAMERA perm verified in release manifest.
- ★ LAYER 1 CODE COMPLETE (scaffold+Supabase, auth, linking). NOT device-tested yet —
  the batch device test (needs 2 accounts) is THE GATE before Layer 2.
- APK 69.5MB; J grabbing it himself to test later.

### 2026-09-02 — BUILD SESSION (part 29): email/password auth built + committed
- Built full email/password auth (welcome/toggle, signup+18+/terms, verify+resend,
  signin, forgot-password send). Riverpod stream state, auth_repository over Supabase,
  silent timezone capture, placeholder home. Fixed release-manifest INTERNET perm.
  Committed e0b432c. NOT device-tested yet — J batching auth+linking test before L2.
- APK built (49.7MB) but J will copy it to his phone himself + test later.
- NEXT: couple-linking (join_couple SECURITY DEFINER fn + Realtime unlock).

### 2026-09-02 — BUILD SESSION (part 28): Flutter scaffold + Supabase connected (COMMITTED)
- Flutter app scaffolded into repo + connected to Supabase, VERIFIED running
  ('Supabase init completed', foundation screen renders white+mint). Committed 34913c5
  (78 files) + pushed. env.json verified OUT of git (keys stayed local).
- Claude Code caught + fixed a real .gitignore inline-comment bug that had left env.json
  UN-ignored (placeholders only, no leak) — verify-don't-assume paid off again.
- LOCKED testing rule: APK-on-real-device, no emulator unless necessary.
- NEXT: auth flow (signup/login).

### 2026-09-02 — BUILD SESSION (part 27): LAYER 1 database built + verified
- COOKING STARTED. Created BOND Supabase project (free org, after an accidental Pro
  upgrade J is downgrading + emailing support for refund):
  https://hzvxqafbcxpncuuukrpd.supabase.co
- Built the ENTIRE Layer 1 database via 4 SQL migrations in the Supabase SQL Editor:
  core identity + auto-profile trigger, core RLS (current_couple_id helper + vault
  rule), all feature tables, all feature RLS (incl. DB-level mutual prompt lock,
  read-only subscriptions). VERIFIED 16 tables present (checked, not assumed — Turf lesson).
- Next: Flutter init + connect to Supabase, then auth + couple-linking flow.

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
