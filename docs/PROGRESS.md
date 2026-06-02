# Progress Tracker — TikTok Battle Game
อัปเดตทุกครั้งที่ feature เสร็จ

---

## Done ✅

### Core Gameplay (Completed)
- [2026-05-30] **CLAUDE.md** — project overview, coding rules, signal contract, intended folder structure
- [2026-05-30] **docs/PROGRESS.md, docs/PROMPTS.md** — project documentation
- [2026-05-30] **autoload/GameManager.gd** — AutoLoad singleton: GameState enum (WAITING/COUNTDOWN/PLAYING/GAME_OVER), 120s timer, score dict, gift→effect table (rose/ice_cream/universe), like accumulator (×10→micro), all 6 signals
- [2026-05-30] **Arena.tscn + Arena.gd** — neon grid background shader, Team A/B zone glow shaders, glowing center divider, score labels (96pt neon), timer panel; spawn_avatar(), trigger_gift_attack(), screen_shake(), knockback_team(), on_chat/on_gift/on_like event API
- [2026-05-30] **PlayerAvatar.tscn + PlayerAvatar.gd** — circular avatar (circle-clip shader), per-team neon glow ring shader, HTTPRequest image loader (jpg/png), float idle animation, billiard bounce physics, username label
- [2026-05-30] **GiftAttackEffect.tscn + GiftAttackEffect.gd** — rose projectile (pink orb shader), GPUParticles2D trail (additive blend, pink-red gradient), GPUParticles2D explosion burst (80 particles), arc flight path, screen shake callback, score/knockback on impact, auto queue_free
- [2026-05-30] **DebugPanel.tscn + DebugPanel.gd** — CanvasLayer F1-toggle debug panel; Spawn A/B, Rose, Ultimate, Kill, Auto Demo, Reset; Attack Mode lock (Rnd/Basic/Laser/Chain) with live label
- [2026-05-30] **DemoRunner.gd** — automated demo driver: spawn every 1-3s, rose every 5s, ultimate every 15s; console logging with timestamps
- [2026-05-30] **MockWebSocket.gd** — keyboard simulator: 1=TeamA, 2=TeamB, Q/E=rose, W=universe, L=like×10
- [2026-05-30] **WebSocketManager.gd** — WebSocketPeer client: ws://localhost:8765, JSON parse, auto-reconnect
- [2026-05-30] **WSConnector.gd** — bridges MockWebSocket/WebSocketManager → GameManager Dictionary API; hot-swappable via `use_mock`
- [2026-05-30] **test_game_manager.gd** — 15 automated tests covering all GameManager flows
- [2026-05-30] **Folder reorganization** — scenes/ effects/ debug/ autoload/ ตาม intended structure
- [2026-05-30] **UltimateEffect.tscn + UltimateEffect.gd** — golden orb shader, 60-particle trail, 140-particle explosion, fires 3× with screen_shake
- [2026-05-30] **MicroEffect.tscn + MicroEffect.gd** — teal/gold additive sparkle burst, on_like trigger
- [2026-05-30] **WinScreen.tscn + WinScreen.gd** — CanvasLayer layer=50; game_over signal; animated title + backdrop
- [2026-05-30] **UILayer.tscn + UILayer.gd** — standalone CanvasLayer; score/timer/game_over signals
- [2026-05-30] **Main.tscn** — root scene
- [2026-05-31] **Viewport 1920×1080** — ขยายจาก 1280×900; zone_a/zone_b แต่ละฝั่ง 900×860px; max_avatars_per_zone=100
- [2026-05-31] **Billiard physics** — `_base_speed` คงที่; bounce ตาม zone bounds; spawn ที่ zone center; knockback เปลี่ยนทิศทางเท่านั้น
- [2026-05-31] **Avatar resize** — FloatPivot scale 0.22; HP bar, label ย่อตาม; fix $HPBarRoot node path
- [2026-05-31] **DamageNumber.tscn + .gd** — floating "-N" label, tween ลอยขึ้น -35px + fade 0.9s; spawn บน game_layer ทุก take_damage()
- [2026-05-31] **Attack effect pool** — random 1 ใน 3 per cycle: PlayerAttackEffect (5dmg), LaserAttackEffect (20dmg/tick × 3s), LightningAttackEffect (20dmg × chain ≤3); `_is_attacking` flag บล็อก overlap; `on_complete` callback reset cooldown
- [2026-05-31] **LaserAttackEffect.tscn + .gd** — Line2D 2 ชั้น (glow 8px + beam 2.5px); track target realtime; DAMAGE_PER_TICK=20, TICK_INTERVAL=0.5s, BEAM_DURATION=3s; fade → on_complete
- [2026-05-31] **LightningAttackEffect.tscn + .gd** — zigzag chain ≤3 targets; 5 intermediate points ±18px; outer glow + inner bolt; 20dmg/target instant; flash→fade→on_complete
- [2026-05-31] **Arena.gd additions** — spawn_laser_attack(), spawn_lightning_attack(), get_nearest_on_team_excluding(); debug_attack_mode var
- [2026-05-31] **DebugPanel attack mode** — 4 ปุ่ม Rnd/Basic/Laser/Chain; lock attack type สำหรับ testing; label แสดง active mode
- [2026-05-31] **LightningEffect.tscn + .gd** *(cinematic)* — Shader+GPUParticles2D; Line2D bolt กับ 5 branches แบบ realtime track; flicker 8-15fps; afterglow sequence: fade→double burst→shockwave ring→screen_shake; Dictionary API `fire({attacker, target, arena, ...})`
- [2026-05-31] **Ultimate Cinematic System** — UltimateController.gd (pause/queue/resume), overlay darken, ultimate_finished signal, prevent spam cooldown
- [2026-05-31] **Character Videos (OGV)** — Abyss Awakening (dark dragon), Celestial Blessing (light dragon), 10sec with embedded audio, converted MP4→OGV via ffmpeg
- [2026-05-31] **Video Integration** — VideoPlayer in UltimateEffect, sound embed, sync with visual effects

