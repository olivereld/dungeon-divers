class_name DungeonLevelController
extends Node3D

## Controlador de escena para generación, visualización e interacción con la mazmorra.
## Implementa flujo por pasos: 
## 1. Generación y Previsualización en Plano 2D interactivo (con segmentación multinivel).
## 2. Al presionar "Generar en 3D" (o Espacio/Enter), materializa el mundo 3D navegable con toolbar de visualización.

@export var config: DungeonConfig = null
@export var visualizer: DungeonVisualizer = null
@export var camera: Camera3D = null

const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _MultiFloorGeneratorScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _LightingProfileScript = preload("res://src/dungeon_lighting/config/lighting_profile.gd")

var _pipeline: DungeonPipeline = DungeonPipeline.new()
var _semantic_orchestrator := _SemanticOrchestratorScript.new()
var _presentation_builder := _DungeonPresentationBuilderScript.new()
var _multi_floor_generator := _MultiFloorGeneratorScript.new()
var _lighting_profile: LightingProfile = null

var _current_result: DungeonResult = null
var _current_multi_result: DungeonMultiFloorResult = null
var _current_semantic_result: DungeonSemanticResult = null
var _current_presentation_root: Node3D = null
var _player: CharacterBody3D = null

var _camera_pivot := Vector3.ZERO
var _zoom: float = 40.0
var _camera_yaw: float = 45.0
var _is_orbiting: bool = false
var _is_top_down: bool = false
var _current_isolated_floor: int = -1
var _are_walls_visible: bool = true

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
		if not visualizer.algorithm_changed.is_connected(_on_algorithm_changed):
			visualizer.algorithm_changed.connect(_on_algorithm_changed)
		if not visualizer.floor_view_mode_changed.is_connected(_on_floor_view_mode_changed):
			visualizer.floor_view_mode_changed.connect(_on_floor_view_mode_changed)
		if not visualizer.generate_3d_requested.is_connected(build_3d_presentation):
			visualizer.generate_3d_requested.connect(build_3d_presentation)
		if not visualizer.toggle_2d_view_requested.is_connected(_on_toggle_2d_view_requested):
			visualizer.toggle_2d_view_requested.connect(_on_toggle_2d_view_requested)
		if not visualizer.preset_changed.is_connected(_on_preset_changed):
			visualizer.preset_changed.connect(_on_preset_changed)
		if not visualizer.grid_size_changed.is_connected(_on_grid_size_changed):
			visualizer.grid_size_changed.connect(_on_grid_size_changed)
		if not visualizer.mission_depth_changed.is_connected(_on_mission_depth_changed):
			visualizer.mission_depth_changed.connect(_on_mission_depth_changed)
		if not visualizer.corridor_width_changed.is_connected(_on_corridor_width_changed):
			visualizer.corridor_width_changed.connect(_on_corridor_width_changed)
		if not visualizer.walls_visibility_toggled.is_connected(_on_walls_visibility_toggled):
			visualizer.walls_visibility_toggled.connect(_on_walls_visibility_toggled)
		if not visualizer.camera_view_toggled.is_connected(_on_camera_view_toggled):
			visualizer.camera_view_toggled.connect(_on_camera_view_toggled)

		# Señales de Suelos Procedurales
		if not visualizer.floor_pattern_changed.is_connected(_on_floor_pattern_changed):
			visualizer.floor_pattern_changed.connect(_on_floor_pattern_changed)
		if not visualizer.floor_preset_changed.is_connected(_on_floor_preset_changed):
			visualizer.floor_preset_changed.connect(_on_floor_preset_changed)
		if not visualizer.floor_tile_size_changed.is_connected(_on_floor_tile_size_changed):
			visualizer.floor_tile_size_changed.connect(_on_floor_tile_size_changed)
		if not visualizer.floor_margin_changed.is_connected(_on_floor_margin_changed):
			visualizer.floor_margin_changed.connect(_on_floor_margin_changed)
		if not visualizer.floor_collision_mode_changed.is_connected(_on_floor_collision_mode_changed):
			visualizer.floor_collision_mode_changed.connect(_on_floor_collision_mode_changed)
		if not visualizer.floor_noise_toggled.is_connected(_on_floor_noise_toggled):
			visualizer.floor_noise_toggled.connect(_on_floor_noise_toggled)

		# Señales de Iluminación 3D y Entorno
		if not visualizer.lighting_torch_color_changed.is_connected(_on_lighting_torch_color_changed):
			visualizer.lighting_torch_color_changed.connect(_on_lighting_torch_color_changed)
		if not visualizer.lighting_torch_energy_changed.is_connected(_on_lighting_torch_energy_changed):
			visualizer.lighting_torch_energy_changed.connect(_on_lighting_torch_energy_changed)
		if not visualizer.lighting_torch_range_changed.is_connected(_on_lighting_torch_range_changed):
			visualizer.lighting_torch_range_changed.connect(_on_lighting_torch_range_changed)
		if not visualizer.lighting_torch_attenuation_changed.is_connected(_on_lighting_torch_attenuation_changed):
			visualizer.lighting_torch_attenuation_changed.connect(_on_lighting_torch_attenuation_changed)
		if not visualizer.lighting_torch_flicker_toggled.is_connected(_on_lighting_torch_flicker_toggled):
			visualizer.lighting_torch_flicker_toggled.connect(_on_lighting_torch_flicker_toggled)
		if not visualizer.lighting_torch_flicker_amp_changed.is_connected(_on_lighting_torch_flicker_amp_changed):
			visualizer.lighting_torch_flicker_amp_changed.connect(_on_lighting_torch_flicker_amp_changed)
		if not visualizer.lighting_torch_shadows_toggled.is_connected(_on_lighting_torch_shadows_toggled):
			visualizer.lighting_torch_shadows_toggled.connect(_on_lighting_torch_shadows_toggled)
		if not visualizer.lighting_ambient_color_changed.is_connected(_on_lighting_ambient_color_changed):
			visualizer.lighting_ambient_color_changed.connect(_on_lighting_ambient_color_changed)
		if not visualizer.lighting_ambient_energy_changed.is_connected(_on_lighting_ambient_energy_changed):
			visualizer.lighting_ambient_energy_changed.connect(_on_lighting_ambient_energy_changed)
		if not visualizer.lighting_rim_color_changed.is_connected(_on_lighting_rim_color_changed):
			visualizer.lighting_rim_color_changed.connect(_on_lighting_rim_color_changed)
		if not visualizer.lighting_rim_energy_changed.is_connected(_on_lighting_rim_energy_changed):
			visualizer.lighting_rim_energy_changed.connect(_on_lighting_rim_energy_changed)
		if not visualizer.lighting_fog_density_changed.is_connected(_on_lighting_fog_density_changed):
			visualizer.lighting_fog_density_changed.connect(_on_lighting_fog_density_changed)

