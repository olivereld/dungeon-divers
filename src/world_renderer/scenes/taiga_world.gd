class_name TaigaWorld
extends Node3D

## Taiga World Lab & Exploration Viewer.
## Entorno interactivo para calibrar en tiempo real los parámetros del terreno,
## explorar el mundo procedural en 3D con IsometricCameraRig y analizar telemetría,
## capas de ruido 2D y paletas de color en paneles tácticos.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")
const _LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")

@export var world_seed: int = 12345

# 3D Environment & Presentation
var world_container: Node3D = null
var current_world_node: Node3D = null
var current_result: WorldResult = null
var profile: TaigaWorldProfile = null

# Testing Player for Scale Comparison & Ground Navigation
var test_player: CharacterBody3D = null
var is_player_active: bool = true
var player_toggle_btn: Button = null

# Camera & Navigation
var camera_rig: IsometricCameraRig = null
var focus_target: Marker3D = null
var sun_light: DirectionalLight3D = null
var world_env: WorldEnvironment = null
var _is_panning: bool = false
var _is_orbiting: bool = false
var _is_perspective: bool = false

# UI Canvas & Top-Level Containers
var canvas_layer: CanvasLayer = null
var ui_root: Control = null
var top_bar: PanelContainer = null
var bottom_bar: PanelContainer = null
var left_panel: PanelContainer = null
var right_panel: PanelContainer = null

# TopBar Controls
var seed_spin: SpinBox = null
var preset_option: OptionButton = null
var auto_gen_btn: Button = null
var is_auto_gen: bool = true
var gen_btn: Button = null

# LeftPanel Sliders
var _sliders: Dictionary = {}

# RightPanel Tabs & Containers
enum RightTab { TELEMETRY, NOISE, COLORS, HYDROLOGY }
var active_tab: RightTab = RightTab.TELEMETRY

var tab_btn_telemetry: Button = null
var tab_btn_noise: Button = null
var tab_btn_colors: Button = null
var tab_btn_hydrology: Button = null
var tab_title_icon: Label = null
var tab_title_lbl: Label = null

var panel_telemetry: VBoxContainer = null
var panel_noise: VBoxContainer = null
var panel_colors: VBoxContainer = null
var panel_hydrology: VBoxContainer = null

# Terrain Debug Visualizer Widgets
enum TerrainDebugMode { OVERVIEW_2X2, MACRO, MEDIUM, DETAIL, WARP, COMBINED, ELEVATION, SLOPE, NORMALIZED_HEIGHT }
var current_terrain_debug_mode: TerrainDebugMode = TerrainDebugMode.OVERVIEW_2X2
var terrain_debug_option: OptionButton = null
var terrain_debug_rect: TextureRect = null
var terrain_debug_legend: Label = null
var terrain_overview_grid: GridContainer = null
var terrain_single_box: VBoxContainer = null

# Hydrology Debug Visualizer Widgets
enum HydroDebugMode { OFF, NOISE, LAKE_POTENTIAL, RIVER_POTENTIAL, DRAINAGE, FLOW_DIR, DEPTH, BODIES }
var current_hydro_debug_mode: HydroDebugMode = HydroDebugMode.BODIES
var hydro_debug_option: OptionButton = null
var hydro_debug_rect: TextureRect = null
var hydro_debug_legend: Label = null
var hydro_stat_lakes_lbl: Label = null
var hydro_stat_rivers_lbl: Label = null
var hydro_stat_depth_lbl: Label = null
var hydro_stat_area_lbl: Label = null

# Telemetry Widgets
var stat_time_lbl: Label = null
var stat_walkable_lbl: Label = null
var stat_height_lbl: Label = null
var stat_range_lbl: Label = null
var zone_bar_pcts: Dictionary = {}
var zone_bar_fills: Dictionary = {}
var ent_trees_lbl: Label = null
var ent_shrubs_lbl: Label = null
var ent_rocks_lbl: Label = null
var ent_total_lbl: Label = null

# Noise Visualizer Widgets
var tex_rect_height: TextureRect = null
var tex_rect_warp: TextureRect = null
var tex_rect_eco: TextureRect = null
var tex_rect_composite: TextureRect = null

# Color Palette Widgets
var gradient_preview_rect: TextureRect = null
var color_pickers: Dictionary = {}
var color_hex_labels: Dictionary = {}

const COLOR_DEFS: Array[Dictionary] = [
	{ "key": "color_deep_water", "label": "Agua Profunda", "sublabel": "Fondo oceánico",    "range": "0 – 27%"   },
	{ "key": "color_water",      "label": "Agua",          "sublabel": "Zonas costeras",    "range": "27 – 35%"  },
	{ "key": "color_sand",       "label": "Arena",         "sublabel": "Playas y dunas",    "range": "35 – 41%"  },
	{ "key": "color_ground",     "label": "Tierra",        "sublabel": "Suelo desnudo",     "range": "41 – 50%"  },
	{ "key": "color_grass",      "label": "Pasto",         "sublabel": "Claros y praderas", "range": "50 – 67%"  },
	{ "key": "color_forest",     "label": "Bosque",        "sublabel": "Zona forestal",     "range": "67 – 77%"  },
	{ "key": "color_rock",       "label": "Roca",          "sublabel": "Picos rocosos",     "range": "77 – 88%"  },
	{ "key": "color_snow",       "label": "Nieve",         "sublabel": "Cimas nevadas",     "range": "88 – 100%" },
]

const COLOR_PRESETS: Dictionary = {
	"Taiga Clásica": {
		"color_deep_water": Color("#1a3a5c"), "color_water": Color("#2456a4"), "color_sand": Color("#c8a96e"),
		"color_ground": Color("#7a6548"), "color_grass": Color("#4a8c3f"), "color_forest": Color("#2d5a27"),
		"color_rock": Color("#5a5a5a"), "color_snow": Color("#dce8f0")
	},
	"Desierto Árido": {
		"color_deep_water": Color("#1a4a6a"), "color_water": Color("#1a6080"), "color_sand": Color("#e8c87a"),
		"color_ground": Color("#c4914a"), "color_grass": Color("#b8a04a"), "color_forest": Color("#8a6a20"),
		"color_rock": Color("#7a5a3a"), "color_snow": Color("#f0e8d0")
	},
	"Mundo Alien": {
		"color_deep_water": Color("#1a0a3a"), "color_water": Color("#3a0a6a"), "color_sand": Color("#8a4a8a"),
		"color_ground": Color("#5a2a5a"), "color_grass": Color("#2a6a4a"), "color_forest": Color("#0a4a2a"),
		"color_rock": Color("#3a3a5a"), "color_snow": Color("#c0a0e0")
	},
	"Tundra Nevada": {
		"color_deep_water": Color("#0a1a2a"), "color_water": Color("#1a3060"), "color_sand": Color("#a0a8b0"),
		"color_ground": Color("#808890"), "color_grass": Color("#607080"), "color_forest": Color("#304858"),
		"color_rock": Color("#505860"), "color_snow": Color("#e8eef8")
	}
}

const PRESETS: Dictionary = {
	0: {
		"name": "Taiga Canónica (Equilibrada)",
		"macro_strength": 14.0, "macro_frequency": 0.012, "relief_exponent": 1.1,
		"base_height": 1.5, "height_scale": 1.0,
		"warp_strength": 18.0, "warp_frequency": 0.018, "warp_octaves": 2,
		"clearing_threshold": 0.45, "forest_frequency": 0.025,
		"tree_density": 0.70, "min_tree_spacing": 2.0, "shrub_density": 0.45, "rock_density": 0.20
	},
	1: {
		"name": "Valle Glaciar Amplio (Bajo Relieve)",
		"macro_strength": 16.0, "macro_frequency": 0.010, "relief_exponent": 1.6,
		"base_height": 1.2, "height_scale": 0.9,
		"warp_strength": 16.0, "warp_frequency": 0.015, "warp_octaves": 2,
		"clearing_threshold": 0.52, "forest_frequency": 0.020,
		"tree_density": 0.55, "min_tree_spacing": 2.4, "shrub_density": 0.50, "rock_density": 0.12
	},
	2: {
		"name": "Tierras Altas Escarpadas (Fiordos)",
		"macro_strength": 22.0, "macro_frequency": 0.018, "relief_exponent": 0.95,
		"base_height": 2.0, "height_scale": 1.3,
		"warp_strength": 22.0, "warp_frequency": 0.022, "warp_octaves": 3,
		"clearing_threshold": 0.42, "forest_frequency": 0.030,
		"tree_density": 0.50, "min_tree_spacing": 2.2, "shrub_density": 0.35, "rock_density": 0.35
	},
	3: {
		"name": "Bosque Boreal Cerrado (Old-Growth)",
		"macro_strength": 12.0, "macro_frequency": 0.014, "relief_exponent": 1.05,
		"base_height": 1.5, "height_scale": 1.0,
		"warp_strength": 15.0, "warp_frequency": 0.018, "warp_octaves": 2,
		"clearing_threshold": 0.32, "forest_frequency": 0.025,
		"tree_density": 0.85, "min_tree_spacing": 1.7, "shrub_density": 0.60, "rock_density": 0.15
	},
	4: {
		"name": "Turberas y Claros Abiertos",
		"macro_strength": 9.0, "macro_frequency": 0.012, "relief_exponent": 1.3,
		"base_height": 1.0, "height_scale": 0.85,
		"warp_strength": 12.0, "warp_frequency": 0.015, "warp_octaves": 2,
		"clearing_threshold": 0.62, "forest_frequency": 0.018,
		"tree_density": 0.30, "min_tree_spacing": 2.0, "shrub_density": 0.65, "rock_density": 0.10
	},
	5: {
		"name": "Archipiélago (Islas y Fiordos)",
		"macro_strength": 15.0, "macro_frequency": 0.020, "relief_exponent": 1.8,
		"base_height": 0.5, "height_scale": 1.1,
		"warp_strength": 22.0, "warp_frequency": 0.025, "warp_octaves": 2,
		"clearing_threshold": 0.55, "forest_frequency": 0.022,
		"tree_density": 0.40, "min_tree_spacing": 2.2, "shrub_density": 0.45, "rock_density": 0.30
	},
	6: {
		"name": "Tundra Nevada (Cimas Rocosas)",
		"macro_strength": 18.0, "macro_frequency": 0.010, "relief_exponent": 1.2,
		"base_height": 2.5, "height_scale": 1.4,
		"warp_strength": 8.0, "warp_frequency": 0.015, "warp_octaves": 2,
		"clearing_threshold": 0.70, "forest_frequency": 0.015,
		"tree_density": 0.15, "min_tree_spacing": 3.0, "shrub_density": 0.25, "rock_density": 0.45
	}
}