---

- [2026-06-01] **ShieldBubble.tscn + .gd** — Donut ¥1 gift effect; blue neon Line2D circle (GlowLine 14px + CircleLine 2.5px), FlashPolygon fade 0.35s, pulse scale 1.0↔1.05 via looping Tween, 5s duration, 0.5s fade out; `fire({position, team, arena})`
- [2026-06-01] **SpikeExplosion.tscn + .gd** — Gift Box ¥1 gift effect; 8 triangle Polygon2D spikes (alternating yellow/orange) expand 85px in 0.3s via Expo tween, center FlashPolygon fade, GPUParticles2D burst 50 gold particles (1-shot), 0.2s spike fade; `fire({position, from_team, arena})`
- [2026-06-01] **StunProjectile.tscn + .gd** — Rock ¥1 gift effect; 8-point Polygon2D rock on parabolic arc (ARC_HEIGHT=-145), rotation 5.5rad/s in flight, GPUParticles2D dust trail + impact burst (40 particles), screen_shake(0.35,9.0), deals 15 dmg, spawns 5-star StunIndicator (rotating 1.5s) on target; thunder sound; `fire({from_team, arena})`
- [2026-06-01] **DebugPanel additions** — "Gift FX Test" section: Donut A/B, GiftBox A/B, Rock A→B / B→A buttons; Arena.gd 3 new spawn methods + 3 ShieldBubble/SpikeExplosion/StunProjectile preloads

---

## In Progress 🔄

- Phase 2-D: Boss Clear Rewards ✅ Complete — Phase 2 fully done
- Phase 3-A: Counter-Ultimate System ✅ Complete
- Phase 3-B: Ultimate Meter System ✅ Complete
- Phase 3-C: Team Synergy & Combo Chains ✅ Complete

---

## Todo — Phase 1 (Core Progression Systems) ❌

### A. Player Leveling System
- [x] **PlayerStats.gd** (AutoLoad) — 2026-05-31
- [x] **AvatarStats.gd** (component on PlayerAvatar) — 2026-05-31
- [x] **PlayerAvatar.gd integration** — player_id, take_damage(killer_id), die→on_kill, level-up glow+resize — 2026-05-31
  - Track per-player: current_level, exp_accumulated, total_exp_for_kills, total_exp_for_likes
  - EXP formula: `50 × 4^(level-2)` exponential curve
  - HP formula: `100 + (level^1.8 × 50)`
  - DMG formula: `10 × (1 + level × 0.15)`
  - Level cap: 10 (can extend beyond)
  - Signals: `level_changed(player_id, new_level)`, `exp_gained(player_id, amount)`, `player_died(player_id)`

- [x] **AvatarStats.gd** (component on PlayerAvatar) — exp_updated signal, get_exp_progress(), EXP bar visual on avatar — 2026-05-31
- [x] **EXP Source Integration** — 2026-05-31
  - Kill: PlayerStats.on_kill awards exp to killer
  - Like: GameManager.on_like_received → PlayerStats.add_exp(username, count, "like")
  - Boss clear: PlayerStats.on_boss_cleared (ready, wires in when BossManager exists)
  - UI: Arena.spawn_exp_gain_text() shows "+N EXP" at kill location
  - Arena: trigger_effect_requested → MicroEffect now connected; on_like spawns at avatar pos

