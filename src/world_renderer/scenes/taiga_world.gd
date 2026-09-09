class_name TaigaWorld
extends Node3D

## Taiga World Lab & Exploration Viewer.
## Provee un entorno interactivo con UI táctica estilo DungeonLab para calibrar
## en tiempo real los parámetros del bioma Taiga y explorar el terreno generado en 3D
## mediante el IsometricCameraRig reutilizable del proyecto.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const _LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")

@export var world_seed: int = 12345

# 3D Environment & Presentation
var world_container: Node3D = null
var current_world_node: Node3D = null
var current_result: WorldResult = null
var profile: TaigaWorldProfile = null

# Camera & Navigation
var camera_rig: IsometricCameraRig = null
var focus_target: Marker3D = null
var sun_light: DirectionalLight3D = null
var world_env: WorldEnvironment = null
var _is_panning: bool = false
var _is_orbiting: bool = false
var _is_perspective: bool = false

# UI Canvas & Controls
var canvas_layer: CanvasLayer = null
var ui_root: Control = null
var left_panel: PanelContainer = null
var right_panel: PanelContainer = null
var top_bar: PanelContainer = null
var bottom_bar: PanelContainer = null

# UI Control references
var seed_spin: SpinBox = null
var preset_option: OptionButton = null
var auto_gen_check: CheckBox = null
var gen_btn: Button = null

# Telemetry Labels
var stat_time_lbl: Label = null
var stat_walkable_lbl: Label = null
var stat_reachable_lbl: Label = null
var stat_height_lbl: Label = null
var stat_spawn_lbl: Label = null
var stat_slopes_lbl: Label = null
var stat_canopy_lbl: Label = null
var stat_veg_lbl: Label = null

# Slider references for parameter reading & updating
var _sliders: Dictionary = {}

const PRESETS: Dictionary = {
	0: {
		"name": "Taiga Canónica (Equilibrada)",
		"macro_strength": 14.0,
		"macro_frequency": 0.012,
		"relief_exponent": 1.1,
		"base_height": 1.5,
		"height_scale": 1.0,
		"warp_strength": 18.0,
		"warp_frequency": 0.018,
		"warp_octaves": 2,
		"clearing_threshold": 0.45,
		"forest_frequency": 0.025,
		"tree_density": 0.70,
		"shrub_density": 0.45,
		"rock_density": 0.20,
		"min_tree_spacing": 2.0
	},
	1: {
		"name": "Valle Glaciar Amplio (Bajo Relieve)",
		"macro_strength": 16.0,
		"macro_frequency": 0.010,
		"relief_exponent": 1.6,
		"base_height": 1.2,
		"height_scale": 0.9,
		"warp_strength": 16.0,
		"warp_frequency": 0.015,
		"warp_octaves": 2,
		"clearing_threshold": 0.52,
		"forest_frequency": 0.020,
		"tree_density": 0.55,
		"shrub_density": 0.50,
		"rock_density": 0.12,
		"min_tree_spacing": 2.4
	},
	2: {
		"name": "Tierras Altas Escarpadas (Fiordos)",
		"macro_strength": 22.0,
		"macro_frequency": 0.018,
		"relief_exponent": 0.95,
		"base_height": 2.0,
		"height_scale": 1.3,
		"warp_strength": 22.0,
		"warp_frequency": 0.022,
		"warp_octaves": 3,
		"clearing_threshold": 0.42,
		"forest_frequency": 0.030,
		"tree_density": 0.50,
		"shrub_density": 0.35,
		"rock_density": 0.35,
		"min_tree_spacing": 2.2
	},
	3: {
		"name": "Bosque Boreal Cerrado (Old-Growth)",
		"macro_strength": 12.0,
		"macro_frequency": 0.014,
		"relief_exponent": 1.05,
		"base_height": 1.5,
		"height_scale": 1.0,
		"warp_strength": 15.0,
		"warp_frequency": 0.018,
		"warp_octaves": 2,
		"clearing_threshold": 0.32,
		"forest_frequency": 0.025,
		"tree_density": 0.85,
		"shrub_density": 0.60,
		"rock_density": 0.15,
		"min_tree_spacing": 1.7
	},
	4: {
		"name": "Turberas y Claros Abiertos",
		"macro_strength": 9.0,
		"macro_frequency": 0.012,
		"relief_exponent": 1.3,
		"base_height": 1.0,
		"height_scale": 0.85,
		"warp_strength": 12.0,
		"warp_frequency": 0.015,
		"warp_octaves": 2,
		"clearing_threshold": 0.62,
		"forest_frequency": 0.018,
		"tree_density": 0.30,
		"shrub_density": 0.65,
		"rock_density": 0.10,
		"min_tree_spacing": 2.6
	}
}

