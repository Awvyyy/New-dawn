extends Node3D

@onready var label: Label3D = $Label3D

# ⚙️ Настройки поведения
var lifetime := 1.8
var float_speed := 0.6
var start_scale := Vector3(0.3, 0.3, 0.3)
var end_scale := Vector3(1.0, 1.0, 1.0)

# Этапы появления/исчезновения
var fade_in_time := 0.2
var fade_out_time := 0.5

# Настройки "вылета"
var jump_force := 0.8
var gravity := -1.8
var side_drift := 0.4

var velocity := Vector3.ZERO
var elapsed := 0.0
var setup_done := false
var camera: Camera3D

# 🎨 Цвета ресурсов
var resource_colors := {
	"metal": Color(0.8, 0.8, 0.9),   # светло-серый с голубым оттенком
	"wood": Color(0.6, 0.4, 0.2),    # коричневый
	"stone": Color(0.5, 0.5, 0.5),   # нейтрально-серый
	"water": Color(0.3, 0.6, 1.0),   # ярко-голубой
	"food": Color(0.9, 0.7, 0.2)     # золотистый, для еды
}

func _ready():
	camera = get_viewport().get_camera_3d()

# text = "+5", resource_type = "metal"
func setup(text: String, resource_type: String = "default") -> void:
	var color = resource_colors.get(resource_type.to_lower(), Color.WHITE)
	label.text = text
	label.modulate = color
	label.modulate.a = 0.0
	scale = start_scale
	elapsed = 0.0
	setup_done = true

	var random_dir = Vector3(randf_range(-side_drift, side_drift), 1.0, randf_range(-side_drift, side_drift)).normalized()
	velocity = random_dir * jump_force

func _process(delta: float) -> void:
	if not setup_done:
		return

	elapsed += delta

	# Поворот лицом к камере
	if camera:
		look_at(camera.global_position, Vector3.UP)

	# "Физика" движения
	velocity.y += gravity * delta
	global_position += velocity * delta

	# Этапы появления / исчезновения
	if elapsed < fade_in_time:
		var t = elapsed / fade_in_time
		label.modulate.a = t
		scale = start_scale.lerp(end_scale, t)
	elif elapsed < lifetime - fade_out_time:
		label.modulate.a = 1.0
	else:
		var t = (elapsed - (lifetime - fade_out_time)) / fade_out_time
		label.modulate.a = lerp(1.0, 0.0, t)
		scale = end_scale.lerp(end_scale * 1.3, t)

	if elapsed >= lifetime:
		queue_free()
