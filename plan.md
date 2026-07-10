# Skorio Tournaments — App Flow Plan

## 1. Router Overview (`lib/core/routing/router.dart`)

- **Initial location:** `/login`
- **Redirect logic:** `/` and `/login` → `/tournaments` if already authenticated
- **Page transition:** Custom `_slidePage()` — slide-in animation (280ms forward, 220ms reverse)

---

## 2. Screen Hierarchy

```
App
├── LoginScreen                          /login                  (no shell)
│
└── MainShell (persistent nav wrapper)
    ├── TournamentDashboardScreen        /tournaments/dashboard
    ├── TournamentsListScreen            /tournaments
    ├── TeamsScreen                      /teams
    ├── PlayersScreen                    /players
    ├── ProfileScreen                    /profile
    └── NotificationSettingsScreen       /notifications
│
├── PointsShopScreen                     /points-shop            (no shell)
├── CreateTournamentScreen               /tournaments/create     (no shell)
├── JoinTournamentScreen                 /tournaments/join       (no shell)
│
├── TournamentDetailScreen               /tournaments/:id        (no shell)
│   ├── Tab: Overview / Teams
│   ├── Tab: Matches
│   ├── Tab: Standings
│   └── Tab: Bracket (conditional on format)
│
├── TeamDetailScreen                     /teams/:id              (no shell)
├── PlayerProfileScreen                  /players/:name          (no shell)
├── PlayerRegistrationScreen             /tournaments/:id/register/:teamId
├── HeadToHeadScreen                     /tournaments/:id/h2h/:teamA/:teamB
├── LiveMatchScreen                      /tournaments/:id/live/:matchId
├── MatchQRScreen                        /tournaments/:id/matches/:matchId/qr
├── MatchScanScreen                      /tournaments/:id/matches/:matchId/scan
│
└── ScoringScreenRouter                  /tournaments/:id/matches/:matchId/score
    ├── CricketScoringScreen
    ├── FootballScoringScreen
    ├── TennisScoringScreen
    ├── PointGameScoringScreen           (badminton, table tennis)
    ├── ChessScoringScreen
    └── _GenericScoreScreen              (fallback)
```

---

## 3. All Routes Table

| Route | Screen | Shell? | Purpose |
|-------|--------|--------|---------|
| `/login` | `LoginScreen` | No | Phone + 6-digit PIN login/register |
| `/tournaments/dashboard` | `TournamentDashboardScreen` | Yes | Organizer hub |
| `/tournaments` | `TournamentsListScreen` | Yes | Browse all tournaments |
| `/tournaments/standings` | `TournamentsListScreen` | Yes | Standings view alias |
| `/teams` | `TeamsScreen` | Yes | Manage global teams |
| `/players` | `PlayersScreen` | Yes | Browse all players |
| `/profile` | `ProfileScreen` | Yes | User profile, XP, achievements |
| `/notifications` | `NotificationSettingsScreen` | Yes | Notification preferences |
| `/points-shop` | `PointsShopScreen` | No | Buy cosmetics, boosts, lifelines |
| `/tournaments/create` | `CreateTournamentScreen` | No | 6-step creation wizard |
| `/tournaments/join` | `JoinTournamentScreen` | No | Join via 6-char invite code |
| `/tournaments/:id` | `TournamentDetailScreen` | No | Details, tabs, bracket |
| `/teams/:id` | `TeamDetailScreen` | No | Squad management |
| `/players/:name` | `PlayerProfileScreen` | No | Career stats |
| `/tournaments/:id/live/:matchId` | `LiveMatchScreen` | No | Live score & events |
| `/tournaments/:id/register/:teamId` | `PlayerRegistrationScreen` | No | Register player to team |
| `/tournaments/:id/h2h/:teamA/:teamB` | `HeadToHeadScreen` | No | H2H match history |
| `/tournaments/:id/matches/:matchId/qr` | `MatchQRScreen` | No | Generate check-in QR |
| `/tournaments/:id/matches/:matchId/scan` | `MatchScanScreen` | No | Scan check-in QR |
| `/tournaments/:id/matches/:matchId/score` | `ScoringScreenRouter` | No | Sport-specific scoring |

---

## 4. Page-by-Page Detail

