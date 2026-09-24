class_name ChunkWorldIntegration
extends Node3D

## Escena de integración y prueba interactiva para generación procedural
## y streaming de chunks con navegación del jugador (WASD / Flechas / Espacio).

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _DungeonSessionDataScript = preload("res://src/world_generator/poi/dungeon_session_data.gd")

@export var world_seed: int = 12345
@export var render_distance: int = 4

var chunk_world: ChunkWorld = null
var player: CharacterBody3D = null
var camera_rig: IsometricCameraRig = null
var sun_light: DirectionalLight3D = null
var world_environment: WorldEnvironment = null

var profile: WorldProfile = null
var config: ChunkConfig = null
var shared_hydrology: HydrologyResult = null

# HUD Elements
var _hud_layer: CanvasLayer = null
var _info_label: Label = null
var _water_toggle_btn: Button = null


func _ready() -> void:
	_setup_environment()
	_setup_chunk_world()
	_setup_player()
	_setup_hud()


func _setup_environment() -> void:
	# 1. Luz Solar (Cálida y dorada para atmósfera de bosque otoñal)
	sun_light = DirectionalLight3D.new()
	sun_light.name = "DirectionalLight3D"
	sun_light.rotation_degrees = Vector3(-45, 38, 0)
	sun_light.light_color = Color(1.0, 0.94, 0.85)
	sun_light.light_energy = 1.25
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.04
	add_child(sun_light)

	# 2. Entorno y Cielo Procedural
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.52, 0.75)
	sky_mat.sky_horizon_color = Color(0.82, 0.74, 0.65)
	sky_mat.ground_bottom_color = Color(0.25, 0.20, 0.18)
	sky_mat.ground_horizon_color = Color(0.65, 0.58, 0.50)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.60
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = env
	add_child(world_environment)


func _setup_chunk_world() -> void:
	# Perfil de Bosque Otoñal por defecto con texturas del proyecto
	profile = _AutumnForestWorldProfileScript.new()
	config = _ChunkConfigScript.new(16, 1, render_distance)
	shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	chunk_world = _ChunkWorldScript.new()
	chunk_world.name = "ChunkWorld"
	chunk_world.render_distance = render_distance
	chunk_world.dungeon_enter_requested.connect(_on_dungeon_enter_requested)
	add_child(chunk_world)

	chunk_world.initialize(world_seed, profile, config, shared_hydrology, render_distance)
	# Carga inicial del radio centrado en (0, 0)
	chunk_world.load_initial_area(Vector2i.ZERO, render_distance)


