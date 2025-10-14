extends Node3D

@onready var hud_scene = preload("res://ui/hud.tscn")
var hud_instance

func _ready():
	print("Main ready")

	# Добавляем HUD
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)
	print("✅ HUD добавлен:", hud_instance)

	# Проверяем ResourceManager
	if ResourceManager:
		print("✅ ResourceManager найден")
	else:
		push_error("❌ ResourceManager не найден!")