### LoginScreen
**File:** `lib/features/auth/presentation/login_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `GlassCard` | Container for form |
| `TextField` | Phone number input |
| `PinDigitBox` | 6-digit PIN input boxes |
| `TabButton` | Toggle Login / Register |

| Function | Action |
|----------|--------|
| `_handleSubmit()` | Authenticate with Supabase |
| `_switchMode()` | Toggle between login and register tabs |

**Navigation out:**
- `context.go('/')` → Redirected to `/tournaments` after login

---

### TournamentDashboardScreen
**File:** `lib/features/contests/presentation/tournament_dashboard_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `TopBar` | Custom app bar |
| `NavDrawer` | Side drawer nav |
| `GlassCard` | Quick action cards |
| `ListView` | Active tournaments list |

| Function | Action |
|----------|--------|
| `_showScheduleMatchDialog()` | Modal to schedule a fixture |
| `_buildQuickActionCard()` | Renders action buttons |

**Navigation out:**
- `context.push('/tournaments/create')` → Create new tournament
- `context.push('/tournaments/${id}')` → View tournament detail

---

### TournamentsListScreen
**File:** `lib/features/contests/presentation/tournaments_list_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `TextField` | Search bar |
| `FilterChip` | Sport filter chips |
| `_TournamentCard` | Individual tournament row |

| Function | Action |
|----------|--------|
| `_getTournamentStatus()` | Compute live/upcoming/completed |
| `_buildSportFilterChip()` | Render sport filter |

**Navigation out:**
- `context.push('/tournaments/create')` → FAB
- `context.push('/tournaments/join')` → Tune icon button
- `context.push('/tournaments/${id}')` → Tap on card

---

### CreateTournamentScreen
**File:** `lib/features/contests/presentation/create_tournament_screen.dart`
**Widget:** `ConsumerStatefulWidget`

**Steps (6-step wizard):**
1. Basic info (name, sport, date range)
2. Format (league / knockout / groups)
3. Rules (win pts, draw pts, loss pts)
4. Teams (add participating teams)
5. Draw method
6. Confirmation & submit

| Component | Purpose |
|-----------|---------|
| `Stepper` | Step-by-step wizard |
| `TextField` | Input fields per step |
| `DropdownButton` | Format & sport selectors |
| `Checkbox` | Rule toggles |

**Navigation out:** Implicit pop after creation

---

### TournamentDetailScreen
**File:** `lib/features/contests/presentation/tournament_detail_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Tab | Content |
|-----|---------|
| Overview / Teams | Team list, player rosters |
| Matches | Fixtures with status |
| Standings | Points table |
| Bracket | Knockout bracket (conditional) |

| Function | Action |
|----------|--------|
| `_ensureTabController()` | Initialize tab state |
| `_showAssignRefereeSheet()` | Bottom sheet to assign referee |

**Navigation out (inline):**
- Push to `LiveMatchScreen`, `ScoringScreenRouter`, `MatchQRScreen`, `MatchScanScreen`, `HeadToHeadScreen`, `PlayerRegistrationScreen`

---

### LiveMatchScreen
**File:** `lib/features/contests/presentation/live_match_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `Scoreboard` | Live score display |
| `ListView` | Event feed (goals, cards, subs) |

| Provider | Purpose |
|----------|---------|
| `matchEventsProvider` | Real-time Supabase subscription |

**Navigation out:** None (leaf screen)

---

### JoinTournamentScreen
**File:** `lib/features/contests/presentation/join_tournament_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `TextField` | 6-char invite code input |
| `ElevatedButton` | Submit to join |

| Function | Action |
|----------|--------|
| `_join()` | Search local cache then Supabase |

**Navigation out:**
- `context.push('/tournaments/${id}')` → After code found

---

