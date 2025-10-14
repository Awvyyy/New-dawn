extends Camera3D

@export var move_speed = 10.0
@export var rotate_speed = 0.3
@export var zoom_speed = 5.0
var distance = 15.0

func _process(delta):
	if Input.is_action_pressed("ui_left"):
		translate(Vector3(-move_speed * delta, 0, 0))
	if Input.is_action_pressed("ui_right"):
		translate(Vector3(move_speed * delta, 0, 0))
	if Input.is_action_pressed("ui_up"):
		translate(Vector3(0, 0, -move_speed * delta))
	if Input.is_action_pressed("ui_down"):
		translate(Vector3(0, 0, move_speed * delta))

func _input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_y(-event.relative.x * rotate_speed * 0.01)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			translate(Vector3(0, 0, -zoom_speed))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			translate(Vector3(0, 0, zoom_speed))