func _on_walls_visibility_toggled(p_visible: bool) -> void:
	_are_walls_visible = p_visible
	_apply_walls_visibility()

func _on_camera_view_toggled() -> void:
	_is_top_down = not _is_top_down
	_update_camera_transform()

func _apply_walls_visibility() -> void:
	if _current_presentation_root == null:
		return

	# Mono-piso:
	var single_walls = _current_presentation_root.get_node_or_null("ContinuousWalls")
	if single_walls != null:
		single_walls.visible = _are_walls_visible

	# Multi-piso:
	for child in _current_presentation_root.get_children():
		if child.name.begins_with("Floor_"):
			var floor_walls = child.get_node_or_null("ContinuousWalls")
			if floor_walls != null:
				floor_walls.visible = _are_walls_visible

func _on_preset_changed(idx: int) -> void:
	if config != null:
		match idx:
			0: config.apply_preset_standard()
			1: config.apply_preset_compact()
			2: config.apply_preset_large()
			3: config.apply_preset_massive()
		if visualizer != null and visualizer.has_method("sync_controls_from_config"):
			visualizer.sync_controls_from_config(config)
		regenerate(false)

func _on_grid_size_changed(w: int, h: int) -> void:
	if config != null:
		config.grid_width = w
		config.grid_height = h
		regenerate(false)

func _on_mission_depth_changed(depth: int) -> void:
	if config != null:
		config.mission_depth = depth
		regenerate(false)

func _on_corridor_width_changed(w: int) -> void:
	if config != null:
		config.corridor_width = w
		regenerate(false)

