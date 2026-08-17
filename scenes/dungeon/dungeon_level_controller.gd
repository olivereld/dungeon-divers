class_name DungeonLevelController
extends Node3D

## Controlador de escena para generación, visualización e interacción con la mazmorra.

@export var config: DungeonConfig = null
@export var visualizer: DungeonVisualizer = null
@export var camera: Camera3D = null

const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")

var _pipeline: DungeonPipeline = DungeonPipeline.new()
var _semantic_orchestrator := _SemanticOrchestratorScript.new()
var _presentation_builder := _DungeonPresentationBuilderScript.new()

var _current_result: DungeonResult = null
var _current_semantic_result: DungeonSemanticResult = null
var _current_presentation_root: Node3D = null

var _camera_pivot := Vector3.ZERO
var _zoom: float = 40.0
var _is_top_down: bool = false

func _ready() -> void:
	if config == null:
		config = preload("res://resources/configs/hybrid_dungeon.tres")

	_connect_visualizer_signals()
	_setup_camera()
	regenerate(false)

func _connect_visualizer_signals() -> void:
	if visualizer != null:
		if not visualizer.seed_submitted.is_connected(_on_seed_submitted):
			visualizer.seed_submitted.connect(_on_seed_submitted)
		if not visualizer.random_seed_requested.is_connected(_on_random_seed_requested):
			visualizer.random_seed_requested.connect(_on_random_seed_requested)

func _on_seed_submitted(p_seed: int) -> void:
	if config != null:
		config.seed = p_seed
		config.use_fixed_seed = true
		regenerate(false)

func _on_random_seed_requested() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var random_seed: int = rng.randi_range(100000, 999999999)
	_on_seed_submitted(random_seed)

func _setup_camera() -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	_update_camera_transform()

func regenerate(force_new_seed: bool = false) -> void:
	_connect_visualizer_signals()
	if config == null:
		return

	if force_new_seed:
		config.seed = 0
		config.use_fixed_seed = false

	# 1. Generar mazmorra física (Fases 1–6.1.1)
	var new_result = _pipeline.generate(config, DungeonPipeline.MAX_ATTEMPTS, force_new_seed)
	if new_result == null:
		push_error("[DungeonLevelController] Falló la generación física tras %d intentos para '%s'." % [
			DungeonPipeline.MAX_ATTEMPTS,
			config.dungeon_id if ("dungeon_id" in config) else "default"
		])
		if _current_result != null:
			return
		_show_failure_ui("Generación física fallida tras %d intentos.\nPresiona [R] o [Espacio] para reintentar con otra semilla." % DungeonPipeline.MAX_ATTEMPTS)
		return

	# 2. Generar modelo semántico (Fase 7)
	var new_semantic = _semantic_orchestrator.generate_semantics(new_result, config)
	if new_semantic == null or not new_semantic.gameplay_valid:
		push_error("[DungeonLevelController] Falló la validación semántica.")
		if _current_semantic_result != null:
			return
		_show_failure_ui("Validación semántica fallida.\nPresiona [R] o [Espacio] para reintentar.")
		return

	# 3. Materializar representación 3D atómica (Fase 8)
	var biome: BiomeProfile = config.biome_profile if config.biome_profile != null else BiomeProfile.new()
	var pres_res = _presentation_builder.build_presentation(
		new_semantic, self, biome, config, _current_presentation_root, true
	)

	if not pres_res.success:
		push_error("[DungeonLevelController] Falló la presentación 3D:\n%s" % pres_res.to_debug_string())
		if not pres_res.previous_presentation_preserved:
			_show_failure_ui("Fallo en presentación 3D:\n" + pres_res.to_debug_string())
		return

	_hide_failure_ui()
	_current_result = new_result
	_current_semantic_result = new_semantic
	_current_presentation_root = pres_res.presentation_root

	# Actualizar Overlay 2D
	if visualizer != null:
		visualizer.set_dungeon_result(_current_result)

	# Centrar cámara en la mazmorra
	_center_camera_on_dungeon()

var _failure_label: Label = null

func _show_failure_ui(message: String = "") -> void:
	if _failure_label == null:
		_failure_label = Label.new()
		_failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_failure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_failure_label.anchors_preset = Control.PRESET_FULL_RECT
		_failure_label.add_theme_font_size_override("font_size", 22)
		_failure_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
		add_child(_failure_label)
	_failure_label.text = message if not message.is_empty() else "Generación fallida.\nPresiona [R] o [Espacio] para reintentar."
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

	# No mover cámara si el usuario está escribiendo en un campo de texto
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
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
	# Manejo de foco en interfaz de usuario
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				focus_owner.release_focus()
				get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R, KEY_SPACE:
				_on_random_seed_requested()
			KEY_T, KEY_V:
				_is_top_down = not _is_top_down
				_update_camera_transform()
			KEY_1:
				config = preload("res://resources/configs/cave_dungeon.tres").duplicate()
				_on_random_seed_requested()
			KEY_2:
				config = preload("res://resources/configs/castle_dungeon.tres").duplicate()
				_on_random_seed_requested()
			KEY_3:
				config = preload("res://resources/configs/hybrid_dungeon.tres").duplicate()
				_on_random_seed_requested()
			KEY_4:
				config = preload("res://resources/configs/dungeon_128.tres").duplicate()
				_on_random_seed_requested()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(10.0, _zoom - 4.0)
			if camera != null:
				camera.size = _zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(200.0, _zoom + 4.0)
			if camera != null:
				camera.size = _zoom
