extends Node

## Cinematic ultimate controller — manages pause, dark overlay, FIFO queue, and cooldown.
## Registered as AutoLoad "UltimateController" in project.godot.
## Call register_arena(arena) from Arena._ready() before any ultimates fire.

const UltimateEffectScene := preload("res://effects/UltimateEffect.tscn")
const COOLDOWN_SEC := 2.0

signal ultimate_finished(team: String)

var is_ultimate_active: bool = false
var ultimate_queue: Array = []
var can_use_ultimate: bool = true

var _arena_ref: Node = null
var _focus_canvas: CanvasLayer = null
var _focus_rect: ColorRect = null

func _ready() -> void:
	# Must keep running while the scene tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_arena(arena: Node) -> void:
	_arena_ref = arena

# ── Public entry point ────────────────────────────────────────────────────────

func request_ultimate(from_team: int) -> void:
	if not can_use_ultimate:
		return
	can_use_ultimate = false
	_run_cooldown()  # async — resets can_use after COOLDOWN_SEC

	if is_ultimate_active:
		ultimate_queue.append(from_team)
		return

	_play_cinematic(from_team)  # async fire-and-forget

# ── Internal coroutines ───────────────────────────────────────────────────────

func _run_cooldown() -> void:
	await get_tree().create_timer(COOLDOWN_SEC, true).timeout
	can_use_ultimate = true

func _play_cinematic(from_team: int) -> void:
	if not is_instance_valid(_arena_ref):
		push_warning("[UltimateController] No arena registered — cannot play cinematic.")
		return

	is_ultimate_active = true
	GameManager.in_ultimate_mode = true

	_pause_game()
	await _show_focus_overlay()

	var effect := UltimateEffectScene.instantiate()
	_arena_ref.add_child(effect)
	CounterUltimate.start_window(3 - from_team)  # fire-and-forget; window opens at 6 s
	effect.fire({"from_team": from_team, "arena": _arena_ref})
	await effect.finished

	ultimate_finished.emit("team_a" if from_team == 1 else "team_b")

	await _hide_focus_overlay()
	_resume_game()
	GameManager.in_ultimate_mode = false

	# Chain next queued ultimate as a fresh coroutine, then exit this one.
	if ultimate_queue.size() > 0:
		await get_tree().create_timer(0.5, true).timeout
		var next: int = ultimate_queue.pop_front()
		_play_cinematic(next)  # fire-and-forget; it owns is_ultimate_active from here
		return

	is_ultimate_active = false

func _pause_game() -> void:
	get_tree().paused = true

func _resume_game() -> void:
	get_tree().paused = false

# ── Focus overlay ─────────────────────────────────────────────────────────────

func _show_focus_overlay() -> void:
	_focus_canvas = CanvasLayer.new()
	# Layer 5 = above game arena (0) but below VideoLayer (10) so the video stays bright.
	_focus_canvas.layer = 5
	_focus_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_focus_canvas)

	_focus_rect = ColorRect.new()
	_focus_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_focus_canvas.add_child(_focus_rect)
	# Set anchors after adding to tree so they resolve against the viewport.
	_focus_rect.anchor_right = 1.0
	_focus_rect.anchor_bottom = 1.0

	var tween := create_tween()
	tween.tween_property(_focus_rect, "color:a", 0.6, 0.3)
	await tween.finished

func _hide_focus_overlay() -> void:
	if not is_instance_valid(_focus_rect):
		return
	var tween := create_tween()
	tween.tween_property(_focus_rect, "color:a", 0.0, 0.3)
	await tween.finished
	if is_instance_valid(_focus_canvas):
		_focus_canvas.queue_free()
	_focus_canvas = null
	_focus_rect = null
