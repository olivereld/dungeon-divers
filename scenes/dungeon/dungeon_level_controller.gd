class_name DungeonLevelController
extends Node3D

## Controlador de escena para generación, visualización e interacción con la mazmorra.

@export var config: DungeonConfig = null
@export var grid_map_mapper: GridMapMapper = null
@export var visualizer: DungeonVisualizer = null
@export var camera: Camera3D = null

var _pipeline: DungeonPipeline = DungeonPipeline.new()
var _current_result: DungeonResult = null
var _camera_pivot := Vector3.ZERO
var _zoom: float = 40.0
var _is_top_down: bool = false

func _ready() -> void:
	if config == null:
		config = preload("res://resources/configs/hybrid_dungeon.tres")

	_setup_camera()
	regenerate(false)

func _setup_camera() -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	_update_camera_transform()

func regenerate(force_new_seed: bool = false) -> void:
	if config == null:
		return

	if force_new_seed:
		config.seed = 0
		config.use_fixed_seed = false

	# Generar mazmorra lógica
	var new_result = _pipeline.generate(config, DungeonPipeline.MAX_ATTEMPTS, force_new_seed)
	if new_result == null:
		push_error("[DungeonLevelController] Falló la generación tras %d intentos para '%s'. Presiona 'R' o 'Espacio' para reintentar con otra semilla." % [
			DungeonPipeline.MAX_ATTEMPTS,
			config.dungeon_id if ("dungeon_id" in config) else "default"
		])
		# Si ya existe una mazmorra previa, conservarla para no dejar la pantalla en negro
		if _current_result != null:
			return
		_show_failure_ui()
		return

	_hide_failure_ui()
	_current_result = new_result

	# Mapear a GridMap 3D
	if grid_map_mapper != null:
		grid_map_mapper.apply(_current_result.grid, config, _current_result.rooms)

	# Actualizar Overlay 2D
	if visualizer != null:
		visualizer.set_dungeon_result(_current_result)

	# Centrar cámara en la mazmorra
	_center_camera_on_dungeon()

var _failure_label: Label = null

func _show_failure_ui() -> void:
	if _failure_label == null:
		_failure_label = Label.new()
		_failure_label.text = "Generación fallida tras %d intentos.\nPresiona [R] o [Espacio] para reintentar." % DungeonPipeline.MAX_ATTEMPTS
		_failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_failure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_failure_label.anchors_preset = Control.PRESET_FULL_RECT
		_failure_label.add_theme_font_size_override("font_size", 24)
		_failure_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
		add_child(_failure_label)
	_failure_label.visible = true

func _hide_failure_ui() -> void:
	if _failure_label != null:
		_failure_label.visible = false

func _center_camera_on_dungeon() -> void:
	if camera == null or _current_result == null:
		return

	var center_x: float = (_current_result.grid.width * config.cell_size) * 0.5
	var center_z: float = (_current_result.grid.height * config.cell_size) * 0.5
	_camera_pivot = Vector3(center_x, 0, center_z)

	_zoom = maxf(float(_current_result.grid.width), float(_current_result.grid.height)) * config.cell_size * 0.9
	camera.size = _zoom
	_update_camera_transform()

func _update_camera_transform() -> void:
	if camera == null:
		return

	var cam_distance: float = 60.0
	if _is_top_down:
		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.position = _camera_pivot + Vector3(0, cam_distance, 0)
	else:
		camera.rotation_degrees = Vector3(-45, 45, 0)
		var rot_rad_x: float = deg_to_rad(-45.0)
		var rot_rad_y: float = deg_to_rad(45.0)
		var offset := Vector3(
			sin(rot_rad_y) * cos(rot_rad_x),
			-sin(rot_rad_x),
			cos(rot_rad_y) * cos(rot_rad_x)
		) * cam_distance
		camera.position = _camera_pivot + offset

func _process(delta: float) -> void:
	_handle_camera_pan(delta)

func _handle_camera_pan(delta: float) -> void:
	if camera == null:
		return

	var speed: float = _zoom * 1.5 * delta
	var move_dir := Vector3.ZERO

	if _is_top_down:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_dir += Vector3(0, 0, -1)
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_dir += Vector3(0, 0, 1)
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_dir += Vector3(-1, 0, 0)
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_dir += Vector3(1, 0, 0)
	else:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_dir += Vector3(-1, 0, -1).normalized()
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_dir += Vector3(1, 0, 1).normalized()
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_dir += Vector3(-1, 0, 1).normalized()
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_dir += Vector3(1, 0, -1).normalized()

	if move_dir != Vector3.ZERO:
		_camera_pivot += move_dir.normalized() * speed
		_update_camera_transform()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R, KEY_SPACE:
				regenerate(true)
			KEY_T, KEY_V:
				_is_top_down = not _is_top_down
				_update_camera_transform()
			KEY_1:
				config = preload("res://resources/configs/cave_dungeon.tres").duplicate()
				regenerate(true)
			KEY_2:
				config = preload("res://resources/configs/castle_dungeon.tres").duplicate()
				regenerate(true)
			KEY_3:
				config = preload("res://resources/configs/hybrid_dungeon.tres").duplicate()
				regenerate(true)
			KEY_4:
				config = preload("res://resources/configs/dungeon_128.tres").duplicate()
				regenerate(true)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(10.0, _zoom - 4.0)
			if camera != null:
				camera.size = _zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(200.0, _zoom + 4.0)
			if camera != null:
				camera.size = _zoom
