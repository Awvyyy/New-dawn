extends CanvasLayer

@onready var resource_labels := {
	"metal": $Control/VBoxContainer/ResourceLabel_Metal,
	"wood": $Control/VBoxContainer/ResourceLabel_Wood,
	"stone": $Control/VBoxContainer/ResourceLabel_Stone,
	"water": $Control/VBoxContainer/ResourceLabel_Water,
}

func _ready() -> void:
	print("✅ HUD ready!")
	for rname in resource_labels.keys():
		print("  ", rname, ":", resource_labels[rname])
	
	# подключаем сигнал от ResourceManager (глобального)
	if ResourceManager:
		ResourceManager.connect("resource_changed", Callable(self, "_on_resource_changed"))
		print("✅ Подключен к ResourceManager")
	else:
		push_error("⚠️ ResourceManager не найден!")

func _on_resource_changed(resource_name: String, new_value: int) -> void:
	print("🔔 Сигнал получен от ResourceManager:", resource_name, new_value)

	if not resource_labels.has(resource_name):
		push_warning("⚠️ Нет лейбла для ресурса: %s" % resource_name)
		return
	
	resource_labels[resource_name].text = "%s: %d" % [resource_name.capitalize(), new_value]
