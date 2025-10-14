extends Node3D

@onready var player = get_node_or_null("/root/Node3D/Player")
@onready var hud = get_node_or_null("/root/Node3D/HUD")

var recipes = {
	"campfire": {
		"requirements": {"wood": 10, "stone": 5},
		"scene": preload("res://Scenes/buildings/Campfire.tscn")
	},
	"workbench": {
		"requirements": {"wood": 15, "metal": 10},
		"scene": preload("res://Scenes/buildings/Workbench.tscn")
	}
}

var resource_manager = null


func _ready():
	if Engine.has_singleton("ResourceManager"):
		resource_manager = Engine.get_singleton("ResourceManager")
	else:
		resource_manager = get_node_or_null("/root/ResourceManager")

	print("✅ CraftingManager initialized")


# ========================
# 🔨 Основной метод крафта
# ========================
func craft_item(item_name: String) -> void:
	if not recipes.has(item_name):
		push_warning("⚠️ Нет рецепта для: " + item_name)
		return

	var recipe = recipes[item_name]
	var requirements = recipe["requirements"]

	# Проверяем наличие всех ресурсов
	for res_type in requirements.keys():
		if resource_manager.get_resource(res_type) < requirements[res_type]:
			_show_notification("❌ Недостаточно " + res_type)
			return

	# Вычитаем ресурсы
	for res_type in requirements.keys():
		resource_manager.add_resource(res_type, -requirements[res_type])

	# Задаём фиксированную точку спавна
	var spawn_pos = Vector3(-8, 0, 5)

	# Создаём предмет
	_spawn_crafted_item(item_name, spawn_pos)

	# Визуальное уведомление
	_show_notification("🔥 Скрафчен " + item_name.capitalize() + "!")


# ========================
# 🧱 Спавн предмета (фиксированная позиция)
# ========================
func _spawn_crafted_item(item_name: String, spawn_pos: Vector3) -> void:
	if not recipes.has(item_name):
		print("⚠️ Нет данных для предмета:", item_name)
		return

	var recipe = recipes[item_name]
	var scene = recipe.get("scene")
	if scene == null:
		print("⚠️ Не найдена сцена для:", item_name)
		return

	# === Инстанцируем и добавляем напрямую в корень ===
	var inst = scene.instantiate()
	var world_root = get_tree().root.get_child(0)
	world_root.add_child(inst)
	print("📦 Родитель верстака:", inst.get_parent().get_path())


	# === Устанавливаем позицию ===
	inst.global_position = spawn_pos
	print("🔥 Создан объект:", item_name, "в позиции", inst.global_position)

	# === Эффект появления ===
	var tween = create_tween()
	inst.scale = Vector3(0.1, 0.1, 0.1)
	tween.tween_property(inst, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# === Световой эффект ===
	var light = OmniLight3D.new()
	light.light_color = Color(1, 0.8, 0.4)
	light.light_energy = 2.5
	inst.add_child(light)

	var lt_tween = create_tween()
	lt_tween.tween_property(light, "light_energy", 0.0, 1.0)
	lt_tween.finished.connect(func(): light.queue_free())

	# === Звук при создании (если есть файл) ===
	if ResourceLoader.exists("res://sounds/build.wav"):
		var sfx = AudioStreamPlayer3D.new()
		sfx.stream = load("res://sounds/build.wav")
		sfx.global_position = spawn_pos
		world_root.add_child(sfx)
		sfx.play()

	# === Если объект поддерживает on_crafted() ===
	if inst.has_method("on_crafted"):
		inst.on_crafted()

	print("✅ Объект успешно зафиксирован в мире:", inst.name)


# ========================
# 💬 Всплывающее уведомление
# ========================
func _show_notification(text: String) -> void:
	if hud and hud.has_method("show_message"):
		hud.show_message(text)
	else:
		var label = Label3D.new()
		label.text = text
		label.modulate = Color(1, 1, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		get_tree().root.get_child(0).add_child(label)

		if player:
			label.global_position = player.global_position + Vector3(0, 2.0, 0)
		else:
			label.global_position = Vector3(0, 2.0, 0)

		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y + 1.0, 1.0)
		tween.tween_property(label, "modulate:a", 0.0, 1.0)
		await tween.finished
		label.queue_free()
