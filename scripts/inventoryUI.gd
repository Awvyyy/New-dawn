extends Control

@export var slot_scene: PackedScene
@export var columns: int = 4
@export var slot_size: Vector2 = Vector2(64, 64)
@export var max_stack: int = 999

@onready var panel: GridContainer = $Panel/GridContainer
@onready var grid: GridContainer = $Panel/GridContainer

var inventory: Node = null
var slots: Array[TextureButton] = []

var item_icons := {
	"metal": "res://ui/icons/metal.png",
	"wood": "res://ui/icons/wood.png",
	"stone": "res://ui/icons/stone.png",
	"water": "res://ui/icons/water.png",
	"default": "res://ui/icons/default.png"
}

# drag/drop state
var drag_active := false
var hovered_slot: TextureButton = null
var hovered_tween: Tween = null
var dragging_slot: TextureButton = null  # слот, который "подпрыгивает"

# ===============================
# READY
# ===============================
func _ready() -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.mouse_filter = Control.MOUSE_FILTER_PASS

	visible = false
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	add_to_group("inventory_ui_debug")
	set_process_input(true)

	await _ensure_inventory_loaded()
	if inventory == null:
		push_error("❌ Inventory не найден — UI не сможет обновиться!")
		return

	inventory.connect("inventory_updated", Callable(self, "_on_inventory_updated"), CONNECT_DEFERRED)
	_on_inventory_updated()

# ===============================
# LOAD INVENTORY
# ===============================
func _ensure_inventory_loaded() -> void:
	for i in range(10):
		if Engine.has_singleton("Inventory"):
			inventory = Engine.get_singleton("Inventory")
			return
		var inv: Node = get_node_or_null("/root/Inventory")
		if inv:
			inventory = inv
			return
		await get_tree().process_frame
	push_warning("⚠️ Inventory не найден даже после ожидания!")

# ===============================
# UI UPDATE
# ===============================
func _on_inventory_updated() -> void:
	if inventory == null:
		return
	var items: Dictionary = inventory.get_all_items()
	_update_grid(items)

func _update_grid(items: Dictionary) -> void:
	for s in slots:
		if is_instance_valid(s):
			s.queue_free()
	slots.clear()
	for item_name in items.keys():
		var item_data: Dictionary = items[item_name]
		var slot := _create_slot(String(item_name), item_data)
		grid.add_child(slot)
		slots.append(slot)

# ===============================
# CREATE SLOT
# ===============================
func _create_slot(item_name: String, item_data: Dictionary) -> TextureButton:
	var slot := TextureButton.new()
	slot.custom_minimum_size = slot_size
	slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var icon_path: String = item_icons.get(item_name, item_icons["default"])
	if not ResourceLoader.exists(icon_path):
		icon_path = item_icons["default"]
	slot.texture_normal = load(icon_path)

	var label := Label.new()
	label.text = str(int(item_data.get("amount", 0)))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	slot.add_child(label)

	slot.set_meta("item_name", item_name)
	slot.set_meta("amount", int(item_data.get("amount", 0)))

	slot.set_drag_forwarding(
		Callable(self, "_get_drag_data"),
		Callable(self, "_can_drop_data"),
		Callable(self, "_drop_data")
	)
	return slot

# ===============================
# INPUT
# ===============================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		_toggle_inventory()

# ===============================
# INVENTORY TOGGLE
# ===============================
func _toggle_inventory() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if not visible:
		visible = true
		panel.visible = true
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.9, 0.9)
		tw.tween_property(panel, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.25)
	else:
		tw.tween_property(panel, "modulate:a", 0.0, 0.25)
		tw.parallel().tween_property(panel, "scale", Vector2(0.9, 0.9), 0.25)
		await tw.finished
		panel.visible = false
		visible = false

