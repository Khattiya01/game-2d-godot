extends Node

## AutoLoad: manages the counter-ultimate TikTok parry window.
## Viewers press ❤️ (like) or donate to fill the parry meter within the window.
## UltimateController calls start_window() fire-and-forget at cinematic start.
## UltimateEffect calls get_damage_multiplier() at impact time to resolve damage.

const WINDOW_OPEN_DELAY := 6.0     # seconds into cinematic before window appears
const WINDOW_DURATION   := 3.0     # seconds the window stays open
const DAMAGE_MULT_HIT   := 1.0     # meter not full → full damage
const DAMAGE_MULT_PARRY := 0.3     # meter full → 30% damage (70% blocked)

# Fill per TikTok event (0.0–1.0 scale; parry triggers when _fill >= 1.0)
const FILL_PER_LIKE         := 0.04   # ~25 likes to fill
const FILL_PER_ROSE         := 0.08   # small gift / any unknown gift
const FILL_PER_ICE_CREAM    := 0.20   # medium gift
const FILL_PER_ROSE_BOUQUET := 0.35   # large gift
const FILL_PER_UNIVERSE     := 0.80   # ultimate gift

var _window_open: bool = false
var _counter_succeeded: bool = false
var _window_timer: float = 0.0
var _fill: float = 0.0              # 0.0 → 1.0; parry triggers at 1.0
var _window_gen: int = 0
var _prompt_canvas: CanvasLayer = null
var _prompt_root: Control = null
var _countdown_fill: ColorRect = null
var _parry_fill: ColorRect = null   # the fill meter bar

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not _window_open:
		return
	_window_timer = maxf(0.0, _window_timer - delta)
	_refresh_countdown(_window_timer / WINDOW_DURATION)
	if _window_timer <= 0.0:
		_close_window(false)

# ── Public API ────────────────────────────────────────────────────────────────

# Fire-and-forget: waits 6 s then opens the 3 s parry window.
# Called by UltimateController without await at the start of each cinematic.
func start_window(defender_team: int) -> void:
	cancel()
	_counter_succeeded = false
	_fill = 0.0
	_window_gen += 1
	var gen := _window_gen
	await get_tree().create_timer(WINDOW_OPEN_DELAY, true).timeout
	if gen != _window_gen or not is_inside_tree():
		return
	_open_window(defender_team)

# Called from Arena.on_like() — each TikTok heart fills the parry meter a little.
func add_like_parry() -> void:
	if not _window_open:
		return
	_add_fill(FILL_PER_LIKE)

# Called from Arena.on_gift() — donations fill the parry meter faster.
func add_donation_parry(gift_name: String) -> void:
	if not _window_open:
		return
	var amount: float
	match gift_name.to_lower():
		"universe":     amount = FILL_PER_UNIVERSE
		"rose_bouquet": amount = FILL_PER_ROSE_BOUQUET
		"ice_cream":    amount = FILL_PER_ICE_CREAM
		_:              amount = FILL_PER_ROSE
	_add_fill(amount)

# Returns 0.3 if parry succeeded, 1.0 otherwise.
# Called by UltimateEffect._show_impact() at damage-application time.
func get_damage_multiplier() -> float:
	return DAMAGE_MULT_PARRY if _counter_succeeded else DAMAGE_MULT_HIT

# Closes any active window and invalidates pending start_window coroutines.
func cancel() -> void:
	_window_gen += 1
	_window_open = false
	_fill = 0.0
	_remove_prompt_ui()

# ── Internal ──────────────────────────────────────────────────────────────────

func _add_fill(amount: float) -> void:
	_fill = minf(1.0, _fill + amount)
	_refresh_parry_meter(_fill)
	if _fill >= 1.0:
		_close_window(true)

func _open_window(defender_team: int) -> void:
	_window_open = true
	_window_timer = WINDOW_DURATION
	_build_prompt_ui(defender_team)

