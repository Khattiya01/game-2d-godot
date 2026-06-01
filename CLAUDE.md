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

## Current Status
ดู docs/PROGRESS.md

## Current Game Design
Read docs/DESIGN.md for complete system design
Read docs/PROGRESS.md for implementation status
