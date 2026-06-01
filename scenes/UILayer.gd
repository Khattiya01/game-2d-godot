extends CanvasLayer

@onready var score_a: Label = $ScoreA
@onready var score_b: Label = $ScoreB
@onready var timer_label: Label = $TimerPanel/TimerLabel

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.timer_updated.connect(_on_timer_updated)
	GameManager.game_over.connect(_on_game_over)
	_on_timer_updated(GameManager.time_remaining)

func _on_score_changed(team: String, new_score: int) -> void:
	if team == "team_a":
		score_a.text = str(new_score)
	else:
		score_b.text = str(new_score)

func _on_timer_updated(seconds: float) -> void:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	timer_label.text = "%d:%02d" % [m, s]

func _on_game_over(winner: String) -> void:
	match winner:
		"team_a":
			timer_label.text = "TEAM A!"
			timer_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 1.0))
		"team_b":
			timer_label.text = "TEAM B!"
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.08, 1.0))
		"draw":
			timer_label.text = "DRAW!"
			timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