func _ready() -> void:
	profile = _TaigaWorldProfileScript.new()

	_setup_3d_environment()
	_setup_ui()

	generate_world(true)

func _setup_3d_environment() -> void:
	if world_container != null:
		return

	world_container = Node3D.new()
	world_container.name = "WorldContainer"
	add_child(world_container)

	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnv"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#070b14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.72, 0.85)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun_light.light_color = Color(1.0, 0.96, 0.90)
	sun_light.light_energy = 1.35
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.04
	add_child(sun_light)

	focus_target = Marker3D.new()
	focus_target.name = "FocusTarget"
	focus_target.position = Vector3(64.0, 5.0, 64.0)
	add_child(focus_target)

	camera_rig = _IsometricCameraRigScript.new()
	camera_rig.name = "IsometricCameraRig"
	camera_rig.zoom_min = 6.0
	camera_rig.zoom_max = 220.0
	camera_rig.default_zoom = 48.0
	camera_rig.zoom_step = 6.0
	camera_rig.zoom_smoothing = 14.0
	camera_rig.follow_speed = 12.0
	camera_rig.yaw_degrees = 45.0
	camera_rig.pitch_degrees = 35.264
	add_child(camera_rig)

	camera_rig.set_target(focus_target)
	camera_rig.set_follow_enabled(true)

func _process(delta: float) -> void:
	if camera_rig == null or focus_target == null:
		return

	# When the test player is active, WASD moves the character and camera follows the player automatically
	if is_player_active and test_player != null and is_instance_valid(test_player):
		return

	var move_dir := Vector3.ZERO
	var cam: Camera3D = camera_rig.get_camera()
	if cam != null and cam.is_inside_tree():
		var right: Vector3 = cam.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		var forward: Vector3 = -cam.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_dir += forward
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_dir -= forward
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_dir -= right
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_dir += right

		if move_dir.length_squared() > 0.001:
			var pan_speed: float = camera_rig.get_zoom() * 1.5 * delta
			focus_target.global_position += move_dir.normalized() * pan_speed
			var max_w := float(profile.width) * profile.cell_size
			var max_h := float(profile.height) * profile.cell_size
			focus_target.global_position.x = clampf(focus_target.global_position.x, 0.0, max_w)
			focus_target.global_position.z = clampf(focus_target.global_position.z, 0.0, max_h)

func _unhandled_input(event: InputEvent) -> void:
	if camera_rig == null or focus_target == null:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.is_pressed():
			camera_rig.zoom_in()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.is_pressed():
			camera_rig.zoom_out()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.shift_pressed or mb.alt_pressed:
				_is_orbiting = mb.is_pressed()
				_is_panning = false
			else:
				_is_panning = mb.is_pressed()
				_is_orbiting = false
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_orbiting = mb.is_pressed()
			_is_panning = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_orbiting:
			camera_rig.yaw_degrees -= mm.relative.x * 0.4
			camera_rig.pitch_degrees = clampf(camera_rig.pitch_degrees - mm.relative.y * 0.3, 15.0, 80.0)
		elif _is_panning:
			var cam: Camera3D = camera_rig.get_camera()
			if cam != null and cam.is_inside_tree():
				var pan_factor: float = camera_rig.get_zoom() * 0.002
				var right: Vector3 = cam.global_transform.basis.x
				right.y = 0.0
				right = right.normalized()
				var forward: Vector3 = -cam.global_transform.basis.z
				forward.y = 0.0
				forward = forward.normalized()
				focus_target.global_position -= (right * mm.relative.x + forward * -mm.relative.y) * pan_factor
				var max_w := float(profile.width) * profile.cell_size
				var max_h := float(profile.height) * profile.cell_size
				focus_target.global_position.x = clampf(focus_target.global_position.x, 0.0, max_w)
				focus_target.global_position.z = clampf(focus_target.global_position.z, 0.0, max_h)

	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_Q:
			camera_rig.yaw_degrees -= 45.0
		elif ke.keycode == KEY_E:
			camera_rig.yaw_degrees += 45.0
		elif ke.keycode == KEY_P:
			_toggle_player()
		elif ke.keycode == KEY_F11:
			_toggle_fullscreen()
		elif ke.keycode == KEY_TAB or ke.keycode == KEY_H:
			_toggle_ui_visibility()
		elif ke.keycode == KEY_SPACE:
			if is_player_active and test_player != null and is_instance_valid(test_player):
				test_player.global_position = current_result.spawn_position + Vector3(0.0, 0.3, 0.0)
				test_player.velocity = Vector3.ZERO
				camera_rig.teleport_to_target()
			else:
				_focus_spawn()
		elif ke.keycode == KEY_ENTER:
			_frame_entire_world()

# ==============================================================================
# 2. Generación Procedural y Actualización de Vistas
# ==============================================================================
func generate_world(reset_camera: bool = false) -> void:
	var start_usec := Time.get_ticks_usec()

	if current_world_node != null and is_instance_valid(current_world_node):
		current_world_node.queue_free()
		current_world_node = null

	_read_ui_to_profile()

	current_result = _WorldPipelineScript.generate(world_seed, profile)

	var renderer := _WorldRendererScript.new()
	current_world_node = renderer.render_world(current_result, profile)
	world_container.add_child(current_world_node)
	renderer.queue_free()

	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0

	if current_result != null:
		if is_player_active:
			_spawn_test_player()
		else:
			if test_player != null and is_instance_valid(test_player):
				test_player.queue_free()
				test_player = null

		if reset_camera:
			if is_player_active and test_player != null:
				camera_rig.set_target(test_player)
				camera_rig.set_zoom(18.0)
				camera_rig.teleport_to_target()
			else:
				if focus_target.is_inside_tree():
					focus_target.global_position = current_result.spawn_position
				else:
					focus_target.position = current_result.spawn_position
				camera_rig.set_target(focus_target)
				camera_rig.teleport_to_target()
				camera_rig.set_zoom(48.0)

		_update_telemetry(current_result, duration_ms)
		_update_noise_textures()
		_update_gradient_preview()
		if active_tab == RightTab.HYDROLOGY or panel_hydrology != null:
			_update_hydrology_debug_view()

func _spawn_test_player() -> void:
	if test_player != null and is_instance_valid(test_player):
		if test_player.get_parent() != null:
			test_player.get_parent().remove_child(test_player)
		test_player.queue_free()
		test_player = null

	if current_result == null or world_container == null:
		return

	test_player = _PlayerTestScript.new()
	test_player.name = "PlayerTestInstance"
	test_player.position = current_result.spawn_position + Vector3(0.0, 0.4, 0.0)
	world_container.add_child(test_player)

	if is_player_active and camera_rig != null:
		camera_rig.set_target(test_player)
		camera_rig.set_follow_enabled(true)
		camera_rig.set_zoom(18.0)
		camera_rig.teleport_to_target()

func _toggle_player() -> void:
	is_player_active = not is_player_active
	_update_player_button_style()

	if is_player_active:
		if test_player == null or not is_instance_valid(test_player):
			_spawn_test_player()
		else:
			test_player.visible = true
			test_player.set_physics_process(true)
			if camera_rig != null:
				camera_rig.set_target(test_player)
				camera_rig.set_follow_enabled(true)
				camera_rig.set_zoom(18.0)
				camera_rig.teleport_to_target()
	else:
		if test_player != null and is_instance_valid(test_player):
			test_player.visible = false
			test_player.set_physics_process(false)
			if focus_target != null:
				if is_inside_tree() and test_player.is_inside_tree():
					focus_target.global_position = test_player.global_position
				else:
					focus_target.position = test_player.position
		if camera_rig != null and focus_target != null:
			camera_rig.set_target(focus_target)
			camera_rig.set_follow_enabled(true)

func _update_telemetry(result: WorldResult, duration_ms: float) -> void:
	if result == null or stat_time_lbl == null:
		return

	var min_h := INF
	var max_h := -INF
	var total_cells := float(result.cells.size())

	var water_count := 0
	var sand_count := 0
	var grass_count := 0
	var forest_count := 0
	var rock_count := 0

	for cell: WorldCell in result.cells.values():
		if cell.height < min_h: min_h = cell.height
		if cell.height > max_h: max_h = cell.height

		var nh := cell.normalized_height
		if nh < 0.35: water_count += 1
		elif nh < 0.41: sand_count += 1
		elif nh < 0.67: grass_count += 1
		elif nh < 0.77: forest_count += 1
		else: rock_count += 1

	var conifers := 0
	var shrubs := 0
	var rocks := 0
	for item: WorldVegetationItem in result.vegetation:
		match item.type:
			WorldVegetationItem.Type.CONIFER: conifers += 1
			WorldVegetationItem.Type.SHRUB: shrubs += 1
			WorldVegetationItem.Type.ROCK: rocks += 1

	var val_report := WorldValidator.validate(result)
	var walkable_pct: float = val_report.get("walkable_ratio", 0.0) * 100.0

	stat_time_lbl.text = "%.1f ms" % duration_ms
	stat_walkable_lbl.text = "%.1f%%" % walkable_pct
	stat_height_lbl.text = "%.1fm – %.1fm" % [min_h, max_h]
	stat_range_lbl.text = "%.1fm" % (max_h - min_h)

	# Update Zone Bars
	_set_zone_bar("Agua", (water_count / total_cells) * 100.0)
	_set_zone_bar("Arena", (sand_count / total_cells) * 100.0)
	_set_zone_bar("Pasto", (grass_count / total_cells) * 100.0)
	_set_zone_bar("Bosque", (forest_count / total_cells) * 100.0)
	_set_zone_bar("Roca", (rock_count / total_cells) * 100.0)

	# Update Entities Grid
	if ent_trees_lbl != null: ent_trees_lbl.text = "%d" % conifers
	if ent_shrubs_lbl != null: ent_shrubs_lbl.text = "%d" % shrubs
	if ent_rocks_lbl != null: ent_rocks_lbl.text = "%d" % rocks
	if ent_total_lbl != null: ent_total_lbl.text = "%d" % result.vegetation.size()

