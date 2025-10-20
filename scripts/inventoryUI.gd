extends Control

@export var slot_scene: PackedScene
@export var columns: int = 4
@export var slot_size: Vector2 = Vector2(64, 64)

@onready var panel := $Panel/GridContainer
@onready var grid := $Panel/GridContainer
var inventory: Node = null
var slots: Array = []

var item_icons := {
	"metal": "res://ui/icons/metal.png",
	"wood": "res://ui/icons/wood.png",
	"stone": "res://ui/icons/stone.png",
	"water": "res://ui/icons/water.png",
	"default": "res://ui/icons/default.png"
}

# Диалог для ввода количества
var amount_dialog: ConfirmationDialog
var amount_spinbox: SpinBox
var selected_item: String
var max_amount: int = 0
var drop_target_slot: TextureButton
var from_slot_field: TextureButton  # Переименовал поле, чтобы не конфликтовать с параметрами функций

# ===============================
# READY
# ===============================
func _ready():
	visible = false
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	add_to_group("inventory_ui_debug")
	set_process_input(true)
	print("✅ InventoryUI ready!")
	await _ensure_inventory_loaded()

	if not inventory:
		push_error("❌ Inventory не найден — UI не сможет обновиться!")
		return

	inventory.connect("inventory_updated", Callable(self, "_on_inventory_updated"), CONNECT_DEFERRED)
	_on_inventory_updated()

	# Диалог для выбора количества
	amount_dialog = ConfirmationDialog.new()
	amount_dialog.title = "Выберите количество"
	add_child(amount_dialog)

	var vbox = VBoxContainer.new()
	amount_dialog.add_child(vbox)

	amount_spinbox = SpinBox.new()
	amount_spinbox.min_value = 1
	amount_spinbox.max_value = 1
	amount_spinbox.step = 1
	vbox.add_child(amount_spinbox)

	var confirm_button = Button.new()
	confirm_button.text = "Перенести"
	confirm_button.pressed.connect(Callable(self, "_on_amount_confirmed"))
	vbox.add_child(confirm_button)

# ===============================
# Ожидание Inventory
# ===============================
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

# ===============================
# Обновление UI
# ===============================
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

