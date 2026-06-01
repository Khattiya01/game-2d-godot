extends Node2D

@onready var team_a_sprite: TextureRect = $TeamA_Bg/CharBg
@onready var team_b_sprite: TextureRect = $TeamB_Bg/CharBg
@onready var anim_player_a: AnimationPlayer = $TeamA_Bg/AnimationPlayer
@onready var anim_player_b: AnimationPlayer = $TeamB_Bg/AnimationPlayer

const IDLE_PATH := "res://assets/characters/{team}/bg_idle.jpg"
const ULTIMATE_PATH := "res://assets/characters/{team}/ultimate_pose.jpg"

func _ready() -> void:
	add_to_group("character_bg")
	_setup_rects()
	_load_idle_textures()
	_start_idle_animations()

func _setup_rects() -> void:
	# Size each TextureRect to fill its half of the screen at runtime.
	var vp := get_viewport().get_visible_rect().size
	var half_w := vp.x * 0.5
	for sprite in [team_a_sprite, team_b_sprite]:
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	team_a_sprite.position = Vector2.ZERO
	team_a_sprite.size    = Vector2(half_w, vp.y)
	team_b_sprite.position = Vector2(half_w, 0.0)
	team_b_sprite.size    = Vector2(half_w, vp.y)

func _load_idle_textures() -> void:
	# Load idle sprite for both teams if assets exist
	_try_set_texture(team_a_sprite, IDLE_PATH.format({"team": "team_a"}))
	_try_set_texture(team_b_sprite, IDLE_PATH.format({"team": "team_b"}))

func _start_idle_animations() -> void:
	# Play idle loop if animation is defined in editor
	if anim_player_a.has_animation("idle"):
		anim_player_a.play("idle")
	if anim_player_b.has_animation("idle"):
		anim_player_b.play("idle")

func switch_character(team: String) -> void:
	# Show idle pose of the given team, hide the other
	team_a_sprite.visible = (team == "team_a")
	team_b_sprite.visible = (team == "team_b")

func play_ultimate_pose(team: String) -> void:
	# Transition sprite to ultimate pose; UltimateEffect calls return_to_idle when done
	var sprite := team_a_sprite if team == "team_a" else team_b_sprite
	_try_set_texture(sprite, ULTIMATE_PATH.format({"team": team}))
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.8, 0.1)

func return_to_idle(team: String) -> void:
	# Fade back to idle texture after ultimate ends
	var sprite := team_a_sprite if team == "team_a" else team_b_sprite
	_try_set_texture(sprite, IDLE_PATH.format({"team": team}))
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.2)

func _try_set_texture(sprite: TextureRect, path: String) -> void:
	# Only load if asset file exists to avoid errors on missing placeholders
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
