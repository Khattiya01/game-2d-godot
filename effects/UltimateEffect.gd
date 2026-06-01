extends Node2D

@onready var video_player: VideoStreamPlayer = $VideoLayer/VideoStreamPlayer
@onready var impact_particles: GPUParticles2D = $ImpactParticles
@onready var screen_flash_rect: ColorRect = $ScreenFlash/FlashRect
@onready var final_shockwave: Line2D = $FinalShockwave

const VIDEO_PATH_TEMPLATE := "res://assets/videos/ultimate/abyss_awakening_{team}.ogv"
const FinalShockwaveAScene := preload("res://effects/FinalShockwaveA.tscn")
const FinalShockwaveBScene := preload("res://effects/FinalShockwaveB.tscn")
const ULTIMATE_DAMAGE := 500

signal finished

var attacker_team: String = ""
var _from_team_int: int = 1
var target_pos: Vector2 = Vector2.ZERO
var _arena_ref: Node = null

func fire(effect_data: Dictionary) -> void:
	# Keep processing while the scene tree is paused (game is paused during cinematics).
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("ultimate_effects")
	_from_team_int = effect_data.get("from_team", 1)
	_arena_ref = effect_data.get("arena", null)
	attacker_team = "team_a" if _from_team_int == 1 else "team_b"

	if _arena_ref and _arena_ref.has_method("get_zone_center"):
		target_pos = _arena_ref.get_zone_center(3 - _from_team_int)
	else:
		target_pos = get_viewport_rect().size / 2.0

	get_tree().call_group("character_bg", "play_ultimate_pose", attacker_team)
	_fit_video_to_sprite()
	_start_playback()

func _fit_video_to_sprite() -> void:
	# Match VideoStreamPlayer rect to the CharBg TextureRect of the attacking team
	var nodes := get_tree().get_nodes_in_group("character_bg")
	if nodes.is_empty():
		return
	var sprite_path := "TeamA_Bg/CharBg" if attacker_team == "team_a" else "TeamB_Bg/CharBg"
	var sprite: TextureRect = nodes[0].get_node_or_null(sprite_path)
	if sprite == null:
		return
	# Reset anchors so code-set position/size is not overridden
	video_player.anchor_left = 0.0
	video_player.anchor_top = 0.0
	video_player.anchor_right = 0.0
	video_player.anchor_bottom = 0.0
	video_player.expand = true
	# TextureRect uses top-left origin — copy position and size directly
	video_player.position = sprite.position
	video_player.size = sprite.size

func _start_playback() -> void:
	# Play video with its own audio track; file suffix is "a"/"b" not full team string
	var team_letter := "a" if attacker_team == "team_a" else "b"
	var video_file := VIDEO_PATH_TEMPLATE.format({"team": team_letter})
	video_player.stream = load(video_file)
	video_player.play()

	# process_always=true so these timers tick even while the scene tree is paused.
	await get_tree().create_timer(8.5, true).timeout
	_show_impact(target_pos)
	_trigger_particles()

	await get_tree().create_timer(2.0, true).timeout
	get_tree().call_group("character_bg", "return_to_idle", attacker_team)
	finished.emit()
	queue_free()

func _show_impact(pos: Vector2) -> void:
	# Flash screen and expand team-specific shockwave at impact point
	impact_particles.global_position = pos

	screen_flash_rect.modulate.a = 0.7
	var tween := create_tween()
	tween.tween_property(screen_flash_rect, "modulate:a", 0.0, 0.4)

	if attacker_team == "team_b":
		var sw := FinalShockwaveBScene.instantiate()
		sw.process_mode = Node.PROCESS_MODE_ALWAYS
		get_parent().add_child(sw)
		sw.play(pos)
	else:
		var sw := FinalShockwaveAScene.instantiate()
		sw.process_mode = Node.PROCESS_MODE_ALWAYS
		get_parent().add_child(sw)
		sw.play(pos)

	# Apply counter-ultimate reduction before dealing damage
	var target_team := 3 - _from_team_int
	var mult := CounterUltimate.get_damage_multiplier()
	var damage := int(float(ULTIMATE_DAMAGE) * mult)
	if _arena_ref and _arena_ref.has_method("damage_team_all"):
		_arena_ref.damage_team_all(target_team, damage)

	# Outcome text: "HIT!" if no counter, "PARRIED!" already shown at spacebar press
	if mult >= 1.0:
		_show_outcome_text("HIT!", Color(1.0, 0.22, 0.22, 1.0))

	var shake := 18.0 if mult >= 1.0 else 5.0
	if _arena_ref and _arena_ref.has_method("screen_shake"):
		_arena_ref.screen_shake(0.6, shake)

func _show_outcome_text(text: String, color: Color) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 16
	# Add to parent (Arena) so the label outlives this effect node
	if is_instance_valid(get_parent()):
		get_parent().add_child(cl)
	else:
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

func _draw_shockwave(center: Vector2) -> void:
	# Expand and fade a ring from the impact center
	final_shockwave.points = _circle_points(center, 10.0, 32)
	final_shockwave.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_method(
		func(r: float) -> void: final_shockwave.points = _circle_points(center, r, 32),
		10.0, 400.0, 0.5
	)
	tween.parallel().tween_property(final_shockwave, "modulate:a", 0.0, 0.5)

func _trigger_particles() -> void:
	# One-shot burst at target position
	impact_particles.emitting = true

func _circle_points(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	# Generate evenly-spaced points forming a closed ring
	var pts := PackedVector2Array()
	pts.resize(segments + 1)
	for i in range(segments + 1):
		var a := (float(i) / segments) * TAU
		pts[i] = center + Vector2(cos(a), sin(a)) * radius
	return pts
