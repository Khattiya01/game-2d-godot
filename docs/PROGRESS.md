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

*(none)*

---

## Todo — Phase 8 (Neutral Effects — Chaos System) ❌

### Overview
Effects triggered by TikTok gifts that hit **all avatars on both teams simultaneously**.
Full design spec in `docs/DESIGN.md` → "Neutral Effects System" section.

### A. Meteor Shower ☄️ *(rose_bouquet neutral variant)*
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
- [ ] **Dispatcher spawn_neutral_effect(name, data)** — for Meteor / BlackHole / Toxic (Phase 8A-C)

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

## Todo — Phase 9 (Skill System v2.0 — กำลังภายใน Theme) ❌

Full design spec in `docs/DESIGN.md` → "Skill System v2.0" section.

### A. Team Theme — Patch 1.0 Config ✅
- [x] Add `current_patch` const to GameManager: `"wudang_dark"` (ขาว vs ดำ)
- [x] Update PlayerAvatar glow ring: Team A = cyan `Color(0,0.88,1)`, Team B = purple `Color(0.65,0,0.9)` (replace blue/red)
- [x] Update CharacterBackground: `_resolve_path()` checks `assets/characters/wudang_dark/{team}/` first, falls back to base path
- [x] Update Arena zone glow shaders + score/team labels to match new team colors (cyan/purple)

### B. Gift → Skill Router (Option B) ✅
- [x] Expand GameManager.GIFT_TABLE keys: `donut`, `gift_box`, `panda`, `whale_gift` + `skill_type`/`skill_type_2` fields on all entries
- [x] Add `donation_value` routing in `on_gift_received`: >10–50B → t4b, >50–100B → t4c, >100B → t4d (overrides gift-based tier)
- [x] GameManager.on_gift_received: emits `skill_type`/`skill_type_2`/`donation_value` in trigger_effect_requested
- [x] Arena: `spawn_skill(skill_type, team, attacker, target)` dispatcher — all 10 skill types routed; unimplemented fall back to placeholders (see Phase 9-C/D/E/F)
- [x] Arena: `_on_trigger_effect_requested` updated to call `spawn_skill` when skill_type present; `_get_random_alive_avatar()` helper added
- [x] MockWebSocket: R=donut, T=gift_box, Y=panda, U=ice_cream, I=whale_gift test keys
- [x] Node.js JSON spec documented in WSConnector.gd comment: `donation_value` float (baht) optional field

### C. Dash Skill — Tier 1 (gift: gift_box) ✅
- [x] **CloudStep.tscn + CloudStep.gd** (Team A) — 200px smooth dash, 5-streak white-cyan trail, arrival ring, invincible 0.20s
- [x] **ShadowBlink.tscn + ShadowBlink.gd** (Team B) — instant 200px blink, purple smoke at origin + 8-spark ring at dest, invincible 0.20s
- [x] PlayerAvatar: `_is_dashing: bool` flag; physics skipped + `take_damage` blocked while dashing
- [x] Both scripts: `fire({avatar, arena})` Dictionary API; dash direction = velocity or team forward; clamped to zone bounds
- [x] Arena: CloudStep/ShadowBlink preloaded; `spawn_skill("dash_t1")` instantiates correct scene by team

### D. Shield Skill — Tier 1 (gift: donut) ✅
- [x] **ChiShield.tscn + ChiShield.gd** (Team A) — gold/white bubble ring (Line2D + FlashPolygon), absorbs 1 hit fully, 5s max, golden burst on activate, white-gold flash on break
- [x] **DemonShell.tscn + DemonShell.gd** (Team B) — black/red ring + 8 blood-red Polygon2D spikes, absorbs 1 hit + reflects 20% dmg back to attacker (call_deferred), 5s max
- [x] PlayerAvatar: `take_damage()` already intercepts via `shield_bubble` group + `absorb_damage(dmg, killer_id)`; killer_id now passed so reflect works
- [x] Shield visual attached as child of avatar at `position = Vector2.ZERO`; auto-removes on break (0.22s) or timeout (5s fade)
- [x] Both scripts: `fire({avatar})` Dictionary API; add_to_group("shield_bubble")
- [x] Arena: ChiShield/DemonShell preloaded; `spawn_skill("shield_t1")` routes by team (was ShieldBubble placeholder)
- [x] DebugPanel: "Chi Shield A / Demon Shell B" test buttons added (donut gift via on_gift)

### E. Buff Skills ✅
#### E1. Buff T1 — ATK +20% (gift: panda) ✅
- [x] **ChiGathering.tscn + ChiGathering.gd** (Team A) — rotating white-cyan orbit ring + rising chi particles, +20% ATK 8s; "ATK +20%" float label on activate
- [x] **BloodRage.tscn + BloodRage.gd** (Team B) — pulsing blood-red ring + rising fire particles, +20% ATK 8s; "RAGE +20%" label on activate
- [x] PlayerAvatar: `_personal_atk_mult: float = 1.0` + `_atk_buff_stacks: int` (ref-count for overlap); `dmg_mult *= _personal_atk_mult` in `_do_attack()`
- [x] Stack-safe: expire decrements counter, resets to 1.0 only when stacks reach 0
- [x] Arena: ChiGathering/BloodRage preloaded; `spawn_skill("buff_t1")` routes by team
- [x] DebugPanel: "Chi Gather A / Blood Rage B" buttons (panda gift)