func _ready() -> void:
	profile = _TaigaWorldProfileScript.new()
	_setup_3d_environment()
	_setup_camera_rig()
	_setup_ui()
	generate_world(true)

# ==============================================================================
# 1. 3D Environment & Camera Rig Setup
# ==============================================================================
func _setup_3d_environment() -> void:
	world_container = Node3D.new()
	world_container.name = "WorldContainer"
	add_child(world_container)

	# Sun & Directional Light
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun_light.light_energy = 1.2
	sun_light.light_color = Color(0.98, 0.95, 0.88)
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.05
	add_child(sun_light)

	# Environment with sky and ambient lighting
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnv"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.13, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.50)
	env.ambient_light_energy = 0.75
	world_env.environment = env
	add_child(world_env)

func _setup_camera_rig() -> void:
	focus_target = Marker3D.new()
	focus_target.name = "FocusTarget"
	add_child(focus_target)

	camera_rig = _IsometricCameraRigScript.new()
	camera_rig.name = "IsometricCameraRig"
	camera_rig.zoom_min = 6.0
	camera_rig.zoom_max = 220.0
	camera_rig.zoom_step = 4.0
	camera_rig.default_zoom = 55.0
	camera_rig.camera_distance = 60.0
	camera_rig.follow_speed = 15.0
	add_child(camera_rig)

	camera_rig.set_target(focus_target)
	camera_rig.set_follow_enabled(true)

# ==============================================================================
# 2. Procedural World Generation & Real-time Telemetry
# ==============================================================================
func generate_world(reset_camera: bool = false) -> void:
	var start_usec := Time.get_ticks_usec()

	# Free old world mesh & multimeshes
	if current_world_node != null and is_instance_valid(current_world_node):
		current_world_node.queue_free()
		current_world_node = null

	# Synchronize profile parameters from active UI sliders
	_read_ui_to_profile()

	# Execute pipeline
	current_result = _WorldPipelineScript.generate(world_seed, profile)

	# Render 3D representation
	var renderer := _WorldRendererScript.new()
	current_world_node = renderer.render_world(current_result, profile.cell_size)
	world_container.add_child(current_world_node)
	renderer.queue_free()

	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0

	# Position focus target at spawn
	if current_result != null:
		if reset_camera:
			focus_target.global_position = current_result.spawn_position
			camera_rig.teleport_to_target()
			camera_rig.set_zoom(50.0)

		# Validate and update real-time telemetry panel
		_update_telemetry(current_result, duration_ms)