### PlayerRegistrationScreen
**File:** `lib/features/contests/presentation/player_registration_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `TextField` | Player name, jersey # |
| `DropdownButton` | Position selector |
| `ElevatedButton` | Submit registration |

| Function | Action |
|----------|--------|
| `_submit()` | Add player to team via `tournamentsProvider` |

**Navigation out:** Pop after submit

---

### PlayerProfileScreen
**File:** `lib/features/contests/presentation/player_profile_screen.dart`
**Widget:** `ConsumerWidget`

| Component | Purpose |
|-----------|---------|
| `_PlayerHeader` | Avatar, name, position |
| `_CareerTotalsGrid` | Goals, assists, cards, MOTM, appearances |
| `GlassCard` | Per-tournament stat breakdown |

| Provider | Purpose |
|----------|---------|
| `careerStatsProvider` | Aggregate stats across all tournaments |

**Navigation out:** None (leaf screen)

---

### HeadToHeadScreen
**File:** `lib/features/contests/presentation/head_to_head_screen.dart`
**Widget:** `ConsumerWidget`

| Component | Purpose |
|-----------|---------|
| `GlassCard` | W/D/L summary, goal diff |
| `ListView` | H2H match history list |

**Navigation out:**
- `context.pop()` → Back

---

### TeamsScreen
**File:** `lib/features/contests/presentation/teams_screen.dart` *(new file)*
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `TextField` | Search teams |
| `ListView` | Team list |
| `FAB` | Create new team |

**Navigation out:**
- `context.push('/teams/${id}')` → Team detail

---

### PlayersScreen
**File:** `lib/features/contests/presentation/players_screen.dart` *(new file)*
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `TextField` | Search players |
| `ListView` | Player list |

**Navigation out:**
- `context.push('/players/${name}')` → Player profile

---

### TeamDetailScreen
**File:** `lib/features/contests/presentation/` *(team_detail_screen.dart)*
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `ListView` | Squad member list |
| `TextField` | Search/add player |

**Navigation out:**
- `context.pop()` → Back

---

### ProfileScreen
**File:** `lib/features/auth/presentation/profile_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `CircularProgressIndicator` | XP ring |
| `GlassCard` | Achievements, milestones |
| `GridView` | Achievement badges |
| `ListView` | Activity log |

| Function | Action |
|----------|--------|
| `_fetchXpLogs()` | Load XP history |
| `_showAchievementDetail()` | Modal with achievement info |
| `_buildTournamentProfile()` | Tournament-context profile view |

**Navigation out:**
- `context.push('/notifications')` → Notification settings
- `context.push('/points-shop')` → Points shop

---

