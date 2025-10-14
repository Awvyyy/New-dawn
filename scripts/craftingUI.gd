extends Control

@onready var crafting_manager = get_node_or_null("/root/CraftingManager")

var campfire_button: Button
var workbench_button: Button

func _ready() -> void:
	if not crafting_manager:
		push_warning("⚠️ CraftingManager не найден!")
		return

	# Ищем кнопки по именам во всех потомках UI
	campfire_button = find_child("CampfireButton", true, false)
	workbench_button = find_child("WorkbenchButton", true, false)

	if campfire_button:
		campfire_button.pressed.connect(_on_craft_campfire)
	else:
		push_warning("⚠️ Кнопка CampfireButton не найдена!")

	if workbench_button:
		workbench_button.pressed.connect(_on_craft_workbench)
	else:
		push_warning("⚠️ Кнопка WorkbenchButton не найдена!")

	print("✅ Crafting UI готов!")


# =========================
# 🔥 Крафт костра
# =========================
func _on_craft_campfire() -> void:
	if crafting_manager:
		crafting_manager.craft_item("campfire")


# =========================
# 🛠️ Крафт верстака
# =========================
func _on_craft_workbench() -> void:
	if crafting_manager:
		crafting_manager.craft_item("workbench")
