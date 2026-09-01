# BOND — Feature Deep-Dives

> Companion to `BOND_MASTER.md`. This file holds the detailed launch-version +
> future-version spec for each feature. The master file holds vision, stack,
> workflow, layer plan, ground rules, design, and the session log.
> Method: each feature gets a LAUNCH version (lean, build first) + FUTURE version
> (captured, off our mind) + data/schema implications. When all features here are
> done + schema + safety pass + AI/privacy decision → thinking phase closes.

**Last updated:** 2026-08-30 (split out from BOND_MASTER)

---

### MESSAGING [deep-dive DONE]

**LAUNCH VERSION:**
- Send: text + voice notes + photos (rich from day one).
- Reactions: emoji reactions on any message.
- Reply-to-specific-message (quoting a message). Important for couples —
  reacting/replying to a specific text IS the intimacy.
- Delete: BOTH options — "delete for me" OR "unsend for both."
- Media gallery: tap the couple header at top of chat → opens shared view with
  tabs: Photos & Videos / Voice notes / Links (newest first). Copies the proven
  WhatsApp/Instagram pattern. Voice-notes tab is emotional for couples.
  Gallery connects to Memory Vault — a shared chat photo is one tap from being
  saved as a memory. Chat and vault feed each other.
- Privacy: STANDARD PRIVATE at launch (Supabase row-level security so only the
  two partners can ever access; encrypted in transit + at rest). NOT fake E2E.
  Architected so true E2E can be added later as a premium/privacy upgrade.
  (Rationale: doing E2E wrong gives false security, worse than being honest.
  Promise exactly what we deliver.)