func _set_zone_bar(zone_key: String, pct: float) -> void:
	if zone_bar_pcts.has(zone_key):
		zone_bar_pcts[zone_key].text = "%.1f%%" % pct
	if zone_bar_fills.has(zone_key):
		var fill: ProgressBar = zone_bar_fills[zone_key]
		fill.value = pct

func _update_noise_textures() -> void:
	if current_result == null or profile == null:
		return
	if tex_rect_height == null:
		return

	var w: int = current_result.dimensions.x
	var h: int = current_result.dimensions.y

	var terrain_seed: int = WorldSeedSystem.derive_seed(world_seed, WorldSeedSystem.DOMAIN_TERRAIN)

	var macro_noise := FastNoiseLite.new()
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.seed = terrain_seed
	macro_noise.frequency = profile.get_macro_frequency()

	var medium_noise := FastNoiseLite.new()
	medium_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	medium_noise.seed = terrain_seed + 101
	medium_noise.frequency = profile.get_medium_frequency()

	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.seed = terrain_seed + 202
	detail_noise.frequency = profile.get_detail_frequency()

	var warp_noise_x := FastNoiseLite.new()
	var warp_noise_y := FastNoiseLite.new()
	if profile.warp_enabled:
		warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_x.seed = terrain_seed + 303
		warp_noise_x.frequency = profile.get_warp_frequency()
		warp_noise_x.fractal_octaves = profile.warp_octaves

		warp_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_y.seed = terrain_seed + 404
		warp_noise_y.frequency = profile.get_warp_frequency()
		warp_noise_y.fractal_octaves = profile.warp_octaves

	var a_macro: float = profile.get_macro_amplitude()
	var a_med: float = profile.get_medium_amplitude()
	var a_det: float = profile.get_detail_amplitude()
	var total_amplitude: float = a_macro + a_med + a_det
	if total_amplitude <= 0.0:
		total_amplitude = 1.0

	if current_terrain_debug_mode == TerrainDebugMode.OVERVIEW_2X2:
		if terrain_overview_grid != null: terrain_overview_grid.visible = true
		if terrain_single_box != null: terrain_single_box.visible = false

		var img_height := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var img_warp := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var img_eco := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var img_composite := Image.create(w, h, false, Image.FORMAT_RGBA8)

		for y in range(h):
			for x in range(w):
				var cell := current_result.get_cell(Vector2i(x, y))
				if cell == null: continue

				# 1. Height map with subtle contours
				var nh := clampf(cell.normalized_height, 0.0, 1.0)
				var contour: float = 0.75 if sin(nh * PI * 14.0) > 0.85 else 1.0
				var val: float = nh * contour
				img_height.set_pixel(x, y, Color(val, val, val, 1.0))

				# 2. Domain Warp vector distortion in metric world space
				var warp_r := 0.5
				var warp_g := 0.5
				if profile.warp_enabled:
					var sx: float = float(x) * profile.cell_size
					var sy: float = float(y) * profile.cell_size
					warp_r = clampf((warp_noise_x.get_noise_2d(sx, sy) + 1.0) * 0.5, 0.0, 1.0)
					warp_g = clampf((warp_noise_y.get_noise_2d(sx, sy) + 1.0) * 0.5, 0.0, 1.0)
				img_warp.set_pixel(x, y, Color(warp_r, warp_g, 1.0 - warp_r * 0.5, 1.0))

				# 3. Ecology Mask
				var is_forest := cell.forest_density > profile.clearing_threshold
				var eco_col := Color("#22c55e") if is_forest else Color("#c8a96e")
				img_eco.set_pixel(x, y, eco_col)

				# 4. Composite Color
				var comp_col: Color = _TerrainColorResolverScript.resolve_vertex_color(cell, profile)
				img_composite.set_pixel(x, y, comp_col)

		tex_rect_height.texture = ImageTexture.create_from_image(img_height)
		tex_rect_warp.texture = ImageTexture.create_from_image(img_warp)
		tex_rect_eco.texture = ImageTexture.create_from_image(img_eco)
		tex_rect_composite.texture = ImageTexture.create_from_image(img_composite)
	else:
		if terrain_overview_grid != null: terrain_overview_grid.visible = false
		if terrain_single_box != null: terrain_single_box.visible = true

		var img_diag := Image.create(w, h, false, Image.FORMAT_RGBA8)

		for y in range(h):
			for x in range(w):
				var cell := current_result.get_cell(Vector2i(x, y))
				var sx: float = float(x) * profile.cell_size
				var sy: float = float(y) * profile.cell_size
				var col := Color.BLACK

				match current_terrain_debug_mode:
					TerrainDebugMode.MACRO:
						var n_m := clampf((macro_noise.get_noise_2d(sx, sy) + 1.0) * 0.5, 0.0, 1.0)
						col = Color(n_m, n_m, n_m, 1.0)
					TerrainDebugMode.MEDIUM:
						var n_md := clampf((medium_noise.get_noise_2d(sx, sy) + 1.0) * 0.5, 0.0, 1.0)
						col = Color(n_md, n_md, n_md, 1.0)
					TerrainDebugMode.DETAIL:
						var n_d := clampf((detail_noise.get_noise_2d(sx, sy) + 1.0) * 0.5, 0.0, 1.0)
						col = Color(n_d, n_d, n_d, 1.0)
					TerrainDebugMode.WARP:
						var wx := clampf((warp_noise_x.get_noise_2d(sx, sy) + 1.0) * 0.5, 0.0, 1.0) if profile.warp_enabled else 0.5
						var wy := clampf((warp_noise_y.get_noise_2d(sx, sy) + 1.0) * 0.5, 0.0, 1.0) if profile.warp_enabled else 0.5
						col = Color(wx, wy, 1.0 - wx * 0.5, 1.0)
					TerrainDebugMode.COMBINED:
						var n1 := macro_noise.get_noise_2d(sx, sy)
						var n2 := medium_noise.get_noise_2d(sx, sy)
						var n3 := detail_noise.get_noise_2d(sx, sy)
						var c_raw := (n1 * a_macro + n2 * a_med + n3 * a_det) / total_amplitude
						var c_norm := clampf((c_raw + 1.0) * 0.5, 0.0, 1.0)
						col = Color(c_norm, c_norm, c_norm, 1.0)
					TerrainDebugMode.ELEVATION:
						if cell != null:
							var h_val: float = cell.height
							var c_band: float = 0.75 if fmod(h_val, 2.0) < 0.25 else 1.0
							var norm_h := clampf((h_val - profile.base_height) / maxf(total_amplitude * profile.height_scale, 1.0), 0.0, 1.0) * c_band
							col = Color(norm_h * 0.85 + 0.1, norm_h * 0.75 + 0.15, norm_h * 0.65 + 0.15, 1.0)
					TerrainDebugMode.SLOPE:
						if cell != null:
							var sl: float = cell.slope
							if sl < 10.0:
								col = Color("#22c55e") # Flat <10°
							elif sl < 25.0:
								col = Color("#38bdf8") # Gentle <25°
							elif sl < 35.0:
								col = Color("#f59e0b") # Steep <35°
							else:
								col = Color("#ef4444") # Cliff >=35°
					TerrainDebugMode.NORMALIZED_HEIGHT:
						if cell != null:
							var nh_v: float = clampf(cell.normalized_height, 0.0, 1.0)
							col = Color(nh_v, nh_v, nh_v, 1.0)

				img_diag.set_pixel(x, y, col)

		terrain_debug_rect.texture = ImageTexture.create_from_image(img_diag)

		if terrain_debug_legend != null:
			match current_terrain_debug_mode:
				TerrainDebugMode.MACRO:
					terrain_debug_legend.text = "Capa Macro pura (λ = %.1fm, A = %.1fm). Define valles amplios y cordilleras." % [profile.macro_wavelength, profile.macro_amplitude]
				TerrainDebugMode.MEDIUM:
					terrain_debug_legend.text = "Capa Media pura (λ = %.1fm, A = %.1fm). Modela colinas secundarias y terrazas." % [profile.medium_wavelength, profile.medium_amplitude]
				TerrainDebugMode.DETAIL:
					terrain_debug_legend.text = "Capa Detalle pura (λ = %.1fm, A = %.1fm). Rugosidad del terreno sin picos artificiales." % [profile.detail_wavelength, profile.detail_amplitude]
				TerrainDebugMode.WARP:
					terrain_debug_legend.text = "Distorsión Domain Warp (λ = %.1fm, A = %.1fm). Deformación natural de fallas geológicas." % [profile.warp_wavelength, profile.warp_amplitude]
				TerrainDebugMode.COMBINED:
					terrain_debug_legend.text = "Suma compuesta ponderada Macro + Medio + Detalle antes de moldeado no lineal."
				TerrainDebugMode.ELEVATION:
					terrain_debug_legend.text = "Elevación física en metros con isolíneas cada 2.0 metros de desnivel."
				TerrainDebugMode.SLOPE:
					terrain_debug_legend.text = "Zonas de Pendiente: Plano <10° (verde), Suave <25° (azul), Escarpado <35° (naranja), Risco >=35° (rojo)."
				TerrainDebugMode.NORMALIZED_HEIGHT:
					terrain_debug_legend.text = "Altura normalizada [0.0 - 1.0] sobre la envolvente topográfica."

func _update_gradient_preview() -> void:
	if gradient_preview_rect == null or profile == null:
		return

	var img := Image.create(128, 16, false, Image.FORMAT_RGBA8)
	for x in range(128):
		var nh: float = float(x) / 127.0
		var col: Color
		if nh < 0.27:
			col = profile.color_deep_water.lerp(profile.color_water, nh / 0.27)
		elif nh < 0.35:
			col = profile.color_water.lerp(profile.color_sand, (nh - 0.27) / 0.08)
		elif nh < 0.41:
			col = profile.color_sand.lerp(profile.color_ground, (nh - 0.35) / 0.06)
		elif nh < 0.50:
			col = profile.color_ground.lerp(profile.color_grass, (nh - 0.41) / 0.09)
		elif nh < 0.67:
			col = profile.color_grass.lerp(profile.color_forest, (nh - 0.50) / 0.17)
		elif nh < 0.77:
			col = profile.color_forest.lerp(profile.color_rock, (nh - 0.67) / 0.10)
		elif nh < 0.88:
			col = profile.color_rock.lerp(profile.color_snow, (nh - 0.77) / 0.11)
		else:
			col = profile.color_snow

		for y in range(16):
			img.set_pixel(x, y, col)

	gradient_preview_rect.texture = ImageTexture.create_from_image(img)

