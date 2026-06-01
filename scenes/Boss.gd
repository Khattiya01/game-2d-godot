extends Node2D

# Boss visual lives on game_layer at world position (960, 280).
# Avatar attack effects target this node via global_position + take_damage().

const ATTACK_INTERVAL: float = 3.0
const BOSS_W: float = 280.0
const BOSS_H: float = 110.0
const HP_BAR_W: float = 320.0
const HP_BAR_H: float = 18.0
const TEAM_BAR_W: float = 130.0
const TEAM_BAR_H: float = 12.0

signal boss_defeated
signal boss_timed_out

var _level: int = 1
var _max_hp: int = 0
var _current_hp: int = 0
var _time_remaining: float = 0.0
var _attack_timer: float = 1.5   # slight delay before first attack
var _arena_ref: Node = null
var _alive: bool = false

var _hp_fill: ColorRect = null
var _hp_label: Label = null
var _timer_label: Label = null
var _team_a_fill: ColorRect = null
var _team_b_fill: ColorRect = null
var _team_a_label: Label = null
var _team_b_label: Label = null

func setup(level: int, arena: Node) -> void:
	_level = level
	_arena_ref = arena
	_max_hp = BossManager.get_boss_hp(level)
	_current_hp = _max_hp
	_time_remaining = BossManager.get_boss_time(level)
	position = Vector2(960, 280)
	_build_visuals()
	_alive = true
	# Entrance pop-in
	modulate.a = 0.0
	scale = Vector2(0.25, 0.25)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.5)
	t.tween_property(self, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_visuals() -> void:
	var half := BOSS_W * 0.5

	# ── Body halves ───────────────────────────────────────────────
	var left := ColorRect.new()
	left.size = Vector2(half, BOSS_H)
	left.position = Vector2(-half, -BOSS_H * 0.5)
	left.color = Color(0.05, 0.3, 0.92, 0.9)
	add_child(left)

	var right := ColorRect.new()
	right.size = Vector2(half, BOSS_H)
	right.position = Vector2(0, -BOSS_H * 0.5)
	right.color = Color(0.92, 0.12, 0.05, 0.9)
	add_child(right)

	# Center divider
	var div := ColorRect.new()
	div.size = Vector2(3, BOSS_H)
	div.position = Vector2(-1.5, -BOSS_H * 0.5)
	div.color = Color(1.0, 1.0, 1.0, 0.75)
	add_child(div)

	# Boss name label
	var name_lbl := Label.new()
	name_lbl.text = "BOSS  LV.%d" % _level
	name_lbl.size = Vector2(BOSS_W, BOSS_H)
	name_lbl.position = Vector2(-half, -BOSS_H * 0.5)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_lbl.add_theme_constant_override("outline_size", 3)
	add_child(name_lbl)

	# ── HP bar ─────────────────────────────────────────────────────
	var bar_y := -BOSS_H * 0.5 - HP_BAR_H - 10.0

	var bar_title := Label.new()
	bar_title.text = "BOSS HP"
	bar_title.position = Vector2(-HP_BAR_W * 0.5, bar_y - 18.0)
	bar_title.add_theme_font_size_override("font_size", 12)
	bar_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 0.9))
	bar_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	bar_title.add_theme_constant_override("outline_size", 1)
	add_child(bar_title)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(HP_BAR_W, HP_BAR_H)
	bar_bg.position = Vector2(-HP_BAR_W * 0.5, bar_y)
	bar_bg.color = Color(0.07, 0.07, 0.07, 0.92)
	add_child(bar_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.size = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_fill.position = Vector2(-HP_BAR_W * 0.5, bar_y)
	add_child(_hp_fill)

	_hp_label = Label.new()
	_hp_label.size = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_label.position = Vector2(-HP_BAR_W * 0.5, bar_y)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_hp_label.add_theme_constant_override("outline_size", 1)
	add_child(_hp_label)

	# ── Phase timer ────────────────────────────────────────────────
	_timer_label = Label.new()
	_timer_label.size = Vector2(90, 22)
	_timer_label.position = Vector2(-45, BOSS_H * 0.5 + 5.0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 15)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35, 1.0))
	_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_timer_label.add_theme_constant_override("outline_size", 2)
	add_child(_timer_label)

	# ── Team HP Pool bars (below timer) ──────────────────────────────
	var pool_y := BOSS_H * 0.5 + 38.0   # just below the timer label

	# Team A pool (left half, blue)
	var title_a := Label.new()
	title_a.text = "A POOL"
	title_a.size = Vector2(TEAM_BAR_W, 13)
	title_a.position = Vector2(-BOSS_W * 0.5, pool_y - 14.0)
	title_a.add_theme_font_size_override("font_size", 10)
	title_a.add_theme_color_override("font_color", Color(0.45, 0.72, 1.0, 0.9))
	title_a.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_a.add_theme_constant_override("outline_size", 1)
	add_child(title_a)

	var bg_a := ColorRect.new()
	bg_a.size = Vector2(TEAM_BAR_W, TEAM_BAR_H)
	bg_a.position = Vector2(-BOSS_W * 0.5, pool_y)
	bg_a.color = Color(0.06, 0.06, 0.12, 0.88)
	add_child(bg_a)

	_team_a_fill = ColorRect.new()
	_team_a_fill.size = Vector2(TEAM_BAR_W, TEAM_BAR_H)
	_team_a_fill.position = Vector2(-BOSS_W * 0.5, pool_y)
	add_child(_team_a_fill)

	_team_a_label = Label.new()
	_team_a_label.size = Vector2(TEAM_BAR_W, TEAM_BAR_H)
	_team_a_label.position = Vector2(-BOSS_W * 0.5, pool_y)
	_team_a_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_a_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_team_a_label.add_theme_font_size_override("font_size", 9)
	_team_a_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_team_a_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_team_a_label.add_theme_constant_override("outline_size", 1)
	add_child(_team_a_label)

	# Team B pool (right half, red)
	var title_b := Label.new()
	title_b.text = "B POOL"
	title_b.size = Vector2(TEAM_BAR_W, 13)
	title_b.position = Vector2(BOSS_W * 0.5 - TEAM_BAR_W, pool_y - 14.0)
	title_b.add_theme_font_size_override("font_size", 10)
	title_b.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3, 0.9))
	title_b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_b.add_theme_constant_override("outline_size", 1)
	add_child(title_b)

	var bg_b := ColorRect.new()
	bg_b.size = Vector2(TEAM_BAR_W, TEAM_BAR_H)
	bg_b.position = Vector2(BOSS_W * 0.5 - TEAM_BAR_W, pool_y)
	bg_b.color = Color(0.12, 0.06, 0.06, 0.88)
	add_child(bg_b)

	_team_b_fill = ColorRect.new()
	_team_b_fill.size = Vector2(TEAM_BAR_W, TEAM_BAR_H)
	_team_b_fill.position = Vector2(BOSS_W * 0.5 - TEAM_BAR_W, pool_y)
	add_child(_team_b_fill)

	_team_b_label = Label.new()
	_team_b_label.size = Vector2(TEAM_BAR_W, TEAM_BAR_H)
	_team_b_label.position = Vector2(BOSS_W * 0.5 - TEAM_BAR_W, pool_y)
	_team_b_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_b_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_team_b_label.add_theme_font_size_override("font_size", 9)
	_team_b_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_team_b_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_team_b_label.add_theme_constant_override("outline_size", 1)
	add_child(_team_b_label)

	_refresh_hp_bar()
	_refresh_timer()