**CRITICAL TECHNICAL FIXES (learned from Turf's broken chat):**
Turf's chat had a 2-3 MINUTE delay on send because it inserted to DB then WAITED
for the realtime stream to echo the message back before showing it. Also, much
of Turf's chat was never verified end-to-end (trusted from IDE reports). BOND fixes:
1. OPTIMISTIC SEND — message appears instantly on sender's screen the moment they
   hit send; DB write + realtime broadcast happen in background. No frozen wait.
2. DEDUPLICATION — when the realtime echo returns, match against what's already
   shown so a message never appears twice. (Makes optimistic append safe.)
3. DELIVERY STATES — each message shows real state: sending → sent → delivered →
   read. If something IS slow, user sees "sending," not a frozen screen.
4. CLEAN CHANNEL LIFECYCLE — realtime subscription opens on entering chat, closes
   on leaving. No leaks / stale connections (a common "stopped updating" cause).
5. TEST GATE (the Turf process lesson): messaging is NOT "done" until the full
   path is proven on TWO PHYSICAL DEVICES — send, receive, reaction, reply, voice
   note, photo, delete — confirmed live, never trusted from an IDE report.

**FUTURE VERSION:**
- True end-to-end encryption (premium/privacy upgrade).
- Message search (WhatsApp-style keyword search in chat).
- Centralized media hub across all content.
- More gesture types beyond soft ping.

**STILL OPEN (ask girlfriend / decide later):**
- Typing indicators + online presence ("online now") — J leaning NO, but keep on
  the list to ask girlfriend. Not in launch unless she wants it.
- Storage limits / space allocation per tier (free vs BOND+) — TBD, comes back
  with the overall storage-cost decision. Chosen model: free tier limited,
  unlimited for BOND+.
- "Last seen" — not decided.

---

### DAILY PROMPTS & THE REVEAL MOMENT [deep-dive: mostly done, timing parked]

The emotional core of the app. One shared prompt; both answer privately; reveal together.

**LOCKED — core mechanics:**
- ONE shared prompt per day for the couple (not per-person — same prompt for both).
- Couple can REQUEST A NEW ONE if they don't like the one they got.
- THE ANSWER LOCK (the magic, = how Paired does it): neither partner sees the
  other's answer until BOTH have submitted. You write your honest answer BEFORE
  seeing theirs (removes pressure to match energy / copy their vibe). Then both
  answers reveal SIMULTANEOUSLY — a shared moment, not "answer then peek."
- AFTER THE REVEAL: reactions (emoji) on each other's answers AND the reveal can
  flow into a conversation ("talk about it" opens/continues chat). Both, not either.
- HOME TIMEZONE captured during account setup (needed for any shared-clock timing).

**PARKED — ask girlfriend (options already worked out, just pick):**
- Daily RHYTHM & EXPIRY. J chose "expires at end of day" but the timezone problem
  makes strict per-person midnight BREAK the mutual lock (see below). Options to
  choose from:
  (a) Couple's SHARED timezone — one clock, both always see the same prompt (safe).
  (b) Shared timezone + GENEROUS window — doesn't die at strict midnight; lives
      until the next prompt replaces it. (Claude's recommendation — most forgiving
      for long-distance.)
  (c) Let long-distance couples pick which partner's zone is "home."
- Whether missed prompts are gone forever vs revisitable.

**WHY per-person midnight breaks it (important — don't let this regress):**
The mutual lock REQUIRES both partners answering the SAME prompt in the SAME
window. If each has their own local midnight, long-distance partners can be on
DIFFERENT DAYS seeing DIFFERENT prompts at the same moment → they can never answer
the same prompt → the simultaneous reveal becomes impossible. The prompt belongs
to the COUPLE and must live on ONE shared clock. This is exactly the timezone
problem flagged earlier; it hits prompts hardest.

**FUTURE VERSION:**
- AI-personalized prompts (Claude, via Edge Function) that learn the couple over
  time — draw on their persona, recent activity, mood. (MVP can start with a
  strong curated prompt bank + light personalization; full personalization later.)
- "Deeper" bonus prompts / themed prompt packs (Valentine's, anniversary, etc.).
- Prompt history browsing (revisit past answers — ties to a keepsake feeling).

**DATA/SCHEMA IMPLICATIONS:**
- prompts belong to couple_id, on the couple's shared timezone.
- prompt_responses locked per user until both submitted; reveal flips a state that
  Realtime broadcasts to both devices simultaneously (same pattern as messaging).
- couples table needs home_timezone (set at setup).

---

### LIVE GAMES [deep-dive: engine + philosophy locked, per-game details parked]

The potential viral feature — nobody else has real-time couple games. Also the
MOST technically complex feature. Strategy: build the shared ENGINE once, each
game plugs into it.

**LOCKED — engine & philosophy:**
- The 5 games (all intended, but see launch-scope note): Would You Rather, Truth
  or Dare, Hot Take Battle, Who Said It? (past messages as trivia), Couple Quiz.
- LIVE vs ASYNC is a PER-GAME property, not one global rule. Some games are
  "live-preferred" (Truth or Dare, Hot Take Battle — the fun is being together),
  some are "async-friendly" (Who Said It?, Couple Quiz). Would You Rather works
  both ways. THE ENGINE SUPPORTS BOTH MODES FROM THE START — each game just picks
  which mode(s) it allows. Build the flexible foundation once, flip a setting per
  game. (So "decide live/async per game later with girlfriend" costs nothing技术.)
- DISCONNECT/QUIT mid-game → PAUSES & can be resumed later, nothing lost.
  (Zero-guilt principle applied to games. No freezing, no penalty.)
- Games FEED the baby AI's mood AND the bond score/XP. Playing together = the kind
  of connection that makes the creature happy and earns couple XP. Connective
  tissue tying games to the entity they're raising.

**CLAUDE'S RECOMMENDATION ON LAUNCH SCOPE (J leaning "all 5"):**
Games are the most complex feature — each has its own rules, screens, edge cases.
Recommend: build the shared engine + 2-3 games for LAUNCH, other 2-3 as fast-
follows. Same games, all still happening — just not 5 fighting for attention in
the first build. Fewer bugs, faster launch. J's call; not yet finalized.

**PARKED — ask girlfriend:**
- Add more game ideas.
- Decide live vs async PER GAME (she has good instincts on which need to be together).
- (If accepted) which 2-3 games are the launch set vs fast-follow.

**FUTURE VERSION:**
- More games / game packs.
- Spicy-mode games (18+, opt-in-by-both) — note: store-compliance research needed
  BEFORE building (flagged in safety pass).
- "How well do you know me?" style deeper games.

**DATA/SCHEMA IMPLICATIONS:**
- game_sessions (couple_id, game_type, mode live|async, status waiting|active|
  paused|completed, started_at, ended_at).
- game_moves (session_id, user_id, move_data jsonb) — Realtime syncs moves to both
  devices; simultaneous reveal via broadcast (same pattern as prompts/messaging).
- Paused sessions persist so they can be resumed.
- On completion → award bond XP + trigger baby AI reaction.

---

### MEMORY VAULT [deep-dive DONE]

The keepsake heart. One shared vault, everything is "ours" — fits the couple-
entity thesis. Connects to messaging (chat media gallery feeds the vault).

**LAUNCH VERSION:**
- Save: photos + videos + captions (rich from day one).
- ONE FULLY SHARED vault — no "mine vs yours," every memory belongs to both.
  Most on-brand (couple = one entity) AND simplest to build.
- Organization: AUTO BY DATE — timeline, newest first. Zero effort from the couple,
  matches how people naturally scroll back ("last summer"). Albums + milestone-
  tagging are FUTURE.
- FLASHBACKS at launch — "1 year ago today" surfaces old memories via notification.
  Emotionally huge, technically cheap (daily check for date-matching memories → push).

**CUT (not even future unless J revives it):**
- TIME CAPSULES — removed entirely. Nice idea but not core to what the vault is for;
  cutting keeps launch focused. (First feature actively CUT vs deferred — healthy.)

**FUTURE VERSION:**
- Relationship Chapters — each month auto-becomes a story chapter (mood arc,
  highlights, AI-written recap). DEFERRED because (1) needs months of accumulated
  data to work at all — useless for a brand-new couple, and (2) leans on the AI
  layer which is undecided. Natural "few months post-launch" feature.
- Custom albums / collections.
- Milestone auto-tagging of special moments.
- Voice notes attached to memories.

**DATA/SCHEMA IMPLICATIONS:**
- memories (couple_id, media_url, media_type photo|video, caption, taken_at date,
  created_at). Belongs to couple, not user (fully shared).
- Media in Supabase Storage, PRIVATE bucket, signed URLs only (never public).
- Flashback = scheduled daily check for memories where taken_at matches today's
  month/day in prior years → FCM push.
- STORAGE LIMITS still open (see below) — VIDEO is the big cost driver; the free-
  vs-BOND+ line matters most on video.

**STILL OPEN (storage decision, shared with messaging):**
- Storage caps / space per tier (free limited, unlimited BOND+ is the chosen model;
  actual numbers TBD). Video length + size limits. Compression before upload.

---

### MOOD / BOND SCORE / BOND FLAME [deep-dive DONE]

Three faces of ONE engine: the flame (simple visible number), the bond score
(permanent progress), the creature's mood (emotional expression). All computed
from the same underlying connection data.

**WHAT EARNS CONNECTION (locked):**
- EVERYTHING counts — messaging, prompts, games, memories, mood check-ins. No
  hierarchy of "worthy" connection; any form of connecting feeds the bond.
- Design principle (for tuning, not a feature): light touch so it CAN'T be gamed —
  spamming 100 one-word texts shouldn't rocket the score. The FEEL should be "we
  connected today," not "grind for points." Tune numbers with this in mind.

**BOND SCORE (locked):**
- Permanent "how far we've come" number. ONLY EVER GOES UP. Never decreases.
- Quietly powers the creature's growth + evolutions (so it MEANS something) but is
  NOT shoved in your face as a big competitive score.

**THE BOND FLAME (locked) — Snapchat flame, reimagined WITHOUT the cruelty:**
- Reference: Snapchat streaks (simple flame + shared number = the appeal). BUT
  Snapchat's mechanic RESETS TO ZERO on a missed day, and its whole engine is the
  FEAR of losing it — textbook guilt/anxiety design. That DIRECTLY violates BOND's
  zero-guilt spine. So we take the simplicity + shared pride, DROP the punishment.
- A simple flame + number, shared by the couple, on the home screen.
- Grows with connection — number goes UP the more you connect.
- NEVER RESETS TO ZERO. Busy/quiet times → it dims/cools visually and pauses, then
  resumes when you return. The NUMBER NEVER BURNS DOWN.
- NO hourglass-of-doom. NO "your streak is about to break!" anxiety pings.
- Rationale (decided with conviction): a relationship app must NEVER manufacture a
  reason for partners to be annoyed at each other ("you broke our streak"). Keeps
  100% of the pride ("we've connected 200 days"), throws away only the fear.
  Slightly less addictive than Snapchat's cruelty by design — that's the correct
  trade for a relationship product; kindness is more durable + is itself a
  differentiator ("this app is so kind").

**THE CREATURE'S MOOD (locked) — emotional face of the same engine:**
- Always happy to see you (warm floor, never distress).
- Blooms MORE when you connect (recent connection = thriving/bright); quiet times =
  calm/resting (never sad or sick). Difference is "peacefully resting vs joyfully
  thriving," never "happy vs sad."
- WARM "missed you" ON RETURN — after a gap it can greet with "I missed you two 🤍",
  acknowledging time with warmth.
- HARD GUARDRAILS: never counts days, never shames, never pressures. And CRITICALLY —
  NO guilt-pings while you're away ("come back, I'm lonely 😢" = BANNED). Missing you
  when you return = sweet; pinging while you're gone = toxic. This line (warmth on
  return, silence while away) is what makes it a companion, not a monitor.

**DATA/SCHEMA IMPLICATIONS:**
- couples.bond_score (int, monotonic — only increases).
- A connection/activity signal feeds flame level + creature mood; store enough to
  compute "recent connection" (e.g. recent activity timestamps) — mood is derived,
  not stored as a fixed value.
- Flame "cools/dims" = a display state derived from recency; the stored count never
  decrements.
- This is PLAIN CODE, not AI (per the baby-AI "4 jobs" split — state/mood/growth is
  free logic, no model calls).

---

### DISCOVER [deep-dive DONE]

"What should we do?" — restaurants, movies, attractions, date ideas.

**BIG DECISION — NO standalone Discover page. Discover lives ENTIRELY through the
baby AI.** You ask the creature ("find us Thai food nearby," "what should we watch")
and it pulls it up. Rationale: a separate browse/filter tab would just be a second
door to the same room = duplication. This also makes the creature genuinely useful
(solves the "what does it actually DO" question). Locked.

**HOW RESULTS SHOW (important — not a page, but not plain text either):**
- The creature renders RICH RESULT CARDS right in the conversation — restaurant
  cards with name, photo, rating, tap-to-open-in-maps; movie posters you can tap.
- It replaces NAVIGATION (no browse UI), not DISPLAY (results still look good).
- So: creature is the search box, beautiful results appear right below, all inside
  the chat with the creature.

**DATA SOURCES (the real plumbing — cutting the page changed interface, not plumbing):**
- MOVIES/SHOWS → TMDB. Free, excellent, industry standard, no billing surprises. Locked.
  (OMDb is the only real alt; TMDB is strictly better + free, so no tradeoff.)
- RESTAURANTS/PLACES → Google Places, but CAGED:
  * IMPORTANT 2026 pricing change: Google RETIRED the old $200/mo universal credit
    (March 2025). Now per-SKU free tiers (~10k basic / 5k pro calls/mo) then pay per
    1k. Asking for rating/photos/reviews RE-PRICES THE WHOLE CALL to the most
    expensive tier (~$40/1k). Requires a credit card, NO hard cap by default →
    surprise-bill risk (matters for a solo dev with no backup).
  * MITIGATIONS (required, not optional): request MINIMAL fields only (name,
    location, one photo) to stay in cheap tier; set a HARD QUOTA CAP in the console
    so a bug/spike CAN'T run up a bill; CACHE AGGRESSIVELY (50 couples asking "Thai
    in Atlanta" = fetch once, reuse — huge cost lever).
  * Put the places call behind a SWAPPABLE function (same principle as the AI Router)
    so we can switch providers without touching the app.
- FOURSQUARE → the cost-conscious ALTERNATIVE, kept ready. Historically more
  generous free tier for "places nearby," no field-tier trap. Swap to it if Google's
  bill ever creeps.

**FUTURE VERSION:**
- Swipe-to-match (both partners swipe to converge on a choice) — an INTERACTION, not
  a question, so it doesn't fit the pure-ask model cleanly. Future: the creature could
  SET UP a swipe round ("want me to start a swipe round?"). Deferred.
- Bucket list, "surprise us" as distinct flows — the creature can approximate these
  conversationally at launch; formalize later if wanted.
- Attractions/things-to-do beyond restaurants (same Places plumbing).

**DATA/SCHEMA IMPLICATIONS:**
- No Discover tables for browsing. Results are fetched live via Edge Function →
  external API (TMDB / Google Places / Foursquare) → rendered as cards in the creature
  chat. Cache layer for places results (by area+query) to cut cost.
- Ties to the baby-AI "assistant" job (the smart-tier model that does tool use).

---