func _update_telemetry(result: WorldResult, duration_ms: float) -> void:
	if result == null or stat_time_lbl == null:
		return

	var min_h := INF
	var max_h := -INF
	var slopes := {"FLAT": 0, "GENTLE": 0, "STEEP": 0, "CLIFF": 0}
	var zones := {"CLEARING": 0, "EDGE": 0, "SPARSE": 0, "DENSE": 0}

	for cell: WorldCell in result.cells.values():
		if cell.height < min_h: min_h = cell.height
		if cell.height > max_h: max_h = cell.height

		match cell.slope_category:
			0: slopes["FLAT"] += 1
			1: slopes["GENTLE"] += 1
			2: slopes["STEEP"] += 1
			3: slopes["CLIFF"] += 1

		match cell.canopy_zone:
			WorldCell.CanopyZone.CLEARING: zones["CLEARING"] += 1
			WorldCell.CanopyZone.FOREST_EDGE: zones["EDGE"] += 1
			WorldCell.CanopyZone.SPARSE_FOREST: zones["SPARSE"] += 1
			WorldCell.CanopyZone.DENSE_FOREST: zones["DENSE"] += 1

	var total_cells := float(result.cells.size())
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
	var reachable_pct: float = val_report.get("reachable_walkable_ratio", 0.0) * 100.0

	stat_time_lbl.text = "⏱️ Generación: %.1f ms" % duration_ms
	stat_walkable_lbl.text = "🚶 Caminabilidad: %.1f%%" % walkable_pct
	stat_reachable_lbl.text = "🌐 Conectividad BFS: %.1f%%" % reachable_pct
	stat_height_lbl.text = "⛰️ Altura: %.1fm - %.1fm (Δ %.1fm)" % [min_h, max_h, max_h - min_h]
	stat_spawn_lbl.text = "📍 Spawn: (%.1f, %.1f, %.1f)" % [result.spawn_position.x, result.spawn_position.y, result.spawn_position.z]
	stat_slopes_lbl.text = "📐 Pendientes: Flat: %.0f%% | Gentle: %.0f%% | Steep: %.0f%%" % [
		(slopes["FLAT"] / total_cells) * 100.0,
		(slopes["GENTLE"] / total_cells) * 100.0,
		(slopes["STEEP"] / total_cells) * 100.0
	]
	stat_canopy_lbl.text = "🌲 Zonas: Claro: %.0f%% | Borde: %.0f%% | Bosque: %.0f%%" % [
		(zones["CLEARING"] / total_cells) * 100.0,
		(zones["EDGE"] / total_cells) * 100.0,
		((zones["SPARSE"] + zones["DENSE"]) / total_cells) * 100.0
	]
	stat_veg_lbl.text = "🌿 Entidades: 🌲 %d  |  🌿 %d  |  🪨 %d (Total: %d)" % [conifers, shrubs, rocks, result.vegetation.size()]

# ==============================================================================
# 3. Interactive Camera Navigation
# ==============================================================================
func _process(delta: float) -> void:
	if camera_rig == null or focus_target == null:
		return

	# Keyboard WASD / Arrow Key Panning
	var move_dir := Vector3.ZERO
	var cam: Camera3D = camera_rig.get_camera()
	if cam != null:
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
			focus_target.global_position.x = clampf(focus_target.global_position.x, 0.0, 128.0)
			focus_target.global_position.z = clampf(focus_target.global_position.z, 0.0, 128.0)

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
			if cam != null:
				var pan_factor: float = camera_rig.get_zoom() * 0.002
				var right: Vector3 = cam.global_transform.basis.x
				right.y = 0.0
				right = right.normalized()
				var forward: Vector3 = -cam.global_transform.basis.z
				forward.y = 0.0
				forward = forward.normalized()
				focus_target.global_position -= (right * mm.relative.x + forward * -mm.relative.y) * pan_factor
				focus_target.global_position.x = clampf(focus_target.global_position.x, 0.0, 128.0)
				focus_target.global_position.z = clampf(focus_target.global_position.z, 0.0, 128.0)

	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_Q:
			camera_rig.yaw_degrees -= 45.0
		elif ke.keycode == KEY_E:
			camera_rig.yaw_degrees += 45.0
		elif ke.keycode == KEY_F11 or ke.keycode == KEY_TAB:
			_toggle_ui_visibility()
		elif ke.keycode == KEY_SPACE:
			_focus_spawn()

func _focus_spawn() -> void:
	if current_result != null and focus_target != null and camera_rig != null:
		focus_target.global_position = current_result.spawn_position
		camera_rig.teleport_to_target()
		camera_rig.set_zoom(32.0)

func _frame_entire_world() -> void:
	if focus_target != null and camera_rig != null:
		focus_target.global_position = Vector3(64.0, 10.0, 64.0)
		camera_rig.teleport_to_target()
		camera_rig.set_zoom(80.0)
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

func _on_viewport_resized() -> void:
	if ui_root != null:
		ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ==============================================================================
# 4. User Interface Architecture (Tactical Blueprint Theme)
# ==============================================================================
func _setup_ui() -> void:
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
	_build_left_control_panel()
	_build_right_telemetry_panel()
	_build_bottom_toolbar()

	get_viewport().size_changed.connect(_on_viewport_resized)

