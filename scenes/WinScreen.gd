extends CanvasLayer

@onready var backdrop: ColorRect = $Backdrop
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

const WIN_TEXT := ["DRAW!", "TEAM A WINS!", "TEAM B WINS!"]
const WIN_COLORS := [
	Color(0.85, 0.85, 0.85, 1.0),
	Color(0.32, 0.62, 1.0,  1.0),
	Color(1.0,  0.25, 0.10, 1.0),
]
const SHADOW_COLORS := [
	Color(0.5,  0.5,  0.5,  0.7),
	Color(0.0,  0.35, 1.0,  0.7),
	Color(1.0,  0.1,  0.0,  0.7),
]

func _ready() -> void:
	hide()
	get_parent().game_over.connect(_on_game_over)

func _on_game_over(winner: int) -> void:
	show_winner(winner)

func show_winner(winner: int) -> void:
	title_label.text = WIN_TEXT[winner]
	title_label.add_theme_color_override("font_color",         WIN_COLORS[winner])
	title_label.add_theme_color_override("font_shadow_color",  SHADOW_COLORS[winner])
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))

	backdrop.modulate.a  = 0.0
	title_label.modulate.a    = 0.0
	title_label.scale         = Vector2(0.85, 0.85)
	subtitle_label.modulate.a = 0.0
	show()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(backdrop,       "modulate:a", 1.0,                 0.8)
	tw.tween_property(title_label,    "modulate:a", 1.0,                 0.45).set_delay(0.25)
	tw.tween_property(title_label,    "scale",      Vector2(1.08, 1.08), 0.12).set_delay(0.25)
	tw.tween_property(title_label,    "scale",      Vector2.ONE,         0.30).set_delay(0.37)
	tw.tween_property(subtitle_label, "modulate:a", 1.0,                 0.45).set_delay(0.65)

func dismiss() -> void:
	hide()