func _setup_player() -> void:
	player = _PlayerTestScript.new()
	player.name = "Player"

	# Posicionar al jugador: si venimos de regreso de una mazmorra, usar la posición guardada
	var start_pos := Vector3(8.0, 10.0, 8.0)
	if _DungeonSessionDataScript.saved_player_overworld_position != Vector3.ZERO:
		start_pos = _DungeonSessionDataScript.saved_player_overworld_position
		_DungeonSessionDataScript.saved_player_overworld_position = Vector3.ZERO
	else:
		var start_cell := chunk_world.get_cell_at_world_pos(Vector2i(8, 8))
		var start_y: float = start_cell.height if start_cell != null else 10.0
		start_pos = Vector3(8.0, start_y + 1.2, 8.0)

	player.position = start_pos
	add_child(player)

	# Cámara isométrica orbital de producción (IsometricCameraRig)
	camera_rig = _IsometricCameraRigScript.new()
	camera_rig.name = "IsometricCameraRig"
	camera_rig.yaw_degrees = 45.0
	camera_rig.pitch_degrees = 35.264 # Ángulo isométrico real
	camera_rig.zoom_min = 6.0
	camera_rig.zoom_max = 60.0
	camera_rig.default_zoom = 20.0
	camera_rig.zoom_step = 4.0
	camera_rig.zoom_smoothing = 14.0
	camera_rig.follow_speed = 12.0
	add_child(camera_rig)

	camera_rig.set_target(player)
	camera_rig.set_follow_enabled(true)
	camera_rig.teleport_to_target()

	# Conectar player como autoridad de streaming
	chunk_world.set_tracked_target(player)


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	add_child(_hud_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 360
	panel.offset_bottom = 220
	_hud_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.text = "Cargando mundo de chunks..."
	vbox.add_child(_info_label)

	_water_toggle_btn = Button.new()
	_water_toggle_btn.name = "WaterToggleBtn"
	_water_toggle_btn.text = "💧 Ocultar Malla de Agua [H]"
	_water_toggle_btn.focus_mode = Control.FOCUS_NONE
	_water_toggle_btn.pressed.connect(_on_toggle_water_pressed)
	vbox.add_child(_water_toggle_btn)

	var dist_hbox := HBoxContainer.new()
	dist_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(dist_hbox)

	var dist_down_btn := Button.new()
	dist_down_btn.text = "➖ Rango [J]"
	dist_down_btn.focus_mode = Control.FOCUS_NONE
	dist_down_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist_down_btn.pressed.connect(_decrease_render_distance)
	dist_hbox.add_child(dist_down_btn)

	var dist_up_btn := Button.new()
	dist_up_btn.text = "➕ Rango [K]"
	dist_up_btn.focus_mode = Control.FOCUS_NONE
	dist_up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist_up_btn.pressed.connect(_increase_render_distance)
	dist_hbox.add_child(dist_up_btn)


func _on_toggle_water_pressed() -> void:
	_toggle_water()


func _toggle_water() -> void:
	if chunk_world != null:
		var is_vis: bool = chunk_world.toggle_water_visible()
		if _water_toggle_btn != null:
			_water_toggle_btn.text = "💧 Ocultar Malla de Agua [H]" if is_vis else "🌊 Mostrar Malla de Agua [H]"


func _increase_render_distance() -> void:
	if chunk_world != null:
		render_distance = clampi(render_distance + 1, 1, 8)
		chunk_world.set_render_distance(render_distance)


func _decrease_render_distance() -> void:
	if chunk_world != null:
		render_distance = clampi(render_distance - 1, 1, 8)
		chunk_world.set_render_distance(render_distance)


func _process(_delta: float) -> void:
	_update_hud()
	_handle_debug_inputs()


func _update_hud() -> void:
	if _info_label == null or chunk_world == null or player == null:
		return

	var fps: int = int(Engine.get_frames_per_second())
	var p_pos: Vector3 = player.global_position
	var mgr = chunk_world.chunk_manager
	var active_coord: Vector2i = chunk_world.active_chunk

	var loaded_count: int = mgr.loaded_chunks.size() if mgr != null else 0
	var pred_chunk: Vector2i = chunk_world.streaming_controller.predicted_chunk if chunk_world.streaming_controller != null else active_coord
	var queue_len: int = chunk_world.activation_scheduler.get_queue_size() if chunk_world.activation_scheduler != null else 0
	var act_ms: float = chunk_world.activation_scheduler.last_frame_activation_time_ms if chunk_world.activation_scheduler != null else 0.0

	var text := "=== PROCEDURAL PREDICTIVE STREAMING ===\n"
	text += "FPS: %d %s\n" % [fps, "⚠️ SPIKE (>16ms)" if fps < 60 else "🟢"]
	text += "Chunk Activo: (%d, %d) | Predicho: (%d, %d)\n" % [active_coord.x, active_coord.y, pred_chunk.x, pred_chunk.y]
	text += "Posición Jugador: (%.1f, %.1f, %.1f)\n" % [p_pos.x, p_pos.y, p_pos.z]
	text += "Radios: Vis %d | Preload %d | Cache %d\n" % [
		config.visible_radius if config != null else 2,
		config.preload_radius if config != null else 5,
		config.cache_radius if config != null else 8
	]
	var vis_views: int = chunk_world.chunk_views.size() if chunk_world != null else 0
	var act_sched = chunk_world.activation_scheduler
	text += "Vistas Activas: %d | Chunks en RAM (Ready/Preload): %d\n" % [vis_views, loaded_count]
	text += "Cola Activación: %d | Frame Act: %.2f ms (Budget: %.1f ms)\n" % [
		queue_len,
		act_ms,
		config.activation_budget_ms if config != null else 2.0
	]
	if act_sched != null:
		text += "  [Etapas] Terreno: %.1fms | Colisión: %.1fms | Agua: %.1fms | Veg: %.1fms\n" % [
			act_sched.telemetry_terrain_ms,
			act_sched.telemetry_collision_ms,
			act_sched.telemetry_water_ms,
			act_sched.telemetry_vegetation_ms
		]
	if mgr != null:
		text += "Req: %d | Gen: %d | Desc: %d\n" % [
			mgr.stats_requested,
			mgr.stats_generated,
			mgr.stats_discarded
		]
	text += "Malla de Agua: %s\n" % ("Visible" if chunk_world.water_visible else "Oculta")
	text += "-----------------------------------\n"
	text += "[WASD / Flechas]: Mover personaje\n"
	text += "[Q / E]: Rotar cámara orbital 45°\n"
	text += "[Rueda Mouse]: Zoom In / Out\n"
	text += "[Espacio]: Saltar\n"
	text += "[J / K] o [+ / -]: Reducir / Aumentar Rango\n"
	text += "[H]: Ocultar / Mostrar Malla de Agua\n"
	text += "[R]: Reaparecer en origen (8, 8)\n"

	_info_label.text = text



func _unhandled_input(event: InputEvent) -> void:
	if camera_rig == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.is_pressed():
			camera_rig.zoom_in()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.is_pressed():
			camera_rig.zoom_out()

	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var ke := event as InputEventKey
		if ke.keycode == KEY_Q:
			camera_rig.yaw_degrees -= 45.0
		elif ke.keycode == KEY_E:
			camera_rig.yaw_degrees += 45.0
		elif ke.keycode == KEY_H:
			_toggle_water()
		elif ke.keycode == KEY_J or ke.keycode == KEY_MINUS or ke.keycode == KEY_KP_SUBTRACT:
			_decrease_render_distance()
		elif ke.keycode == KEY_K or ke.keycode == KEY_EQUAL or ke.keycode == KEY_PLUS or ke.keycode == KEY_KP_ADD:
			_increase_render_distance()


func _handle_debug_inputs() -> void:
	if Input.is_key_pressed(KEY_R) and player != null and chunk_world != null:
		var start_cell := chunk_world.get_cell_at_world_pos(Vector2i(8, 8))
		var start_y: float = start_cell.height if start_cell != null else 10.0
		player.position = Vector3(8.0, start_y + 1.2, 8.0)
		player.velocity = Vector3.ZERO
		if camera_rig != null:
			camera_rig.teleport_to_target()



func _on_dungeon_enter_requested(poi: RefCounted, dungeon_result: RefCounted, player_node: Node3D) -> void:
	print("[ChunkWorldIntegration] Preparando transición a la escena de mazmorra independiente...")

	# 1. Guardar posición previa del jugador en el mundo exterior para el regreso
	var active_player: CharacterBody3D = (player_node as CharacterBody3D) if player_node is CharacterBody3D else player
	var return_pos := Vector3(8.0, 12.0, 8.0)
	if active_player != null:
		return_pos = active_player.global_position
	elif poi != null and "world_position" in poi:
		return_pos = poi.world_position + Vector3(0.0, 0.5, 3.0)

	# 2. Persistir datos en DungeonSessionData para la escena dedicada
	_DungeonSessionDataScript.active_poi = poi
	_DungeonSessionDataScript.active_dungeon_result = dungeon_result
	_DungeonSessionDataScript.saved_player_overworld_position = return_pos
	_DungeonSessionDataScript.return_scene_path = scene_file_path if not scene_file_path.is_empty() else "res://src/world_generator/scenes/chunk_world_integration.tscn"
	_DungeonSessionDataScript.return_world_seed = world_seed
	_DungeonSessionDataScript.return_render_distance = render_distance

	# 3. Cambiar a la escena separada de la mazmorra
	print("[ChunkWorldIntegration] Cambiando a res://src/world_generator/scenes/dungeon_gameplay_scene.tscn")
	get_tree().change_scene_to_file("res://src/world_generator/scenes/dungeon_gameplay_scene.tscn")