#### E2. Buff T2 (gift: ice_cream secondary alongside T3 attack) ✅
- [x] **WhiteLotusVeil.tscn + WhiteLotusVeil.gd** (Team A) — 16 white petal streaks + green heal particles burst; `arena.heal_team(team, 15)` instant; 0.85s then queue_free
- [x] **DarkHunger.tscn + DarkHunger.gd** (Team B) — 6 purple tendril activation + counter-rotating dark ring + dark swirl particles; `_lifesteal_active = true` for 8s; stack-safe ref-count
- [x] PlayerAvatar: `_lifesteal_active: bool` + `_lifesteal_stacks: int`; in `_do_attack()` heals self `int(est_dmg × 0.20)` after 0.28s delay per attack
- [x] Both scripts: `fire({avatar, team, arena})` Dictionary API; attached as child of attacker avatar
- [x] Arena: WhiteLotusVeil/DarkHunger preloaded; `spawn_skill("buff_t2")` routes by team
- [x] DebugPanel: "Lotus Veil A / Dark Hunger B" buttons (ice_cream gift)

### F. Attack Skills (Team-specific, replace existing generic effects) ✅
*All scripts: `fire({attacker, target, arena, damage_mult, base_dmg})` Dictionary API*
- [x] **SwordQi.gd** (T2 A) — white blade projectile, ×2 dmg, cross-flash impact
- [x] **DarkNeedle.gd** (T2 B) — 3-needle spread fan, ×2 total dmg, chains to nearest enemies
- [x] **WhiteCrane.gd** (T3 A) — 3 feather arcs, ×2 per feather, staggered 0.08s, white petal burst
- [x] **TigerClaw.gd** (T3 B) — 3 claw-slash marks at target, ×2 per slash, staggered 0.10s
- [x] **TaiChiVortex.gd** (T4a A) — spinning concentric rings build-up, ×3.5 AoE 200px, expand rings on burst
- [x] **DarkTornado.gd** (T4a B) — pull phase (_process) 150px 0.65s then purple burst, ×3.5 AoE 200px
- [x] **HeavenPalm.gd** (T4b A) — 4-ring shockwave + palm-print 5-line burst, ×5 + knockback 300px, 400px AoE
- [x] **ShadowEruption.gd** (T4b B) — jagged cracks + 5 dark eruption pillars, ×5 + knockback 300px, 400px AoE
- [x] **WhiteDragonBeam.gd** (T4c A) — 4-layer wide white/cyan beam + energy-wave shader, ×8 (3 ticks), 1.5s
- [x] **BlackSerpent.gd** (T4c B) — serpentine wobbling dark/purple beam (sin-wave path), ×8 + DoT 20/s × 3s
- [x] **Transcendence.gd** (T4d A) — full-screen white flash + 5-ring nova, ×15, stun 2s, AoE 450px
- [x] **AbyssAnnihilation.gd** (T4d B) — screen dim + void implosion pull → purple explosion, ×15, stun 2s, AoE 450px
- [x] Arena: `spawn_skill("attack_t2"…"attack_t4d")` fully wired; `_get_avatar_base_dmg` / `_get_avatar_dmg_mult` helpers added

### G. Player Avatar Private Ultimate Bar ✅
- [x] PlayerAvatar.gd: `_private_ult_meter: float`, `_priv_ult_fired: bool`
- [x] `add_private_ult(percent)`: clamp 0–100, update CircularBars.set_ult(), call `_fire_private_ultimate()` at 100
- [x] Meter fill in `take_damage()`: `+3% + dmg/10%` (skips respawning state)
- [x] Meter fill in `_do_attack()`: `+2% + est_dmg/10%` (skips roll=3 shield)
- [x] T4d hit bonus: Arena.spawn_skill "attack_t4d" calls `attacker.add_private_ult(15.0)`
- [x] Auto-trigger: `_fire_private_ultimate()` → flash bar, "ULTIMATE!" label, `arena.spawn_private_ultimate(self)`, reset meter
- [x] **Bar UI**: 40×4 px in CircularBars._draw() below arc (y=RADIUS+7); Team A cyan→white, Team B purple→red gradient blend; `flash_ult_full()` method
- [x] CircularBars: `set_team()`, `set_ult()`, `flash_ult_full()` added
- [x] **DragonSoulAscension.gd+.tscn** (A): S-curve dragon body + wing arcs + cyan rings AoE, 300 DMG 300px, self-heal 50% max HP
- [x] **DemonKingDescent.gd+.tscn** (B): descent columns + demon crown spikes + purple aura rings, 300 DMG + stun 1.5s 300px, lifesteal 20%
- [x] Arena: `spawn_private_ultimate()` dispatcher + two new preloads
- [x] DebugPanel: "Dragon Soul A / Demon King B" buttons → fills first alive avatar meter to 100

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
