extends Control

@export var slot_scene: PackedScene
@export var columns: int = 4
@export var slot_size: Vector2 = Vector2(64, 64)

@onready var panel := $Panel/GridContainer
@onready var grid := $Panel/GridContainer
var inventory: Node = null

var slots: Array = []
var item_icons := {} # { "metal": "res://icons/metal.png", ... }

func _ready():
	panel.visible = false
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	add_to_group("inventory_ui_debug")
	set_process_input(true)
	print("✅ InventoryUI ready!")
	await _ensure_inventory_loaded()

	if not inventory:
		push_error("❌ Inventory так и не найден — UI не сможет обновиться!")
		return

	inventory.connect("inventory_updated", Callable(self, "_on_inventory_updated"), CONNECT_DEFERRED)
	_on_inventory_updated()


# 🔄 Мягкое ожидание появления автозагрузки
func _ensure_inventory_loaded() -> void:
	var retries = 10
	while retries > 0:
		if Engine.has_singleton("Inventory"):
			inventory = Engine.get_singleton("Inventory")
		elif get_node_or_null("/root/Inventory"):
			inventory = get_node_or_null("/root/Inventory")
		if inventory:
			print("✅ Inventory найден после", (10 - retries), "попыток")
			return
		await get_tree().process_frame
		retries -= 1
	push_warning("⚠️ Inventory не найден даже после ожидания!")


# 🔁 Обновление UI
func _on_inventory_updated():
	if not inventory:
		return
	var items = inventory.get_all_items()
	_update_grid(items)


func _update_grid(items: Dictionary):
	for slot in slots:
		slot.queue_free()
	slots.clear()

	for item_name in items.keys():
		var item_data = items[item_name]
		var slot = _create_slot(item_name, item_data)
		grid.add_child(slot)
		slots.append(slot)


func _create_slot(item_name: String, item_data: Dictionary) -> TextureButton:
	var slot = TextureButton.new()
	slot.custom_minimum_size = slot_size
	slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED  # 🔹 чтобы иконка не искажалась

	var icon_path = item_data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		slot.texture_normal = load(icon_path)
	else:
		slot.texture_normal = load("res://ui/icons/wood.png")

	# количество
	var label = Label.new()
	label.text = str(item_data.get("amount", 0))
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	slot.add_child(label)

	slot.connect("pressed", Callable(self, "_on_slot_pressed").bind(item_name))
	return slot


func _on_slot_pressed(item_name: String):
	print("🎒 Нажат предмет:", item_name)


# 🎛 Обработка нажатия клавиши I
func _input(event):
	if event.is_action_pressed("inventory_toggle"):
		_toggle_inventory()


# 🌀 Анимация открытия/закрытия
func _toggle_inventory():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	if not panel.visible:
		panel.visible = true
		tween.tween_property(panel, "modulate:a", 1.0, 0.25)
		tween.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.25)
	else:
		tween.tween_property(panel, "modulate:a", 0.0, 0.25)
		tween.parallel().tween_property(panel, "scale", Vector2(0.9, 0.9), 0.25)
		tween.tween_callback(func(): panel.visible = false)

	print("🎛 Инвентарь:", panel.visible)
	for node in get_tree().get_nodes_in_group("inventory_ui_debug"):
		print("🧩 Найден UI:", node.name, "| Путь:", node.get_path(), "| visible:", node.visible)
