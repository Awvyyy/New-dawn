extends Camera3D

@export var target_path: NodePath
@export var zoom_speed: float = 3.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.5

var target: Node3D
var zoom_level: float = 1.0

func _ready():
	if target_path != NodePath(""):
		target = get_node(target_path)
	else:
		push_warning("⚠ target_path не задан — перетащи сюда World в инспекторе!")

func _process(_delta):
	if not target:
		return

	# Зум колёсиком
	if Input.is_action_just_pressed("zoom_in"):
		zoom_level = max(zoom_level - 0.1, min_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		zoom_level = min(zoom_level + 0.1, max_zoom)

	# Применяем зум: просто масштабируем весь мир
	target.scale = Vector3.ONE * zoom_level
