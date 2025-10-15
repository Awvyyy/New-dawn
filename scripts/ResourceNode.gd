extends Area3D
const PARTICLES_SCENE := preload("res://effects/ResourceParticles.tscn")

@export var resource_type: String = "metal"
@export var resource_amount: int = 5
@export var respawn_time: float = 5.0
@export var highlight_material: Material
@export var floating_text_scene: PackedScene
@export var particles_scene: PackedScene
@export var collect_distance: float = 3.0
@export var glow_distance: float = 4.0 # 🔹 радиус свечения при приближении

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var label_3d: Label3D = $Label3D

var original_material: Material
var is_collected := false
var player_in_range := false
var player_ref: Node3D = null
var is_glowing_nearby := false
var is_mouse_over := false

# =========================
# 🧠 Инициализация
# =========================
func _ready() -> void:
	if mesh:
		original_material = mesh.get_surface_override_material(0)

	# ⚙️ Здесь больше не используем ResourceManager для хранения — но всё ещё может быть, если ты хочешь совместимость
	# Этот код можно оставить или убрать:
	# if Engine.has_singleton("ResourceManager"):
	#     resource_manager = Engine.get_singleton("ResourceManager")
	# else:
	#     resource_manager = get_node_or_null("/root/ResourceManager")

	# ⚡ Подключаем сигналы
	if not is_connected("input_event", Callable(self, "_on_input_event")):
		connect("input_event", Callable(self, "_on_input_event"))
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))

	print("✅ ResourceNode ready:", resource_type)


# =========================
# 🔦 Подсветка
# =========================
func _on_mouse_entered() -> void:
	is_mouse_over = true
	if not is_collected:
		_set_highlight(true)

func _on_mouse_exited() -> void:
	is_mouse_over = false
	if not is_collected and not is_glowing_nearby:
		_set_highlight(false)

func _set_highlight(state: bool) -> void:
	if mesh and highlight_material:
		mesh.set_surface_override_material(0, highlight_material if state else original_material)


# =========================
# 🧍 Обнаружение игрока
# =========================
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		label_3d.text = "Press [E] to collect " + resource_type

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		label_3d.text = resource_type
		is_glowing_nearby = false
		if not is_mouse_over:
			_set_highlight(false)


# =========================
# 🖱️ Клик по ресурсу
# =========================
func _on_input_event(_camera, event, click_position, _normal, _shape_idx) -> void:
	if is_collected:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _player_close_enough():
			is_collected = true
			is_glowing_nearby = false
			_set_highlight(false)
			_collect_resource(click_position)
		else:
			print("🚫 Слишком далеко для сбора!")


# =========================
# 🎮 Логика свечения и взаимодействия
# =========================
func _process(_delta: float) -> void:
	if player_ref and not is_collected:
		var distance = global_position.distance_to(player_ref.global_position)

		# Вошёл в радиус свечения
		if distance <= glow_distance and not is_glowing_nearby:
			is_glowing_nearby = true
			_set_highlight(true)
		# Вышел из радиуса свечения
		elif distance > glow_distance and is_glowing_nearby:
			is_glowing_nearby = false
			if not is_mouse_over:
				_set_highlight(false)

	# Нажатие клавиши взаимодействия
	if player_in_range and not is_collected and Input.is_action_just_pressed("interact"):
		if _player_close_enough():
			is_collected = true
			is_glowing_nearby = false
			_set_highlight(false)
			_collect_resource(global_position)
		else:
			print("🚫 Игрок слишком далеко для сбора.")


# =========================
# 📏 Проверка расстояния
# =========================
func _player_close_enough() -> bool:
	return player_ref and global_position.distance_to(player_ref.global_position) <= collect_distance


