# Duel — Real-Time Multiplayer Quiz (Flutter)

A live 1v1 trivia duel app: two players matched in real time, answering the same questions simultaneously, with live score sync and an animated answer race. Built to be free to run indefinitely and to still work reliably whenever someone tries it — including an interviewer opening it cold after it's sat untouched for weeks.

---

## Why Firebase over Supabase for this specific app

Both are free and capable, but for a portfolio app that needs to survive long idle periods, they behave differently:

- **Supabase's free tier auto-pauses a project after 7 days of inactivity** — the next request after that takes 10-30 seconds to cold-start, and if you don't catch it and manually restore the project, a recruiter opening your app could hit a dead connection entirely.
- **Firebase's free (Spark) tier has no equivalent pause behavior.** It stays live indefinitely at zero cost within its usage caps, which is the property that actually matters here.

This is the one architectural decision in this whole project where "free" and "reliable" genuinely pointed to different providers — Firebase is the right call specifically because this is a portfolio piece, not because it's objectively better for every use case.

---

## Tech stack

| Purpose | Package / service |
|---|---|
| Real-time data sync | `cloud_firestore` (Firestore, free Spark tier) — used for match state, live answers, scores |
| Anonymous auth (no login friction for a recruiter trying it) | `firebase_auth` with anonymous sign-in |
| Trivia question data | Open Trivia DB (`opentdb.com`) — free, no API key, no rate limit that matters at this scale |
| State management | `flutter_riverpod` |
| Fonts | `google_fonts` — Space Grotesk + Inter |
| Animation | `flutter_animate` for the score count-up and answer-reveal states; the live answer race is a custom `AnimatedBuilder` driven by real Firestore timestamp deltas |
| Local persistence (match history, settings) | `hive` + `hive_flutter` |

No paid packages, no paid tier required anywhere in this stack.

---

## How real-time matchmaking and sync actually work

This is the core engineering of the app — worth understanding before you start building, not just copying code.

### 1. Matchmaking
- Player taps "Play" → app writes a document to a `waitingRoom` collection with their ID and timestamp.
- App listens for either: (a) another waiting player to pick them up, or (b) being picked up by someone else.
- Simplest free-tier-friendly approach: when a player joins the waiting room, query for one other existing waiting document; if found, both are moved into a new `matches/{matchId}` document and the waiting room entries are deleted. If none found, wait and listen for someone else to pick you up.
- This avoids needing a separate matchmaking server — Firestore's real-time listeners do the coordination.

### 2. The match document
```
matches/{matchId}
  players: [player1Id, player2Id]
  currentRound: 1
  questions: [ ...5 questions fetched from Open Trivia DB at match creation... ]
  rounds: {
    1: { player1Answer, player1AnsweredAt, player2Answer, player2AnsweredAt, resolved }
    ...
  }
```
Both players' apps subscribe to this one document with a real-time listener (`.snapshots()`). Every write either player makes (submitting an answer) is instantly visible to the other player's listener — this is what makes the live answer race actually live, not simulated.

### 3. Scoring
- When a player answers, write their answer + a server timestamp (`FieldValue.serverTimestamp()`, not the device's local clock — devices can have clock drift, and using the server's own clock keeps timing fair and consistent between two different phones).
- Once both players have answered a round (or a timeout expires), a simple client-side or Cloud Function-based resolver marks the round `resolved`, calculates who was correct/faster, and updates scores.
- For a portfolio-scope MVP, resolving client-side (whichever client sees both answers present, computes the result and writes it) is fine and avoids needing Cloud Functions at all — mention in your README/interview that a production version would move this to a server-side Cloud Function to prevent a malicious client from writing a fake result, and that you made a deliberate scope tradeoff here.

### 4. The live answer race animation
Driven directly by the real `player1AnsweredAt` / `player2AnsweredAt` server timestamps once both exist — the marker position is a function of actual elapsed time, not a fixed animation duration. This is the detail worth highlighting in an interview: the animation isn't decorative, it's a direct visualization of real data.

---

## Setup

### 1. Prerequisites
- Flutter SDK (stable channel)
- A free Firebase project (console.firebase.google.com) — enable Firestore and Anonymous Authentication

### 2. Install dependencies
```bash
flutter pub add firebase_core firebase_auth cloud_firestore
flutter pub add flutter_riverpod flutter_animate hive hive_flutter google_fonts
```

### 3. Connect Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This generates `firebase_options.dart` and wires up your platform config files automatically — no manual JSON file juggling.

### 4. Firestore security rules (don't skip this)
Free tier or not, an open Firestore database is a real risk — someone could write garbage data or run up your read/write quota. Set rules that only allow a player to write to a match they're actually a participant in:
```
match /matches/{matchId} {
  allow read, write: if request.auth.uid in resource.data.players;
}
```
This is also a good interview talking point — it shows you thought about security even in a portfolio-scope project, not just happy-path functionality.

### 5. Run
```bash
flutter run
```

---

## Build sequence

1. Set up Firebase project, anonymous auth, and confirm a basic Firestore read/write works before building any UI.
2. Build the theme (`app_colors.dart`, `app_typography.dart`) per `design.md`.
3. Build the matchmaking flow (§ above) — test with two devices/emulators simultaneously from the start; single-device testing will hide real sync bugs.
4. Wire up Open Trivia DB fetching at match creation — cache the 5 questions into the match document itself so both players see identical questions without a second API call each.
5. Build the match screen and answer submission flow, writing to Firestore with server timestamps.
6. Build the live answer race animation, driven by real timestamp data from step 5 — don't build this against mock data, build it against your actual working sync so the timing is honest.
7. Build round resolution and score count-up.
8. Build match result, home, and settings screens last.
9. Write the Firestore security rules (§4) before considering this "done" — this isn't a polish step, it's a correctness step.

---

## Play Store & App Store notes

- Anonymous auth means zero signup friction — a recruiter can open the app and be matched within seconds, which matters a lot for something meant to be tried on the spot.
- This app has clear, real functionality (live sync, matchmaking, scoring) well beyond Apple's Guideline 4.2 minimum-functionality bar.
- One honest practical note: since matchmaking needs another real player, consider adding a "practice mode" against a simple bot (answers after a randomized delay) so a solo recruiter can still experience the core loop without needing a second person online at the same time. This is worth building — a "requires 2 humans online simultaneously" app is a real friction point for a portfolio piece specifically.
