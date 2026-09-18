# Duel — Real-Time Multiplayer Trivia Quiz

A live 1v1 trivia duel app built with Flutter and Firebase. Two players get matched in real time, answer the same questions simultaneously, and see each other's answers, speed, and score update live. Features an animated answer race, ELO-based rating system, and a global leaderboard.

---

## Table of Contents

- [Features](#features)
- [Screens](#screens)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Firebase Setup](#firebase-setup)
- [Firestore Data Model](#firestore-data-model)
- [Real-Time Matchmaking](#real-time-matchmaking)
- [Scoring System](#scoring-system)
- [Design System](#design-system)
- [Getting Started](#getting-started)
- [Build & Run](#build--run)

---

## Features

### Core Gameplay
- **Real-Time 1v1 Duels** — Two players answer the same trivia questions simultaneously with live sync via Firestore
- **Live Answer Race** — Animated horizontal race showing both players' progress in real time, driven by actual Firestore timestamps
- **20-Second Round Timer** — Auto-resolves unanswered rounds; submits timeout answers for both players to prevent deadlocks
- **3-2-1 Countdown** — Dedicated countdown screen with animated pulsing numbers before the match begins
- **Animated Score Count-Up** — Scores animate smoothly between rounds using Flutter animation

### Matchmaking
- **Public Matchmaking** — Tap "Play", select category/difficulty/rounds, and get matched with a random opponent
- **Play with Friends** — Create private rooms with 6-character invite codes, share via clipboard or system share
- **Category Selection** — 24 trivia categories from Open Trivia DB (General Knowledge, Film, Music, Science, Sports, etc.)
- **Difficulty Filter** — Easy, Medium, Hard, or Any
- **Configurable Rounds** — 3, 5, 7, or 10 rounds per match

### Player System
- **Anonymous Sign-In** — Zero-friction entry; no login required to play
- **Email Sign-Up/Sign-In** — Optional account linking to preserve stats across devices
- **Remember Me** — Credentials stored locally via Hive for seamless re-login
- **Player Profiles** — Display name, avatar initial, win/loss/draw stats

### Scoring & Ranking
- **ELO Rating System** — K-factor 32; rating changes based on opponent strength
- **Streak Bonus** — +2 rating per consecutive win (max +10 bonus)
- **Rating Floor** — Minimum rating of 100, maximum 9999
- **Win Rate** — Calculated as wins / total games played
- **Best Streak Tracking** — Highest consecutive wins recorded

### Social
- **Global Leaderboard** — Ranked list of all players sorted by ELO rating
- **Leaderboard Badges** — 🥇 🥈 🥉 medals for top 3, fire streak indicator
- **Share Results** — Share match outcome via system share sheet
- **Match History** — Recent 20 completed matches with win/loss/draw indicators

### UI/UX
- **Dark & Light Themes** — Full theme support with toggle; persisted via Hive
- **Hanken Grotesk + Space Grotesk** — Modern typography pairing throughout
- **Coral/Teal Player Colors** — Consistent color coding: coral = you, teal = opponent
- **Animated Transitions** — Scale, fade, and slide animations via `flutter_animate`
- **Responsive Layout** — Works across phone sizes with scrollable content

---

## Screens

| # | Screen | Description |
|---|--------|-------------|
| 1 | **Home** | Stats summary (wins/losses/streak), Play button, Play with Friends, Leaderboard, Settings, recent match history (max 5 inline, "View All" bottom sheet for 20) |
| 2 | **Auth** | Sign up / Sign in with email, continue as guest, remember me, password visibility toggle, prefix icons, keyboard navigation |
| 3 | **Category** | Choose rounds (3/5/7/10), difficulty (Any/Easy/Medium/Hard), topic (24 categories + Any), Find Match button |
| 4 | **Matchmaking** | Searching animation with radar circles, nearby players list, "Player Found!" confirmation screen with animated checkmark |
| 5 | **Countdown** | 3-2-1-GO! with pulsing animation, opponent avatar and name, round count badge |
| 6 | **Match** | Core game screen — scores with avatars, question text, 4 answer options, live answer race, status button |
| 7 | **Round Result** | Round complete screen, correct/incorrect indicator, animated score count-up, auto-advances after 3 seconds |
| 8 | **Match Result** | Final score, win/loss/draw with animated icon, share result button, back to home |
| 9 | **Leaderboard** | Your rank/win rate/rating header, top players list with medals, streak badges, win rate + games played |
| 10 | **Settings** | Account info, theme toggle (light/dark), sound effects toggle, notifications toggle, about dialog, sign out |
| 11 | **Room** | Create room (generates 6-char code), join room (enter code), share/copy code, preference chips, category/difficulty/rounds selection |

---

## Tech Stack

| Purpose | Package / Service |
|---------|-------------------|
| Framework | Flutter (Dart SDK ^3.13.1) |
| Real-time Database | Cloud Firestore (`cloud_firestore: ^6.8.0`) |
| Authentication | Firebase Auth (`firebase_auth: ^6.6.1`) — Anonymous + Email |
| Push Notifications | Firebase Cloud Messaging (`firebase_messaging: ^16.6.0`) |
| Local Notifications | `flutter_local_notifications: ^18.0.1` |
| State Management | Flutter Riverpod (`flutter_riverpod: ^3.4.3`) |
| Trivia API | Open Trivia DB (`opentdb.com`) — free, no API key |
| HTTP Client | `http: ^1.2.0` |
| Reactive Streams | RxDart (`rxdart: ^0.28.0`) |
| Fonts | Google Fonts (`google_fonts: ^8.2.1`) — Hanken Grotesk + Space Grotesk |
| Animations | `flutter_animate: ^4.5.2` |
| Local Storage | Hive (`hive: ^2.2.3`, `hive_flutter: ^1.1.0`) |
| Sharing | `share_plus: ^10.1.4` |

No paid packages. No paid Firebase tier required.

---

## Architecture

### State Management (Riverpod)

| Provider | Type | Purpose |
|----------|------|---------|
| `authStateProvider` | `StreamProvider<User?>` | Firebase auth state stream |
| `authProvider` | `Provider<AuthService>` | Sign in/out/up methods |
| `storageServiceProvider` | `Provider<StorageService>` | Hive local storage |
| `themeProvider` | `NotifierProvider<ThemeNotifier, ThemeMode>` | Dark/light theme persistence |
| `currentPlayerProvider` | `StreamProvider<Player?>` | Current user's Firestore player document (reactive to auth changes) |
| `matchHistoryProvider` | `StreamProvider<List<Map>>` | Last 20 completed matches (reactive to auth changes) |
| `currentMatchProvider` | `StreamProvider<Match?>` | Active match for current user |
| `matchByIdProvider` | `StreamProvider.family<Match?, String>` | Specific match by document ID |
| `matchPreferencesProvider` | `NotifierProvider<MatchPreferencesNotifier, MatchPreferences>` | Category/difficulty/rounds selection |
| `waitingPlayersProvider` | `StreamProvider<List<WaitingPlayer>>` | Real-time list of players waiting for matches |
| `leaderboardProvider` | `StreamProvider<List<Player>>` | Top 500 players by rating |
| `gameServiceProvider` | `Provider<GameService>` | Match lifecycle: create, join, answer, resolve |
| `roomServiceProvider` | `Provider<RoomService>` | Private room creation and joining |
| `isWaitingForOpponentProvider` | `Provider<bool>` | Whether current user has a waiting match |

### Services

| Service | Responsibility |
|---------|---------------|
| `GameService` | Match creation, joining (with Firestore transactions), answer submission (with transactions), round resolution, timeout handling, player stats update |
| `RoomService` | Private room creation with 6-char codes, room joining |
| `AuthService` | Email sign-in/up, anonymous sign-in, sign-out (with player doc creation), account deletion, credential persistence |
| `NotificationService` | FCM token management, foreground/background notification handling, match result notifications |
| `OpenTriviaService` | Fetches questions from Open Trivia DB API, decodes HTML entities, shuffles options |
| `StorageService` | Hive-based local storage for auth credentials and remember-me preference |
| `PlayerService` | CRUD operations for player documents (used by various screens) |

---

## Project Structure

```
lib/
├── main.dart                          # App entry, Firebase init, theme setup
├── firebase_options.dart              # Firebase config (auto-generated)
│
├── models/
│   ├── match.dart                     # Match, RoundData, PlayerAnswer, MatchStatus
│   ├── player.dart                    # Player, PlayerStats
│   └── question.dart                  # Question model
│
├── providers/
│   ├── auth_provider.dart             # AuthService, authStateProvider
│   ├── game_provider.dart             # GameService, matchmaking, scoring providers
│   ├── player_provider.dart           # currentPlayerProvider, leaderboard, match history
│   ├── storage_service.dart           # Hive credential storage
│   └── theme_provider.dart            # Dark/light theme persistence
│
├── screens/
│   ├── home_screen.dart               # Main dashboard with stats + history
│   ├── auth_screen.dart               # Sign up / Sign in / Guest
│   ├── category_screen.dart           # Category + difficulty + rounds selection
│   ├── matchmaking_screen.dart        # Searching + "Player Found!" screen
│   ├── countdown_screen.dart          # 3-2-1-GO! countdown
│   ├── match_screen.dart              # Core trivia gameplay
│   ├── round_result_screen.dart       # Between-round result display
│   ├── match_result_screen.dart       # Final match outcome
│   ├── room_screen.dart               # Play with Friends (create/join room)
│   ├── leaderboard_screen.dart        # Global rankings
│   └── settings_screen.dart           # App settings
│
├── services/
│   ├── open_trivia_service.dart       # Open Trivia DB API integration
│   └── notification_service.dart      # FCM + local notifications
│
├── theme/
│   ├── app_colors.dart                # Light + dark color palettes
│   └── app_typography.dart            # Font definitions (Space Grotesk + Hanken Grotesk)
│
├── widgets/
│   ├── primary_button.dart            # Coral filled button
│   ├── secondary_button.dart          # Outlined button
│   ├── player_avatar.dart             # Colored ring avatar
│   ├── score_display.dart             # Score number + label
│   ├── answer_option_button.dart      # A/B/C/D answer option with state
│   └── live_answer_race.dart          # Animated race track widget
│
└── utils/
    └── seed_questions.dart            # Firestore question seeder (dev utility)
```

---

## Firebase Setup

### Prerequisites
- Flutter SDK (stable channel)
- A free Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

### Enable Services
1. **Authentication** → Sign-in method → Enable "Anonymous" and "Email/Password"
2. **Firestore Database** → Create database → Start in test mode (then add security rules)
3. **Cloud Messaging** → No setup needed (auto-configured)

### Connect to Project
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This generates `firebase_options.dart` automatically.

### Firestore Security Rules
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /players/{playerId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == playerId;
    }
    match /matches/{matchId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if request.auth != null;
    }
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Firestore Data Model

### `players/{uid}`
```json
{
  "displayName": "John",
  "email": "john@example.com",
  "isAnonymous": false,
  "wins": 15,
  "losses": 8,
  "draws": 2,
  "streak": 3,
  "bestStreak": 7,
  "rating": 1247,
  "totalMatches": 25,
  "fcmToken": "device_fcm_token",
  "createdAt": "2024-01-01T00:00:00Z",
  "lastSeen": "2024-01-15T12:30:00Z"
}
```

### `matches/{matchId}`
```json
{
  "player1Id": "uid_1",
  "player2Id": "uid_2",
  "player1Name": "John",
  "player2Name": "Jane",
  "player1Score": 30,
  "player2Score": 27,
  "currentRound": 3,
  "totalRounds": 5,
  "status": "active",
  "isPrivate": false,
  "roomCode": null,
  "categoryId": 21,
  "categoryName": "Sports",
  "difficulty": 2,
  "rounds": {
    "0": {
      "questionId": "opentdb_123_0",
      "questionText": "Which sport uses a shuttlecock?",
      "options": ["Tennis", "Badminton", "Squash", "Table Tennis"],
      "correctIndex": 1,
      "category": "Sports",
      "player1Answer": { "answerIndex": 1, "timeMs": 4500, "isCorrect": true, "answeredAt": "..." },
      "player2Answer": { "answerIndex": 2, "timeMs": 6200, "isCorrect": false, "answeredAt": "..." },
      "resolved": true
    }
  },
  "createdAt": "2024-01-15T12:00:00Z",
  "completedAt": null
}
```

### Match Status Flow
```
waiting → active → completed
```

---

## Real-Time Matchmaking

### Public Match Flow
1. Player taps **Play** → selects category, difficulty, rounds
2. `startMatchmaking()` deletes any stale waiting matches for the user
3. Queries Firestore for compatible waiting matches (sorted newest first)
4. **If found:** Joins via Firestore transaction (atomically checks status + player2Id)
5. **If not found:** Creates new match with prefetched questions, enters waiting state
6. MatchmakingScreen watches `matchByIdProvider(matchId)` for status change
7. When opponent joins → status becomes `active` → "Player Found!" → 3-2-1 countdown → Match

### Private Room Flow
1. Player creates room → 6-character code generated
2. Code displayed with copy + share buttons
3. Friend enters code → joins room → status becomes `active`
4. Both navigate to countdown → match begins

### Key Safety Mechanisms
- **Firestore transactions** on join prevent two players from joining the same match
- **Stale match cleanup** only deletes `waiting` matches (never `active` or `completed`)
- **Match document contains all questions** — both players see identical data without duplicate API calls

---

## Scoring System

### ELO Rating
- **Starting rating:** 1000
- **K-factor:** 32 (standard for online games)
- **Formula:** `change = K × (actualScore - expectedScore)`
  - Expected score: `1 / (1 + 10^((oppRating - myRating) / 400))`
  - Actual score: Win = 1.0, Draw = 0.5, Loss = 0.0

### Rating Changes
| Scenario | Change |
|----------|--------|
| Beat much weaker opponent | +1 to +4 |
| Beat equally rated opponent | +16 |
| Beat much stronger opponent | +28 to +50 |
| Draw with equal opponent | -10 to +10 |
| Lose to much weaker opponent | -38 to -50 |
| Lose to much stronger opponent | -1 to -6 |

### Streak Bonus
- Each consecutive win adds +2 rating (max +10 at 5+ streak)
- Streak resets on any loss or draw

### Round Points
| Scenario | Winner | Loser |
|----------|--------|-------|
| Both correct, different times | 10 pts (faster) | 7 pts (slower) |
| One correct, one wrong | 10 pts | 0 pts |
| Both wrong | 0 pts | 0 pts |
| Timeout | 0 pts | 0 pts |

---

## Design System

### Colors

| Token | Light | Dark | Role |
|-------|-------|------|------|
| `background` | `#FAF8F4` | `#0D1117` | Page background |
| `surface` | `#EFEBE4` | `#161B22` | Card/panel background |
| `surfaceVariant` | `#E4DFD7` | `#1C2128` | Input fields, subtle surfaces |
| `card` | `#FFFFFF` | `#21262D` | Elevated cards |
| `border` | `#D4CFC7` | `#30363D` | Borders, dividers |
| `ink` | `#171A1F` | `#E6EDF3` | Primary text |
| `inkSubtle` | `#6B7280` | `#8B949E` | Secondary text |
| `inkFaint` | `#9CA3AF` | `#484F58` | Disabled/hint text |
| `coral` | `#E5533D` | `#F85149` | Player 1 / Primary action |
| `teal` | `#2FB8AC` | `#3FB950` | Player 2 / Success |
| `gold` | `#D9A441` | `#D29922` | Correct answer / Win state |
| `onAccent` | `#FFFFFF` | `#0D1117` | Text on colored backgrounds |

### Typography

| Style | Font | Size | Weight | Use |
|-------|------|------|--------|-----|
| `scoreDisplay` | Space Grotesk | 48px | 700 | Score numbers |
| `display` | Space Grotesk | 28px | 600 | Screen titles |
| `h1` | Space Grotesk | 22px | 600 | Section headers |
| `body` | Hanken Grotesk | 16px | 400 | Body text, questions, answers |
| `caption` | Hanken Grotesk | 13px | 400 | Labels, metadata |
| `timer` | Hanken Grotesk | 16px | 500 | Tabular figures for scores |

### Player Color Mapping
- **Coral (`#E5533D` / `#F85149`)** = "You" — your score, your avatar ring, your answer highlight
- **Teal (`#2FB8AC` / `#3FB950`)** = "Opponent" — their score, their avatar ring
- **Gold (`#D9A441` / `#D29922`)** = Correct answer / Win confirmation

---

## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- Dart SDK ^3.13.1
- Firebase project with Firestore + Auth enabled

### Installation
```bash
# Clone the repository
git clone <repo-url>
cd duel_multiplayer_quiz

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run on connected device
flutter run
```

### Firebase Configuration
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Anonymous Authentication** and **Email/Password Authentication**
3. Create a **Firestore Database**
4. Run `flutterfire configure` to generate `firebase_options.dart`
5. Deploy Firestore security rules (see [Firebase Setup](#firebase-setup))

---

## Build & Run

```bash
# Debug mode
flutter run

# Release build (Android)
flutter build apk --release

# Release build (iOS)
flutter build ios --release

# Web
flutter build web --release

# Analyze for issues
flutter analyze
```

---

## How Real-Time Sync Works

### The Match Document
Both players subscribe to the same Firestore match document via `.snapshots()`. Every write (answer submission, round resolution) is instantly visible to both players' listeners.

### Answer Submission
1. Player taps an answer → `submitAnswer()` runs a Firestore transaction
2. Transaction atomically checks: document exists, match not completed, round valid, player hasn't already answered
3. Writes answer with `answerIndex`, `timeMs`, `isCorrect`, and `answeredAt` timestamp
4. After write, re-reads document and checks if both players answered

### Round Resolution
1. When both answers are present (or timeout fires), `_resolveRoundIfReady()` runs
2. Uses Firestore transaction to prevent concurrent overwrites
3. Computes points based on correctness and speed
4. Updates scores, marks round resolved, advances `currentRound`
5. On final round, sets status to `completed`

### Live Answer Race
- Progress is a function of real elapsed time, not decorative animation
- `myProgress = 0.1` (idle) → `0.6` (selected) → `1.0` (submitted)
- `opponentProgress = 0.1` (idle) → `0.3` (after you submit) → `1.0` (they submit)
- Animated via `AnimatedBuilder` with `Curves.easeOut`

---

## App Behavior Details

### Authentication
- On first launch: anonymous sign-in → player document created
- On sign-out: credentials cleared → re-signed in anonymously → new player document created
- On sign-up: email account created → Firestore player document created with display name
- Provider reactivity: `currentPlayerProvider` and `matchHistoryProvider` watch `authStateProvider` and rebuild when user changes

### Stale Match Cleanup
- Only `waiting` matches are deleted during matchmaking
- `active` and `completed` matches are never touched
- Prevents orphaned matches from blocking new matchmaking

### Round Timeout
- 20-second timer per round
- When timeout fires: submits timeout answers for BOTH players who haven't answered
- Prevents deadlock when one player disconnects
- Re-reads document and triggers resolution

### Match History
- Only `completed` matches appear in history
- Sorted by `createdAt` descending
- Limited to 20 most recent

### Leaderboard
- Shows all players with `totalMatches > 0`
- Sorted by rating descending (ELO)
- Top 3 get medal icons (🥇 🥈 🥉)
- Players with 2+ win streak get fire badge (🔥)
- Shows win rate percentage and total games played

---

## License

This project is for educational and portfolio purposes.