# ==============================================================================
# 3. Construcción y Arquitectura de la Interfaz
# ==============================================================================
func _setup_ui() -> void:
	if canvas_layer != null:
		return

	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "LabCanvas"
	add_child(canvas_layer)

	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui_root.grow_vertical = Control.GROW_DIRECTION_BOTH

	_build_top_bar()
	_build_left_panel()
	_build_right_panel()
	_build_bottom_bar()

	_set_active_tab(RightTab.TELEMETRY)

func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_bottom = 44
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_bar.grow_vertical = Control.GROW_DIRECTION_END
	top_bar.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#070b14"), Color("#1f293d"), 0, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	top_bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# Logo
	var logo_box := HBoxContainer.new()
	logo_box.add_theme_constant_override("separation", 6)
	var hex_lbl := Label.new()
	hex_lbl.text = "⬡"
	hex_lbl.add_theme_color_override("font_color", Color("#22c55e"))
	logo_box.add_child(hex_lbl)

	var brand_lbl := Label.new()
	brand_lbl.text = "TAIGA WORLD LAB"
	brand_lbl.add_theme_color_override("font_color", Color("#c8d4e8"))
	brand_lbl.add_theme_font_size_override("font_size", 12)
	logo_box.add_child(brand_lbl)

	var sep_lbl := Label.new()
	sep_lbl.text = "//"
	sep_lbl.add_theme_color_override("font_color", Color("#334155"))
	logo_box.add_child(sep_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "PROCEDURAL EXPLORER"
	sub_lbl.add_theme_color_override("font_color", Color("#4a6a8a"))
	sub_lbl.add_theme_font_size_override("font_size", 11)
	logo_box.add_child(sub_lbl)
	hbox.add_child(logo_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Seed
	var seed_box := HBoxContainer.new()
	seed_box.add_theme_constant_override("separation", 6)
	var seed_tag := Label.new()
	seed_tag.text = "Seed:"
	seed_tag.add_theme_color_override("font_color", Color("#64748b"))
	seed_tag.add_theme_font_size_override("font_size", 11)
	seed_box.add_child(seed_tag)

	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 99999999
	seed_spin.value = world_seed
	seed_spin.value_changed.connect(func(v):
		world_seed = int(v)
		if is_auto_gen: generate_world(false)
	)
	seed_box.add_child(seed_spin)

	var rand_btn := Button.new()
	rand_btn.text = "⟳ Aleatorio"
	rand_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color("#0e1726"), Color("#1f293d"), 4, 1))
	rand_btn.add_theme_color_override("font_color", Color("#94a3b8"))
	rand_btn.add_theme_font_size_override("font_size", 11)
	rand_btn.pressed.connect(func():
		world_seed = randi() % 999999 + 1
		seed_spin.value = world_seed
		generate_world(false)
	)
	seed_box.add_child(rand_btn)
	hbox.add_child(seed_box)

	# Preset
	var preset_box := HBoxContainer.new()
	preset_box.add_theme_constant_override("separation", 6)
	var pre_tag := Label.new()
	pre_tag.text = "Preset:"
	pre_tag.add_theme_color_override("font_color", Color("#64748b"))
	pre_tag.add_theme_font_size_override("font_size", 11)
	preset_box.add_child(pre_tag)

	preset_option = OptionButton.new()
	for p_id in PRESETS.keys():
		preset_option.add_item(PRESETS[p_id]["name"], p_id)
	preset_option.select(0)
	preset_option.item_selected.connect(_on_preset_selected)
	preset_box.add_child(preset_option)
	hbox.add_child(preset_box)

	# Auto-Gen Button
	auto_gen_btn = Button.new()
	auto_gen_btn.text = "◉ Auto-Gen" if is_auto_gen else "○ Auto-Gen"
	auto_gen_btn.add_theme_font_size_override("font_size", 11)
	_update_auto_gen_button_style()
	auto_gen_btn.pressed.connect(func():
		is_auto_gen = not is_auto_gen
		auto_gen_btn.text = "◉ Auto-Gen" if is_auto_gen else "○ Auto-Gen"
		_update_auto_gen_button_style()
	)
	hbox.add_child(auto_gen_btn)

	# Fullscreen Button
	var btn_fs := Button.new()
	btn_fs.text = "⛶ Pantalla Completa"
	btn_fs.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color("#0e1726"), Color("#1f293d"), 4, 1))
	btn_fs.add_theme_color_override("font_color", Color("#94a3b8"))
	btn_fs.add_theme_font_size_override("font_size", 11)
	btn_fs.pressed.connect(_toggle_fullscreen)
	hbox.add_child(btn_fs)

	# Player Testing Toggle Button (Scale comparison & ground navigation)
	player_toggle_btn = Button.new()
	player_toggle_btn.text = "👤 Jugador: ACTIVO" if is_player_active else "👤 Jugador: OFF"
	player_toggle_btn.add_theme_font_size_override("font_size", 11)
	_update_player_button_style()
	player_toggle_btn.pressed.connect(_toggle_player)
	hbox.add_child(player_toggle_btn)

	# Generate Button
	gen_btn = Button.new()
	gen_btn.text = "⚡ GENERAR MUNDO"
	gen_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color(0.13, 0.77, 0.36, 0.15), Color("#22c55e"), 4, 1))
	gen_btn.add_theme_color_override("font_color", Color("#22c55e"))
	gen_btn.add_theme_font_size_override("font_size", 11)
	gen_btn.pressed.connect(func(): generate_world(false))
	hbox.add_child(gen_btn)

	ui_root.add_child(top_bar)

func _update_player_button_style() -> void:
	if player_toggle_btn == null:
		return
	if is_player_active:
		player_toggle_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color(0.1, 0.75, 0.95, 0.18), Color(0.1, 0.75, 0.95, 0.8), 4, 1))
		player_toggle_btn.add_theme_color_override("font_color", Color("#38bdf8"))
		player_toggle_btn.text = "👤 Jugador: ACTIVO"
	else:
		player_toggle_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color("#0e1726"), Color("#1f293d"), 4, 1))
		player_toggle_btn.add_theme_color_override("font_color", Color("#64748b"))
		player_toggle_btn.text = "👤 Jugador: OFF"

func _update_auto_gen_button_style() -> void:
	if is_auto_gen:
		auto_gen_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color(0.13, 0.77, 0.36, 0.12), Color(0.13, 0.77, 0.36, 0.4), 4, 1))
		auto_gen_btn.add_theme_color_override("font_color", Color("#22c55e"))
	else:
		auto_gen_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color("#0e1726"), Color("#1f293d"), 4, 1))
		auto_gen_btn.add_theme_color_override("font_color", Color("#64748b"))

func _build_left_panel() -> void:
	left_panel = PanelContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.anchor_left = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_top = 44
	left_panel.offset_bottom = -28
	left_panel.offset_right = 260
	left_panel.grow_horizontal = Control.GROW_DIRECTION_END
	left_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	left_panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#0b1120"), Color("#1a263d"), 0, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	left_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# 1. TERRENO Y RELIEVE (Metros)
	_add_left_section(vbox, "TERRENO Y RELIEVE", "⬡", Color("#f59e0b"))
	_add_slider(vbox, "macro_wavelength", "Long. Onda Macro (m)", profile.macro_wavelength, 20.0, 400.0, 5.0, Color("#f59e0b"))
	_add_slider(vbox, "macro_amplitude", "Amplitud Macro (m)", profile.macro_amplitude, 0.0, 25.0, 0.5, Color("#f59e0b"))
	_add_slider(vbox, "medium_wavelength", "Long. Onda Media (m)", profile.medium_wavelength, 10.0, 150.0, 2.0, Color("#f59e0b"))
	_add_slider(vbox, "medium_amplitude", "Amplitud Media (m)", profile.medium_amplitude, 0.0, 10.0, 0.2, Color("#f59e0b"))
	_add_slider(vbox, "detail_wavelength", "Long. Onda Detalle (m)", profile.detail_wavelength, 2.0, 30.0, 0.5, Color("#f59e0b"))
	_add_slider(vbox, "detail_amplitude", "Amplitud Detalle (m)", profile.detail_amplitude, 0.0, 2.0, 0.05, Color("#f59e0b"))
	_add_slider(vbox, "base_height", "Altura Base (m)", profile.base_height, 0.0, 5.0, 0.05, Color("#f59e0b"))
	_add_slider(vbox, "height_scale", "Multiplicador Vertical", profile.height_scale, 0.1, 3.0, 0.05, Color("#f59e0b"))
	_add_slider(vbox, "relief_exponent", "Moldeado (Exp)", profile.relief_exponent, 0.1, 5.0, 0.05, Color("#f59e0b"))

	# 2. DOMAIN WARP (Metros)
	_add_left_section(vbox, "DOMAIN WARP", "◈", Color("#a855f7"))
	_add_slider(vbox, "warp_wavelength", "Long. Onda Warp (m)", profile.warp_wavelength, 20.0, 250.0, 5.0, Color("#a855f7"))
	_add_slider(vbox, "warp_amplitude", "Amplitud Warp (m)", profile.warp_amplitude, 0.0, 40.0, 0.5, Color("#a855f7"))
	_add_slider(vbox, "warp_octaves", "Octavas Warp", float(profile.warp_octaves), 1.0, 4.0, 1.0, Color("#a855f7"))

	# 3. ECOLOGÍA & CLAROS
	_add_left_section(vbox, "ECOLOGÍA & CLAROS", "☵", Color("#22c55e"))
	_add_slider(vbox, "forest_wavelength", "Long. Onda Bosque (m)", profile.forest_wavelength, 20.0, 200.0, 5.0, Color("#22c55e"))
	_add_slider(vbox, "clearing_wavelength", "Long. Onda Claros (m)", profile.clearing_wavelength, 10.0, 100.0, 2.0, Color("#22c55e"))
	_add_slider(vbox, "clearing_threshold", "Umbral de Claros", profile.clearing_threshold, 0.1, 0.95, 0.01, Color("#22c55e"))

	# 4. VEGETACIÓN
	_add_left_section(vbox, "VEGETACIÓN", "⚃", Color("#14b8a6"))
	_add_slider(vbox, "tree_density", "Densidad Árboles", profile.tree_density, 0.0, 1.0, 0.01, Color("#14b8a6"))
	_add_slider(vbox, "min_tree_spacing", "Espaciado Mínimo", profile.min_tree_spacing, 0.5, 8.0, 0.1, Color("#14b8a6"))
	_add_slider(vbox, "shrub_density", "Densidad Arbustos", profile.shrub_density, 0.0, 1.0, 0.01, Color("#14b8a6"))
	_add_slider(vbox, "rock_density", "Densidad Rocas", profile.rock_density, 0.0, 1.0, 0.01, Color("#14b8a6"))

	# 5. ESCALA DEL MUNDO (1 Godot unit = 1 metro)
	_add_left_section(vbox, "ESCALA DEL MUNDO", "⛶", Color("#38bdf8"))
	_add_slider(vbox, "cell_size", "Escala del Mundo (m/celda)", profile.cell_size, 0.5, 3.0, 0.1, Color("#38bdf8"))

	# 6. HIDROLOGÍA & CUENCAS
	_add_left_section(vbox, "HIDROLOGÍA & CUENCAS", "💧", Color("#38bdf8"))
	_add_slider(vbox, "lake_threshold", "Umbral Lagos", profile.lake_threshold, 0.05, 0.50, 0.01, Color("#38bdf8"))
	_add_slider(vbox, "lake_minimum_area", "Área Mín. Lagos", float(profile.lake_minimum_area), 1.0, 20.0, 1.0, Color("#38bdf8"))
	_add_slider(vbox, "max_rivers", "Cant. Ríos", float(profile.max_rivers), 0.0, 8.0, 1.0, Color("#38bdf8"))
	_add_slider(vbox, "river_source_min_height", "Altura Cabecera", profile.river_source_min_height, 0.3, 0.95, 0.05, Color("#38bdf8"))
	_add_slider(vbox, "river_meander_strength", "Meandros / Jitter", profile.river_meander_strength, 0.0, 0.5, 0.02, Color("#38bdf8"))
	_add_slider(vbox, "hydrology_noise_wavelength", "Long. Onda Ruido Cauce (m)", profile.hydrology_noise_wavelength, 20.0, 200.0, 5.0, Color("#38bdf8"))
	_add_slider(vbox, "hydrology_noise_strength", "Fuerza Ruido Cauce", profile.hydrology_noise_strength, 0.0, 0.8, 0.05, Color("#38bdf8"))

	ui_root.add_child(left_panel)

