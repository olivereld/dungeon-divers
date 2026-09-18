class_name ChunkWorldIntegration
extends Node3D

## Escena de integración y prueba interactiva para generación procedural
## y streaming de chunks con navegación del jugador (WASD / Flechas / Espacio).

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

@export var world_seed: int = 12345
@export var render_distance: int = 1

var chunk_world: ChunkWorld = null
var player: CharacterBody3D = null
var camera: Camera3D = null
var sun_light: DirectionalLight3D = null
var world_environment: WorldEnvironment = null

var profile: WorldProfile = null
var config: ChunkConfig = null
var shared_hydrology: HydrologyResult = null

# HUD Elements
var _hud_layer: CanvasLayer = null
var _info_label: Label = null


func _ready() -> void:
	_setup_environment()
	_setup_chunk_world()
	_setup_player()
	_setup_hud()


func _setup_environment() -> void:
	# 1. Luz Solar
	sun_light = DirectionalLight3D.new()
	sun_light.name = "DirectionalLight3D"
	sun_light.rotation_degrees = Vector3(-45, 35, 0)
	sun_light.light_energy = 1.15
	sun_light.shadow_enabled = true
	add_child(sun_light)

	# 2. Entorno y Cielo Procedural
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.70, 0.78, 0.85)
	sky_mat.ground_bottom_color = Color(0.20, 0.22, 0.25)
	sky_mat.ground_horizon_color = Color(0.55, 0.60, 0.65)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = env
	add_child(world_environment)


func _setup_chunk_world() -> void:
	profile = _TaigaWorldProfileScript.new()
	config = _ChunkConfigScript.new(16, render_distance)
	shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	chunk_world = _ChunkWorldScript.new()
	chunk_world.name = "ChunkWorld"
	add_child(chunk_world)

	chunk_world.initialize(world_seed, profile, config, shared_hydrology)
	# Carga inicial del radio centrado en (0, 0)
	chunk_world.load_initial_area(Vector2i.ZERO, render_distance)


func _setup_player() -> void:
	player = _PlayerTestScript.new()
	player.name = "Player"

	# Cámara de seguimiento en tercera persona
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.position = Vector3(0, 10, 12)
	camera.rotation_degrees = Vector3(-38, 0, 0)
	camera.fov = 65.0
	player.add_child(camera)

	# Posicionar al jugador en una cota segura sobre el terreno inicial
	var start_cell := chunk_world.get_cell_at_world_pos(Vector2i(8, 8))
	var start_y: float = start_cell.height if start_cell != null else 10.0
	player.position = Vector3(8.0, start_y + 1.2, 8.0)

	add_child(player)

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

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.text = "Cargando mundo de chunks..."
	margin.add_child(_info_label)


func _process(_delta: float) -> void:
	_update_hud()
	_handle_debug_inputs()


func _update_hud() -> void:
	if _info_label == null or chunk_world == null or player == null:
		return

	var mgr = chunk_world.chunk_manager
	var active_coord: Vector2i = chunk_world.active_chunk
	var p_pos: Vector3 = player.global_position
	var fps: int = int(Engine.get_frames_per_second())

	var loaded_count: int = mgr.loaded_chunks.size() if mgr != null else 0
	var text := "=== PROCEDURAL CHUNK STREAMING ===\n"
	text += "FPS: %d\n" % fps
	text += "Chunk Activo: (%d, %d)\n" % [active_coord.x, active_coord.y]
	text += "Posición Jugador: (%.1f, %.1f, %.1f)\n" % [p_pos.x, p_pos.y, p_pos.z]
	text += "Chunks Cargados: %d\n" % loaded_count
	if mgr != null:
		text += "Peticiones: %d | Generados: %d | Descartados: %d\n" % [
			mgr.stats_requested,
			mgr.stats_generated,
			mgr.stats_discarded
		]
	text += "-----------------------------------\n"
	text += "[WASD / Flechas]: Mover personaje\n"
	text += "[Espacio]: Saltar\n"
	text += "[R]: Reaparecer en origen (8, 8)\n"

	_info_label.text = text


func _handle_debug_inputs() -> void:
	if Input.is_key_pressed(KEY_R) and player != null and chunk_world != null:
		var start_cell := chunk_world.get_cell_at_world_pos(Vector2i(8, 8))
		var start_y: float = start_cell.height if start_cell != null else 10.0
		player.position = Vector3(8.0, start_y + 1.2, 8.0)
		player.velocity = Vector3.ZERO