### NotificationSettingsScreen
**File:** `lib/features/auth/presentation/notification_settings_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `Switch` | Toggle per notification type |
| `GlassCard` | Settings groups |
| `TextField` | Custom preference inputs |

| Function | Action |
|----------|--------|
| `_loadPreferences()` | Fetch saved settings |
| `_savePreferences()` | Persist to Supabase |

**Navigation out:** None (leaf screen)

---

### PointsShopScreen
**File:** `lib/features/auth/presentation/points_shop_screen.dart`
**Widget:** `ConsumerStatefulWidget`

| Component | Purpose |
|-----------|---------|
| `GridView` | Shop items grid |
| `GlassCard` | Item card with price |
| `ElevatedButton` | Purchase / equip |

| Function | Action |
|----------|--------|
| `_purchaseItem()` | Deduct points, grant item |
| `_buildShopItemCard()` | Render item card |
| `_formatDuration()` | Format boost timer |

**Navigation out:**
- `context.pop()` → Back

---

### MatchQRScreen & MatchScanScreen
**File:** `lib/features/contests/presentation/match_checkin_screen.dart`
**Widget:** `ConsumerWidget`

| Component | Purpose |
|-----------|---------|
| `QrFlutter` | Generate QR code for player |
| `MobileScanner` | Camera-based QR scanner |

| Provider | Purpose |
|----------|---------|
| `checkInProvider` | Track checked-in players |

**Navigation out:** None (leaf screens)

---

### ScoringScreenRouter
**File:** `lib/features/contests/presentation/scoring/scoring_screen_router.dart`
**Widget:** Dispatcher

Routes to sport-specific screen based on tournament sport:

| Sport | Screen |
|-------|--------|
| `cricket` | `CricketScoringScreen` |
| `football` / `soccer` | `FootballScoringScreen` |
| `tennis` | `TennisScoringScreen` |
| `badminton` / `table tennis` | `PointGameScoringScreen` |
| `chess` | `ChessScoringScreen` |
| *(anything else)* | `_GenericScoreScreen` |

All scoring screens call:
- `tournamentsProvider.notifier.updateMatchResult()` to persist results

---

## 5. Providers

### `tournaments_provider.dart`

**Models:** `Tournament`, `TournamentTeam`, `TournamentMatch`, `TournamentPlayer`

| Function | Action |
|----------|--------|
| `loadTournaments()` | Fetch all from Supabase |
| `addPlayerToTeam()` | Register player in tournament team |
| `updateMatchResult()` | Set final score |
| `addMatchToTournament()` | Schedule new fixture |
| `assignReferee()` | Assign referee to match |
| `updateMatchStatus()` | Change to live / completed |

---

### `teams_provider.dart`

**Models:** `GlobalTeam`, `GlobalPlayer`

| Function | Action |
|----------|--------|
| `loadTeams()` | Fetch all from Supabase |
| `createTeam()` | Create new global team |
| `addPlayer()` | Add player to global team |
| `updateTeam()` | Modify team details |

---

### `match_events_provider.dart`

**Models:** `MatchEvent`, `MatchEventType` (enum: goal, yellow/red card, sub, kickoff, fullTime)

| Function | Action |
|----------|--------|
| `watchMatch()` | Real-time Supabase subscription |
| `stopWatching()` | Unsubscribe |
| `addEvent()` | Log goal, card, substitution |

---

### `career_stats_provider.dart`

**Models:** `PlayerCareerStats`, `TournamentStatLine`, `StatLeader`

| Function | Action |
|----------|--------|
| `getCareerStats(playerName)` | Aggregate stats across all tournaments |

---

### Sport Scoring Providers

| File | Sport |
|------|-------|
| `cricket_scoring_provider.dart` | Innings, wickets, dot balls |
| `football_scoring_provider.dart` | Goals, assists, cards |
| `point_game_scoring_provider.dart` | Sets & points (badminton, table tennis) |
| `tennis_scoring_provider.dart` | Set / game / point |

---

## 6. Core Widgets (`lib/core/widgets/`)

| Widget | Purpose |
|--------|---------|
| `MainShell` | Shell wrapper with persistent nav |
| `GlassCard` | Frosted glass effect card |
| `TopBar` | Custom app bar |
| `NavDrawer` | Side navigation drawer |
| `PitchBackground` | Dynamic sport-themed background |
| `ParticleBackground` | Animated floating particles |
| `StaggeredEntrance` | Staggered list/item animation |

---

## 7. Navigation Methods Summary

| Method | When used |
|--------|-----------|
| `context.go('/path')` | Replace current screen (no back) |
| `context.push('/path')` | Push on stack (back button works) |
| `context.pop()` | Go back one screen |
| Route params `/path/:id` | Pass IDs through URL |
| `showDialog()` | Inline confirm/info dialogs |
| `showModalBottomSheet()` | Bottom sheet panels (assign referee, etc.) |

---

## 8. Navigation Flow Diagram

```
LoginScreen
    └── [on login] ──────────────────────────────► TournamentsListScreen
                                                          │
                              ┌───────────────────────────┤
                              │                           │
                    [FAB: create]                [tap tournament]
                              │                           │
                   CreateTournamentScreen     TournamentDetailScreen
                                                  ├── [schedule match]
                                                  │       ├── ScoringScreenRouter
                                                  │       │     ├── CricketScoringScreen
                                                  │       │     ├── FootballScoringScreen
                                                  │       │     └── ...
                                                  │       ├── LiveMatchScreen
                                                  │       ├── MatchQRScreen
                                                  │       └── MatchScanScreen
                                                  ├── [register player]
                                                  │       └── PlayerRegistrationScreen
                                                  └── [h2h] HeadToHeadScreen

TournamentDashboardScreen
    ├── [create] ──────────► CreateTournamentScreen
    └── [view]  ──────────► TournamentDetailScreen

TeamsScreen
    └── [tap team] ────────► TeamDetailScreen

PlayersScreen
    └── [tap player] ──────► PlayerProfileScreen

ProfileScreen
    ├── [notifications] ───► NotificationSettingsScreen
    └── [points shop]  ───► PointsShopScreen

TournamentsListScreen
    └── [join icon] ───────► JoinTournamentScreen
                                  └── [found] ──► TournamentDetailScreen
```

---

## 9. Services (`lib/core/`)

| Service | Purpose |
|---------|---------|
| `notifications_service.dart` | FCM token management, push notification registration |
| `offline_sync_service.dart` | Data sync during offline periods |
| `supabase_config.dart` | Supabase client initialization |