func _process(delta: float) -> void:
	_refresh_team_hp_pools()
	if not _alive:
		return
	_time_remaining -= delta
	_refresh_timer()
	if is_instance_valid(_arena_ref):
		_arena_ref.update_boss_phase_timer(_time_remaining)
	if _time_remaining <= 0.0:
		_on_timeout()
		return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = ATTACK_INTERVAL
		_do_attack()

# Called by avatar attack effects (same interface as PlayerAvatar).
func take_damage(amount: int, _killer_id: String = "") -> void:
	if not _alive:
		return
	_current_hp = maxi(0, _current_hp - amount)
	_refresh_hp_bar()
	_spawn_damage_number(amount)
	_flash_hit()
	if _current_hp == 0:
		_die()

func _do_attack() -> void:
	if not is_instance_valid(_arena_ref):
		return
	var dmg := BossManager.get_boss_dmg(_level)
	_arena_ref.damage_team_boss_attack(1, dmg)
	_arena_ref.damage_team_boss_attack(2, dmg)
	_flash_attack()
	_arena_ref.screen_shake(0.35, float(_level) * 2.5 + 2.0)

func _die() -> void:
	_alive = false
	_attack_timer = 9999.0
	_spawn_death_text("BOSS DEFEATED!")
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(self, "modulate", Color(2.0, 2.0, 0.5, 1.0), 0.15)
	t.tween_property(self, "scale", Vector2(1.35, 1.35), 0.15)
	t.tween_property(self, "modulate:a", 0.0, 0.55)
	t.tween_callback(func():
		boss_defeated.emit()
		queue_free()
	)