# ===============================
# Создание слота
# ===============================
func _create_slot(item_name: String, item_data: Dictionary) -> TextureButton:
	var slot = TextureButton.new()
	slot.custom_minimum_size = slot_size
	slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var icon_path = item_icons.get(item_name, item_icons["default"])
	if not ResourceLoader.exists(icon_path):
		push_warning("⚠️ Иконка не найдена, путь: %s" % icon_path)
		icon_path = item_icons["default"]

	slot.texture_normal = load(icon_path)

	var label = Label.new()
	label.text = str(item_data.get("amount", 0))
	label.add_theme_color_override("font_color", Color(1,1,1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	slot.add_child(label)

	slot.set_meta("item_name", item_name)
	slot.set_meta("amount", item_data.get("amount", 0))

	slot.set_drag_forwarding(
		Callable(self, "_get_drag_data"),
		Callable(self, "_can_drop_data"),
		Callable(self, "_drop_data")
	)

	slot.connect("pressed", Callable(self, "_on_slot_pressed").bind(item_name))
	return slot

func _on_slot_pressed(item_name: String):
	print("🎒 Нажат предмет:", item_name)

# ===============================
# Ввод с клавиши
# ===============================
func _input(event):
	if event.is_action_pressed("inventory_toggle"):
		_toggle_inventory()

# ===============================
# Анимация открытия/закрытия
# ===============================
func _toggle_inventory():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	if not visible:
		visible = true
		panel.visible = true
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.9, 0.9)
		tween.tween_property(panel, "modulate:a", 1.0, 0.25)
		tween.parallel().tween_property(panel, "scale", Vector2(1,1), 0.25)
	else:
		tween.tween_property(panel, "modulate:a", 0.0, 0.25)
		tween.parallel().tween_property(panel, "scale", Vector2(0.9,0.9), 0.25)
		await tween.finished
		panel.visible = false
		visible = false

# ===============================
# Drag & Drop
# ===============================
func _get_drag_data(_mouse_pos: Vector2) -> Variant:
	var slot = get_slot_under_mouse(get_global_mouse_position())
	if slot == null:
		return {}
	from_slot_field = slot
	set_drag_preview(slot.duplicate())
	return {
		"item_name": slot.get_meta("item_name"),
		"amount": slot.get_meta("amount")
	}

func _can_drop_data(_mouse_pos: Vector2, data: Variant) -> bool:
	return data.has("item_name") and data.has("amount")

func _drop_data(_mouse_pos: Vector2, data: Variant) -> void:
	drop_target_slot = get_slot_under_mouse(get_global_mouse_position())
	if drop_target_slot == null:
		return

	selected_item = data["item_name"]
	max_amount = data["amount"]

	if Input.is_key_pressed(KEY_SHIFT):
		var move_amount = max(1, int(max_amount / 2.0))
		_animate_drop(from_slot_field, drop_target_slot, move_amount)
	else:
		amount_spinbox.max_value = max_amount
		amount_spinbox.value = max_amount
		amount_dialog.popup_centered()

func _on_amount_confirmed():
	var move_amount = int(amount_spinbox.value)
	amount_dialog.hide()
	_animate_drop(from_slot_field, drop_target_slot, move_amount)

# ===============================
# Перемещение предметов
# ===============================
func _perform_move(move_amount: int):
	if from_slot_field == null or drop_target_slot == null or move_amount <= 0:
		return

	var from_item_name = from_slot_field.get_meta("item_name")
	var _from_amount = from_slot_field.get_meta("amount")
	var to_item_name = drop_target_slot.get_meta("item_name")
	var to_amount = drop_target_slot.get_meta("amount")

	if to_item_name == "" or to_amount <= 0:
		# Просто перемещаем
		inventory.remove_item(from_item_name, move_amount)
		inventory.add_item(from_item_name, move_amount)
	else:
		if to_item_name == from_item_name:
			# Складываем одинаковые предметы
			inventory.remove_item(from_item_name, move_amount)
			inventory.add_item(to_item_name, move_amount)
		else:
			# Меняем местами
			inventory.swap_items(from_item_name, to_item_name)

	_on_inventory_updated()

# ===============================
# Поиск слотов
# ===============================
func get_slot_under_mouse(pos: Vector2) -> TextureButton:
	for slot in slots:
		if slot.get_global_rect().has_point(pos):
			return slot
	return null

# ===============================
# Анимация дропа с цифрой
# ===============================
func _animate_drop(from_slot_param: TextureButton, to_slot_param: TextureButton, move_amount: int) -> void:
	if from_slot_param == null or to_slot_param == null:
		return

	var icon_preview = TextureRect.new()
	icon_preview.texture = from_slot_param.texture_normal
	icon_preview.size = from_slot_param.custom_minimum_size
	icon_preview.global_position = from_slot_param.get_global_position()
	icon_preview.z_index = 1000
	add_child(icon_preview)

	var amount_label = Label.new()
	amount_label.text = str(move_amount)
	amount_label.add_theme_color_override("font_color", Color(1,1,0))
	amount_label.global_position = from_slot_param.get_global_position() + Vector2(0, -10)
	amount_label.z_index = 1001
	add_child(amount_label)

	var tween = create_tween()
	tween.tween_property(icon_preview, "global_position", to_slot_param.get_global_position(), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(amount_label, "global_position", to_slot_param.get_global_position() + Vector2(0, -10), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(Callable(self, "_on_drop_animation_finished_with_label").bind(icon_preview, amount_label, move_amount))

func _on_drop_animation_finished_with_label(icon_preview: Node, amount_label: Node, move_amount: int) -> void:
	icon_preview.queue_free()
	amount_label.queue_free()
	_perform_move(move_amount)
