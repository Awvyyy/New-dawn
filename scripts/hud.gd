extends CanvasLayer

@onready var resource_labels := {
	"metal": $Control/VBoxContainer/ResourceLabel_Metal,
	"wood": $Control/VBoxContainer/ResourceLabel_Wood,
	"stone": $Control/VBoxContainer/ResourceLabel_Stone,
	"water": $Control/VBoxContainer/ResourceLabel_Water,
}

var inventory_manager: Node = null


# ========================
# ⚙️ Инициализация
# ========================
func _ready() -> void:
	print("✅ HUD ready! id:", self.get_instance_id())

	# Проверим, нет ли уже другого HUD в дереве
	for node in get_tree().get_nodes_in_group("hud_instances"):
		if node != self:
			queue_free()
			return

	add_to_group("hud_instances")

	for rname in resource_labels.keys():
		print("  ", rname, ":", resource_labels[rname])

	if Engine.has_singleton("Inventory"):
		inventory_manager = Engine.get_singleton("Inventory")
	else:
		inventory_manager = get_node_or_null("/root/Inventory")

	if inventory_manager:
		inventory_manager.connect("inventory_updated", Callable(self, "_on_inventory_updated"))
		print("✅ Подключен к InventoryManager")
		_on_inventory_updated()
	else:
		push_error("⚠️ InventoryManager не найден!")



# ========================
# 🔁 Обновление всех значений
# ========================
func _on_inventory_updated() -> void:
	if not inventory_manager:
		return

	var items = inventory_manager.get_all_items()

	for rname in resource_labels.keys():
		var amount := 0
		if items.has(rname):
			amount = int(items[rname]["amount"])
		resource_labels[rname].text = "%s: %d" % [rname.capitalize(), amount]

	print("🔁 HUD обновлён по сигналу от InventoryManager")