### B. Avatar Elimination & Respawn
- [x] **Avatar Elimination & Respawn** — 2026-05-31
  - die() → _start_respawn(): red flash, level-1 sync, size shrink tween, teleport random zone
  - 3-second countdown label "3...2...1...Ready!" above avatar; semi-transparent (modulate 0.4)
  - _finish_respawn(): HP restored to new level max, full opacity, resume movement + attack
  - _process(): physics and attacks frozen during _respawning; floating bob continues
  - Arena: get_nearest_on_team/excluding + damage_team_all skip _alive==false avatars
  - Arena.add_score(3-_team, 1) called directly in die() (replaced old avatar_died emit)

### C. HP Restore via Combos & Donations
- [x] **ComboTracker.gd** (AutoLoad) — 2026-06-01
  - Track consecutive likes: like_combo_count
  - Track consecutive donations: donate_combo_count
  - Reset on non-action (>5 sec idle)
  - Milestones fire at ×3, ×5, ×10; counter continues until ×10 then resets
  - Thresholds:
	- Like ×3: +10 HP random avatar
	- Like ×5: +25 HP each avatar
	- Like ×10: +100 HP each avatar
	- Donate ×3: +15 HP team
	- Donate ×5: +50 HP team
	- Donate ×10: +100 HP team
  - DMG boost (Donate ×5) and ultimate meter boost (Donate ×10) are TODO Phase 3
  - GameManager.on_gift_received → ComboTracker.add_donation(team)
  - GameManager.on_like_received → ComboTracker.add_like(team)
  - Arena connects heal_requested + combo_milestone signals in _ready()
  - DebugPanel: Like×3 A/B and Don×3 A/B buttons for testing

- [x] **HP Restore Animation** — 2026-06-01
  - PlayerAvatar.heal(amount): HP clamped to max, HP bar flashes green, returns to normal
  - "+N HP" floating label in green (same tween pattern as damage numbers)
  - Glow ring flashes green then back to team color
  - Arena.heal_team(team, amount): heals all alive/non-respawning avatars on team
  - Arena.heal_random_avatar(team, amount): heals one random alive avatar
  - Arena.spawn_combo_announce(text, team): pop-in label rises from zone center

### D. Donation Type Scaling
- [x] **Update donation EXP/HP values** — 2026-06-01
  - GameManager.GIFT_TABLE: rose (+10 EXP, +5 HP), ice_cream (+25 EXP, +20 HP), rose_bouquet (+50 EXP, +50 HP), universe (+250 EXP, +150 HP)
  - on_gift_received: PlayerStats.add_exp(donor, exp, "donate") + passes hp in trigger_effect_requested
  - Arena._on_trigger_effect_requested: routes all tiers (small/medium → gift_attack, ultimate → ultimate_attack) + heal_team from hp field
  - Also fixes bug: TikTok path previously dropped rose/universe visual attacks (only "micro" was handled)
  - Arena.debug_donation_all(team, gift_name): applies GIFT_TABLE EXP+HP to ALL avatars on team
  - DebugPanel: "Donation Scale (All)" section — Rose A/B, IceCrm A/B, Univ A/B buttons
  - ultimate meter fill from universe: TODO Phase 3 (UltimateCharger not yet built)

---

## Todo — Phase 2 (Boss System & Difficulty Scaling) ❌

### A. Boss Spawning & Phases
- [x] **BossManager.gd** (AutoLoad) — 2026-06-01
  - States: IDLE → ANNOUNCING → ACTIVE → RESOLVED
  - Auto-spawn every 240s of active game, or score gap ≤ 20 after 60s
  - request_spawn() for manual/debug trigger
  - get_boss_hp/dmg/time(level) formulas: HP=100×1.6^L, DMG=25×1.5^L, TIME=120+L×10
  - On defeat: current_boss_level++, PlayerStats.on_boss_cleared(), Arena.exit_boss_phase(true)
  - On timeout: same level retry, Arena.exit_boss_phase(false)

- [x] **Boss spawn trigger logic** — 2026-06-01
  - 10-second warning overlay with darkening + "BOSS LEVEL X APPROACHING!" text
  - Arena.start_boss_announce() creates CanvasLayer overlay (layer=8)
  - Arena.enter_boss_phase() freezes avatars, blocks new spawns
  - Arena.exit_boss_phase() unfreezes, awards rewards on success