func _on_timeout() -> void:
	_alive = false
	_spawn_death_text("Boss survived...")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.7)
	t.tween_callback(func():
		boss_timed_out.emit()
		queue_free()
	)

func _flash_hit() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate", Color(0.5, 1.4, 0.5, 1.0), 0.06)
	t.tween_property(self, "modulate", Color.WHITE, 0.18)

func _flash_attack() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1.6, 0.4, 0.4, 1.0), 0.1)
	t.tween_property(self, "modulate", Color.WHITE, 0.28)

func _spawn_damage_number(amount: int) -> void:
	if not is_instance_valid(_arena_ref):
		return
	var container := Node2D.new()
	_arena_ref.game_layer.add_child(container)
	container.z_index = 15
	container.global_position = global_position + Vector2(randf_range(-30, 30), -20)
	var lbl := Label.new()
	container.add_child(lbl)
	lbl.text = "-%d" % amount
	lbl.position = Vector2(-18, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	var t := container.create_tween().set_parallel(true)
	t.tween_property(container, "global_position:y", container.global_position.y - 40.0, 0.85)
	t.tween_property(container, "modulate:a", 0.0, 0.85).set_delay(0.25)
	t.set_parallel(false)
	t.tween_callback(container.queue_free)

func _spawn_death_text(msg: String) -> void:
	if not is_instance_valid(_arena_ref):
		return
	var container := Node2D.new()
	_arena_ref.game_layer.add_child(container)
	container.z_index = 20
	container.global_position = global_position + Vector2(0, -40)
	var lbl := Label.new()
	container.add_child(lbl)
	lbl.text = msg
	lbl.size = Vector2(360, 50)
	lbl.position = Vector2(-180, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	container.scale = Vector2.ZERO
	var t := container.create_tween().set_parallel(true)
	t.tween_property(container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(container, "global_position:y", container.global_position.y - 80.0, 2.5).set_delay(0.1)
	t.tween_property(container, "modulate:a", 0.0, 1.5).set_delay(0.8)
	t.set_parallel(false)
	t.tween_callback(container.queue_free)

func _refresh_team_hp_pools() -> void:
	if not is_instance_valid(_arena_ref):
		return
	_refresh_team_bar(_team_a_fill, _team_a_label, _arena_ref.get_team_hp_ratio(1),
		_arena_ref.get_team_hp_totals(1))
	_refresh_team_bar(_team_b_fill, _team_b_label, _arena_ref.get_team_hp_ratio(2),
		_arena_ref.get_team_hp_totals(2))

func _refresh_team_bar(fill: ColorRect, lbl: Label, ratio: float, totals: Vector2i) -> void:
	if not is_instance_valid(fill):
		return
	fill.size.x = TEAM_BAR_W * ratio
	# green → yellow → red gradient
	fill.color = Color(
		lerpf(0.15, 0.92, 1.0 - ratio),
		lerpf(0.15, 0.88, ratio),
		0.1, 0.95
	)
	if is_instance_valid(lbl):
		lbl.text = "%d/%d" % [totals.x, totals.y]

func _refresh_hp_bar() -> void:
	if not is_instance_valid(_hp_fill):
		return
	var ratio := float(_current_hp) / float(maxi(1, _max_hp))
	_hp_fill.size.x = HP_BAR_W * ratio
	_hp_fill.color = Color(lerpf(0.9, 0.1, ratio), lerpf(0.1, 0.88, ratio), 0.1, 1.0)
	if is_instance_valid(_hp_label):
		_hp_label.text = "%d / %d" % [_current_hp, _max_hp]

func _refresh_timer() -> void:
	if not is_instance_valid(_timer_label):
		return
	var secs := int(maxf(0.0, _time_remaining))
	_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	if _time_remaining <= 30.0:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	elif _time_remaining <= 60.0:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2, 1.0))
