extends Node

## AutoLoad: manages the counter-ultimate spacebar window during enemy cinematics.
## UltimateController calls start_window() fire-and-forget at cinematic start.
## UltimateEffect calls get_damage_multiplier() at impact time to resolve damage.

const WINDOW_OPEN_DELAY := 6.0     # seconds into cinematic before window appears
const WINDOW_DURATION   := 3.0     # seconds the spacebar window stays open
const DAMAGE_MULT_HIT   := 1.0     # no counter → full damage
const DAMAGE_MULT_PARRY := 0.3     # successful counter → 30% damage

var _window_open: bool = false
var _counter_succeeded: bool = false
var _window_timer: float = 0.0
var _window_gen: int = 0            # generation counter guards stale coroutines
var _prompt_canvas: CanvasLayer = null
var _prompt_root: Control = null
var _countdown_fill: ColorRect = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not _window_open:
		return
	_window_timer = maxf(0.0, _window_timer - delta)
	_refresh_countdown(_window_timer / WINDOW_DURATION)
	if _window_timer <= 0.0:
		_close_window(false)

func _unhandled_input(event: InputEvent) -> void:
	if not _window_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_close_window(true)
			get_viewport().set_input_as_handled()

# ── Public API ────────────────────────────────────────────────────────────────

# Fire-and-forget: waits 6 s then opens the 3 s counter window.
# Called by UltimateController without await at the start of each cinematic.
func start_window(defender_team: int) -> void:
	cancel()
	_counter_succeeded = false
	_window_gen += 1
	var gen := _window_gen
	await get_tree().create_timer(WINDOW_OPEN_DELAY, true).timeout
	if gen != _window_gen or not is_inside_tree():
		return
	_open_window(defender_team)

# Returns 0.3 if player parried, 1.0 otherwise.
# Called by UltimateEffect._show_impact() at damage-application time.
func get_damage_multiplier() -> float:
	return DAMAGE_MULT_PARRY if _counter_succeeded else DAMAGE_MULT_HIT

# Closes any active window and invalidates pending start_window coroutines.
func cancel() -> void:
	_window_gen += 1
	_window_open = false
	_remove_prompt_ui()

# ── Internal ──────────────────────────────────────────────────────────────────

func _open_window(defender_team: int) -> void:
	_window_open = true
	_window_timer = WINDOW_DURATION
	_build_prompt_ui(defender_team)

func _close_window(pressed: bool) -> void:
	_window_open = false
	_remove_prompt_ui()
	if pressed:
		_counter_succeeded = true
		_show_outcome("PARRIED!", Color(1.0, 0.88, 0.15, 1.0))

# ── Prompt UI ─────────────────────────────────────────────────────────────────

func _build_prompt_ui(defender_team: int) -> void:
	_prompt_canvas = CanvasLayer.new()
	_prompt_canvas.layer = 15
	_prompt_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_prompt_canvas)
	_prompt_root = Control.new()
	_prompt_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_canvas.add_child(_prompt_root)

	# Background panel — tinted by defender team color
	var tint := Color(0.2, 0.4, 1.0, 0.18) if defender_team == 1 \
			else Color(1.0, 0.22, 0.12, 0.18)
	var bg := ColorRect.new()
	bg.color = tint
	bg.size = Vector2(560, 196)
	bg.position = Vector2(680, 762)   # centered: 960 - 280
	_prompt_root.add_child(bg)

	var top_line := ColorRect.new()
	top_line.color = Color(1.0, 0.85, 0.0, 0.92)
	top_line.size = Vector2(560, 3)
	top_line.position = Vector2(680, 762)
	_prompt_root.add_child(top_line)

	var header := Label.new()
	header.text = "COUNTER WINDOW!"
	header.size = Vector2(560, 34)
	header.position = Vector2(680, 768)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	header.add_theme_constant_override("outline_size", 2)
	_prompt_root.add_child(header)

	# SPACEBAR key visual (outer frame + inner face)
	var key_outer := ColorRect.new()
	key_outer.color = Color(0.88, 0.88, 0.88, 1.0)
	key_outer.size = Vector2(300, 58)
	key_outer.position = Vector2(810, 808)   # centered: 960 - 150
	_prompt_root.add_child(key_outer)

	var key_inner := ColorRect.new()
	key_inner.color = Color(0.72, 0.72, 0.72, 1.0)
	key_inner.size = Vector2(292, 50)
	key_inner.position = Vector2(814, 812)
	_prompt_root.add_child(key_inner)

	var key_lbl := Label.new()
	key_lbl.text = "SPACE BAR"
	key_lbl.size = Vector2(300, 58)
	key_lbl.position = Vector2(810, 808)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_lbl.add_theme_font_size_override("font_size", 26)
	key_lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
	_prompt_root.add_child(key_lbl)

	# Countdown bar (yellow → red)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.06, 0.06, 0.06, 0.92)
	bar_bg.size = Vector2(480, 20)
	bar_bg.position = Vector2(720, 880)   # centered: 960 - 240
	_prompt_root.add_child(bar_bg)

	_countdown_fill = ColorRect.new()
	_countdown_fill.color = Color(1.0, 0.85, 0.0, 1.0)
	_countdown_fill.size = Vector2(480, 20)
	_countdown_fill.position = Vector2(720, 880)
	_prompt_root.add_child(_countdown_fill)

	var inst := Label.new()
	inst.text = "PRESS TO COUNTER  —  70%% DAMAGE BLOCKED"
	inst.size = Vector2(560, 24)
	inst.position = Vector2(680, 906)
	inst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inst.add_theme_font_size_override("font_size", 13)
	inst.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	inst.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	inst.add_theme_constant_override("outline_size", 1)
	_prompt_root.add_child(inst)

	_prompt_root.modulate.a = 0.0
	var t := _prompt_root.create_tween()
	t.tween_property(_prompt_root, "modulate:a", 1.0, 0.25)

func _refresh_countdown(ratio: float) -> void:
	if not is_instance_valid(_countdown_fill):
		return
	_countdown_fill.size.x = 480.0 * ratio
	# yellow → orange → red as time runs out
	_countdown_fill.color = Color(
		lerpf(0.92, 1.0, 1.0 - ratio),
		lerpf(0.12, 0.82, ratio),
		0.05, 1.0
	)

func _remove_prompt_ui() -> void:
	if is_instance_valid(_prompt_canvas):
		_prompt_canvas.queue_free()
	_prompt_canvas = null
	_countdown_fill = null

# ── Outcome text ─────────────────────────────────────────────────────────────

func _show_outcome(text: String, color: Color) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 16
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	var lbl := Label.new()
	lbl.text = text
	lbl.size = Vector2(800, 100)
	lbl.position = Vector2(560, 450)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.modulate.a = 0.0
	lbl.pivot_offset = Vector2(400.0, 50.0)
	lbl.scale = Vector2(0.3, 0.3)
	cl.add_child(lbl)
	var t := lbl.create_tween().set_parallel(true)
	t.tween_property(lbl, "modulate:a", 1.0, 0.18)
	t.tween_property(lbl, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade := cl.create_tween()
	fade.tween_interval(1.8)
	fade.tween_property(cl, "modulate:a", 0.0, 0.5)
	fade.tween_callback(cl.queue_free)
