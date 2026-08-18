class_name DungeonLevelController
extends Node3D

## Controlador de escena para generación, visualización e interacción con la mazmorra.

@export var config: DungeonConfig = null
@export var visualizer: DungeonVisualizer = null
@export var camera: Camera3D = null

const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _MultiFloorGeneratorScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")

var _pipeline: DungeonPipeline = DungeonPipeline.new()
var _semantic_orchestrator := _SemanticOrchestratorScript.new()
var _presentation_builder := _DungeonPresentationBuilderScript.new()
var _multi_floor_generator := _MultiFloorGeneratorScript.new()

const _PlayerTestScript = preload("res://src/character_test/player_test.gd")

var _current_result: DungeonResult = null
var _current_multi_result: DungeonMultiFloorResult = null
var _current_semantic_result: DungeonSemanticResult = null
var _current_presentation_root: Node3D = null
var _player: CharacterBody3D = null

var _camera_pivot := Vector3.ZERO
var _zoom: float = 40.0
var _is_top_down: bool = false
var _current_isolated_floor: int = -1

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
		if not visualizer.floors_changed.is_connected(_on_floors_changed):
			visualizer.floors_changed.connect(_on_floors_changed)
		if not visualizer.floor_view_mode_changed.is_connected(_on_floor_view_mode_changed):
			visualizer.floor_view_mode_changed.connect(_on_floor_view_mode_changed)

func _on_floors_changed(p_floors: int) -> void:
	if config != null:
		config.total_floors = maxi(1, p_floors)
		_current_isolated_floor = -1
		regenerate(false)

func _on_floor_view_mode_changed(p_floor_idx: int) -> void:
	_current_isolated_floor = p_floor_idx
	_apply_floor_visibility()
	_center_camera_on_dungeon()

func _apply_floor_visibility() -> void:
	if _current_presentation_root == null:
		return
	for child in _current_presentation_root.get_children():
		if child.name.begins_with("Floor_"):
			if _current_isolated_floor == -1:
				child.visible = true
			else:
				child.visible = (child.name == "Floor_%d" % _current_isolated_floor)

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

	var biome: BiomeProfile = config.biome_profile if config.biome_profile != null else BiomeProfile.new()

	# FLUJO MULTI-PISO (Fase 10)
	if config.total_floors > 1:
		var multi_res: DungeonMultiFloorResult = _multi_floor_generator.generate_multi_floor(config)
		if multi_res == null or not multi_res.is_valid:
			_show_failure_ui("Generación multi-piso fallida.\nPresiona [R] o [Espacio] para reintentar.")
			return

		var pres_res = _presentation_builder.build_multi_floor_presentation(
			multi_res, self, biome, config, _current_presentation_root
		)
		if not pres_res.success:
			_show_failure_ui("Fallo en presentación multi-piso 3D:\n" + pres_res.to_debug_string())
			return

		_hide_failure_ui()
		_current_multi_result = multi_res
		_current_presentation_root = pres_res.presentation_root

		# Spawnea / reposiciona personaje en Piso 0
		var f0 = multi_res.get_floor(0)
		if f0 != null and not f0.rooms.is_empty():
			var center_cell = f0.rooms[0].get_center_cell()
			var p_pos := GridToWorld.get_cell_center_world_3d(center_cell, 0, config.cell_size, config.floor_height, 0.5)
			if _player == null:
				_player = _PlayerTestScript.new()
				_player.name = "Player"
				add_child(_player)
			_player.position = p_pos

		if visualizer != null:
			visualizer.update_floor_view_options(config.total_floors, _current_isolated_floor)
		_apply_floor_visibility()
		_center_camera_on_dungeon()
		return

	# FLUJO MONO-PISO ESTÁNDAR
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

	# Posicionar o spawnear personaje de prueba
	_spawn_or_reposition_player()

	# Centrar cámara en la mazmorra
	_center_camera_on_dungeon()

