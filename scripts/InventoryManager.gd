extends Node
class_name InventoryManager

signal item_added(item_name: String, amount: int)
signal item_removed(item_name: String, amount: int)
signal inventory_updated()

var items: Dictionary = {}
var default_max_stack := 999

# --- Бэчинг изменений, чтобы эмитить inventory_updated 1 раз за кадр ---
var _pending_changed_items: = {}          # Set (Dictionary acting as set) of item names changed this frame
var _scheduled_emit: bool = false

func _ready() -> void:
	print("✅ InventoryManager initialized")

# ==============================
# ➕ ДОБАВЛЕНИЕ ПРЕДМЕТА
# ==============================
func add_item(item_name: String, amount: int = 1, icon_path: String = "") -> void:
	if amount == 0:
		return

	if not items.has(item_name):
		items[item_name] = {
			"amount": 0,
			"max_stack": default_max_stack,
			"icon": icon_path
		}

	var prev = items[item_name]["amount"]
	items[item_name]["amount"] = clamp(prev + amount, 0, items[item_name]["max_stack"])

	emit_signal("item_added", item_name, amount)

	# Пометить item как изменённый и запланировать единое уведомление
	_pending_changed_items[item_name] = true
	_schedule_inventory_update_if_needed()

	# Отладочный лог (показывает кадр и состояние)
	print("📦 Добавлено:", amount, item_name, "| всего:", items[item_name]["amount"], "| frame:", Engine.get_frames_drawn())

# ==============================
# ➖ УДАЛЕНИЕ ПРЕДМЕТА
# ==============================
func remove_item(item_name: String, amount: int = 1) -> void:
	if not items.has(item_name):
		push_warning("⚠️ Попытка удалить несуществующий предмет: %s" % item_name)
		return

	var prev = items[item_name]["amount"]
	items[item_name]["amount"] = max(prev - amount, 0)

	if items[item_name]["amount"] <= 0:
		items.erase(item_name)

	emit_signal("item_removed", item_name, amount)

	_pending_changed_items[item_name] = true
	_schedule_inventory_update_if_needed()

	print("🗑 Удалено:", amount, item_name, "| frame:", Engine.get_frames_drawn())

# ==============================
# Планирование и единый эмит
# ==============================
func _schedule_inventory_update_if_needed() -> void:
	# Если уже запланировано — не планируем снова
	if _scheduled_emit:
		return
	_scheduled_emit = true
	# Асинхронно ждём следующий кадр, затем эмитим один сигнал с информацией о всех изменениях
	_emit_batched_update()

# асинхронный метод (await внутри)
func _emit_batched_update() -> void:
	# Ждём завершения текущего кадра (один frame), чтобы собрать все вызовы
	await get_tree().process_frame
	# Собираем список изменённых имён
	var changed = []
	for k in _pending_changed_items.keys():
		changed.append(k)
	# Очистим набор
	_pending_changed_items.clear()
	# Сброс флага до эмита — но можно эмитить сейчас
	_scheduled_emit = false

	# Отладочный вывод: какие предметы изменились и кадр
	print("🔁 inventory_updated (batched). changed:", changed, "frame:", Engine.get_frames_drawn())
	emit_signal("inventory_updated")

# ==============================
# 📊 ПОЛУЧЕНИЕ КОЛИЧЕСТВА
# ==============================
func get_amount(item_name: String) -> int:
	if not items.has(item_name):
		return 0
	return int(items[item_name]["amount"])

# ==============================
# 🔍 ПРОВЕРКА НАЛИЧИЯ ПРЕДМЕТОВ
# ==============================
func has_items(requirements: Dictionary) -> bool:
	for k in requirements.keys():
		if get_amount(k) < int(requirements[k]):
			return false
	return true

# ==============================
# 🧮 ВЫЧЕСТЬ НАБОР ПРЕДМЕТОВ (для крафта)
# ==============================
func consume_items(requirements: Dictionary) -> void:
	for k in requirements.keys():
		remove_item(k, int(requirements[k]))

# ==============================
# 📋 ВОЗВРАТ ВСЕГО ИНВЕНТАРЯ (для UI)
# ==============================
func get_all_items() -> Dictionary:
	return items.duplicate(true)