- [x] **Boss.tscn + Boss.gd** — 2026-06-01
  - Code-drawn visuals: blue left half (Team A) + red right half (Team B), center divider
  - HP bar above boss body with current/max label; color: green→red as depletes
  - Phase countdown timer below boss body; turns yellow at 60s, red at 30s
  - Attacks every 3 sec → Arena.damage_team_boss_attack(1/2, dmg)
  - Attack flash (red) and hit flash (green) on boss body
  - Damage numbers float up from boss on hit
  - "BOSS DEFEATED!" / "Boss survived..." text on resolve
  - Boss entered at (960, 280) on game_layer; avatar attacks auto-retarget it
  - Avatars use basic attack only during boss phase (no chain/laser)
  - Arena.get_nearest_enemy() returns boss node when is_boss_phase==true
  - Fixed: TikTok chat→spawn now wired via GameManager.spawn_avatar_requested signal
  - DebugPanel: "Spawn Boss" button + live "Lv.X" label

### B. Boss Damage Distribution
- [x] **Boss attack damage formula** — 2026-06-01 (implemented in Phase 2A)
  - Arena.damage_team_boss_attack(team, total_dmg)
  - 30% to highest-level avatar + 70% split evenly among ALL alive avatars (including highest)
  - maxi(1, dmg) ensures no zero-damage hits; skips dead/respawning avatars

- [x] **Team HP Pool indicator** — 2026-06-01
  - Arena.get_team_hp_ratio(team): sum(current_hp) / sum(max_hp) across all avatars → 0.0-1.0
  - Arena.get_team_hp_totals(team): returns Vector2i(cur_sum, max_sum) for label text
  - Boss.gd: two bars added below the phase timer (A POOL left, B POOL right)
  - Bars are 130×12px, color green→yellow→red as HP depletes
  - Text label inside each bar: "cur/max" updated every frame during boss phase

### C. Boss Phase Timing
- [x] **Timer scaling per boss level** — 2026-06-01
  - Formula: 120 + (level × 10) seconds already in BossManager.get_boss_time()
  - UI: Large center-bottom CanvasLayer overlay (600×104px) with 56px countdown timer
  - Color: white → yellow at 60s → red at 30s

- [x] **Boss phase flow** — 2026-06-01
  - Avatars freeze via set_boss_phase(true), spawn blocked while is_boss_phase
  - Cinematic camera: Camera2D added in Arena._ready(); tweens to (960,450) zoom 1.05× on enter, returns to (960,540) zoom 1.0 on exit
  - Success: score_bonus (100×level) both teams, 50% HP heal, overlay removed, camera returns
  - Failure (timeout): announce, overlay removed, camera returns, same boss level retry

### D. Boss Clear Rewards
- [x] **On boss defeat** — 2026-06-01
  - EXP: PlayerStats.on_boss_cleared(level) → +500×level to all registered players ✅ (was in Phase 2A)
  - Score: add_score(1/2, 100×level) in exit_boss_phase ✅ (was in Phase 2A)
  - HP restore: _heal_all_half() in exit_boss_phase ✅ (was in Phase 2A)
  - Visual: _spawn_boss_defeat_celebration(level) — CanvasLayer layer=12; white screen flash; 90px gold "BOSS DEFEATED!" pop-in; 44px purple "LEVEL X CLEARED!"; 28px green "+EXP • +Score • +50% HP" reward line; fades out over 3.85s
  - Fireworks: _spawn_fireworks(level) → 6+level bursts (cap 14) staggered 0–2.5s; _burst_firework() — 16-dot colored explosion, fly outward 52–115px, fade; 6 palette colors

---

## Todo — Phase 3 (Team Mechanics & Game Modes) ❌

### A. Counter-Ultimate System
- [x] **CounterUltimate.gd** (AutoLoad) — 2026-06-01
  - `start_window(defender_team)` — fire-and-forget coroutine; awaits 6 s, then opens 3 s window
  - Generation counter (`_window_gen`) prevents stale coroutines from opening stale windows
  - `get_damage_multiplier()` → 0.3 (parried) or 1.0 (hit) — called by UltimateEffect at impact
  - `cancel()` — public; clears active window and invalidates pending coroutines; hooked into DebugPanel cancel button
  - UltimateController._play_cinematic: calls `CounterUltimate.start_window(3 - from_team)` fire-and-forget after effect is added
  - UltimateEffect._show_impact: reads multiplier → damage = int(500 × mult); screen shake 18→5 on parry
  - Outcome texts: "PARRIED!" gold (CounterUltimate, on spacebar press); "HIT!" red (UltimateEffect, if mult=1.0)