func _spawn_or_reposition_player() -> void:
	if _player == null:
		_player = _PlayerTestScript.new()
		_player.name = "PlayerTest"
		add_child(_player)

	var spawn_grid_pos := Vector2i.ZERO
	if _current_semantic_result != null:
		for obj in _current_semantic_result.objectives:
			if obj.type == ObjectiveData.ObjectiveType.SPAWN:
				spawn_grid_pos = obj.position
				break
		if spawn_grid_pos == Vector2i.ZERO and not _current_semantic_result.rooms.is_empty():
			spawn_grid_pos = _current_semantic_result.rooms[0].center
	elif _current_result != null and not _current_result.rooms.is_empty():
		spawn_grid_pos = _current_result.rooms[0].center

	var cell_size: float = config.cell_size if config != null else 2.0
	var player_pos: Vector3 = GridToWorld.get_cell_center_world(spawn_grid_pos, cell_size, 0.5)
	_player.position = player_pos
	_player.velocity = Vector3.ZERO

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
	if camera == null:
		return

	var grid_w: int = 32
	var grid_h: int = 32
	if _current_result != null and _current_result.grid != null:
		grid_w = _current_result.grid.width
		grid_h = _current_result.grid.height
	elif _current_multi_result != null and _current_multi_result.get_floor(0) != null and _current_multi_result.get_floor(0).grid != null:
		grid_w = _current_multi_result.get_floor(0).grid.width
		grid_h = _current_multi_result.get_floor(0).grid.height

	var center_x: float = (grid_w * config.cell_size) * 0.5
	var center_z: float = (grid_h * config.cell_size) * 0.5
	var num_floors: int = config.total_floors if config != null else 1
	var center_y: float = float(num_floors - 1) * config.floor_height * 0.5

	if _current_isolated_floor >= 0:
		center_y = float(_current_isolated_floor) * config.floor_height
		_zoom = maxf(float(grid_w), float(grid_h)) * config.cell_size * 0.9
	else:
		_zoom = maxf(float(grid_w), float(grid_h)) * config.cell_size * (1.1 if num_floors > 1 else 0.9)

	_camera_pivot = Vector3(center_x, center_y, center_z)
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

	# Cámara se mueve EXCLUSIVAMENTE con WASD (las flechas mueven al jugador)
	if _is_top_down:
		if Input.is_key_pressed(KEY_W):
			move_dir += Vector3(0, 0, -1)
		if Input.is_key_pressed(KEY_S):
			move_dir += Vector3(0, 0, 1)
		if Input.is_key_pressed(KEY_A):
			move_dir += Vector3(-1, 0, 0)
		if Input.is_key_pressed(KEY_D):
			move_dir += Vector3(1, 0, 0)
	else:
		if Input.is_key_pressed(KEY_W):
			move_dir += Vector3(-1, 0, -1).normalized()
		if Input.is_key_pressed(KEY_S):
			move_dir += Vector3(1, 0, 1).normalized()
		if Input.is_key_pressed(KEY_A):
			move_dir += Vector3(-1, 0, 1).normalized()
		if Input.is_key_pressed(KEY_D):
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
			KEY_F:
				if _player != null:
					_camera_pivot = _player.global_position
					_update_camera_transform()
			KEY_0:
				_on_floor_view_mode_changed(-1)
				if visualizer != null:
					visualizer.update_floor_view_options(config.total_floors if config != null else 1, -1)
			KEY_BRACKETLEFT:
				var next_f: int = _current_isolated_floor - 1
				if next_f < -1:
					next_f = (config.total_floors - 1) if config != null else 0
				_on_floor_view_mode_changed(next_f)
				if visualizer != null:
					visualizer.update_floor_view_options(config.total_floors if config != null else 1, next_f)
			KEY_BRACKETRIGHT:
				var max_f: int = (config.total_floors - 1) if config != null else 0
				var next_f: int = _current_isolated_floor + 1
				if next_f > max_f:
					next_f = -1
				_on_floor_view_mode_changed(next_f)
				if visualizer != null:
					visualizer.update_floor_view_options(config.total_floors if config != null else 1, next_f)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(10.0, _zoom - 4.0)
			if camera != null:
				camera.size = _zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(200.0, _zoom + 4.0)
			if camera != null:
				camera.size = _zoom
