extends Node2D

const BUFF_DURATION: float = 8.0
const SFX := preload("res://assets/sounds/apply_buff_01.wav")

var _avatar: Node = null
var _done: bool = false

func fire(data: Dictionary) -> void:
	_avatar = data.get("avatar")
	if not is_instance_valid(_avatar):
		queue_free()
		return
	position = Vector2.ZERO
	_play_sound()
	var stacks: int = int(_avatar.get("_lifesteal_stacks")) + 1
	_avatar.set("_lifesteal_stacks", stacks)
	_avatar.set("_lifesteal_active", true)
	_spawn_activation_tendrils()
	_spawn_aura()
	get_tree().create_timer(BUFF_DURATION).timeout.connect(_on_expire)

func _on_expire() -> void:
	if not is_instance_valid(self) or _done:
		return
	_done = true
	if is_instance_valid(_avatar):
		var stacks: int = maxi(0, int(_avatar.get("_lifesteal_stacks")) - 1)
		_avatar.set("_lifesteal_stacks", stacks)
		if stacks == 0:
			_avatar.set("_lifesteal_active", false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func():
		if is_instance_valid(self):
			queue_free()
	)

func _spawn_activation_tendrils() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 6 dark purple tendrils extend then fade
	for i in 6:
		var angle := TAU * float(i) / 6.0 + randf_range(-0.20, 0.20)
		var line := Line2D.new()
		add_child(line)
		line.z_index = 5
		line.material = mat
		line.width = 2.5
		line.default_color = Color(0.62, 0.0, 0.58, 0.88)
		line.antialiased = true
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.from_angle(angle) * randf_range(22.0, 36.0))
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, 0.45)
		t.tween_callback(line.queue_free)
	_spawn_buff_label(Color(0.75, 0.08, 0.70, 1.0), "LIFESTEAL")

func _spawn_aura() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Counter-rotating dark ring (predatory, slow)
	var dark_ring := Line2D.new()
	add_child(dark_ring)
	dark_ring.z_index = 3
	dark_ring.material = mat
	dark_ring.width = 3.0
	dark_ring.default_color = Color(0.58, 0.0, 0.58, 0.58)
	dark_ring.antialiased = true
	for j in 25:
		dark_ring.add_point(Vector2.from_angle(TAU * float(j) / 24.0) * 26.0)
	var rot := create_tween().set_loops()
	rot.tween_property(dark_ring, "rotation", -TAU, BUFF_DURATION * 0.75) \
		.set_trans(Tween.TRANS_LINEAR)
	var pulse := create_tween().set_loops()
	pulse.tween_property(dark_ring, "modulate:a", 0.14, 0.72) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(dark_ring, "modulate:a", 1.0, 0.72) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Dark swirling particles orbiting inward
	var grad := Gradient.new()
	grad.set_color(0, Color(0.65, 0.0, 0.75, 0.85))
	grad.set_color(1, Color(0.32, 0.0, 0.42, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3(0.0, -8.0, 0.0)
	pm.scale_min = 0.3
	pm.scale_max = 0.9
	pm.color_ramp = cramp
	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.z_index = 4
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 10
	particles.lifetime = 0.80
	particles.one_shot = false
	particles.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = pmat

func _spawn_buff_label(col: Color, text: String) -> void:
	var lbl := Label.new()
	add_child(lbl)
	lbl.text = text
	lbl.position = Vector2(-28, -36)
	lbl.size = Vector2(56, 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	var t := lbl.create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.85)
	t.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.35)
	t.set_parallel(false)
	t.tween_callback(lbl.queue_free)

func _play_sound() -> void:
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = SFX
	player.play()
	player.finished.connect(player.queue_free)

func _make_circle_tex() -> ImageTexture:
	const S := 8
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			var a := clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / (S * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