func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 0
	top_bar.offset_top = 0
	top_bar.offset_right = 0
	top_bar.offset_bottom = 50
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_bar.grow_vertical = Control.GROW_DIRECTION_END
	top_bar.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(_LabColors.BG_PANEL, _LabColors.BORDER_BRIGHT, 0, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	top_bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🌲 TAIGA WORLD LAB  //  PROCEDURAL EXPLORER"
	title_lbl.add_theme_color_override("font_color", _LabColors.CYAN)
	hbox.add_child(title_lbl)

	# Spacer
	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer1)

	# Seed controls
	var seed_lbl := Label.new()
	seed_lbl.text = "Seed:"
	seed_lbl.add_theme_color_override("font_color", _LabColors.TEXT_SECONDARY)
	hbox.add_child(seed_lbl)

	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 99999999
	seed_spin.value = world_seed
	seed_spin.value_changed.connect(func(v):
		world_seed = int(v)
		if auto_gen_check.button_pressed:
			generate_world(false)
	)
	hbox.add_child(seed_spin)

	var rand_btn := Button.new()
	rand_btn.text = "🎲 Aleatorio"
	rand_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(_LabColors.BG_CARD, _LabColors.BORDER))
	rand_btn.pressed.connect(func():
		world_seed = randi() % 999999 + 1
		seed_spin.value = world_seed
		generate_world(false)
	)
	hbox.add_child(rand_btn)

	# Presets
	var preset_lbl := Label.new()
	preset_lbl.text = "Preset:"
	preset_lbl.add_theme_color_override("font_color", _LabColors.TEXT_SECONDARY)
	hbox.add_child(preset_lbl)

	preset_option = OptionButton.new()
	for p_id in PRESETS.keys():
		preset_option.add_item(PRESETS[p_id]["name"], p_id)
	preset_option.select(0)
	preset_option.item_selected.connect(_on_preset_selected)
	hbox.add_child(preset_option)

	# Auto-generate checkbox
	auto_gen_check = CheckBox.new()
	auto_gen_check.text = "Auto-Gen"
	auto_gen_check.button_pressed = false
	auto_gen_check.tooltip_text = "Generar automáticamente al mover sliders"
	hbox.add_child(auto_gen_check)

	# Fullscreen Button
	var btn_fs := Button.new()
	btn_fs.text = "⛶ Pantalla Completa"
	btn_fs.tooltip_text = "Alternar Pantalla Completa (F11 / Alt+Enter)"
	btn_fs.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(_LabColors.BG_CARD, _LabColors.BORDER))
	btn_fs.pressed.connect(_toggle_fullscreen)
	hbox.add_child(btn_fs)

	# Generate Button
	gen_btn = Button.new()
	gen_btn.text = "⚡ GENERAR MUNDO"
	gen_btn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(_LabColors.BG_ACTIVE, _LabColors.AMBER))
	gen_btn.add_theme_color_override("font_color", _LabColors.AMBER)
	gen_btn.pressed.connect(func(): generate_world(false))
	hbox.add_child(gen_btn)

	ui_root.add_child(top_bar)