# =========================
# 💰 Сбор ресурса
# =========================
func _collect_resource(click_position: Vector3) -> void:
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "scale", mesh.scale * 0.2, 0.25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(func():
			mesh.visible = false
			if collision:
				collision.disabled = true
			if label_3d:
				label_3d.visible = false
		)

	# — добавить ресурс в инвентарь
	var inventory = null
	if Engine.has_singleton("Inventory"):
		inventory = Engine.get_singleton("Inventory")
	else:
		inventory = get_node_or_null("/root/Inventory")

	if inventory:
		inventory.add_item(resource_type, resource_amount)
	else:
		push_warning("⚠️ Inventory не найден!")

	_spawn_particles(click_position)
	_spawn_floating_text(click_position, resource_amount, resource_type)

	if respawn_time > 0.0:
		_task_respawn()
	else:
		await get_tree().create_timer(0.5).timeout
		queue_free()


# =========================
# ⏳ Респавн
# =========================
func _task_respawn() -> void:
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return

	is_collected = false
	is_glowing_nearby = false
	is_mouse_over = false

	if mesh:
		mesh.visible = true
		mesh.set_surface_override_material(0, original_material)
		mesh.scale = Vector3(0.2, 0.2, 0.2)

		var tween = create_tween()
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.4) \
			.set_trans(Tween.TRANS_BOUNCE) \
			.set_ease(Tween.EASE_OUT)

	if collision:
		collision.disabled = false

	if label_3d:
		label_3d.visible = true


# =========================
# 💨 Частицы
# =========================
func _spawn_particles(_click_position: Vector3) -> void:
	var inst = PARTICLES_SCENE.instantiate()
	if not inst:
		push_warning("⚠️ Не удалось инстанцировать ResourceParticles.tscn")
		return

	var tree = get_tree()
	if not tree:
		push_warning("⚠️ SceneTree не найден — некуда добавлять частицы")
		return

	var parent = tree.get_current_scene()
	if parent == null:
		parent = tree.root
	if parent == null:
		push_warning("⚠️ Нет подходящего родителя для частиц")
		return

	parent.add_child(inst)

	if inst is Node3D:
		inst.global_position = global_position
	else:
		for child in inst.get_children():
			if child is Node3D:
				child.global_position = global_position
				break

	if inst is GPUParticles3D or inst is CPUParticles3D:
		inst.emitting = true
	else:
		for child in inst.get_children():
			if child is GPUParticles3D or child is CPUParticles3D:
				child.emitting = true
				break

	await tree.create_timer(2.0).timeout
	if inst and inst.is_inside_tree():
		inst.queue_free()


# =========================
# 💬 Всплывающий текст
# =========================
func _spawn_floating_text(click_position: Vector3, amount: int, rtype: String) -> void:
	if not floating_text_scene:
		push_warning("⚠️ floating_text_scene не назначен! (debug)")
		return

	var inst = null
	if floating_text_scene is PackedScene:
		inst = floating_text_scene.instantiate()
	else:
		push_warning("⚠️ floating_text_scene не PackedScene: " + str(floating_text_scene))
		return

	if not inst:
		push_warning("⚠️ Не удалось инстанцировать floating_text_scene")
		return

	var tree = get_tree()
	if not tree:
		push_warning("⚠️ SceneTree не найден — некуда добавлять текст")
		return

	var parent_node = tree.get_current_scene()
	if parent_node == null:
		parent_node = tree.root
	if parent_node == null:
		push_warning("⚠️ Нет подходящего родителя для текста")
		return

	parent_node.add_child(inst)
	inst.owner = parent_node

	if inst is Node3D:
		inst.global_position = click_position + Vector3(0, 1.0, 0)
	else:
		for c in inst.get_children():
			if c is Node3D:
				c.global_position = click_position + Vector3(0, 1.0, 0)
				break

	if inst.has_method("setup"):
		inst.setup("+" + str(amount) + " " + rtype, rtype)
	else:
		var label = null
		if inst.has_node("Label3D"):
			label = inst.get_node("Label3D")
		else:
			for c in inst.get_children():
				if c is Label3D:
					label = c
					break
		if label:
			label.text = "+" + str(amount) + " " + rtype
		else:
			print("⚠️ floating_text_scene не содержит Label3D и нет метода setup.")
