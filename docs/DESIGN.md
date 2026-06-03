# TikTok Battle Game — Comprehensive Design Document
**For Claude Code AI in Terminal to understand complete implementation**

---

## Table of Contents

1. [Game Overview](#game-overview)
2. [Player Progression System](#player-progression-system)
3. [Combat & Avatar System](#combat--avatar-system)
4. [Boss System](#boss-system)
5. [Ultimate & Cinematic System](#ultimate--cinematic-system)
6. [Combo & Reward System](#combo--reward-system)
7. [Team Mechanics](#team-mechanics)
8. [End Game Design](#end-game-design)
9. [TikTok Integration](#tiktok-integration)
10. [Technical Architecture](#technical-architecture)

---

## Game Overview

### Core Loop
```
DUEL PHASE (2-3 minutes)
├─ Team A vs Team B, avatars fight
├─ Players donate/like on TikTok
├─ Donations trigger attacks, accumulate EXP
├─ Game state: score, timer, combo counters
└─ Donations charge ultimate meter

↓ (Boss spawned)

BOSS PHASE (120-240 seconds depending on level)
├─ Both teams pause fighting
├─ Cooperative zone split (Team A left, Team B right)
├─ Both teams deal damage to shared boss
├─ Success: Both level up, return to duel
└─ Failure: Retry same boss level, return to duel

↓ (Repeat until stream end)

INFINITE PROGRESSION
└─ Boss levels escalate (1→2→3→...→10→∞)
└─ Player levels increase alongside
└─ Difficulty grows exponentially
└─ Goal: Reach highest possible boss level
```

### Stream Duration
- **Typical stream**: 30 minutes
- **Duel rounds**: ~8-10 rounds per stream
- **Boss encounters**: 3-5 bosses depending on clear success
- **Progression expected**: Boss Lv1-5, Player Lv1-6

---

## Player Progression System

### Philosophy
- **Individual progression**: Each avatar has own level/EXP
- **No global resets**: Unless death (lose 1 level only)
- **Exponential difficulty**: Encourages grinding between boss phases
- **Social comparison**: Leaderboard creates rivalry

### Level & EXP Mechanics

#### EXP Requirements (Exponential Growth)

```
Level  | EXP Required | Total to Reach | Notes
-------|--------------|---|---
1→2    | 50 EXP       | 50 | Achievable in first minute
2→3    | 200 EXP      | 250 | Achievable in first duel round
3→4    | 1,000 EXP    | 1,250 | Requires killing 1 Lv2 or 50 likes
4→5    | 4,000 EXP    | 5,250 | Requires coordinated effort
5→6    | 16,000 EXP   | 21,250 | Requires multiple boss clears + kills
6→7    | 64,000 EXP   | 85,250 | Multi-stream grind territory
7→8    | 256,000 EXP  | 341,250 | Unlikely in single 30-min stream
8→9    | 1,024,000 EXP | 1.3M | Ultra-rare achievement
9→10   | 4,096,000 EXP | 5.4M | Legendary (probably impossible)
10+    | ×4 each      | Infinite | No hard cap
```

#### HP & Damage Scaling

```
Level | HP  | DMG | Size Scale | Notes
------|-----|-----|------------|---
1     | 100 | 10  | 1.0x       | Newborn avatar (tiny)
2     | 150 | 11  | 1.1x       | Growing
3     | 200 | 12  | 1.2x       | Noticeable bigger
4     | 300 | 14  | 1.3x       | Threatening
5     | 450 | 18  | 1.4x       | Serious threat, streamer notices
6     | 650 | 21  | 1.5x       | Very dangerous
7     | 900 | 24  | 1.6x       | Boss-level dangerous
8     | 1200 | 28 | 1.7x       | HUGE avatar, dominates
9     | 1500 | 31 | 1.8x       | Colossal
10    | 2000 | 35 | 1.9x       | Legendary

Formulas:
HP = 100 + (Level^1.8 × 50)
DMG = 10 × (1 + Level × 0.15)
SIZE = 1.0 + (Level × 0.1)
```

### EXP Sources

#### 1. Like from TikTok (1 Like = 1 EXP)
```
Mechanics:
- Real-time from TikTok live counter
- Personal: each viewer's likes only boost their avatar
- Can spam (but slow for higher levels)
- Example: Viewer A gets 100 likes → only Viewer A's avatar +100 EXP

Implementation:
- TikTok listener tracks like_count_current
- Every 1 like → send JSON { type: "like", user_id, count: 1 }
- GameManager receives → find player in arena → add_exp(1)

Balance:
- Rewards engagement with streamer
- Slow early (Lv1 takes 50 likes), becomes critical mid-game
- By Lv6 requires 16k likes (entire stream dedication)
```

#### 2. Kill Enemy Avatar (EXP = Enemy's Total Accumulated EXP)
```
Mechanics:
- When avatar A eliminates avatar B
- Killer A gains: (enemy_B_level_to_reach_current × all_exp_for_that_level)
- Example: Enemy at Lv3 (1250 total EXP) → Killer gains 1250 EXP
- Visual: Floating "+1250 EXP!" text at kill location

Psychology:
- Reward cooperation against specific threats
- Killing Lv5 enemy = jackpot (16.2k EXP potential)
- Creates "target the high-level player" dynamic
- Balances snowballing (high level = bigger target)

Implementation:
- PlayerAvatar.take_damage(damage, killer_id)
- If HP ≤ 0 → calc total_exp, emit signal to killer
- Killer: add_exp(total_exp), send chat "@KillerName +16250 EXP!"
```

#### 3. Boss Clear (Shared Team Reward)
```
Mechanics:
- When boss HP ≤ 0 and timer > 0
- BOTH teams gain: 500 × boss_level EXP
- Example: Boss Lv3 clear → both teams each member +1500 EXP

Psychology:
- Cooperative reward (not zero-sum)
- Encourages both teams to celebrate
- Creates shared enemy dynamic
- Shared risk: "If we fail, neither team progresses"

Implementation:
- Boss.on_defeated():
  └─ emit_to_scene("boss_defeated", { level })
  └─ GameManager.on_boss_defeated(level)
    └─ for player in team_a: add_exp(500 × level)
    └─ for player in team_b: add_exp(500 × level)
    └─ Arena.show_celebration("BOSS DEFEATED!\nEach team +1500 EXP")
```

### Level Up Mechanics

#### On Level Up
```
Instant effects:
1. HP resets to FULL (100%)
2. Avatar size expands (tween +10%)
3. Green glow animation
4. Floating "+1 LEVEL!" text with sparkles
5. UI update: level label, HP bar, EXP bar
6. Audio: level-up sound

Visible changes:
- Avatar bigger (more threatening)
- Health bar larger
- Damage output increases
- Shadow/effect size scales

Psychological impact:
- "You're stronger now!"
- Visual progression feels good
- Makes investment feel real
```

#### On Death (Level -1)
```
Mechanics:
- Avatar eliminated by enemy
- Level: current → current-1
- HP: 0 → reset to max HP of new level (lower)
- Location: spawn at random zone location (not where killed)
- State: frozen for 3 seconds, then active

Visual:
- "Defeated!" text with red flash
- Size shrink tween (to new level size)
- 3-second respawn timer countdown
- Semi-transparent during respawn

Psychology:
- Punishment is real (lost progress)
- But comeback is fast (3 sec = quick return)
- Yoyo feeling: build up → knocked down → rebuild
- Creates drama: "Don't get killed!"
```

---

## Combat & Avatar System

### Avatar Mechanics

#### Spawning
```
Trigger: Chat message "1" or "2" from TikTok
Process:
1. Validate team (1 = Team A, 2 = Team B)
2. Create PlayerAvatar node
3. Set player profile image (via URL fetch)
4. Position: random spawn point in team zone
5. Initialize: Level 1, HP 100, EXP 0
6. Start: float animation + glow ring

Zone positions:
- Team A: Left side (x: 200-700, y: 200-800)
- Team B: Right side (x: 1220-1720, y: 200-800)
- Spawn: always center of zone initially, then physics take over
```

#### Floating & Physics
```
- Base speed: 100 px/sec constant
- Direction: random angle on spawn
- Bouncing: circle area detects zone boundaries
- On bounce: flip velocity component, continue
- Collision with avatar: pushes apart (billiard balls)
- Knockback: velocity spike + direction change (from attack)

Visual:
- Smooth floating motion (not turning/rotating)
- Slight up-down bobbing for idle feel
- Shadow below avatar (always on ground)
- Neon glow ring matches team color
```

#### Visual Representation
```
Components:
- Circle sprite (50px diameter)
- Glow ring shader (per-team color: A=blue, B=red)
- Health bar above (green/red gradient)
- Damage numbers (floating, fading)
- Username label below
- Size scales with level: 0.22 base scale × (1.0 + level×0.1)

Accessibility:
- High contrast: neon on dark background
- Clear HP bar (easy to assess threat)
- Name visible even when zoomed (UI scaling)
- Glowing ring easy to track in chaos
```

### Attack System

#### Basic Attack Pattern (Cycling)
```
Cycle every 3 seconds, pick ONE of:
1. PlayerAttackEffect (simple damage)
   └─ 5 DMG, instant, small spark
   
2. LaserAttackEffect (tracking beam)
   └─ 20 DMG/tick, every 0.5s for 3s
   └─ Tracks target in real-time
   └─ Glowing line from attacker to target
   
3. LightningAttackEffect (chain lightning)
   └─ 20 DMG per target, instant
   └─ Jumps to ≤3 targets in range
   └─ Zigzag visual path
   └─ AoE effect (flashy, impressive)

Selection:
- Random (50/50/50 each cycle) OR
- Debug mode: fixed by user (for testing)
- Each attacker has independent 3-sec timer
- Visual indicates which effect is coming
```

#### Combat Flow
```
1. Avatar A in range of Avatar B
2. Timer ≥ 3 sec AND not currently attacking
3. Pick random effect (or debug-selected)
4. Spawn effect node at A's position
5. Effect plays animation → targets B
6. B takes damage → HP -amount
7. Damage number floats up from B
8. If HP ≤ 0 → B is eliminated
9. A gains EXP (B's accumulated)
10. B respawns in 3 sec at level-1

Feedback:
- Damage number "−5" or "−20" in red
- Effect animation (laser beam, lightning, etc.)
- Hit sound effect
- Enemy HP bar updates
- Screen shake if big damage
```

#### Damage Calculations
```
Attacker DMG = 10 × (1 + attacker_level × 0.15)

Example damages per level:
Lv1: 10 DMG per hit
Lv2: 11 DMG
Lv5: 18 DMG
Lv10: 35 DMG

Effect multipliers:
- Basic attack: ×0.5 = 5 DMG
- Laser: ×2 = 36 DMG (Lv10), deals every 0.5s (3 ticks = 108 total)
- Lightning: ×2 = 36 DMG per target (can hit 3 = 108 total)

Distance:
- Laser targets closest avatar within 600px
- Lightning chains nearest ≤3 within 400px
- Both ignore dead avatars
```

---

## Boss System

### Boss Mechanics

#### Difficulty Scaling

```
Boss Lv | HP  | DMG/attack | Time allowed | Notes
---------|-----|-----------|--------------|---
1        | 160 | 37        | 120s         | Introductory
2        | 256 | 56        | 130s         | Slightly harder
3        | 410 | 84        | 140s         | Team needs coordination
4        | 656 | 126       | 150s         | Player Lv3+ recommended
5        | 1,050 | 190     | 160s         | Player Lv4-5 required
6        | 1,680 | 285     | 170s         | HARD difficulty
7        | 2,684 | 427     | 180s         | VERY HARD
8        | 4,294 | 641     | 190s         | Extreme (likely fail)
9        | 6,871 | 961     | 200s         | Nearly impossible
10       | 10,995 | 1,441  | 240s         | Legendary

Formulas:
HP = 100 × (1.6 ^ level)
DMG = 25 × (1.5 ^ level)
TIME = 120 + (level × 10) seconds

As level increases:
- Time extends to allow farming
- But damage ramps FAST
- Creates natural progression gates
```

#### Boss Spawn Trigger
```
Conditions (whichever comes first):
1. Time-based: Every 3 duel rounds (~4 minutes)
2. Score-based: When team score gap ≤ 20 (close match)
3. Manual: Debug button "Spawn Boss"

Announcement:
- At trigger: "BOSS LEVEL [X] APPROACHING!"
- 10-second warning countdown
- Arena dims slightly
- Boss enters from top-center

State on spawn:
- Game pauses (pause tree, but video/audio/particles exempt)
- All avatars freeze in place (can't spawn new ones)
- Arena camera focuses on boss
- Arena zooms slightly (cinematic feel)
```

#### Boss Attack Pattern
```
Every 3 seconds:
1. Boss winds up animation (0.5 sec)
2. Boss attacks: deals damage to both teams
3. Damage distributed:
   - 30% to highest-level avatar in team
   - 70% divided equally among ALL team members
   
Example: Boss 100 DMG to Team A [Lv5, Lv3, Lv2, Lv1]
├─ Lv5: 30 DMG
├─ Lv3: 17.5 DMG (70/4)
├─ Lv2: 17.5 DMG (70/4)
└─ Lv1: 17.5 DMG (70/4)

Effect:
- Damage numbers appear on each avatar
- Screen shake (intensity scales with level)
- Red flash on hit
- Team HP bar decreases

Psychology:
- Incentivizes balanced team levels
- No single "tank" character (cooperative)
- High-level players still targeted but spread risk
```

#### Boss Defeat Condition
```
Success: Boss HP ≤ 0 within time limit
├─ Both teams gain EXP: 500 × level
├─ Both teams gain score: 100 × level
├─ All avatars restore 50% HP
├─ Celebration screen: "BOSS DEFEATED!"
├─ Fireworks effect
├─ Audio: victory fanfare
└─ Return to duel phase

Failure: Time ≤ 0 with boss alive
├─ No punishment (no level loss)
├─ Return to duel phase immediately
├─ Announce: "Boss survived! Try again next round."
├─ Boss level SAME (retry)
└─ Can prepare longer this time (longer duel phase)

Design intent:
✅ Encourages participation (no harsh punishment)
✅ Rewards coordination (both benefits)
✅ Creates sense of progression (boss level increases)
✅ Allows come-from-behind (get stronger, retry)
```

### Boss Phase Timing

#### Timer Scaling
```
Current boss level determines time allowed:

Lv1 boss: 120 seconds (2 minutes)
Lv2 boss: 130 seconds
Lv3 boss: 140 seconds
Lv4 boss: 150 seconds
Lv5 boss: 160 seconds (2:40)
Lv6 boss: 170 seconds
Lv7 boss: 180 seconds (3 minutes)
Lv8 boss: 190 seconds
Lv9 boss: 200 seconds
Lv10 boss: 240 seconds (4 minutes!)

Purpose:
- Higher levels get more time to damage boss
- Duel phase extends (more time to farm EXP)
- Natural pacing (not rushed, not dragging)
```

#### Duel Phase Between Bosses
```
After boss clear: return to duel
Duel duration before next boss:
- Variable: depends on boss difficulty
- Easy bosses (Lv1-2): ~3 minutes duel → next boss
- Medium bosses (Lv3-4): ~4 minutes duel
- Hard bosses (Lv5+): ~5 minutes duel (extended farming)

Purpose:
- Players accumulate EXP/kills
- Donations charge ultimate meter
- Leaderboard shuffles
- Chat engagement builds anticipation for next boss
```

---

## Ultimate & Cinematic System

### Ultimate Mechanic (Complete)

#### Triggering
```
Donation universe gift (¥50+) → ultimate meter ≥ 100%

Process:
1. Player donates ¥50+ (universe gift)
2. GameManager.on_gift_received()
3. Ultimate meter team fill → 100%
4. "ULTIMATE READY!" announcement
5. User can activate by next attack OR auto-trigger
6. Pause game → play cinematic → resume
```

#### Cinematic Mode (10.5 seconds)

```
Timeline:
0.0s    │ Game PAUSED
		│ - get_tree().paused = true
		│ - Avatars frozen (visual only)
		│ - Overlay darkens (0.3s fade to 60% opacity)
		│ - Ultimate cinematic starts
		│
0.3s    │ Video starts playing (OGV format)
		│ - Center screen, 60% of viewport
		│ - Audio embedded in video plays
		│
0.3-6.5s│ Cinematic plays (6.2 seconds of pure video)
		│ - Dark dragon (Team A): Abyss Awakening
		│   - Dragon emerges behind character
		│   - Character commands
		│   - Dragon fires void beam (purple-black)
		│   - Explosion vortex at impact
		│   - Character + dragon final pose (cool)
		│
		│ - Light dragon (Team B): Celestial Blessing
		│   - Dragon emerges behind character
		│   - Character blessing gesture
		│   - Dragon fires holy light beam (white-gold)
		│   - Light explosion + healing aura
		│   - Character + dragon final pose (graceful)
		│
6.5s    │ Video ends
		│ - Final shockwave effect (Godot particles)
		│ - Light/Dark ring expands outward
		│ - Screen flash (white or purple based on team)
		│ - Impact damage applied to enemy team
		│
10.0s   │ Cinematic complete
		│ - Overlay fade out (0.3s back to normal)
		│ - Game RESUMED
		│ - Ultimate meter both teams reset to 0%
		│
10.3s   │ Back in duel
		│ - Avatars unfreeze, continue fighting
		│ - Audio resumes (duel ambient)
```

#### Ultimate Queue System
```
If multiple teams have ultimate during one cinematic:
├─ Team A casts ultimate
├─ Game paused for 10.3 seconds
├─ Team B wants to cast while A plays
│  └─ Queued: "Pending Ultimate"
├─ A finishes
├─ Small break (0.5 seconds)
├─ B's queued ultimate triggers
├─ Game paused again 10.3 seconds
└─ Resume, both meters at 0%

Logic:
- Can't overlap cinematics (bad UX)
- Queue prevents spam
- Creates turn-based ultimate feel
- Cooldown: 2 sec minimum between ultimates
```

#### Damage & Effects

```
Team A Ultimate (Abyss Awakening):
├─ Dark damage: +20 score to Team A
├─ Impact: Enemy Team B -10 score
├─ Duration: Instant + 2 sec stun effect
├─ Effect: Screen shake (0.5 intensity), purple flash
└─ Visual: Void explosion at impact point

Team B Ultimate (Celestial Blessing):
├─ Holy damage: +15 score to Team B
├─ Buff: Team B avatars +50% damage 5 seconds
├─ Heal: Team B +100 HP each avatar
├─ Effect: Screen flash white, healing aura
└─ Visual: Light explosion + sparkle burst
```

### Counter-Ultimate System (Interactive)

#### When Enemy Uses Ultimate
```
During enemy ultimate cinematic (while paused):

Timeline:
0.0-6.0s  │ Cinematic plays
		  │
6.0s      │ "COUNTER WINDOW OPEN!"
		  │ - Large red "SPACEBAR" button appears center
		  │ - 3-second countdown bar
		  │ - Sound: warning beep
		  │
6.0-9.0s  │ Player CAN press spacebar
		  │ - Success: Damage reduced 70%
		  │ - Fail: Full damage applied
		  │ - Miss: Full damage (too slow)
		  │
9.0s      │ Window closes
		  │ - Button fades
		  │ - Outcome determined
		  │
10.3s     │ Game resumes
```

#### Mechanics
```
On successful counter:
- Enemy ultimate damage: reduced to 30% (70% blocked)
- Visual: "PARRIED!" text in gold
- Audio: deflect sound
- Arena darkens briefly then clears
- Psychological: Team B feels control

On miss/fail:
- Enemy ultimate damage: 100% applied
- Visual: "HIT!" text in red
- Audio: impact sound
- Screen shake normal
- Psychological: Team A celebrates
```

---

## Combo & Reward System

### Like Combos
```
Trigger: Consecutive likes without break (>5 sec gap resets)

Combo ×3:
├─ Announcement: "3-LIKE COMBO!"
├─ Effect: Small sparkle burst on random avatar
├─ Reward: +10 HP to random Team avatar
└─ Meter: Reset to 0

Combo ×5:
├─ Announcement: "5-LIKE COMBO! 💫"
├─ Effect: Medium particle explosion
├─ Reward: +25 HP to EACH avatar
├─ Boost: +20% ultimate meter
└─ Meter: Reset to 0

Combo ×10:
├─ Announcement: "LEGENDARY COMBO! ✨✨✨"
├─ Effect: Screen pulse, all avatars glow
├─ Reward: +100 HP to each avatar (full restore likely)
├─ Boost: +50% ultimate meter to both teams
├─ Visual: Background flashes, special effect plays
└─ Meter: Reset to 0
```

### Donation Combos
```
Trigger: Consecutive donations (of ANY amount) without break

Combo ×3 donations:
├─ Announcement: "3-DONATION COMBO!"
├─ Reward: +15 HP to team
├─ Boost: +10% ultimate meter
└─ Reset

Combo ×5 donations:
├─ Announcement: "5-DONATION COMBO! 💰"
├─ Reward: +50 HP to team
├─ Boost: +50% damage next 5 seconds (all team avatars)
├─ Note: Stacks if already active (extends duration)
└─ Reset

Combo ×10 donations:
├─ Announcement: "LEGENDARY DONATION CHAIN! 🔥"
├─ Reward: +100 HP to each avatar
├─ Boost: +20% ultimate meter
├─ Buff: +100% damage (double damage) 10 seconds
└─ Reset
```

### Mixed Combos (Like + Donation)
```
When both like AND donation combos hit ×3+ simultaneously:

Combo ×3 each:
├─ Announcement: "PERFECT SYNC!"
├─ Combined reward: +75 HP to team
├─ Ultimate boost: +20%
└─ Special effect: Rainbow particles

Combo ×5 each:
├─ Announcement: "SYNCHRONICITY! 🌈"
├─ Combined reward: Team full HP restore + 50 HP buffer
├─ Ultimate boost: Full meter to 100% (instant ultimate ready!)
├─ Special effect: Screen rainbow flash, celebration music
└─ Duration: 10 seconds of celebration
```

### HP Restore Details
```
HP restore sources (additive):
1. Level up: → 100% HP
2. Like combo ×3: +10 HP (random avatar)
3. Like combo ×5: +25 HP (each)
4. Like combo ×10: +100 HP (each, ~full)
5. Donate ×3: +15 HP (team-wide)
6. Donate ×5: +50 HP (team-wide)
7. Donate ×10: +100 HP (team-wide)
8. Mixed ×5: Full restore + 50 buffer
9. Boss clear: 50% max HP (all avatars)

Visual:
- Green tween on HP bar
- "+50 HP" floating text in green
- Healing sparkle particles on avatar
- Audio: healing chime sound

Balance:
- Encourages continuous engagement
- Prevents snowball (can heal back)
- Donations matter (more HP = longer survival)
- Like rewards (audience participation matters)
```

---

## Team Mechanics

### Team Structure

#### Team A (Dark Dragon)
```
- Zone: Left side (x: 200-700)
- Color: Blue neon glow rings
- Ultimate: Abyss Awakening (dark, destructive)
- Theme: Aggressive, damage-focused
- Avatar background: Dark elegant character
- Max avatars: ~50 per zone
```

#### Team B (Light Dragon)
```
- Zone: Right side (x: 1220-1720)
- Color: Red neon glow rings (golden for light team)
- Ultimate: Celestial Blessing (holy, supportive)
- Theme: Strategic, healing-focused
- Avatar background: Light elegant character
- Max avatars: ~50 per zone
```

### Team HP Pool
```
Mechanic:
- Each team tracks TOTAL current HP (sum all avatars)
- Display: Team HP bar shows cumulative
- Color: Green (>75%) → Yellow (50%) → Red (<25%)
- Used in: Boss phase (team vs single boss)

Boss damage distribution:
- Boss 100 DMG to Team (4 avatars)
- 30% (30 DMG) → highest level avatar
- 70% (70 DMG) → split equally: 17.5 each
- Team total HP bar decreases by 100
- If any avatar dies, that avatar's max HP removed from team pool
```

### Score Tracking
```
Per team score:
- Starting: 0
- Donation impact: +1 (rose) to +15 (universe)
- Kill enemy: +10 points
- Boss clear: +100 × boss_level
- Winning team: announced at game end

Leaderboard impact:
- Tied for primary ranking
- Secondary: player level (tiebreaker)
- Tertiary: kill count (bragging rights)
```

---

## End Game Design

### Infinite Loop Philosophy
```
Design principle:
- "Game never ends" (until stream ends)
- Boss levels escalate infinitely
- Player progression mirrors difficulty
- Natural pacing (not forced/rushed)
- Engagement loop: duel → boss → duel → boss...

Difficulty curve:
- Early (Lv1-3): Achievable, learning phase
- Mid (Lv4-6): Challenging, requires coordination
- Late (Lv7+): Extreme, likely fails but feels epic
- Goal: Reach highest possible before stream ends
```

### Boss Level Progression Example

```
0-4 min    Boss Lv1 spawned
           Team A Lv2, Team B Lv2 (avg)
           Clear easily → both +500 EXP

4-7 min    Duel phase, farming EXP
           Donations build ultimate meter

7-8 min    Boss Lv2 spawned
           Team A Lv3, Team B Lv3
           Clear successfully → both +1000 EXP

8-12 min   Duel phase
           Likes accumulate, kills happen

12-14 min  Boss Lv3 spawned
           Team A Lv4, Team B Lv4
           HARDER - takes full 140s timer
           Eventually clear → +1500 EXP each

14-20 min  Duel phase (longer farming)
           High-level avatars attract attention

20-22 min  Boss Lv4 spawned
           VERY HARD - players struggling
           After tense fight, clear successfully

22-28 min  Duel phase (extended)
           Chase for Boss Lv5 hype

28-30 min  Boss Lv5 FINAL BOSS
           Epic battle, likely fail
           Stream ends on cliffhanger

Final stats:
"Boss Level 5 reached!"
"Highest player level: 5"
"Most kills: @Player_X (7)"
"Thank you for watching!"
```

### Session Ending & Leaderboard
```
When stream ends (timer 0:00):

1. Current boss phase pauses
2. Final stats calculated:
   ├─ Highest boss level cleared
   ├─ Highest player level achieved
   ├─ Most kills by player
   ├─ Most likes received
   ├─ Top donators
   └─ Special achievements

3. End-game screen displays:
   ├─ "You cleared Boss Level 4!"
   ├─ Leaderboard (top 10)
   ├─ Achievements unlocked
   ├─ "Next time, try for Level 5!"
   └─ "Thanks for watching!"

4. Save to file:
   - Player stats for next stream
   - Streak tracking (consecutive stream participation)
   - Highest personal level ever reached
```

---

## TikTok Integration

### Live Event Pipeline

```
TikTok Live          Node.js Listener       Godot Game
─────────            ────────────           ──────────
User types "1"  →    Receive event    →     Spawn Team A avatar
              
User gifts rose  →   Parse gift type  →     Trigger rose attack

User likes x50   →   Accumulate count  →     "+50 EXP" to liker

Donations flow   →   Queue donations  →      Update leaderboard
              
Chat messages   →    Parse commands   →      Debug/interact
```

### Like Counter Real-Time

```
Mechanism:
- TikTok listener tracks cumulative likes per stream
- Every 1 like: JSON { type: "like", user_id, count: 1 }
- Godot GameManager receives
- Find player avatar in arena by user_id
- Call: avatar.add_exp(1)

Scale:
- 1 like = 1 EXP (slow early, critical late)
- By Lv6, needs 16k likes for level
- Encourages: "Keep liking to level up!"
```

### Donation Types

```
rose (¥1)
├─ EXP: +10
├─ HP: +5
├─ Attack: Small spark
└─ Meter: +2% ultimate

ice_cream (¥5)
├─ EXP: +25
├─ HP: +20
├─ Attack: Mini laser
└─ Meter: +5% ultimate

rose bouquet (¥10)
├─ EXP: +50
├─ HP: +50
├─ Attack: Medium attack
└─ Meter: +8% ultimate

universe (¥50+)
├─ EXP: +250
├─ HP: +150
├─ Attack: ULTIMATE (cinematic)
└─ Meter: +100% (triggers cinematic)
```

---

## Neutral Effects System

### Concept
Effects triggered by TikTok gifts that affect **ALL avatars on both teams simultaneously** — no targeting, pure chaos/spectacle. Creates shared threat moments that interrupt the normal team-vs-team dynamic.

### Triggering
```
Neutral effects can be triggered by:
1. Specific "chaos" gift types (new gift tier)
2. Milestone: Like streak ×50 (anyone's total)
3. Manual: Debug button "Chaos [effect]"

JSON format:
{ type: "neutral_effect", effect: "meteor_shower", sender: "username" }

Announcement (2 sec before effect):
- "⚡ [username] triggered ELECTRIC STORM!"
- Screen edge flash in effect color
- Brief warning icon center screen
```

### Effect 1: Meteor Shower ☄️

```
Trigger gift:   rose_bouquet (¥10) → neutral variant
Duration:       5 seconds
Intensity:      10–14 meteors randomly spawned

Mechanics:
├─ Meteors spawn at random x (50–1870), y = -80 (above screen)
├─ Each falls at speed 700–950 px/s with slight random x drift
├─ Hit detection: 55px radius around impact point
├─ On hit → 18 DMG + knockback 220px in random direction
├─ Each meteor independent — can hit same avatar multiple times
└─ No team targeting: both teams take equal random risk

Visual:
├─ Fireball: orange core (Polygon2D) + red outer glow shader
├─ Trail: GPUParticles2D — 30 particles, orange/yellow additive
├─ Impact: burst explosion, 15px crater flash, screen_shake(0.25, 5.0)
└─ Sound: whistle incoming → crash on impact

Balance:
- Average per avatar: 1–2 hits (= 18–36 DMG)
- Arena-wide DPS burst: creates chaos window of ~3 seconds
- Rewards mobile avatars (bouncing away reduces hits)
```

### Effect 2: Black Hole Pull 🌀

```
Trigger gift:   universe (¥50+) → alternate path (if meter already 100%)
Duration:       3s pull + 1s explosion = 4s total
Spawns at:      Arena center (960, 540)

Mechanics — Pull Phase (0–3s):
├─ Every physics frame: add velocity toward (960, 540)
│  velocity += (center - avatar.position).normalized() × PULL_FORCE
│  PULL_FORCE = 280 px/s² (lerps from 0 → 280 over 1.5s = gradual suck)
├─ Zone boundaries still apply (avatars bounce at edges)
└─ Avatars visually drawn toward center — creates collision cluster

Mechanics — Explosion Phase (3–4s):
├─ Instant AoE damage: 30 DMG to all avatars within 500px of center
├─ Knockback: velocity += (avatar.position - center).normalized() × 600
├─ Screen shake: screen_shake(0.65, 16.0) — large radius hit
└─ After explosion: normal physics resume

Visual:
├─ Black sphere (60px radius) with purple-violet neon glow ring shader
├─ GPUParticles2D: particles orbiting center, spiraling inward (additive blend)
├─ Pull distortion: radial shader on Arena background (optional)
├─ Explosion: purple ring expands 0 → 520px, fades in 0.6s
└─ Screen flash: dark purple full-screen rect, alpha 0.4, fade 0.3s

Balance:
- Guaranteed 30 DMG to clustered avatars (most will be near center)
- Creates visible clustering = exciting camera moment
- No team preference — equal risk both zones
```

### Effect 3: Electric Storm ⚡

```
Trigger gift:   ice_cream (¥5) → neutral variant
Duration:       5 seconds
Strike rate:    Every 0.35s = ~14 total strikes

Mechanics:
├─ Timer fires every 0.35s: pick random arena position (x: 100–1820, y: 200–900)
├─ Nearest avatar within 75px radius takes 12 DMG
├─ 25% chance per strike: stun (freeze movement + attacks) 1.0s
│  (stun uses existing _respawning freeze logic — same semi-transparent state)
├─ Visual strike still shows even if no avatar hit (ambient effect)
└─ Chain rule: if avatar hit and another within 120px → 8 DMG chain (one hop only)

Visual:
├─ Bolt: Line2D from top-of-screen to strike point, white core 2px + cyan outer 6px
├─ Branch: 2–3 sub-branches ±15px offset (same zigzag as LightningAttackEffect)
├─ Flash: strike-point GPUParticles2D burst (20 cyan particles, instant)
├─ Flicker: Line2D alpha flickers 3× then fades (0.12s total)
└─ Ambient particles: lightning static slowly drifts across arena during duration

Balance:
- Average per avatar: 2–3 strikes (= 24–36 DMG over 5s)
- Stun chance 25% per strike means ~3–4 stuns per avatar statistically
- LightningAttackEffect already exists — reuse visual logic
```

### Effect 4: Toxic Flood ☠️

```
Trigger gift:   Any gift "x3 consecutive" from same user → alternate trigger
			   OR specific "toxic" gift tier (future)
Duration:       8 seconds active + 2s dissipate
DoT rate:       3 HP every 0.5s = 6 DMG/sec = 48 total

Mechanics:
├─ On trigger: spawn ToxicFloodEffect node (covers entire arena)
├─ Every 0.5s tick: Arena.damage_all_alive(3, "toxic") — skips respawning
├─ Damage type "toxic" bypasses damage multiplier buffs (raw)
├─ No knockback — pure pressure / attrition
├─ Combo heal still works: Like×5 or Donate×5 can partially offset
└─ Avatar death from toxic = normal death (killer_id = "toxic_flood")

Visual:
├─ Arena overlay: dark green semi-transparent rect, alpha 0.25 (CanvasLayer layer=1)
├─ GPUParticles2D: green bubble particles rising from arena floor (150 particles, lifetime 2s)
├─ Avatar tint: each avatar gets slight green modulate during duration
├─ Damage numbers: green "-3" every tick (smaller font than combat damage)
├─ Dissipate: particles fade, overlay alpha → 0 over 2s
└─ Sound: ambient bubbling/hissing loop during duration

Balance:
- 48 total DMG per avatar (equal to ~3 rose hits)
- Low per-tick damage = manageable, but constant pressure
- Encourages teams to donate/like to heal back
- "Chaos tax" on both teams = engagement incentive
```

### Gift → Neutral Effect Mapping

```
Gift / Trigger             → Effect
─────────────────────────────────────────────────────
ice_cream (¥5) chaos flag  → Electric Storm (5s)
rose_bouquet (¥10) chaos   → Meteor Shower (5s)
universe (¥50) alt path    → Black Hole Pull (4s)
3× consecutive same user   → Toxic Flood (8s)

"chaos flag" = Node.js listener sends:
  { type: "neutral_effect", effect: "electric_storm", ... }
instead of normal gift attack — triggered by specific TikTok gift names

Planned TikTok gift→neutral mapping:
  "soccer_ball" → Electric Storm
  "planet"      → Black Hole Pull
  "bomb"        → Meteor Shower
  "alien"       → Toxic Flood
```

### Neutral Effect Signal Contract

```gdscript
# in GameManager.gd
signal neutral_effect_requested(effect_data: Dictionary)

# effect_data shape:
{
  "effect": "meteor_shower",  # or black_hole, electric_storm, toxic_flood
  "sender": "username",
  "gift": "planet",
  "timestamp": 1234567.0
}
```

### Implementation Order

```
Phase 8 — Neutral Effects:
1. ElectricStorm.tscn + .gd    (reuse LightningAttackEffect visuals)
2. MeteorShower.tscn + .gd     (new projectile, simplest mechanic)
3. BlackHolePull.tscn + .gd    (physics pull + explosion)
4. ToxicFlood.tscn + .gd       (DoT + arena overlay)
5. Arena.gd: spawn_neutral_effect() dispatcher
6. GameManager.gd: neutral_effect_requested signal + routing
7. DebugPanel: 4 chaos buttons
```

---

## Skill System v2.0 — กำลังภายใน Theme (Patch 1.0)

### Team Themes

#### Team A: White Sect — Wudang (ทีมขาว)
- Colors: White, Gold, Cyan
- Style: Pure chi energy, flowing internal martial arts
- Character: White robed martial artist

#### Team B: Dark Sect — Demon Cult (ทีมดำ)
- Colors: Black, Purple, Blood Red
- Style: Yin dark energy, explosive power arts
- Character: Dark robed martial artist

---

### Skill Taxonomy

#### 1. Dash — Tier 1 (1 baht, gift: gift_box)

```
Auto-triggers on donate. Avatar dashes 200px forward, invincible 0.2s, particle trail.

Team A — Cloud Step (ก้าวเมฆ):
  Visual: white wind streak + fading footprints, cyan glow

Team B — Shadow Blink (ทะยานเงา):
  Visual: black smoke puff at origin, reappear 200px ahead with dark sparks
```

#### 2. Shield — Tier 1 (1 baht, gift: donut)

```
Auto-triggers on donate. Bubble stays on avatar 5s or until 1 hit absorbed.

Team A — Iron Shirt Chi (เกราะชี่เหล็ก):
  Visual: gold/white Line2D bubble ring pulse
  Mechanic: absorbs next 1 hit fully (any damage)

Team B — Demon Shell (เปลือกมาร):
  Visual: black/red obsidian barrier ring with spikes
  Mechanic: absorbs next 1 hit + reflects 20% damage back to attacker
```

#### 3. Buff

```
T1 (1 baht, gift: panda) — ATK buff:
  Team A — Chi Gathering (รวมพลังชี่): white aura ring, +20% ATK 20s
  Team B — Blood Rage (คลั่งโลหิต):   red fire aura,   +20% ATK 20s

T2 (5 baht, gift: ice_cream, secondary effect):
  Team A — White Lotus Veil (ม่านบัวขาว): white sparkle burst, +15 HP team heal
  Team B — Dark Hunger (หิวมืด):          dark tendrils aura, lifesteal 20% dmg→HP 20s
```

#### 4. Attack Unique Skills

```
T1  Free (auto basic)   Palm Strike (ตบฝ่ามือ)    / Iron Fist (หมัดเหล็ก)         × 1
T2  1B   rose           Sword Qi (ดาบชี่)          / Dark Needle (เข็มมืด) ×3 spread × 2
T3  5B   ice_cream      White Crane (นกกระเรียนขาว)/ Tiger Claw (เล็บเสือ) 3-slash  × 2/hit
T4a 10B  rose_bouquet   Tai Chi Vortex (วังวนไทชี) / Dark Tornado (พายุมืด) pull AoE × 3.5
T4b >10–50B (value)     Heaven Palm (ฝ่ามือฟ้า)    / Shadow Eruption (ระเบิดเงา)    × 5 + KB
T4c >50–100B universe   White Dragon Beam           / Black Serpent DoT beam          × 8
T4d >100B whale_gift    Transcendence (羽化登仙)    / Abyss Annihilation (滅世)       × 15 + stun
```

**T4b note:** Node.js sends `donation_value` (baht) in JSON; GameManager routes to T4a vs T4b vs T4c by value threshold at runtime.

**Visual direction per tier:**
- T1: simple orb/punch effect (reuse PlayerAttackEffect base)
- T2: single projectile with team-colored shader
- T3: multi-hit burst, angular / feather shapes
- T4a: AoE Polygon2D + GPUParticles2D explosion
- T4b: large shockwave ring + knockback
- T4c: Line2D beam with glow layers (extend LaserAttackEffect)
- T4d: full-screen flash + massive particle nova (no pause, unlike charge ultimate)

---

#### 5. Player Avatar Private Ultimate

```
Each avatar has an independent private ultimate meter (0–100%).
At 100% → auto-trigger team private ultimate (no game pause, no queue).
```

##### Meter Fill Sources

```
Deal damage hit:    +2% per hit  (+1% extra per 10 DMG dealt above base)
Receive damage hit: +3% per hit  (+1% extra per 10 DMG received above base)
T4d strike dealt:   +15% bonus
```

##### Ultimate Skills

```
Team A — Dragon Soul Ascension (จิตวิญญาณมังกรฟ้า):
  Visual: white/cyan dragon silhouette bursts from avatar, 0.8s animation
  Effect: 300 DMG AoE (300px radius around attacker) + self-heal 50% max HP

Team B — Demon King's Descent (มารราชาลงมา):
  Visual: dark/purple demon aura explosion from avatar, 0.8s animation
  Effect: 300 DMG + 1.5s stun to enemies within 300px + lifesteal 20% of dmg dealt
```

##### Private Ultimate Bar UI (on avatar)

```
Bar size: 40×4 px, positioned below HP bar
Color:    Team A = cyan→white gradient left-to-right
          Team B = purple→red gradient
At 100%:  bar flashes + small "ULTIMATE!" label above avatar (fades in 0.4s)
On fire:  bar immediately resets to 0, dragon/demon visual spawns at avatar position
```

---

### Gift → Skill Routing Table (Option B — by gift name)

```
Gift Name       Baht   Skill Type      Effect
──────────────────────────────────────────────────────
rose            1B     Attack T2       Sword Qi / Dark Needle
donut           1B     Shield T1       Iron Shirt Chi / Demon Shell
gift_box        1B     Dash T1         Cloud Step / Shadow Blink
panda           1B     Buff T1         Chi Gathering / Blood Rage
ice_cream       5B     Attack T3       White Crane / Tiger Claw
                       + Buff T2       White Lotus Veil / Dark Hunger (team)
rose_bouquet    10B    Attack T4a      Tai Chi Vortex / Dark Tornado
universe        >50B   Attack T4c      White Dragon Beam / Black Serpent
                       + charge meter +100% (triggers cinematic ultimate)
whale_gift      >100B  Attack T4d      Transcendence / Abyss Annihilation
                       + private meter +30%
```

For gifts with `donation_value` field (Node.js sends actual baht amount):
- 10B < value ≤ 50B  → T4b
- 50B < value ≤ 100B → T4c (universe equivalent)
- value > 100B       → T4d (whale)

---

### Charge Ultimate vs Private Ultimate — Comparison

```
                  Charge Ultimate          Private Ultimate
─────────────────────────────────────────────────────────
Trigger:          universe gift → 100%     personal meter 100% (auto)
Scope:            team-wide cinematic      individual avatar burst
Game pause:       yes (10s cinematic)      no
Visual scale:     full video + shockwave   avatar-radius dragon/demon
Frequency:        rare (big gift needed)   common (fills in combat)
Queue:            yes (sequential)         no queue (instant per avatar)
Counter window:   yes (spacebar parry)     no
```

---

## Technical Architecture

### Class Structure

```
AutoLoad/Singleton:
├─ GameManager
│  ├─ Current state (WAITING/COUNTDOWN/PLAYING/GAME_OVER)
│  ├─ Timer (120s countdown)
│  ├─ Score dict { "team_a": 0, "team_b": 0 }
│  ├─ Signals: game_state_changed, score_changed, timer_updated, etc.
│  └─ Methods: start_game(), reset_game(), on_gift_received()
│
├─ PlayerStats (NEW)
│  ├─ Per-player: level, exp, total_exp, kills
│  ├─ Signals: level_changed, exp_gained, player_died
│  └─ Methods: add_exp(), level_up(), reset_on_death()
│
├─ BossManager (NEW)
│  ├─ Current boss_level, health, damage
│  ├─ Attack pattern (every 3 sec)
│  ├─ Signals: boss_spawned, boss_attack, boss_defeated
│  └─ Methods: spawn_boss(), calculate_damage(), clear_boss()
│
├─ UltimateController (NEW)
│  ├─ Ultimate queue system
│  ├─ Cinematic pause/resume
│  ├─ Counter-ultimate window
│  └─ Methods: request_ultimate(), play_cinematic(), handle_counter()
│
├─ ComboTracker (NEW)
│  ├─ Like combo counter
│  ├─ Donation combo counter
│  ├─ Signals: combo_milestone
│  └─ Methods: add_like(), add_donation(), reset()
│
└─ Leaderboard (NEW)
   ├─ Top donators
   ├─ Highest levels
   ├─ Most kills
   └─ Methods: update(), get_top_N()

Scene Structure:
├─ Main.tscn
│  ├─ Arena.tscn
│  │  ├─ TeamAZone
│  │  ├─ TeamBZone
│  │  ├─ Boss.tscn (spawned dynamically)
│  │  └─ Effects layer
│  ├─ UILayer.tscn
│  │  ├─ ScoreLabels
│  │  ├─ TimerPanel
│  │  ├─ ComboCounters
│  │  ├─ LeaderboardPanel
│  │  └─ StretchGoalBar
│  ├─ UltimateEffect.tscn (spawned on trigger)
│  ├─ DebugPanel.tscn (F1 toggle)
│  └─ WinScreen.tscn (shown on game end)
```

### Signal Contract

```
GameManager signals:
- game_state_changed(state) → triggers UI updates
- score_changed(team, new_score) → update leaderboard
- timer_updated(seconds_left) → update timer UI
- game_over(winner) → show end screen
- spawn_avatar_requested(user_data) → Arena creates avatar
- trigger_effect_requested(effect_data) → Arena spawns effect

PlayerStats signals:
- level_changed(player_id, new_level) → update avatar display
- exp_gained(player_id, amount) → show "+EXP" float text
- player_died(player_id, killer_id) → show death, award EXP

BossManager signals:
- boss_spawned(level) → arena setup
- boss_defeated() → celebration, back to duel
- boss_attack(damage) → apply to teams
```

### Data Flow (Example: Donation Rose)

```
1. TikTok user donates ¥1 rose

2. Node.js listener receives:
   { type: "gift", user: "username", avatar: "url", gift: "rose" }

3. WebSocketManager.on_message():
   └─ parse JSON → emit to GameManager

4. GameManager.on_gift_received({ gift: "rose", user, avatar }):
   ├─ gift_to_effect = { "rose": { score: 1, effect: "small", dmg: 5 } }
   ├─ Add 1 score to team
   ├─ Emit trigger_effect_requested()
   ├─ Update ultimate meter +2%
   └─ Send to PlayerStats.add_exp(liker, 10)

5. Arena receives trigger_effect:
   ├─ Find attacker avatar (by user)
   ├─ Find target avatar (random enemy)
   ├─ Spawn GiftAttackEffect
   ├─ Effect deals 5 DMG → target
   ├─ Target.add_exp(5) [from kill] if dies
   └─ Show damage number "−5"

6. UILayer receives updates:
   ├─ Update score label
   ├─ Update ultimate meter
   ├─ Show "+10 EXP" float for attacker
   └─ Leaderboard refreshes
```

---

## Implementation Roadmap

### Immediate (This Session)
1. Create PlayerStats.gd (AutoLoad)
2. Create AvatarStats.gd (component)
3. Implement EXP gains (like, kill, boss clear)
4. Implement level-up mechanics
5. Implement death/respawn

### Short-term (Next 2-3 hours)
6. Create BossManager.gd
7. Implement boss spawning
8. Implement boss damage distribution
9. Create Boss.tscn
10. Implement boss phase flow

### Medium-term (Next 4-5 hours)
11. Create UltimateController.gd
12. Implement counter-ultimate
13. Create ComboTracker.gd
14. Implement combo rewards

### Long-term (Future sessions)
15. Create Leaderboard.gd
16. Implement stretch goals
17. Create end-game screens
18. Full production testing

---

## Notes for AI Implementation

**Priority:** Implement in this order:
1. Level/EXP system (foundation)
2. Boss system (escalation)
3. Combos (engagement)
4. Counter-ultimate (interactivity)
5. Leaderboard (social)

**Key Python/GDScript patterns:**
- Use @onready for node references
- Emit signals before modifying state
- Queue effects → don't block with await
- Use constants for balance tuning

**Testing:**
- DebugPanel already has all buttons (use them!)
- DemoRunner can simulate full flow
- MockWebSocket can fake TikTok events

**Balance:**
- EXP curves feel right (exponential, not linear)
- Boss scaling matches player power growth
- Combos give meaningful rewards without breaking game
- Death penalty (level -1) is harsh but fair