# ===============================
# DRAG & DROP (без призрака, но с анимацией)
# ===============================
func _get_drag_data(_pos: Vector2) -> Variant:
	var slot := get_slot_under_mouse(get_global_mouse_position())
	if slot == null:
		return {}
	@warning_ignore("shadowed_variable_base_class")
	var name := String(slot.get_meta("item_name"))
	var amt := int(slot.get_meta("amount"))
	if name == "" or amt <= 0:
		return {}

	drag_active = true
	dragging_slot = slot
	_start_drag_anim(slot) # 🔹 подпрыгиваем слот при начале drag
	set_drag_preview(slot.duplicate())

	return {
		"item_name": name,
		"amount": amt,
		"from_slot": slot
	}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("item_name") and data.has("amount")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	drag_active = false
	_clear_highlight()
	if is_instance_valid(dragging_slot):
		_end_drag_anim(dragging_slot) # 🔹 возвращаем слот

	var from_slot: TextureButton = data.get("from_slot", null)
	var drop_target_slot := get_slot_under_mouse(get_global_mouse_position())

	if from_slot == null or drop_target_slot == null:
		return
	if drop_target_slot == from_slot:
		_refresh_slot(from_slot)
		return

	var from_item := String(from_slot.get_meta("item_name"))
	var to_item := String(drop_target_slot.get_meta("item_name"))
	var from_amt := int(from_slot.get_meta("amount"))
	var to_amt := int(drop_target_slot.get_meta("amount"))

	# 🔹 SHIFT деление
	if Input.is_key_pressed(KEY_SHIFT):
		if to_item != "" and to_item != from_item:
			_refresh_slot(from_slot)
			return
		var half := int(ceil(float(from_amt) / 2.0))
		from_slot.set_meta("amount", from_amt - half)
		_add_to_slot(drop_target_slot, from_item, half)
		_refresh_slot(from_slot)
		_refresh_slot(drop_target_slot)
		return

	# 🔹 пустой слот
	if to_item == "" or to_amt <= 0:
		drop_target_slot.set_meta("item_name", from_item)
		drop_target_slot.set_meta("amount", from_amt)
		from_slot.set_meta("item_name", "")
		from_slot.set_meta("amount", 0)

	# 🔹 одинаковые — складываем
	elif from_item == to_item:
		var total := from_amt + to_amt
		if total > max_stack:
			drop_target_slot.set_meta("amount", max_stack)
			var overflow := total - max_stack
			for s in slots:
				if String(s.get_meta("item_name")) == "":
					s.set_meta("item_name", from_item)
					s.set_meta("amount", overflow)
					_refresh_slot(s)
					break
		else:
			drop_target_slot.set_meta("amount", total)
		from_slot.set_meta("item_name", "")
		from_slot.set_meta("amount", 0)

	# 🔹 разные — обмен
	else:
		var temp_name := to_item
		var temp_amt := to_amt
		drop_target_slot.set_meta("item_name", from_item)
		drop_target_slot.set_meta("amount", from_amt)
		from_slot.set_meta("item_name", temp_name)
		from_slot.set_meta("amount", temp_amt)

	_refresh_slot(from_slot)
	_refresh_slot(drop_target_slot)

# ===============================
# SLOT ANIMATIONS
# ===============================
func _start_drag_anim(slot: TextureButton) -> void:
	if slot == null:
		return
	var tw := create_tween()
	tw.tween_property(slot, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(slot, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.12)

func _end_drag_anim(slot: TextureButton) -> void:
	if slot == null:
		return
	var tw := create_tween()
	tw.tween_property(slot, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(slot, "modulate", Color(1, 1, 1, 1), 0.15)

# ===============================
# HOVER FX
# ===============================
func _process(_delta: float) -> void:
	if not drag_active:
		return
	var new_hover := get_slot_under_mouse(get_global_mouse_position())
	if new_hover != hovered_slot:
		_clear_highlight()
		if new_hover:
			_highlight_slot(new_hover)

func _highlight_slot(slot: TextureButton) -> void:
	hovered_slot = slot
	slot.modulate = Color(1, 1, 1, 1)
	if is_instance_valid(hovered_tween):
		hovered_tween.kill()
	hovered_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hovered_tween.set_loops()
	hovered_tween.tween_property(slot, "modulate", Color(1.2, 1.2, 0.8, 1), 0.25)
	hovered_tween.tween_property(slot, "modulate", Color(1.0, 1.0, 1.0, 1), 0.25)

func _clear_highlight() -> void:
	if is_instance_valid(hovered_tween):
		hovered_tween.kill()
	hovered_tween = null
	if hovered_slot:
		hovered_slot.modulate = Color(1, 1, 1, 1)
	hovered_slot = null

# ===============================
# HELPERS
# ===============================
func _refresh_slot(slot: TextureButton) -> void:
	if slot == null:
		return
	var item := String(slot.get_meta("item_name"))
	var amount := int(slot.get_meta("amount"))
	var label: Label = null
	for c in slot.get_children():
		if c is Label:
			label = c
			break
	if item == "":
		slot.texture_normal = null
		if label: label.text = ""
	else:
		slot.texture_normal = load(item_icons.get(item, item_icons["default"]))
		if label: label.text = str(amount)

func _add_to_slot(slot: TextureButton, item_name: String, amount: int) -> void:
	if item_name == "":
		return
	var current_name := String(slot.get_meta("item_name"))
	if current_name == "":
		slot.set_meta("item_name", item_name)
		slot.set_meta("amount", amount)
	else:
		var current_amt := int(slot.get_meta("amount"))
		var total := current_amt + amount
		slot.set_meta("amount", min(total, max_stack))
	_refresh_slot(slot)

func get_slot_under_mouse(pos: Vector2) -> TextureButton:
	for s in slots:
		if s.get_global_rect().has_point(pos):
			return s
	return null
