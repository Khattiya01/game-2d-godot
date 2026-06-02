# TikTok Battle Game

## Project Overview
2D battle game รัน local บน PC, stream ผ่าน OBS → TikTok Live
Godot 4 + GDScript, WebSocket รับ event จาก Node.js

## Tech Stack
- Godot 4.x (GDScript)
- Node.js + tiktok-live-connector
- WebSocket bridge localhost:8765

## Game Concept
- สองทีม: Team A (ซ้าย, สีน้ำเงิน) vs Team B (ขวา, สีแดง)
- คนดู TikTok พิมพ์ 1 หรือ 2 เพื่อเลือกทีม
- รูป profile ของคนนั้น spawn ลอยไปที่ทีมที่เลือก
- Donate/Gift trigger effect และโจมตีทีมตรงข้าม
- มี timer จำกัด ทีมไหน score สูงกว่าชนะ

## Gift → Effect Table
| Gift       | Score | Effect tier |
|------------|-------|-------------|
| rose       | +1    | small       |
| ice_cream  | +3    | medium      |
| universe   | +10   | ultimate    |
| like ×10   | —     | micro       |

## Intended File Structure
(ไฟล์ปัจจุบันอยู่ที่ root — การย้ายไป subfolders เป็น Todo ดู docs/PROGRESS.md)

```
autoload/
  GameManager.gd        ← AutoLoad singleton (state, score, timer, signals)
  WebSocketManager.gd   ← ย้ายมาจาก root (TODO)
scenes/
  Main.tscn
  Arena.tscn
  UILayer.tscn
  PlayerAvatar.tscn
  WinScreen.tscn
effects/
  GiftAttackEffect.tscn
  UltimateEffect.tscn
  MicroEffect.tscn
debug/
  DebugPanel.tscn
  DemoRunner.gd
docs/
  PROGRESS.md
  PROMPTS.md
```

## Coding Rules (ห้าม Claude ทำผิด)
- GDScript 4 syntax เท่านั้น
- ทุก signal ประกาศที่ `autoload/GameManager.gd`
- effect ทุกตัวรับ `Dictionary` เป็น parameter
- ห้าม hardcode ค่า ให้ใช้ `const` หรือ `@export`
- comment ภาษาอังกฤษสั้นๆ ทุก function

## Signal Contract (GameManager AutoLoad)
```gdscript
signal game_state_changed(new_state: GameState)
signal score_changed(team: String, new_score: int)
signal timer_updated(seconds_left: float)
signal game_over(winner: String)
signal spawn_avatar_requested(user_data: Dictionary)
signal trigger_effect_requested(effect_data: Dictionary)
```

## Visual Effects Toolkit (Godot 4)

Researched 2026-06-02 — confirmed from codebase. Use this before researching effects tools.

### Core Nodes

| Node | Use Case | Existing Example |
|------|----------|-----------------|
| `Line2D` (3 layers) | Bolts, beams, rings | LightningAttackEffect, LaserAttackEffect |
| `GPUParticles2D` | Bursts, trails, ambient atmosphere | All effects |
| `Polygon2D` | Geometric shapes (spikes, stars, flash) | SpikeExplosion, StunProjectile |
| `ColorRect` + `CanvasLayer` | Full-screen flash/overlay | UltimateEffect, FinalShockwaveA |
| `PointLight2D` | Dynamic 2D lighting on strike/impact | ElectricStorm (Phase 8) |
| `GradientTexture2D` | Programmatic radial gradient for light texture | ElectricStorm |

### Shader Patterns

| Pattern | Use | Code |
|---------|-----|------|
| Radial glow orb | Projectile glow | `smoothstep + pow` on UV distance |
| Animated noise overlay | Storm / fog atmosphere | `sin(uv.x * freq + TIME) * cos(...)` — no texture needed |
| Chromatic aberration | Screen distortion on impact | `uniform sampler2D screen_texture : hint_screen_texture` + RGB offset |

### Bolt / Lightning Technique (proven pattern — see LightningAttackEffect.gd)

```gdscript
# Zigzag with sin-envelope taper
var perp := (end - start).orthogonal().normalized()
var max_disp := clampf(dist * 0.18, 10.0, 42.0)
for i in SEGMENTS:
	var t := float(i) / float(SEGMENTS)
	pts.append(start.lerp(end, t) + perp * randf_range(-max_disp, max_disp) * sin(t * PI))
# 3-layer: aura (16px, alpha 0.13) → glow (6.5px, alpha 0.55) → core (1.8px, alpha 1.0)
# All lines use CanvasItemMaterial.BLEND_MODE_ADD
```

### PointLight2D Setup (programmatic, no asset needed)

```gdscript
var tex := GradientTexture2D.new()
tex.fill = GradientTexture2D.FILL_RADIAL
tex.fill_from = Vector2(0.5, 0.5)
tex.fill_to   = Vector2(1.0, 0.5)
var grad := Gradient.new()
grad.set_color(0, Color(1, 1, 1, 1))
grad.add_point(0.3, Color(0.7, 0.85, 1.0, 0.5))
grad.add_point(1.0, Color(0, 0, 0, 0))
tex.gradient = grad
tex.width = 128; tex.height = 128
light.texture = tex
light.energy = 3.5; light.texture_scale = 3.2; light.color = Color(0.4, 0.75, 1.0)
```

### Animation Patterns (Tween-based — no AnimationPlayer in project)

| Easing | Use Case |
|--------|----------|
| `TRANS_EXPO.EASE_OUT` | Explosive expansion (spikes, rings) |
| `TRANS_SINE.EASE_IN_OUT` | Looping pulse (shield bubble) |
| `TRANS_LINEAR` | Rotation (stun stars) |
| `tween_method()` | Frame-by-frame redraw (bolt flicker, spiral rings) |

### CanvasLayer Z-Budget

| Layer | Purpose |
|-------|---------|
| -1 | CharacterBackground |
| 1 | Storm / fog atmosphere overlay |
| 2 | PointLight2D flash per strike |
| 3 | LeaderboardUI, BossCountdownHUD |
| 4 | UltimateMeterUI |
| 5 | Bolt / beam effects (world-space) |
| 6 | Particle effects, ambient |
| 8 | Boss announce overlay |
| 10 | Video player (Ultimate cinematic) |
| 12 | Boss defeat celebration |
| 14 | StretchGoal unlock banner |
| 15 | Counter-ultimate prompt |
| 16 | Screen flash (ColorRect) |
| 17 | Chromatic aberration overlay |
| 18 | Boss entrance flash |
| 20 | Announcement labels (storm, neutral effects) |
| 50 | WinScreen |
| 55 | EndGameScreen |

### Neutral Effect Coordinate Notes

- World-space nodes (Line2D bolts, PointLight2D, GPUParticles2D impact): add as direct children of effect Node2D
- Screen-space nodes (ColorRect overlays, ambient particles): wrap in CanvasLayer child
- Viewport is 1920×1080, Camera2D at (960,540) zoom=1 → world coords = screen coords → no conversion needed

## Current Status
ดู docs/PROGRESS.md

## Current Game Design
Read docs/DESIGN.md for complete system design
Read docs/PROGRESS.md for implementation status