- [x] **UI Counter Prompt** — 2026-06-01
  - CanvasLayer layer=15; 560×196 px panel centered at (960, 860); team-tinted background
  - Gold "COUNTER WINDOW!" header; 3D-style SPACEBAR key (300×58 px); instruction text
  - Countdown bar 480×20 px — yellow → orange → red as ratio decreases via _refresh_countdown()
  - Fades in over 0.25 s; removed immediately on press or timeout via _remove_prompt_ui()

### B. Ultimate Meter System
- [x] **UltimateCharger.gd** (AutoLoad) — 2026-06-01
  - `_meter {"team_a": 0.0, "team_b": 0.0}` clamped 0–100
  - `add_charge(team, amount)` — adds, clamps, refreshes bar; fires at 100% (transition guard: only fires when crossing from below 100)
  - `add_charge_both(amount)` — checks both prev values first, then updates & fires independently
  - `reset_meters()` — both teams → 0; called on `UltimateController.ultimate_finished`
  - Charge sources wired: rose+2%, ice_cream+5%, rose_bouquet+8%, universe+100% (via GameManager.GIFT_TABLE "meter" field in on_gift_received); like_x3+5%, donate_x3+5% (via ComboTracker.combo_milestone); boss_defeated+20% shared
  - Win streak ×3 charge: TODO Phase 4 (no win tracking yet)
  - Signals: `ultimate_ready(team)`, `meter_updated(team, percent)`
  - **Route fix**: Arena._on_trigger_effect_requested "ultimate" branch removed; Arena.on_gift("universe") → UltimateCharger.add_charge(100); DebugPanel Ultimate A/B → UltimateController.request_ultimate direct (bypass meter for test)

- [x] **Ultimate Meter UI** — 2026-06-01
  - CanvasLayer layer=4 (below dark focus overlay layer=5 during cinematics)
  - Team A: top-left (x=12, y=8–48), blue fill; Team B: top-right (x=1548, y=8–48), red fill
  - "ULTIMATE METER A/B" title (11px), dark bg bar (360×18px), colored fill, "N%" percent label centered on bar
  - "READY!" label (13px gold) below bar — appears with looping pulse tween when meter=100%, stops and hides on reset
  - Fill color lerps from dim base to bright as ratio increases