func _add_left_section(parent: Control, title: String, icon: String, col: Color) -> void:
	var sec_box := HBoxContainer.new()
	sec_box.add_theme_constant_override("separation", 6)
	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_color_override("font_color", col)
	icon_lbl.add_theme_font_size_override("font_size", 12)
	sec_box.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", col)
	title_lbl.add_theme_font_size_override("font_size", 10)
	sec_box.add_child(title_lbl)
	parent.add_child(sec_box)

func _add_slider(parent: Control, prop_name: String, label_text: String, default_val: float, min_val: float, max_val: float, step: float, accent_col: Color) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var header_box := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_color_override("font_color", Color("#7a8ba8"))
	name_lbl.add_theme_font_size_override("font_size", 10)
	header_box.add_child(name_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = "%.3f" % default_val if step < 0.01 else ("%.2f" % default_val if step < 1.0 else "%d" % int(default_val))
	val_lbl.add_theme_color_override("font_color", accent_col)
	val_lbl.add_theme_font_size_override("font_size", 10)
	header_box.add_child(val_lbl)
	box.add_child(header_box)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(new_val: float):
		val_lbl.text = "%.3f" % new_val if step < 0.01 else ("%.2f" % new_val if step < 1.0 else "%d" % int(new_val))
		profile.set(prop_name, new_val)
		if prop_name == "macro_wavelength":
			profile.macro_frequency = 1.0 / maxf(new_val, 1.0)
		elif prop_name == "macro_amplitude":
			profile.macro_strength = new_val
		elif prop_name == "medium_wavelength":
			profile.medium_frequency = 1.0 / maxf(new_val, 1.0)
		elif prop_name == "medium_amplitude":
			profile.medium_strength = new_val
		elif prop_name == "detail_wavelength":
			profile.detail_frequency = 1.0 / maxf(new_val, 1.0)
		elif prop_name == "detail_amplitude":
			profile.detail_strength = new_val
		elif prop_name == "warp_wavelength":
			profile.warp_frequency = 1.0 / maxf(new_val, 1.0)
		elif prop_name == "warp_amplitude":
			profile.warp_strength = new_val
		elif prop_name == "forest_wavelength":
			profile.forest_frequency = 1.0 / maxf(new_val, 1.0)
		elif prop_name == "moisture_wavelength":
			profile.moisture_frequency = 1.0 / maxf(new_val, 1.0)
		elif prop_name == "hydrology_noise_wavelength":
			profile.hydrology_noise_frequency = 1.0 / maxf(new_val, 1.0)

		if is_auto_gen:
			generate_world(false)
	)
	box.add_child(slider)
	parent.add_child(box)

	_sliders[prop_name] = { "slider": slider, "label": val_lbl, "step": step }

func _build_right_panel() -> void:
	right_panel = PanelContainer.new()
	right_panel.name = "RightPanel"
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_top = 44
	right_panel.offset_bottom = -28
	right_panel.offset_left = -310
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	right_panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#0b1120"), Color("#1a263d"), 0, 1))

	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 0)
	right_panel.add_child(main_box)

	# 1. Tab Bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 0)

	tab_btn_telemetry = _create_tab_button("◉", "TELEMETRÍA", Color("#f59e0b"))
	tab_btn_telemetry.pressed.connect(func(): _set_active_tab(RightTab.TELEMETRY))
	tab_bar.add_child(tab_btn_telemetry)

	tab_btn_noise = _create_tab_button("▧", "NOISE", Color("#a855f7"))
	tab_btn_noise.pressed.connect(func(): _set_active_tab(RightTab.NOISE))
	tab_bar.add_child(tab_btn_noise)

	tab_btn_colors = _create_tab_button("●", "COLORES", Color("#14b8a6"))
	tab_btn_colors.pressed.connect(func(): _set_active_tab(RightTab.COLORS))
	tab_bar.add_child(tab_btn_colors)

	tab_btn_hydrology = _create_tab_button("💧", "HIDRO", Color("#38bdf8"))
	tab_btn_hydrology.pressed.connect(func(): _set_active_tab(RightTab.HYDROLOGY))
	tab_bar.add_child(tab_btn_hydrology)

	main_box.add_child(tab_bar)

	# 2. Tab Title Header
	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#070b14"), Color("#151f33"), 0, 1))
	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 12)
	title_margin.add_theme_constant_override("margin_right", 12)
	title_margin.add_theme_constant_override("margin_top", 6)
	title_margin.add_theme_constant_override("margin_bottom", 6)
	title_panel.add_child(title_margin)

	var title_box := HBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	tab_title_icon = Label.new()
	tab_title_icon.text = "◉"
	tab_title_icon.add_theme_font_size_override("font_size", 12)
	title_box.add_child(tab_title_icon)

	tab_title_lbl = Label.new()
	tab_title_lbl.text = "TELEMETRÍA EN TIEMPO REAL"
	tab_title_lbl.add_theme_font_size_override("font_size", 10)
	title_box.add_child(tab_title_lbl)
	title_margin.add_child(title_box)
	main_box.add_child(title_panel)

	# 3. Tab Subpanels Container (Scrollable)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_box.add_child(scroll)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_margin)

	var tabs_holder := VBoxContainer.new()
	tabs_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(tabs_holder)

	_build_telemetry_tab(tabs_holder)
	_build_noise_tab(tabs_holder)
	_build_colors_tab(tabs_holder)
	_build_hydrology_tab(tabs_holder)

	ui_root.add_child(right_panel)

func _create_tab_button(icon: String, text: String, _accent: Color) -> Button:
	var btn := Button.new()
	btn.text = "%s %s" % [icon, text]
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color("#090e1c"), Color("#1a263d"), 0, 1))
	btn.add_theme_color_override("font_color", Color("#4a5d78"))
	return btn

func _set_active_tab(tab: RightTab) -> void:
	active_tab = tab

	panel_telemetry.visible = (tab == RightTab.TELEMETRY)
	panel_noise.visible = (tab == RightTab.NOISE)
	panel_colors.visible = (tab == RightTab.COLORS)
	if panel_hydrology != null:
		panel_hydrology.visible = (tab == RightTab.HYDROLOGY)

	var active_col: Color = Color("#f59e0b")
	var active_title := "TELEMETRÍA EN TIEMPO REAL"
	var active_icon := "◉"

	if tab == RightTab.NOISE:
		active_col = Color("#a855f7")
		active_title = "CAPAS DE RUIDO 2D"
		active_icon = "▧"
	elif tab == RightTab.COLORS:
		active_col = Color("#14b8a6")
		active_title = "PALETA DE TERRENO"
		active_icon = "●"
	elif tab == RightTab.HYDROLOGY:
		active_col = Color("#38bdf8")
		active_title = "HIDROLOGÍA & CUENCAS"
		active_icon = "💧"

	tab_title_icon.text = active_icon
	tab_title_icon.add_theme_color_override("font_color", active_col)
	tab_title_lbl.text = active_title
	tab_title_lbl.add_theme_color_override("font_color", active_col)

	# Update button visual state
	tab_btn_telemetry.add_theme_color_override("font_color", Color("#f59e0b") if tab == RightTab.TELEMETRY else Color("#4a5d78"))
	tab_btn_noise.add_theme_color_override("font_color", Color("#a855f7") if tab == RightTab.NOISE else Color("#4a5d78"))
	tab_btn_colors.add_theme_color_override("font_color", Color("#14b8a6") if tab == RightTab.COLORS else Color("#4a5d78"))
	if tab_btn_hydrology != null:
		tab_btn_hydrology.add_theme_color_override("font_color", Color("#38bdf8") if tab == RightTab.HYDROLOGY else Color("#4a5d78"))

	if tab == RightTab.NOISE:
		_update_noise_textures()
	elif tab == RightTab.COLORS:
		_update_gradient_preview()
	elif tab == RightTab.HYDROLOGY:
		_update_hydrology_debug_view()