func _ensure_floor_config() -> void:
	if config != null and config.floor_tile_config == null:
		config.floor_tile_config = _FloorTileConfigScript.new()

func _on_floor_pattern_changed(idx: int) -> void:
	_ensure_floor_config()
	if config != null and config.floor_tile_config != null:
		(config.floor_tile_config as _FloorTileConfigScript).pattern = idx as _FloorTileConfigScript.PatternType

func _on_floor_preset_changed(idx: int) -> void:
	_ensure_floor_config()
	if config != null and config.floor_tile_config != null:
		(config.floor_tile_config as _FloorTileConfigScript).material_preset = idx

func _on_floor_tile_size_changed(val: float) -> void:
	_ensure_floor_config()
	if config != null and config.floor_tile_config != null:
		(config.floor_tile_config as _FloorTileConfigScript).tile_size = val

func _on_floor_margin_changed(val: float) -> void:
	_ensure_floor_config()
	if config != null and config.floor_tile_config != null:
		(config.floor_tile_config as _FloorTileConfigScript).margin = val

func _on_floor_collision_mode_changed(idx: int) -> void:
	_ensure_floor_config()
	if config != null and config.floor_tile_config != null:
		(config.floor_tile_config as _FloorTileConfigScript).collision_mode = idx as _FloorTileConfigScript.CollisionMode

func _on_floor_noise_toggled(enabled: bool) -> void:
	_ensure_floor_config()
	if config != null and config.floor_tile_config != null:
		(config.floor_tile_config as _FloorTileConfigScript).use_noise_modulation = enabled

func _on_algorithm_changed(p_algo: String) -> void:
	if config != null:
		config.algorithm = p_algo
		regenerate(false)

func _on_floors_changed(p_floors: int) -> void:
	if config != null:
		config.total_floors = maxi(1, p_floors)
		_current_isolated_floor = -1
		regenerate(false)

func _on_floor_view_mode_changed(p_floor_idx: int) -> void:
	_current_isolated_floor = p_floor_idx
	if visualizer != null:
		visualizer.update_floor_view_options(config.total_floors if config != null else 1, _current_isolated_floor)
		if visualizer.is_2d_preview_mode and _current_multi_result != null:
			visualizer.show_multi_floor_preview(_current_multi_result, _current_isolated_floor)
	_apply_floor_visibility()
	_center_camera_on_dungeon()

func _on_toggle_2d_view_requested() -> void:
	if visualizer != null:
		if _current_multi_result != null:
			visualizer.show_multi_floor_preview(_current_multi_result, _current_isolated_floor)
		elif _current_result != null:
			visualizer.show_2d_preview(_current_result, _current_semantic_result)

func _apply_floor_visibility() -> void:
	if _current_presentation_root == null:
		return
	for child in _current_presentation_root.get_children():
		if child.name.begins_with("Floor_"):
			if _current_isolated_floor == -1:
				child.visible = true
			else:
				child.visible = (child.name == "Floor_%d" % _current_isolated_floor)
	_apply_walls_visibility()

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

## Paso 1: Generación lógica y apertura de la vista previa 2D
func regenerate(force_new_seed: bool = false) -> void:
	_connect_visualizer_signals()
	if config == null:
		return

	if force_new_seed:
		config.seed = 0
		config.use_fixed_seed = false

	# Ocultar mundo 3D previo si existe mientras se visualiza el plano 2D
	if _current_presentation_root != null:
		_current_presentation_root.visible = false
	if _player != null:
		_player.visible = false

	# FLUJO MULTI-PISO (Fase 10 / M8)
	if config.total_floors > 1:
		var multi_res: DungeonMultiFloorResult = _multi_floor_generator.generate_multi_floor(config)
		if multi_res == null or not multi_res.is_valid:
			_show_failure_ui("Generación multi-piso fallida.\nPresiona [R] o [Espacio] para reintentar.")
			return

		_hide_failure_ui()
		_current_multi_result = multi_res
		_current_result = null
		_current_semantic_result = null

		if visualizer != null:
			visualizer.update_floor_view_options(config.total_floors, _current_isolated_floor)
			visualizer.show_multi_floor_preview(multi_res, _current_isolated_floor)
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

	_hide_failure_ui()
	_current_result = new_result
	_current_semantic_result = new_semantic
	_current_multi_result = null

	# Mostrar el Plano 2D interactivo en la UI
	if visualizer != null:
		visualizer.update_floor_view_options(1, 0)
		visualizer.show_2d_preview(_current_result, _current_semantic_result)

