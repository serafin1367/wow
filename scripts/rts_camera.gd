extends Node3D
## Kamera RTS: przesuwanie WASD / krawędziami ekranu i zoom kółkiem myszy.

@export var pan_speed: float = 22.0
@export var edge_margin: float = 18.0
@export var zoom_min: float = 12.0
@export var zoom_max: float = 65.0

var zoom_distance: float = 30.0
var orbit_angle: float = 0.0
@export var rotate_speed: float = 1.4
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "RTSCamera"
	camera.current = true
	camera.fov = 60.0
	camera.far = 350.0
	add_child(camera)
	_update_camera()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	var cursor := get_viewport().get_mouse_position()
	var viewport_size := get_viewport().get_visible_rect().size
	if cursor.x >= 0.0 and cursor.y >= 0.0 and cursor.x <= viewport_size.x and cursor.y <= viewport_size.y:
		if cursor.x < edge_margin:
			direction.x -= 1.0
		elif cursor.x > viewport_size.x - edge_margin:
			direction.x += 1.0
		if cursor.y < edge_margin:
			direction.y -= 1.0
		elif cursor.y > viewport_size.y - edge_margin:
			direction.y += 1.0

	if Input.is_key_pressed(KEY_Q):
		orbit_angle -= rotate_speed * delta
		_update_camera()
	elif Input.is_key_pressed(KEY_E):
		orbit_angle += rotate_speed * delta
		_update_camera()

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += Vector3(direction.x, 0.0, direction.y).rotated(Vector3.UP, orbit_angle) * pan_speed * delta * (zoom_distance / 30.0)
		position.x = clampf(position.x, -45.0, 45.0)
		position.z = clampf(position.z, -45.0, 45.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = clampf(zoom_distance - 3.0, zoom_min, zoom_max)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = clampf(zoom_distance + 3.0, zoom_min, zoom_max)
			_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	camera.position = Vector3(sin(orbit_angle) * zoom_distance, zoom_distance * 0.85, cos(orbit_angle) * zoom_distance)
	camera.look_at(global_position, Vector3.UP)