func _close_window(success: bool) -> void:
	_window_open = false
	_remove_prompt_ui()
	if success:
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
	bg.size = Vector2(560, 220)
	bg.position = Vector2(680, 744)   # centered: 960 - 280
	_prompt_root.add_child(bg)

	var top_line := ColorRect.new()
	top_line.color = Color(1.0, 0.85, 0.0, 0.92)
	top_line.size = Vector2(560, 3)
	top_line.position = Vector2(680, 744)
	_prompt_root.add_child(top_line)

	# Header
	var header := Label.new()
	header.text = "COUNTER WINDOW!"
	header.size = Vector2(560, 34)
	header.position = Vector2(680, 750)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	header.add_theme_constant_override("outline_size", 2)
	_prompt_root.add_child(header)

	# Main instruction: heart + donate
	var main_lbl := Label.new()
	main_lbl.text = "❤️  กด HEART  หรือ  DONATE !"
	main_lbl.size = Vector2(560, 42)
	main_lbl.position = Vector2(680, 786)
	main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_lbl.add_theme_font_size_override("font_size", 28)
	main_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.75, 1.0))
	main_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	main_lbl.add_theme_constant_override("outline_size", 2)
	_prompt_root.add_child(main_lbl)

	var sub_lbl := Label.new()
	sub_lbl.size = Vector2(560, 24)
	sub_lbl.position = Vector2(680, 826)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.95))
	sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	sub_lbl.add_theme_constant_override("outline_size", 1)
	_prompt_root.add_child(sub_lbl)

	# PARRY METER label
	var meter_lbl := Label.new()
	meter_lbl.text = "PARRY METER"
	meter_lbl.size = Vector2(480, 18)
	meter_lbl.position = Vector2(720, 854)
	meter_lbl.add_theme_font_size_override("font_size", 11)
	meter_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 0.9))
	_prompt_root.add_child(meter_lbl)

	# Parry meter bar background
	var parry_bg := ColorRect.new()
	parry_bg.color = Color(0.06, 0.06, 0.06, 0.92)
	parry_bg.size = Vector2(480, 22)
	parry_bg.position = Vector2(720, 870)
	_prompt_root.add_child(parry_bg)

	# Parry meter fill (starts empty, fills green → gold)
	_parry_fill = ColorRect.new()
	_parry_fill.color = Color(0.3, 1.0, 0.45, 1.0)
	_parry_fill.size = Vector2(0.0, 22)
	_parry_fill.position = Vector2(720, 870)
	_prompt_root.add_child(_parry_fill)

	# TIME label
	var time_lbl := Label.new()
	time_lbl.text = "TIME"
	time_lbl.size = Vector2(480, 18)
	time_lbl.position = Vector2(720, 896)
	time_lbl.add_theme_font_size_override("font_size", 11)
	time_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	_prompt_root.add_child(time_lbl)

	# Countdown bar background
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.06, 0.06, 0.06, 0.92)
	bar_bg.size = Vector2(480, 16)
	bar_bg.position = Vector2(720, 912)
	_prompt_root.add_child(bar_bg)

	# Countdown fill
	_countdown_fill = ColorRect.new()
	_countdown_fill.color = Color(1.0, 0.85, 0.0, 1.0)
	_countdown_fill.size = Vector2(480, 16)
	_countdown_fill.position = Vector2(720, 912)
	_prompt_root.add_child(_countdown_fill)

	# Bottom instruction
	var inst := Label.new()
	inst.text = "ครบหลอด = บล็อก 70%% ความเสียหาย"
	inst.size = Vector2(560, 22)
	inst.position = Vector2(680, 932)
	inst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inst.add_theme_font_size_override("font_size", 13)
	inst.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	inst.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	inst.add_theme_constant_override("outline_size", 1)
	_prompt_root.add_child(inst)

	_prompt_root.modulate.a = 0.0
	var t := _prompt_root.create_tween()
	t.tween_property(_prompt_root, "modulate:a", 1.0, 0.25)

func _refresh_parry_meter(ratio: float) -> void:
	if not is_instance_valid(_parry_fill):
		return
	_parry_fill.size.x = 480.0 * ratio
	# green → gold as meter fills
	_parry_fill.color = Color(
		lerpf(0.3, 1.0, ratio),
		lerpf(1.0, 0.88, ratio),
		lerpf(0.45, 0.1, ratio),
		1.0
	)

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
	_parry_fill = null

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