# --- Tab 1: Telemetría ---
func _build_telemetry_tab(parent: Control) -> void:
	panel_telemetry = VBoxContainer.new()
	panel_telemetry.add_theme_constant_override("separation", 14)
	panel_telemetry.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Section: Generación
	var gen_box := VBoxContainer.new()
	gen_box.add_theme_constant_override("separation", 6)
	_add_sub_header(gen_box, "● GENERACIÓN", Color("#f59e0b"))
	stat_time_lbl = _add_stat_row(gen_box, "Tiempo de generación", "-- ms", Color("#22c55e"))
	stat_walkable_lbl = _add_stat_row(gen_box, "Caminabilidad", "--%", Color("#22c55e"))
	stat_height_lbl = _add_stat_row(gen_box, "Altura min → max", "--", Color("#c8d4e8"))
	stat_range_lbl = _add_stat_row(gen_box, "Rango Δ", "--", Color("#c8d4e8"))
	panel_telemetry.add_child(gen_box)

	# Section: Distribución de Zonas
	var zones_box := VBoxContainer.new()
	zones_box.add_theme_constant_override("separation", 6)
	_add_sub_header(zones_box, "◈ DISTRIBUCIÓN DE ZONAS", Color("#a855f7"))
	_create_zone_bar_row(zones_box, "Agua", Color("#2456a4"))
	_create_zone_bar_row(zones_box, "Arena", Color("#c8a96e"))
	_create_zone_bar_row(zones_box, "Pasto", Color("#4a8c3f"))
	_create_zone_bar_row(zones_box, "Bosque", Color("#2d5a27"))
	_create_zone_bar_row(zones_box, "Roca", Color("#5a5a5a"))
	panel_telemetry.add_child(zones_box)

	# Section: Entidades
	var ent_box := VBoxContainer.new()
	ent_box.add_theme_constant_override("separation", 6)
	_add_sub_header(ent_box, "⚃ ENTIDADES", Color("#14b8a6"))
	var ent_grid := GridContainer.new()
	ent_grid.columns = 2
	ent_grid.add_theme_constant_override("h_separation", 6)
	ent_grid.add_theme_constant_override("v_separation", 6)

	ent_trees_lbl = _create_entity_card(ent_grid, "🌲 Árboles", Color("#22c55e"))
	ent_shrubs_lbl = _create_entity_card(ent_grid, "🌿 Arbustos", Color("#14b8a6"))
	ent_rocks_lbl = _create_entity_card(ent_grid, "🪨 Rocas", Color("#94a3b8"))
	ent_total_lbl = _create_entity_card(ent_grid, "∑ Total", Color("#f59e0b"))
	ent_box.add_child(ent_grid)
	panel_telemetry.add_child(ent_box)

	# Section: Acciones de Cámara
	var cam_box := VBoxContainer.new()
	cam_box.add_theme_constant_override("separation", 6)
	_add_sub_header(cam_box, "◎ CÁMARA", Color("#3b82f6"))
	_create_cam_action_row(cam_box, "Enfocar Spawn", "Space", _focus_spawn)
	_create_cam_action_row(cam_box, "Encuadrar Mundo", "Enter", _frame_entire_world)
	_create_cam_action_row(cam_box, "Alternar Perspectiva", "Tab", _toggle_projection)
	panel_telemetry.add_child(cam_box)

	parent.add_child(panel_telemetry)

func _add_sub_header(parent: Control, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 9)
	parent.add_child(lbl)

func _add_stat_row(parent: Control, label_text: String, default_val: String, val_col: Color) -> Label:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.add_theme_color_override("font_color", Color("#64748b"))
	l.add_theme_font_size_override("font_size", 10)
	row.add_child(l)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)

	var v := Label.new()
	v.text = default_val
	v.add_theme_color_override("font_color", val_col)
	v.add_theme_font_size_override("font_size", 10)
	row.add_child(v)
	parent.add_child(row)
	return v

func _create_zone_bar_row(parent: Control, label_text: String, bar_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(50, 0)
	l.add_theme_color_override("font_color", Color("#64748b"))
	l.add_theme_font_size_override("font_size", 9)
	row.add_child(l)

	var pb := ProgressBar.new()
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.custom_minimum_size = Vector2(0, 6)
	pb.show_percentage = false
	pb.min_value = 0.0
	pb.max_value = 100.0
	pb.value = 0.0

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.set_corner_radius_all(3)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	bg_style.set_corner_radius_all(3)

	pb.add_theme_stylebox_override("fill", fill_style)
	pb.add_theme_stylebox_override("background", bg_style)
	row.add_child(pb)

	var pct_lbl := Label.new()
	pct_lbl.text = "0.0%"
	pct_lbl.custom_minimum_size = Vector2(38, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct_lbl.add_theme_color_override("font_color", Color("#64748b"))
	pct_lbl.add_theme_font_size_override("font_size", 9)
	row.add_child(pct_lbl)

	parent.add_child(row)
	zone_bar_pcts[label_text] = pct_lbl
	zone_bar_fills[label_text] = pb

func _create_entity_card(parent: Control, label_text: String, num_color: Color) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color(1.0, 1.0, 1.0, 0.03), Color(1.0, 1.0, 1.0, 0.08), 4, 1))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", 4)
	card.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var tag := Label.new()
	tag.text = label_text
	tag.add_theme_color_override("font_color", Color("#64748b"))
	tag.add_theme_font_size_override("font_size", 9)
	vb.add_child(tag)

	var num := Label.new()
	num.text = "0"
	num.add_theme_color_override("font_color", num_color)
	num.add_theme_font_size_override("font_size", 14)
	vb.add_child(num)
	m.add_child(vb)
	parent.add_child(card)
	return num

func _create_cam_action_row(parent: Control, action_name: String, key_tag: String, on_press: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = action_name
	l.add_theme_color_override("font_color", Color("#94a3b8"))
	l.add_theme_font_size_override("font_size", 10)
	row.add_child(l)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)

	var btn := Button.new()
	btn.text = key_tag
	btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color(1.0, 1.0, 1.0, 0.06), Color(1.0, 1.0, 1.0, 0.12), 4, 1))
	btn.add_theme_color_override("font_color", Color("#94a3b8"))
	btn.add_theme_font_size_override("font_size", 9)
	btn.pressed.connect(on_press)
	row.add_child(btn)
	parent.add_child(row)

# --- Tab 2: Noise ---
func _build_noise_tab(parent: Control) -> void:
	panel_noise = VBoxContainer.new()
	panel_noise.add_theme_constant_override("separation", 12)
	panel_noise.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var desc_lbl := Label.new()
	desc_lbl.text = "Capas de ruido 2D calculadas en tiempo real para la elevación, distorsión y ecología."
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color("#64748b"))
	desc_lbl.add_theme_font_size_override("font_size", 9)
	panel_noise.add_child(desc_lbl)

	# 1. Mode Selector (Phase 16 Terrain Debug Visualizer)
	var mode_box := VBoxContainer.new()
	mode_box.add_theme_constant_override("separation", 4)
	_add_sub_header(mode_box, "CAPA DE DEPURACIÓN DE TERRENO", Color("#a855f7"))

	terrain_debug_option = OptionButton.new()
	terrain_debug_option.add_item("[Cuadrícula 2x2] Vista General", TerrainDebugMode.OVERVIEW_2X2)
	terrain_debug_option.add_item("[Macro] Longitud de Onda 140m", TerrainDebugMode.MACRO)
	terrain_debug_option.add_item("[Medio] Colinas y Terrazas 45m", TerrainDebugMode.MEDIUM)
	terrain_debug_option.add_item("[Detalle] Micro-rugosidad 10m", TerrainDebugMode.DETAIL)
	terrain_debug_option.add_item("[Domain Warp] Distorsión Vectorial", TerrainDebugMode.WARP)
	terrain_debug_option.add_item("[Combinado] Suma Ponderada", TerrainDebugMode.COMBINED)
	terrain_debug_option.add_item("[Elevación Real] Cotas Métricas (m)", TerrainDebugMode.ELEVATION)
	terrain_debug_option.add_item("[Pendiente] Zonas de Transitabilidad", TerrainDebugMode.SLOPE)
	terrain_debug_option.add_item("[Altura Normalizada] Altimetría [0-1]", TerrainDebugMode.NORMALIZED_HEIGHT)
	terrain_debug_option.select(TerrainDebugMode.OVERVIEW_2X2)
	terrain_debug_option.item_selected.connect(func(idx: int):
		current_terrain_debug_mode = idx as TerrainDebugMode
		_update_noise_textures()
	)
	mode_box.add_child(terrain_debug_option)
	panel_noise.add_child(mode_box)

	# 2. 2x2 Texture Grid (Visible when in OVERVIEW_2X2)
	terrain_overview_grid = GridContainer.new()
	terrain_overview_grid.columns = 2
	terrain_overview_grid.add_theme_constant_override("h_separation", 10)
	terrain_overview_grid.add_theme_constant_override("v_separation", 10)

	tex_rect_height = _create_noise_card(terrain_overview_grid, "Mapa de Altura", "FBM + Warp", Color("#f59e0b"))
	tex_rect_warp = _create_noise_card(terrain_overview_grid, "Domain Warp", "Vectores R/G", Color("#a855f7"))
	tex_rect_eco = _create_noise_card(terrain_overview_grid, "Máscara Ecológica", "Bosque / claros", Color("#22c55e"))
	tex_rect_composite = _create_noise_card(terrain_overview_grid, "Vista Satélite", "Color resuelto", Color("#14b8a6"))
	panel_noise.add_child(terrain_overview_grid)

	# 3. Single High-Res Diagnostic View (Visible when specific mode selected)
	terrain_single_box = VBoxContainer.new()
	terrain_single_box.add_theme_constant_override("separation", 4)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#050811"), Color("#151f33"), 4, 1))

	terrain_debug_rect = TextureRect.new()
	terrain_debug_rect.custom_minimum_size = Vector2(250, 250)
	terrain_debug_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	terrain_debug_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	terrain_debug_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(terrain_debug_rect)
	terrain_single_box.add_child(panel)

	terrain_debug_legend = Label.new()
	terrain_debug_legend.text = "Capa de depuración de terreno activa"
	terrain_debug_legend.add_theme_color_override("font_color", Color("#64748b"))
	terrain_debug_legend.add_theme_font_size_override("font_size", 9)
	terrain_debug_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terrain_single_box.add_child(terrain_debug_legend)
	terrain_single_box.visible = false
	panel_noise.add_child(terrain_single_box)

	# 4. Legend
	var leg_box := VBoxContainer.new()
	leg_box.add_theme_constant_override("separation", 4)
	_add_sub_header(leg_box, "LEYENDA DE LECTURA", Color("#64748b"))

	var leg1 := Label.new()
	leg1.text = "▫ Altura: negro = valles / blanco = cumbres"
	leg1.add_theme_color_override("font_color", Color("#64748b"))
	leg1.add_theme_font_size_override("font_size", 9)
	leg_box.add_child(leg1)

	var leg2 := Label.new()
	leg2.text = "▫ Warp: canal rojo = X / canal verde = Y"
	leg2.add_theme_color_override("font_color", Color("#64748b"))
	leg2.add_theme_font_size_override("font_size", 9)
	leg_box.add_child(leg2)

	panel_noise.add_child(leg_box)
	parent.add_child(panel_noise)