### C. Team Synergy & Combo Chains (Enhanced)
- [x] **Extend combo rewards to donation types** — 2026-06-01
  - **Updated combo texts** in ComboTracker to show meter/ATK buff info in announcements
  - **Full meter charges** in UltimateCharger: like_x3+5%, like_x5+20%, like_x10+50%(both), donate_x3+10%, donate_x10+20%
  - **Damage buff system** in Arena: `_dmg_buff {team: {mult, timer}}` decremented in `_process`; `apply_damage_buff(team, mult, duration)` extends active buff; `get_attack_mult(team) -> float`
	- donate_x5 → +50% ATK 5s; donate_x10 → +100% ATK 10s (wired in Arena._on_combo_milestone)
  - **Damage mult propagation**: PlayerAvatar._do_attack queries `get_attack_mult(_team)` → passes as `"damage_mult"` in fire() data to all 3 effects (PlayerAttack, Laser, Lightning); each applies `int(BASE_DMG * _damage_mult)`
  - **Mixed combo (PERFECT SYNC)**: ComboTracker.combo_sync signal fires when like≥3 AND donate≥3 simultaneously; resets both to 0; generation-safe (sync can't fire on same event as x10 reset)
    - Arena._on_combo_sync → heal_team(+75 HP) + announce "PERFECT SYNC!" + _spawn_sync_burst (8 rainbow fireworks in zone)
    - UltimateCharger._on_combo_sync → add_charge(team, 20%)

---

## Todo — Phase 4 (Leaderboard & Stream Integration) ❌

### A. Real-time Leaderboard
- [x] **Leaderboard.gd** (AutoLoad) — 2026-06-01
  - Track per stream: donation_score (GIFT_TABLE pts), kill_count, level, boss_clears
  - Wired: PlayerStats.level_changed, player_died; GameManager.trigger_effect_requested, spawn_avatar_requested, game_state_changed; BossManager.boss_defeated
  - Signals: `ranking_changed()`, `new_milestone(player_id, type)`
  - Queries: get_top_donors(n), get_top_killers(n), get_top_levels(n) → sorted Array

- [x] **LeaderboardUI.tscn + .gd** — 2026-06-01
  - CanvasLayer layer=3; code-driven panels at y=942 (bottom of screen)
  - Left: TOP DONORS (blue border); Center: TOP KILLERS (green border); Right: TOP LEVELS (red border)
  - Each panel: dark bg, title, 3 ranked rows (gold/silver/bronze); real-time via ranking_changed signal
  - Instanced in Arena.tscn

### B. Streamer Integration
- [x] **StreamerFeed.gd** (AutoLoad) — 2026-06-01
  - session_likes + session_donate_pts tracking
  - Like counter: live count + progress bar toward milestones (50/100/200/500/1k/5k/10k)
  - Donation toasts: slide-in from right, per-tier color (rose/ice_cream/universe), auto-fade 4s
  - Milestone banners: center-top slide-in for like milestones, level milestones, donor milestones, boss clears
  - Stretch goal bar: 5 tiers (50/100/200/500/1k pts), tier-unlock label
  - GameManager.like_event signal added; emitted in on_like_received for real-time per-like tracking
  - CanvasLayer layer=2; resets on game WAITING state

---

## Todo — Phase 5 (End Game & Long-term Engagement) ❌

### A. End of Stream Stats
- [x] **SessionStats.gd** (AutoLoad) — 2026-06-01
  - Tracks: highest_boss_cleared, highest_player_level, total_kills, total_boss_clears, total_ultimates, perfect_syncs
  - 9 achievements: First Blood, Power Player, Legendary Lv10, Boss Slayer, Boss Master x3, Like Storm 500, Whale Alert, Perfect Sync, Ultimate Frenzy
  - achievement_unlocked signal; get_snapshot() returns full data dict for EndGameScreen
  - Saves user://session_history.json: last_session + all_time (best_boss, total_streams, streak)
  - Loads history on _ready(); increments streak only if boss cleared that session
  - Triggers EndGameScreen 3 s after GAME_OVER; reset_session() on WAITING

- [x] **EndGameScreen.gd** (code-driven CanvasLayer layer=55) — 2026-06-01
  - Shows 3 s after game_over via SessionStats._show_screen()
  - Header: "STREAM ENDED", boss level cleared, stream # + streak
  - 3-column leaderboard (TOP DONORS / TOP KILLERS / TOP LEVELS) — 5 rows each, team-colored names
  - Achievement bubbles: up to 9 centered pills, per-achievement color, auto-hides unused
  - Stats row: ♥ Likes | Donation Pts | Total Kills | Bosses Cleared | Win Streak
  - Footer: "Next stream: reach Boss Level X!" + pulsing dismiss hint
  - Fade-in 0.55 s slide; auto-dismiss after 25 s; any key/click dismisses
  - No .tscn — fully code-driven, instanced from SessionStats on first GAME_OVER

### B. Stretch Goals
- [x] **StretchGoal.gd** (AutoLoad) + **StretchGoalUI** (code-driven) — 2026-06-01
  - 5 tiers at 50/100/200/500/1000 donation pts
  - Each tier fires a real gameplay effect:
    - 50pts  "Extra Visual Effects" → +20% ATK both teams 60s
    - 100pts "Boss Rush!"           → BossManager.request_spawn()
    - 200pts "Dragon Awakening"     → +200HP both + +50% ATK 45s
    - 500pts "Legendary Mode"       → +500HP both + +100% ATK 90s
    - 1000pts "ULTIMATE EVENT!"     → UltimateController fires both teams
  - UI: right strip x=1548, y=282; 5 tier cells (locked/✓), large progress bar, pts counter, next-tier label
  - Unlock announcement: overlay (layer=14), slide-in panel with tier title+desc, flash + fade in 3s
  - register_arena() wired from Arena._ready(); goal_tier_unlocked signal for other listeners
  - Resets on GameManager WAITING state

### C. Infinite Boss Loop Pacing
- [x] **Adjust duel phase duration** — 2026-06-01
  - `get_duel_interval(boss_level)`: 180s at Lv1, +30s/level, capped at 300s (5 min)
    - Lv1=180s | Lv2=210s | Lv3=240s | Lv4=270s | Lv5+=300s
  - Replaces old fixed `AUTO_SPAWN_INTERVAL=240s`
  - Close-match early trigger scaled to `interval × 0.35` min wait (was hardcoded 60s)
  - `_duel_interval` recalculated after every boss_defeated and boss_timed_out
  - `signal duel_phase_started(interval_secs)` emitted when duel resumes
  - Countdown HUD (CanvasLayer layer=3, center x=820, y=74, w=280):
    - "BOSS Lv.X" label + draining bar (green→yellow→red) + "M:SS" countdown
    - Visible only during duel phase (IDLE + game_active); hidden during boss

---

## Todo — Phase 6 (Visual Polish & Character Theming) ❌

### A. Character-Specific Ultimate Visuals
- [x] **Update UltimateEffect.gd to support team-specific videos** — 2026-06-01
  - `VIDEO_PATHS` dict: team_a → abyss_awakening_a.ogv, team_b → abyss_awakening_b.ogv
  - `_start_playback()` uses `VIDEO_PATHS.get(attacker_team)` instead of template string
  - `_fit_video_to_sprite()` repositions VideoStreamPlayer to match CharacterBackground sprite rect

- [x] **Background Character Display** — 2026-06-01
  - `CharacterBackground.tscn` instanced in Arena.tscn (was missing — group calls were no-ops)
  - TeamA_Bg/CharBg + TeamB_Bg/CharBg each fill one half of the screen (960×1080 each), CanvasLayer=-1
  - Idle: loads `assets/characters/{team}/bg_idle.jpg` at alpha 0.55 on _ready()
  - Ultimate pose: swaps to `ultimate_pose.jpg`, tweens alpha 0.55→0.85 in 0.15 s
  - Return to idle: swaps back, tweens alpha 0.85→0.55 in 0.30 s (called by UltimateEffect after effect finishes)

### B. Boss Theming
- [x] **Boss visual variants** — 2026-06-01
  - `_get_tier_data()` returns a dict of body_w/h, colors, aura, hp_bar_w per bracket
  - **AWAKENED** (Lv1-3): 280×110 body, blue/red split, white divider — base look
  - **ENRAGED** (Lv4-6): 330×130 body, gold divider + gold label, static gold aura backdrop, entrance shake 7.0 + golden flash
  - **APOCALYPSE** (Lv7+): 380×155 body, dark purple/blood-red split, red divider, pulsing red aura (sin wave in _process), entrance shake 14.0 + dark purple flash
  - Tier badge subtitle "— AWAKENED / ENRAGED / APOCALYPSE —" rendered inside boss body
  - HP bar width scales with tier (320 → 360 → 400 px)
  - `_refresh_hp_bar()` reads `_tier["hp_bar_w"]` instead of hardcoded const
  - `_spawn_entrance_flash(color, duration)` helper — CanvasLayer layer=18 full-screen rect, fades out

### C. Screen Shake & Feedback
- [x] **Intensity scaling with boss level** — 2026-06-01
  - `SHAKE_INTENSITY_MIN=3.0` (Lv1, spec 0.1) → `SHAKE_INTENSITY_MAX=14.0` (Lv10, spec 0.5)
  - `SHAKE_DURATION_MIN=0.25s` → `SHAKE_DURATION_MAX=0.45s` — also lerped with level
  - Formula: `t = clamp((level-1)/9, 0, 1)` → `lerp(min, max, t)` for both intensity and duration
  - Old formula `level × 2.5 + 2.0` reached 27px at Lv10 (overshoot); now capped at 14px
  - **Ultimate hit**: `SHAKE_HIT_INTENSITY=22.0px` (was 18), `SHAKE_HIT_DURATION=0.65s` (was 0.6) — spec 0.8 normalized
  - **Parry**: `SHAKE_PARRY_INTENSITY=4.0px` (was 5) — more distinct contrast vs full hit
  - Shake constants extracted to `const` in both `Boss.gd` and `UltimateEffect.gd`

---

## Todo — Phase 8 (Neutral Effects — Chaos System) ❌

### Overview
Effects triggered by TikTok gifts that hit **all avatars on both teams simultaneously**.
Full design spec in `docs/DESIGN.md` → "Neutral Effects System" section.

### A. Electric Storm ⚡ *(ice_cream neutral variant)*
- [x] **ElectricStorm.tscn + ElectricStorm.gd** — 2026-06-02
  - Timer 0.35s fires 14 strikes over 5s across random arena positions
  - Hit: 12 DMG to nearest avatar within 75px; 25% chance stun 1.0s
  - Chain: if second avatar within 120px → 8 DMG one-hop
  - Reuse LightningAttackEffect zigzag Line2D visual + cyan bolt shader
  - Ambient: drifting lightning-static GPUParticles2D backdrop
  - `fire({arena})` Dictionary API

### B. Meteor Shower ☄️ *(rose_bouquet neutral variant)*
- [ ] **MeteorShower.tscn + MeteorShower.gd**
  - Spawn 10–14 MeteorProjectile nodes, random x (50–1870), y=-80
  - Each falls speed 700–950 px/s, slight x drift
  - Hit radius 55px → 18 DMG + knockback 220px random direction
  - Fireball: orange Polygon2D + red glow shader + GPUParticles2D trail
  - Impact: burst explosion, screen_shake(0.25, 5.0)
  - `fire({arena})` Dictionary API

### C. Black Hole Pull 🌀 *(universe alternate)*
- [ ] **BlackHolePull.tscn + BlackHolePull.gd**
  - Spawns at arena center (960, 540)
  - Pull phase 3s: add velocity toward center PULL_FORCE=280 px/s² (ramp 0→280 over 1.5s)
  - Explosion phase 1s: 30 DMG + knockback 600px outward to all within 500px
  - Visual: black sphere + purple neon glow ring shader + spiraling GPUParticles2D
  - Explosion: purple ring expands 0→520px; full-screen dark purple flash alpha 0.4
  - screen_shake(0.65, 16.0) on explosion
  - `fire({arena})` Dictionary API

### D. Toxic Flood ☠️ *(3× consecutive gift trigger)*
- [ ] **ToxicFlood.tscn + ToxicFlood.gd**
  - Duration: 8s active + 2s dissipate
  - DoT: Arena.damage_all_alive(3, "toxic") every 0.5s (skips respawning)
  - Damage type "toxic" bypasses ATK multiplier buffs
  - Death from toxic: killer_id = "toxic_flood" (normal respawn)
  - Visual: green semi-transparent arena overlay (alpha 0.25, CanvasLayer layer=1)
  - GPUParticles2D: 150 green bubbles rising from floor, lifetime 2s
  - Damage numbers: green "-3" small font per tick per avatar
  - `fire({arena})` Dictionary API

### E. Arena Integration
- [x] **Arena.gd: spawn_electric_storm()** — 2026-06-02
  - preload ElectricStormScene + `spawn_electric_storm()` method
  - `get_all_alive_avatars() -> Array[Node]` helper (used by ElectricStorm hit detection)
- [x] **GameManager.gd: neutral_effect_requested signal** — 2026-06-02
  - Signal added to contract
- [x] **DebugPanel: "⚡ Electric Storm" button** — 2026-06-02
  - Code-driven button appended to VBox in _ready(); calls Arena.spawn_electric_storm()
- [ ] **Dispatcher spawn_neutral_effect(name, data)** — for Meteor / BlackHole / Toxic (Phase 8B-D)

---

## Todo — Phase 7 (TikTok Integration & Production) ❌

### A. Node.js TikTok Listener
- [ ] **Separate GitHub repo for Node.js listener**
  - Use tiktok-live-connector
  - Parse: chat (1/2), gifts (rose/universe), likes
  - Send to Godot: `ws://localhost:8765`
  - JSON format standardized

- [ ] **Like counter real-time**
  - Track cumulative likes per session
  - Every 50 likes: emit milestone event → Godot
  - Format: `{ type: "like_milestone", count: 50, total: 250 }`

### B. Production Deployment
- [ ] **Test with real TikTok live stream**
  - Full integration test
  - Monitor WebSocket latency
  - Verify all donation tiers work
  - Debug any desync issues

---

## Known Issues 🐛

- (ไม่มี)

---

## Notes & Observations

**Player Progression:**
- EXP curve becomes exponential at Lv6+
- Lv8 requires 256k+ EXP (likely multi-stream grind)
- Killing high-level enemies can accelerate progression

**Boss Difficulty:**
- Health: 1.6× scaling per level
- Damage: 1.5× scaling per level
- Boss Lv10: ~11k HP, ~2500 dmg/attack
- Requires coordinated high-level team (Lv6+)

**Engagement Loop:**
1. Players donate → meter fills → ultimate ready
2. Ultimate triggers → cinematic moment → team levels up
3. Boss appears → cooperative phase → rewards shared
4. Back to duel → continue accumulating exp/score
5. Repeat until stream end

**Monetization Points:**
1. Immediate feedback: donation = avatar grows, effect triggers
2. Progress bars: like counter, stretch goals (FOMO)
3. Leaderboard: competition (rival tracking)
4. Streamer hype: announcements on milestones
5. Long-term: next stream streak (retention)