## Paso 2: Materialización y visualización del mundo 3D al confirmar
func build_3d_presentation() -> void:
	if _current_result == null and _current_multi_result == null:
		return

	var prof := _get_or_create_lighting_profile()
	var biome: BiomeProfile = config.biome_profile if config.biome_profile != null else BiomeProfile.new()
	biome.lighting_profile = prof

	if config != null and config.lighting_config == null:
		config.lighting_config = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd").new()

	if visualizer != null:
		visualizer.hide_2d_preview()

	# Si es multi-piso
	if config.total_floors > 1 and _current_multi_result != null:
		var pres_res = _presentation_builder.build_multi_floor_presentation(
			_current_multi_result, self, biome, config, _current_presentation_root
		)
		if not pres_res.success:
			_show_failure_ui("Fallo en presentación multi-piso 3D:\n" + pres_res.to_debug_string())
			return

		_current_presentation_root = pres_res.presentation_root
		_current_presentation_root.visible = true

		var f0 = _current_multi_result.get_floor(0)
		if f0 != null and not f0.rooms.is_empty():
			var center_cell = f0.rooms[0].get_center()
			var p_pos := GridToWorld.get_cell_center_world_3d(center_cell, 0, config.cell_size, config.floor_height, 0.5)
			if _player == null:
				_player = _PlayerTestScript.new()
				_player.name = "Player"
				add_child(_player)
			_player.position = p_pos
			_player.visible = true

		_apply_floor_visibility()
		_center_camera_on_dungeon()
		_apply_live_lighting_updates()
		return

	# Si es mono-piso
	if _current_semantic_result != null:
		var pres_res = _presentation_builder.build_presentation(
			_current_semantic_result, self, biome, config, _current_presentation_root, true
		)

		if not pres_res.success:
			push_error("[DungeonLevelController] Falló la presentación 3D:\n%s" % pres_res.to_debug_string())
			if not pres_res.previous_presentation_preserved:
				_show_failure_ui("Fallo en presentación 3D:\n" + pres_res.to_debug_string())
			return

		_current_presentation_root = pres_res.presentation_root
		_current_presentation_root.visible = true

		# Posicionar o spawnear personaje de prueba
		_spawn_or_reposition_player()
		if _player != null:
			_player.visible = true

		_apply_walls_visibility()
		_center_camera_on_dungeon()
		_apply_live_lighting_updates()

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
	if camera == null or config == null:
		return

	var grid_w: float = float(config.grid_width)
	var grid_h: float = float(config.grid_height)
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
		camera.rotation_degrees = Vector3(-90, _camera_yaw, 0)
		camera.position = _camera_pivot + Vector3(0, cam_distance, 0)
	else:
		camera.rotation_degrees = Vector3(-45, _camera_yaw, 0)
		var rot_rad_x: float = deg_to_rad(-45.0)
		var rot_rad_y: float = deg_to_rad(_camera_yaw)
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

	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	var speed: float = _zoom * 1.5 * delta
	var move_dir := Vector3.ZERO

	var rad_y: float = deg_to_rad(_camera_yaw)
	var forward := Vector3(-sin(rad_y), 0, -cos(rad_y)).normalized()
	var right := Vector3(cos(rad_y), 0, -sin(rad_y)).normalized()

	if Input.is_key_pressed(KEY_W):
		move_dir += forward
	if Input.is_key_pressed(KEY_S):
		move_dir -= forward
	if Input.is_key_pressed(KEY_A):
		move_dir -= right
	if Input.is_key_pressed(KEY_D):
		move_dir += right

	if move_dir != Vector3.ZERO:
		_camera_pivot += move_dir.normalized() * speed
		_update_camera_transform()