func _create_noise_card(parent: Control, title: String, subtitle: String, accent_col: Color) -> TextureRect:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 110)
	panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#070b14"), accent_col.lerp(Color.BLACK, 0.4), 4, 1))

	var trect := TextureRect.new()
	trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trect.stretch_mode = TextureRect.STRETCH_SCALE
	trect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(trect)
	box.add_child(panel)

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.add_theme_color_override("font_color", accent_col)
	t_lbl.add_theme_font_size_override("font_size", 9)
	box.add_child(t_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_color_override("font_color", Color("#4a5d78"))
	sub_lbl.add_theme_font_size_override("font_size", 8)
	box.add_child(sub_lbl)

	parent.add_child(box)
	return trect

# --- Tab 3: Colores ---
func _build_colors_tab(parent: Control) -> void:
	panel_colors = VBoxContainer.new()
	panel_colors.add_theme_constant_override("separation", 12)
	panel_colors.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 1. Gradient Bar Preview
	var grad_box := VBoxContainer.new()
	grad_box.add_theme_constant_override("separation", 4)
	_add_sub_header(grad_box, "GRADIENTE DE TERRENO", Color("#64748b"))

	gradient_preview_rect = TextureRect.new()
	gradient_preview_rect.custom_minimum_size = Vector2(0, 18)
	gradient_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gradient_preview_rect.stretch_mode = TextureRect.STRETCH_SCALE
	grad_box.add_child(gradient_preview_rect)

	var range_box := HBoxContainer.new()
	var r_min := Label.new()
	r_min.text = "0m"
	r_min.add_theme_color_override("font_color", Color("#4a5d78"))
	r_min.add_theme_font_size_override("font_size", 8)
	range_box.add_child(r_min)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_box.add_child(sp)

	var r_max := Label.new()
	r_max.text = "100%"
	r_max.add_theme_color_override("font_color", Color("#4a5d78"))
	r_max.add_theme_font_size_override("font_size", 8)
	range_box.add_child(r_max)
	grad_box.add_child(range_box)
	panel_colors.add_child(grad_box)

	# 2. Zone Color Pickers
	var zones_box := VBoxContainer.new()
	zones_box.add_theme_constant_override("separation", 6)
	_add_sub_header(zones_box, "ZONAS DE COLOR", Color("#14b8a6"))

	for def in COLOR_DEFS:
		_create_color_row(zones_box, def["key"], def["label"], def["sublabel"], def["range"])
	panel_colors.add_child(zones_box)

	# 3. Presets
	var pre_box := VBoxContainer.new()
	pre_box.add_theme_constant_override("separation", 6)
	_add_sub_header(pre_box, "PALETAS PREDEFINIDAS", Color("#64748b"))

	var pre_grid := GridContainer.new()
	pre_grid.columns = 2
	pre_grid.add_theme_constant_override("h_separation", 6)
	pre_grid.add_theme_constant_override("v_separation", 6)

	for p_name in COLOR_PRESETS.keys():
		var btn := Button.new()
		btn.text = p_name
		btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color(1.0, 1.0, 1.0, 0.04), Color(1.0, 1.0, 1.0, 0.1), 4, 1))
		btn.add_theme_color_override("font_color", Color("#94a3b8"))
		btn.add_theme_font_size_override("font_size", 9)
		btn.pressed.connect(func(): _apply_color_preset(p_name))
		pre_grid.add_child(btn)
	pre_box.add_child(pre_grid)
	panel_colors.add_child(pre_box)

	# 4. Reset Button
	var reset_btn := Button.new()
	reset_btn.text = "Restablecer Colores"
	reset_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(Color("#070b14"), Color("#1f293d"), 4, 1))
	reset_btn.add_theme_color_override("font_color", Color("#64748b"))
	reset_btn.add_theme_font_size_override("font_size", 9)
	reset_btn.pressed.connect(func(): _apply_color_preset("Taiga Clásica"))
	panel_colors.add_child(reset_btn)

	parent.add_child(panel_colors)

