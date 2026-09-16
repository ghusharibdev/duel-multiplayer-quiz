# Design Document — Duel (Real-Time Multiplayer Quiz)

## 1. Concept

A live 1v1 trivia duel: two players get matched, answer the same questions simultaneously, and see each other's answers, speed, and score update in real time. The entire point of this app, both as a product and as a portfolio piece, is that the real-time sync has to feel instant and trustworthy — that's the engineering being demonstrated, and it needs to be visible, not hidden behind a loading spinner.

---

## 2. Design plan

### Fonts — two families, chosen for this app's specific personality

- **Display / headlines / scores:** Space Grotesk — a bold, geometric grotesk with real energy, fitting a live competitive app. Used for the app name, round numbers, and the score itself (the score is the emotional centerpiece of every screen, so it gets the boldest treatment in the app).
- **Body / UI:** Inter — neutral, extremely legible, disappears into the background so Space Grotesk can carry the personality. Used for questions, answer options, settings, everything else.
- Deliberately different from your other apps' Bricolage/Hanken pairing — this app's tone (fast, competitive, a little playful) is distinct enough from PassPhoto's document-utility register and Marginal's literary-notes register that reusing the same fonts everywhere would flatten three different products into one visual voice. Consistency-through-shared-fonts is a good instinct in general, but it should serve the product's actual tone, not override it.
- Type scale (mobile-first, base 16px): Score display (Space Grotesk) 48/52 weight 700, Display (Space Grotesk) 28/34 weight 600, H1 (Space Grotesk) 22/28 weight 600, Body (Inter) 16/24, Caption (Inter) 13/18.
- Numerals (scores, timers) use Inter with tabular figures enabled — no monospace face, even for the countdown timer; tabular Inter prevents digit-width jitter just as well without introducing a third typeface.

### Color — competitive but minimal, not garish

Two players need to be visually distinguishable at a glance, everywhere in the UI, without the app looking like a kids' game.

| Token | Hex | Role |
|---|---|---|
| `cream` | `#FAF8F4` | Base background |
| `ink` | `#171A1F` | Primary text |
| `coral` | `#E5533D` | Player 1 / "you" — used for your score, your answer highlights, your avatar ring |
| `teal` | `#2FB8AC` | Player 2 / opponent — used symmetrically for their score, answers, avatar ring |
| `gold` | `#D9A441` | Win state / correct-answer confirmation — used sparingly, only for the actual moment of being right or winning |
| `stone` | `#EFEBE4` | Card/surface tone, one step up from `cream` |

The coral/teal pairing is the functional core of the whole UI: once a player learns "coral is me, teal is them," that mapping should hold everywhere — score display, answer highlight, avatar border, victory screen — with zero exceptions, so the player never has to think about which side is which.

### Signature visual device: the live answer race

When both players are answering a question, show a simple horizontal race — two small markers (coral and teal) advancing toward the question as each player answers, with the marker's speed reflecting how fast they're actually answering (driven by real elapsed time, not decorative). First to answer correctly reaches the finish first; this is the single most "alive" moment in the app and should be built once, well, rather than adding secondary animations elsewhere.

### Layout concept — match screen

```
+-------------------------------+
|  Round 3 of 5                  |  <- Caption, quiet
|                                |
|  [coral avatar]  VS  [teal avatar] |  <- both scores directly beneath,
|      420            380         |     Space Grotesk, largest text on screen
|                                |
|  What is the capital of...     |  <- H1, question text
|                                |
|  [ Answer A ]                  |  <- large tap targets, full width,
|  [ Answer B ]                  |     highlight in coral/teal only
|  [ Answer C ]                  |     after both players have answered
|  [ Answer D ]                  |     (never before — no peeking)
|                                |
|  ---- live answer race ----     |  <- the signature animation, thin
|  coral marker >>>  teal marker >>|     strip beneath the options
+-------------------------------+
```

Centered score/avatar row at the top (the one deliberately symmetrical, centered element — appropriate here since the head-to-head framing is literally about two equal sides), everything below left-aligned for fast scanning.

### Motion principles

- The live answer race (above) is the one signature, continuously-driven animation — it should feel like it's happening in real time because it is, driven by actual server timestamps, not a fixed-duration fake animation.
- Score changes animate as a quick count-up (not an instant jump) when a round resolves — 400-500ms, eased out — this is the "did I win that round" moment and deserves to be felt, not just displayed.
- Correct/incorrect answer reveal: a brief `gold` flash on the correct option, `ink`-at-40%-opacity dim on the wrong ones — instant enough not to feel laggy, clear enough not to be missed.
- Matchmaking screen: a quiet, looping "searching" indicator — understated, since this is a waiting state, not a moment to showcase.
- Respect reduced-motion settings; the answer race has a simple instant-reveal fallback (show final positions without the animated approach).

### Writing/copy principles

- Round and match language is precise: "Round 3 of 5", not "Question 3" — reinforces that this is a match with a defined structure, not an endless quiz.
- End-of-match copy is plain, not over-the-top: "You won 3-2" or "Opponent won 4-1" — no forced enthusiasm language, let the actual result and the score-count-up animation carry the emotional weight.
- Matchmaking empty/waiting state: "Finding an opponent..." — honest about what's happening, not a cute euphemism.

---

## 3. Screens

1. **Home** — Play button (primary CTA, `coral` fill), recent match history, simple streak/stats summary.
2. **Matchmaking** — quiet waiting state, cancel option, auto-transitions to match screen once paired.
3. **Match** — the core screen described above, repeated per round.
4. **Round result** — brief (2-3 second) transition screen between rounds showing the answer race resolve and score update, then auto-advances.
5. **Match result** — final score, win/loss state, rematch button, share result.
6. **Leaderboard** (optional, if you add persistent ranking) — simple ranked list, your position highlighted in `coral`.
7. **Settings** — sound toggle, notification permissions, about.

---

## 4. Component notes

- **Answer option button**: full-width, `stone` background, `ink` text, 12px corner radius, no shadow at rest. On reveal: `gold` background + `ink` text if correct, `ink`-at-40%-opacity if incorrect and unselected, `coral`/`teal` border (matching whichever player picked it) if incorrect and selected.
- **Score display**: Space Grotesk 48/52, always paired with the avatar and colored ring (`coral` or `teal`) directly above it — score number should never appear without its color context, since color is what makes "whose score is this" instantly legible.
- **Primary button** (`coral` fill, `cream` text) vs **secondary button** (transparent, `ink` border) — consistent two-button-style discipline, same as your other apps.
