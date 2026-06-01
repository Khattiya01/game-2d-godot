extends Node

## Thin connector: routes MockWebSocket / WebSocketManager signals into
## GameManager's on_*_received() handlers (Dictionary API).
## Toggle use_mock in the Inspector; hot-swap via reload_connector().

@export var use_mock: bool = true

const _MOCK_SCRIPT: GDScript = preload("res://debug/MockWebSocket.gd")
const _WS_SCRIPT:   GDScript = preload("res://autoload/WebSocketManager.gd")

var _connector: Node = null

func _ready() -> void:
	_setup_connector()

func reload_connector() -> void:
	if _connector and is_instance_valid(_connector):
		_connector.queue_free()
		_connector = null
	await get_tree().process_frame
	_setup_connector()

func _setup_connector() -> void:
	_connector = Node.new()
	_connector.set_script(_MOCK_SCRIPT if use_mock else _WS_SCRIPT)
	_connector.name = "MockWebSocket" if use_mock else "WebSocketManager"
	add_child(_connector)

	# Bridge individual-param signals → GameManager Dictionary API.
	_connector.chat_received.connect(func(u, m, a):
		GameManager.on_chat_received({"username": u, "message": m, "avatar": a})
	)
	_connector.gift_received.connect(func(u, g, a, t):
		GameManager.on_gift_received({
			"username": u, "gift": g, "avatar": a,
			"team": "team_a" if t == 1 else "team_b"
		})
	)
	_connector.like_received.connect(func(u, c):
		GameManager.on_like_received({"username": u, "count": c, "team": ""})
	)

	print("[WSConnector] Active  mode=%s" % ("MOCK" if use_mock else "WS"))