func _create_color_row(parent: Control, prop_key: String, label_text: String, sublabel: String, range_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var cpb := ColorPickerButton.new()
	cpb.color = profile.get(prop_key)
	cpb.custom_minimum_size = Vector2(24, 20)
	row.add_child(cpb)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var top_line := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.add_theme_color_override("font_color", Color("#c8d4e8"))
	l.add_theme_font_size_override("font_size", 9)
	top_line.add_child(l)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_line.add_child(sp)

	var r_lbl := Label.new()
	r_lbl.text = range_text
	r_lbl.add_theme_color_override("font_color", Color("#4a5d78"))
	r_lbl.add_theme_font_size_override("font_size", 8)
	top_line.add_child(r_lbl)
	text_box.add_child(top_line)

	var sub := Label.new()
	sub.text = sublabel
	sub.add_theme_color_override("font_color", Color("#4a5d78"))
	sub.add_theme_font_size_override("font_size", 8)
	text_box.add_child(sub)
	row.add_child(text_box)

	var hex_lbl := Label.new()
	hex_lbl.text = "#%s" % cpb.color.to_html(false).to_upper()
	hex_lbl.add_theme_color_override("font_color", Color("#64748b"))
	hex_lbl.add_theme_font_size_override("font_size", 8)
	row.add_child(hex_lbl)

	cpb.color_changed.connect(func(new_col: Color):
		profile.set(prop_key, new_col)
		hex_lbl.text = "#%s" % new_col.to_html(false).to_upper()
		_update_gradient_preview()
		if is_auto_gen:
			generate_world(false)
	)

	parent.add_child(row)
	color_pickers[prop_key] = cpb
	color_hex_labels[prop_key] = hex_lbl

func _apply_color_preset(p_name: String) -> void:
	if not COLOR_PRESETS.has(p_name):
		return
	var dict: Dictionary = COLOR_PRESETS[p_name]
	for k in dict.keys():
		var col: Color = dict[k]
		profile.set(k, col)
		if color_pickers.has(k):
			color_pickers[k].color = col
		if color_hex_labels.has(k):
			color_hex_labels[k].text = "#%s" % col.to_html(false).to_upper()

	_update_gradient_preview()
	generate_world(false)

# --- Tab 4: Hidrología & Depuración ---
func _build_hydrology_tab(parent: Control) -> void:
	panel_hydrology = VBoxContainer.new()
	panel_hydrology.add_theme_constant_override("separation", 12)
	panel_hydrology.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 1. Mode Selector
	var mode_box := VBoxContainer.new()
	mode_box.add_theme_constant_override("separation", 4)
	_add_sub_header(mode_box, "CAPA DE DEPURACIÓN HIDROLÓGICA", Color("#38bdf8"))

	hydro_debug_option = OptionButton.new()
	hydro_debug_option.add_item("[OFF] Vista Normal", HydroDebugMode.OFF)
	hydro_debug_option.add_item("[Ruido] Campo de Preferencia", HydroDebugMode.NOISE)
	hydro_debug_option.add_item("[Potencial] Cuencas de Lago", HydroDebugMode.LAKE_POTENTIAL)
	hydro_debug_option.add_item("[Potencial] Cauces de Río", HydroDebugMode.RIVER_POTENTIAL)
	hydro_debug_option.add_item("[Drenaje] Flujo Acumulado", HydroDebugMode.DRAINAGE)
	hydro_debug_option.add_item("[Dirección] Vectores de Flujo", HydroDebugMode.FLOW_DIR)
	hydro_debug_option.add_item("[Profundidad] Niveles de Agua", HydroDebugMode.DEPTH)
	hydro_debug_option.add_item("[Cuerpos] Lagos y Ríos Registrados", HydroDebugMode.BODIES)
	hydro_debug_option.select(HydroDebugMode.BODIES)
	hydro_debug_option.item_selected.connect(func(idx: int):
		current_hydro_debug_mode = idx as HydroDebugMode
		_update_hydrology_debug_view()
	)
	mode_box.add_child(hydro_debug_option)
	panel_hydrology.add_child(mode_box)

	# 2. Debug Texture Map
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 4)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#050811"), Color("#151f33"), 4, 1))

	hydro_debug_rect = TextureRect.new()
	hydro_debug_rect.custom_minimum_size = Vector2(250, 250)
	hydro_debug_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hydro_debug_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hydro_debug_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(hydro_debug_rect)
	preview_box.add_child(panel)

	hydro_debug_legend = Label.new()
	hydro_debug_legend.text = "Cuerpos de agua identificados en el terreno"
	hydro_debug_legend.add_theme_color_override("font_color", Color("#64748b"))
	hydro_debug_legend.add_theme_font_size_override("font_size", 9)
	hydro_debug_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_box.add_child(hydro_debug_legend)
	panel_hydrology.add_child(preview_box)

	# 3. Telemetry Cards
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	_add_sub_header(stats_box, "TELEMETRÍA HIDROLÓGICA", Color("#38bdf8"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)

	hydro_stat_lakes_lbl = _create_entity_card(grid, "🏞 Lagos", Color("#38bdf8"))
	hydro_stat_rivers_lbl = _create_entity_card(grid, "🌊 Ríos", Color("#22c55e"))
	hydro_stat_depth_lbl = _create_entity_card(grid, "↕ Prof. Máx", Color("#f59e0b"))
	hydro_stat_area_lbl = _create_entity_card(grid, "💧 % Agua", Color("#a855f7"))
	stats_box.add_child(grid)
	panel_hydrology.add_child(stats_box)

	parent.add_child(panel_hydrology)

func _update_hydrology_debug_view() -> void:
	if current_result == null or hydro_debug_rect == null:
		return

	var hydro = current_result.hydrology
	if hydro == null:
		return

	var w: int = current_result.dimensions.x
	var h: int = current_result.dimensions.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var max_depth: float = 0.0
	var water_cells_count: int = hydro.water_cells.size()

	for c_data in hydro.water_cells.values():
		var d: float = c_data.get("depth", 0.0)
		if d > max_depth:
			max_depth = d

	for y in range(h):
		for x in range(w):
			var pos := Vector2i(x, y)
			var cell: WorldCell = current_result.get_cell(pos)
			var col := Color.BLACK

			match current_hydro_debug_mode:
				HydroDebugMode.OFF:
					if cell != null:
						col = _TerrainColorResolverScript.resolve_vertex_color(cell, profile)
				HydroDebugMode.NOISE:
					var n_val: float = float(hydro.get_debug_value("noise", pos, 0.5))
					col = Color(n_val, n_val, n_val, 1.0)
				HydroDebugMode.LAKE_POTENTIAL:
					var pot: float = float(hydro.get_debug_value("lake_potential", pos, 0.0))
					col = Color(0.05, 0.2 + pot * 0.6, 0.4 + pot * 0.6, 1.0) if pot > 0.0 else Color(0.08, 0.1, 0.15, 1.0)
				HydroDebugMode.RIVER_POTENTIAL:
					var r_pot: float = float(hydro.get_debug_value("river_potential", pos, 0.0))
					col = Color(r_pot, r_pot * 0.75, 0.1, 1.0)
				HydroDebugMode.DRAINAGE:
					var drain: float = float(hydro.get_debug_value("drainage", pos, 0.0))
					var intensity: float = clampf(drain / 20.0, 0.0, 1.0)
					col = Color(0.05, 0.3 + intensity * 0.7, 0.6 + intensity * 0.4, 1.0) if drain > 0.0 else Color(0.06, 0.08, 0.12, 1.0)
				HydroDebugMode.FLOW_DIR:
					var dir: Vector2 = hydro.get_debug_value("flow_dir", pos, Vector2.ZERO)
					if dir != Vector2.ZERO:
						col = Color(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, 0.8, 1.0)
					else:
						col = Color(0.1, 0.12, 0.16, 1.0)
				HydroDebugMode.DEPTH:
					var depth: float = hydro.get_water_depth(pos)
					if depth > 0.0:
						var depth_norm: float = clampf(depth / 3.0, 0.0, 1.0)
						col = Color(0.1, 0.4 + depth_norm * 0.5, 0.8 + depth_norm * 0.2, 1.0)
					else:
						col = Color(0.06, 0.08, 0.12, 1.0)
				HydroDebugMode.BODIES:
					if hydro.is_lake(pos):
						col = profile.water_color_lake
					elif hydro.is_river(pos):
						col = profile.water_color_river
					else:
						var nh: float = cell.normalized_height if cell != null else 0.5
						col = Color(nh * 0.25 + 0.05, nh * 0.28 + 0.08, nh * 0.20 + 0.05, 1.0)

			img.set_pixel(x, y, col)

	hydro_debug_rect.texture = ImageTexture.create_from_image(img)

	# Update legend
	if hydro_debug_legend != null:
		match current_hydro_debug_mode:
			HydroDebugMode.OFF:
				hydro_debug_legend.text = "Modo depuración apagado. Vista albedo estándar."
			HydroDebugMode.NOISE:
				hydro_debug_legend.text = "Ruido continuo de hidrología [0.0 - 1.0]. Orienta meandros y sesgos de cuenca."
			HydroDebugMode.LAKE_POTENTIAL:
				hydro_debug_legend.text = "Proximidad al umbral de depresión para formación de lagos planos."
			HydroDebugMode.RIVER_POTENTIAL:
				hydro_debug_legend.text = "Potencial de cabecera: pendiente topográfica + altitud + ruido favorable."
			HydroDebugMode.DRAINAGE:
				hydro_debug_legend.text = "Acumulación de flujo gravitacional / longitud acumulada del cauce."
			HydroDebugMode.FLOW_DIR:
				hydro_debug_legend.text = "Vector bidimensional del gradiente de flujo por celda (dirección de caída)."
			HydroDebugMode.DEPTH:
				hydro_debug_legend.text = "Profundidad vertical de columna de agua (m)."
			HydroDebugMode.BODIES:
				hydro_debug_legend.text = "Cuerpos de agua clasificados: Lagos (azul) y Ríos (cian)."

	# Update telemetry readouts
	if hydro_stat_lakes_lbl != null:
		hydro_stat_lakes_lbl.text = "%d" % hydro.lakes.size()
	if hydro_stat_rivers_lbl != null:
		hydro_stat_rivers_lbl.text = "%d" % hydro.rivers.size()
	if hydro_stat_depth_lbl != null:
		hydro_stat_depth_lbl.text = "%.2f m" % max_depth
	if hydro_stat_area_lbl != null:
		var total_cells: float = float(w * h)
		hydro_stat_area_lbl.text = "%.1f%%" % ((float(water_cells_count) / maxf(total_cells, 1.0)) * 100.0)

func _build_bottom_bar() -> void:
	bottom_bar = PanelContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -28
	bottom_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_bar.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(Color("#070b14"), Color("#1f293d"), 0, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	bottom_bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var tag := Label.new()
	tag.text = "▲ CONTROLES:"
	tag.add_theme_color_override("font_color", Color("#22c55e"))
	tag.add_theme_font_size_override("font_size", 9)
	hbox.add_child(tag)

	var controls := [
		"WASD / Flechas · Mover Jugador",
		"P · Alternar Jugador",
		"Espacio · Respawn",
		"Rueda · Zoom",
		"Click Der + Drag · Desplazar",
		"Q/E · Rotar 45°",
		"F11 · Pantalla Completa",
		"Tab/H · Ocultar UI"
	]
	for c in controls:
		var cl := Label.new()
		cl.text = c
		cl.add_theme_color_override("font_color", Color("#4a5d78"))
		cl.add_theme_font_size_override("font_size", 9)
		hbox.add_child(cl)

	ui_root.add_child(bottom_bar)

# ==============================================================================
# 4. Helpers y Conexiones de Eventos
# ==============================================================================
func _read_ui_to_profile() -> void:
	for prop_name in _sliders.keys():
		var entry: Dictionary = _sliders[prop_name]
		var sl: HSlider = entry["slider"]
		profile.set(prop_name, sl.value)

func _on_preset_selected(index: int) -> void:
	if not PRESETS.has(index):
		return
	var p: Dictionary = PRESETS[index]
	for k in p.keys():
		if k == "name": continue
		var val: float = float(p[k])
		profile.set(k, val)

		# Synchronize physical wavelengths & amplitudes
		if k == "macro_strength":
			profile.macro_amplitude = val
			if _sliders.has("macro_amplitude"):
				_update_slider_visual("macro_amplitude", val)
		elif k == "macro_frequency":
			var w_val: float = 1.0 / maxf(val, 0.001)
			profile.macro_wavelength = w_val
			if _sliders.has("macro_wavelength"):
				_update_slider_visual("macro_wavelength", w_val)
		elif k == "warp_strength":
			profile.warp_amplitude = val
			if _sliders.has("warp_amplitude"):
				_update_slider_visual("warp_amplitude", val)
		elif k == "warp_frequency":
			var w_val: float = 1.0 / maxf(val, 0.001)
			profile.warp_wavelength = w_val
			if _sliders.has("warp_wavelength"):
				_update_slider_visual("warp_wavelength", w_val)
		elif k == "forest_frequency":
			var w_val: float = 1.0 / maxf(val, 0.001)
			profile.forest_wavelength = w_val
			if _sliders.has("forest_wavelength"):
				_update_slider_visual("forest_wavelength", w_val)

		if _sliders.has(k):
			_update_slider_visual(k, val)

	generate_world(false)

func _update_slider_visual(k: String, val: float) -> void:
	if _sliders.has(k):
		var sl: HSlider = _sliders[k]["slider"]
		var lbl: Label = _sliders[k]["label"]
		var step: float = _sliders[k]["step"]
		sl.value = val
		lbl.text = "%.3f" % val if step < 0.01 else ("%.2f" % val if step < 1.0 else "%d" % int(val))

func _focus_spawn() -> void:
	if current_result != null and focus_target != null and camera_rig != null:
		focus_target.global_position = current_result.spawn_position
		camera_rig.teleport_to_target()
		camera_rig.set_zoom(32.0)

func _frame_entire_world() -> void:
	if focus_target != null and camera_rig != null:
		var center_x := float(profile.width) * profile.cell_size * 0.5
		var center_z := float(profile.height) * profile.cell_size * 0.5
		focus_target.global_position = Vector3(center_x, 10.0, center_z)
		camera_rig.teleport_to_target()
		var max_dim := maxf(float(profile.width), float(profile.height)) * profile.cell_size
		camera_rig.set_zoom(max_dim * 0.65)
		camera_rig.yaw_degrees = 45.0
		camera_rig.pitch_degrees = 35.264

func _toggle_projection() -> void:
	_is_perspective = not _is_perspective
	var cam: Camera3D = camera_rig.get_camera()
	if cam != null:
		if _is_perspective:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 65.0
		else:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = camera_rig.get_zoom()

func _toggle_fullscreen() -> void:
	var win := get_window()
	if win != null:
		if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			win.mode = Window.MODE_WINDOWED
		else:
			win.mode = Window.MODE_FULLSCREEN

func _toggle_ui_visibility() -> void:
	if ui_root != null:
		ui_root.visible = not ui_root.visible
