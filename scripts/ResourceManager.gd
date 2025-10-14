extends Node

signal resource_changed(resource_type: String, new_value: int)

var resources := {
	"metal": 0,
	"wood": 0,
	"stone": 0,
	"water": 0
}

func add_resource(resource_type: String, amount: int) -> void:
	if not resources.has(resource_type):
		push_warning("⚠️ Неизвестный тип ресурса: %s" % resource_type)
		return

	resources[resource_type] += amount
	print("✅ Добавлено", amount, resource_type, "(итого:", resources[resource_type], ")")
	emit_signal("resource_changed", resource_type, resources[resource_type])


func get_resource(resource_type: String) -> int:
	if resources.has(resource_type):
		return resources[resource_type]
	return 0