func _build_left_control_panel() -> void:
	left_panel = PanelContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.anchor_left = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 12
	left_panel.offset_top = 58
	left_panel.offset_right = 352
	left_panel.offset_bottom = -38
	left_panel.grow_horizontal = Control.GROW_DIRECTION_END
	left_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	left_panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(_LabColors.BG_PANEL, _LabColors.BORDER, 6, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	left_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# --- TERRAIN SECTION ---
	_add_section_header(vbox, "⛰️ TERRENO Y RELIEVE")
	_add_slider(vbox, "macro_strength", "Fuerza Macro (Colinas)", profile.macro_strength, 0.0, 35.0, 0.5)
	_add_slider(vbox, "macro_frequency", "Frecuencia Macro", profile.macro_frequency, 0.005, 0.04, 0.001)
	_add_slider(vbox, "relief_exponent", "Moldeado de Relieve (Exp)", profile.relief_exponent, 0.6, 2.5, 0.05)
	_add_slider(vbox, "base_height", "Altura Base (m)", profile.base_height, 0.0, 10.0, 0.5)
	_add_slider(vbox, "height_scale", "Escala Vertical", profile.height_scale, 0.5, 2.5, 0.1)

	# --- DOMAIN WARP SECTION ---
	_add_section_header(vbox, "🌀 DOMAIN WARP (DISTORSIÓN)")
	_add_slider(vbox, "warp_strength", "Fuerza de Warp", profile.warp_strength, 0.0, 40.0, 1.0)
	_add_slider(vbox, "warp_frequency", "Frecuencia de Warp", profile.warp_frequency, 0.005, 0.04, 0.001)
	_add_slider(vbox, "warp_octaves", "Octavas de Warp", profile.warp_octaves, 1.0, 4.0, 1.0)

	# --- ECOLOGY SECTION ---
	_add_section_header(vbox, "🌲 ECOLOGÍA & CLAROS")
	_add_slider(vbox, "clearing_threshold", "Umbral de Claros", profile.clearing_threshold, 0.20, 0.70, 0.01)
	_add_slider(vbox, "forest_frequency", "Frecuencia de Bosque", profile.forest_frequency, 0.01, 0.06, 0.002)

	# --- VEGETATION SECTION ---
	_add_section_header(vbox, "🌿 VEGETACIÓN (SPATIAL HASH)")
	_add_slider(vbox, "tree_density", "Densidad Árboles", profile.tree_density, 0.0, 1.0, 0.05)
	_add_slider(vbox, "min_tree_spacing", "Espaciado Mínimo Árboles", profile.min_tree_spacing, 1.2, 4.0, 0.1)
	_add_slider(vbox, "shrub_density", "Densidad Arbustos", profile.shrub_density, 0.0, 1.0, 0.05)
	_add_slider(vbox, "rock_density", "Densidad Rocas", profile.rock_density, 0.0, 1.0, 0.05)

	ui_root.add_child(left_panel)

func _build_right_telemetry_panel() -> void:
	right_panel = PanelContainer.new()
	right_panel.name = "RightPanel"
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -342
	right_panel.offset_top = 58
	right_panel.offset_right = -12
	right_panel.offset_bottom = -38
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	right_panel.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(_LabColors.BG_PANEL, _LabColors.BORDER, 6, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	right_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "📊 TELEMETRÍA EN TIEMPO REAL"
	title.add_theme_color_override("font_color", _LabColors.AMBER)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	stat_time_lbl = _create_stat_label(vbox, "⏱️ Generación: -- ms")
	stat_walkable_lbl = _create_stat_label(vbox, "🚶 Caminabilidad: --%")
	stat_reachable_lbl = _create_stat_label(vbox, "🌐 Conectividad BFS: --%")
	stat_height_lbl = _create_stat_label(vbox, "⛰️ Altura: --")
	stat_spawn_lbl = _create_stat_label(vbox, "📍 Spawn: --")
	stat_slopes_lbl = _create_stat_label(vbox, "📐 Pendientes: --")
	stat_canopy_lbl = _create_stat_label(vbox, "🌲 Zonas: --")
	stat_veg_lbl = _create_stat_label(vbox, "🌿 Entidades: --")

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Actions Card
	var cam_title := Label.new()
	cam_title.text = "🎥 ACCIONES DE CÁMARA"
	cam_title.add_theme_color_override("font_color", _LabColors.CYAN)
	vbox.add_child(cam_title)

	var btn_spawn := Button.new()
	btn_spawn.text = "🔭 Enfocar Spawn (Space)"
	btn_spawn.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(_LabColors.BG_CARD, _LabColors.BORDER))
	btn_spawn.pressed.connect(_focus_spawn)
	vbox.add_child(btn_spawn)

	var btn_frame := Button.new()
	btn_frame.text = "🗺️ Encuadrar Mundo Completo"
	btn_frame.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(_LabColors.BG_CARD, _LabColors.BORDER))
	btn_frame.pressed.connect(_frame_entire_world)
	vbox.add_child(btn_frame)

	var btn_proj := Button.new()
	btn_proj.text = "👁️ Alternar Isométrica / Perspectiva"
	btn_proj.add_theme_stylebox_override("normal", _LabColors.create_btn_stylebox(_LabColors.BG_CARD, _LabColors.BORDER))
	btn_proj.pressed.connect(_toggle_projection)
	vbox.add_child(btn_proj)

	ui_root.add_child(right_panel)