func _input(event: InputEvent) -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				focus_owner.release_focus()
				get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				if visualizer != null and visualizer.is_2d_preview_mode:
					build_3d_presentation()
				else:
					_on_random_seed_requested()
			KEY_TAB, KEY_M:
				if visualizer != null:
					visualizer.toggle_2d_preview()
			KEY_R:
				_on_random_seed_requested()
			KEY_T, KEY_V:
				_on_camera_view_toggled()
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
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(10.0, _zoom - 4.0)
			if camera != null:
				camera.size = _zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(200.0, _zoom + 4.0)
			if camera != null:
				camera.size = _zoom

	if event is InputEventMouseMotion and _is_orbiting:
		_camera_yaw -= event.relative.x * 0.4
		_update_camera_transform()

# ==============================================================================
# MANEJADORES DE ILUMINACIÓN PROCEDURAL Y ENTORNO
# ==============================================================================

func _get_or_create_lighting_profile() -> LightingProfile:
	if visualizer != null and visualizer.has_method("get_current_lighting_profile"):
		_lighting_profile = visualizer.get_current_lighting_profile()
		if config != null and config.biome_profile != null:
			config.biome_profile.lighting_profile = _lighting_profile
		return _lighting_profile

	if _lighting_profile != null:
		return _lighting_profile
	if config != null and config.biome_profile != null and config.biome_profile.lighting_profile != null:
		_lighting_profile = config.biome_profile.lighting_profile
		return _lighting_profile
	_lighting_profile = _LightingProfileScript.new()
	if config != null and config.biome_profile != null:
		config.biome_profile.lighting_profile = _lighting_profile
	return _lighting_profile

func _apply_live_lighting_updates() -> void:
	var prof := _get_or_create_lighting_profile()
	if _current_presentation_root != null:
		var omnis = _current_presentation_root.find_children("*", "OmniLight3D", true, false)
		for omni in omnis:
			omni.light_color = prof.light_color
			omni.light_energy = prof.energy
			omni.omni_range = prof.omni_range
			omni.omni_attenuation = prof.attenuation
			omni.shadow_enabled = prof.shadow_enabled

		var controllers = _current_presentation_root.find_children("*", "TorchLightController", true, false)
		for ctrl in controllers:
			ctrl.base_energy = prof.energy
			ctrl.flicker_amplitude = prof.flicker_amplitude if prof.flicker_enabled else 0.0

func _on_lighting_torch_color_changed(c: Color) -> void:
	_get_or_create_lighting_profile().light_color = c
	_apply_live_lighting_updates()

func _on_lighting_torch_energy_changed(val: float) -> void:
	_get_or_create_lighting_profile().energy = val
	_apply_live_lighting_updates()

func _on_lighting_torch_range_changed(val: float) -> void:
	_get_or_create_lighting_profile().omni_range = val
	_apply_live_lighting_updates()

func _on_lighting_torch_attenuation_changed(val: float) -> void:
	_get_or_create_lighting_profile().attenuation = val
	_apply_live_lighting_updates()

func _on_lighting_torch_flicker_toggled(pressed: bool) -> void:
	_get_or_create_lighting_profile().flicker_enabled = pressed
	_apply_live_lighting_updates()

func _on_lighting_torch_flicker_amp_changed(val: float) -> void:
	_get_or_create_lighting_profile().flicker_amplitude = val
	_apply_live_lighting_updates()

func _on_lighting_torch_shadows_toggled(pressed: bool) -> void:
	_get_or_create_lighting_profile().shadow_enabled = pressed
	_apply_live_lighting_updates()

func _on_lighting_ambient_color_changed(c: Color) -> void:
	var we = get_node_or_null("WorldEnvironment")
	if we != null and we.environment != null:
		we.environment.ambient_light_color = c

func _on_lighting_ambient_energy_changed(val: float) -> void:
	var we = get_node_or_null("WorldEnvironment")
	if we != null and we.environment != null:
		we.environment.ambient_light_energy = val

func _on_lighting_rim_color_changed(c: Color) -> void:
	var dl = get_node_or_null("DirectionalLight3D")
	if dl != null:
		dl.light_color = c

func _on_lighting_rim_energy_changed(val: float) -> void:
	var dl = get_node_or_null("DirectionalLight3D")
	if dl != null:
		dl.light_energy = val

func _on_lighting_fog_density_changed(val: float) -> void:
	var we = get_node_or_null("WorldEnvironment")
	if we != null and we.environment != null:
		we.environment.fog_density = val