func _build_bottom_toolbar() -> void:
	bottom_bar = PanelContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = 0
	bottom_bar.offset_top = -32
	bottom_bar.offset_right = 0
	bottom_bar.offset_bottom = 0
	bottom_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_bar.add_theme_stylebox_override("panel", _LabColors.create_panel_stylebox(_LabColors.BG_DARK, _LabColors.BORDER, 0, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	bottom_bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	var help_lbl := Label.new()
	help_lbl.text = "🕹️ CONTROLES: WASD / Flechas: Panorámica  |  Rueda: Zoom  |  Click Der + Drag: Desplazar  |  Q/E / Click Central: Rotar 45°  |  F11/Alt+Enter: Pantalla Completa  |  Tab/H: Ocultar UI"
	help_lbl.add_theme_color_override("font_color", _LabColors.TEXT_SECONDARY)
	help_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(help_lbl)

	ui_root.add_child(bottom_bar)

func _create_stat_label(parent: Control, default_text: String) -> Label:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _LabColors.make_card_style(_LabColors.BG_CARD, _LabColors.BORDER, 1, 4))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", 4)
	card.add_child(m)

	var lbl := Label.new()
	lbl.text = default_text
	lbl.add_theme_color_override("font_color", _LabColors.TEXT_PRIMARY)
	lbl.add_theme_font_size_override("font_size", 12)
	m.add_child(lbl)
	parent.add_child(card)
	return lbl

func _add_section_header(parent: Control, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", _LabColors.CYAN)
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)

func _add_slider(parent: Control, prop_name: String, label_text: String, default_val: float, min_val: float, max_val: float, step: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var header_box := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_color_override("font_color", _LabColors.TEXT_SECONDARY)
	name_lbl.add_theme_font_size_override("font_size", 12)
	header_box.add_child(name_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = "%.3f" % default_val if step < 0.01 else ("%.2f" % default_val if step < 1.0 else "%d" % int(default_val))
	val_lbl.add_theme_color_override("font_color", _LabColors.AMBER)
	val_lbl.add_theme_font_size_override("font_size", 12)
	header_box.add_child(val_lbl)
	box.add_child(header_box)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%.3f" % v if step < 0.01 else ("%.2f" % v if step < 1.0 else "%d" % int(v))
		if auto_gen_check.button_pressed:
			generate_world(false)
	)
	box.add_child(slider)
	parent.add_child(box)

	_sliders[prop_name] = {"slider": slider, "val_lbl": val_lbl, "step": step}

func _read_ui_to_profile() -> void:
	for prop in _sliders.keys():
		var s: HSlider = _sliders[prop]["slider"]
		var val: float = s.value
		match prop:
			"macro_strength": profile.macro_strength = val
			"macro_frequency": profile.macro_frequency = val
			"relief_exponent": profile.relief_exponent = val
			"base_height": profile.base_height = val
			"height_scale": profile.height_scale = val
			"warp_strength": profile.warp_strength = val
			"warp_frequency": profile.warp_frequency = val
			"warp_octaves": profile.warp_octaves = int(val)
			"clearing_threshold": profile.clearing_threshold = val
			"forest_frequency": profile.forest_frequency = val
			"tree_density": profile.tree_density = val
			"min_tree_spacing": profile.min_tree_spacing = val
			"shrub_density": profile.shrub_density = val
			"rock_density": profile.rock_density = val

func _on_preset_selected(idx: int) -> void:
	if not PRESETS.has(idx):
		return
	var data: Dictionary = PRESETS[idx]
	for prop in data.keys():
		if prop == "name":
			continue
		if _sliders.has(prop):
			var s: HSlider = _sliders[prop]["slider"]
			var lbl: Label = _sliders[prop]["val_lbl"]
			var step: float = _sliders[prop]["step"]
			var v: float = float(data[prop])
			s.value = v
			lbl.text = "%.3f" % v if step < 0.01 else ("%.2f" % v if step < 1.0 else "%d" % int(v))

	generate_world(false)
