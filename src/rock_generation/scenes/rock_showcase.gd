extends Node3D

## Rock Laboratory: Herramienta visual de autoría y configuración de rocas procedurales.
## Permite diseñar geometrías, siluetas, deformaciones, clusters y materiales en tiempo real
## y exportar/importar configuraciones JSON unificadas (RockConfig) por bioma.

const RockConfig = preload("res://src/rock_generation/config/rock_config.gd")
const RockSizeConfig = preload("res://src/rock_generation/config/rock_size_config.gd")
const RockMeshBuilder = preload("res://src/rock_generation/rock_mesh_builder.gd")
const RockMaterial = preload("res://src/rock_generation/rock_material.gd")
const RockInstance = preload("res://src/rock_generation/rock_instance.gd")
const RockGeneration = preload("res://src/rock_generation/rock_generation.gd")

# Configuración del Laboratorio
var _rock_config: RockConfig = null
var _current_seed: int = 4242
var _selected_category: int = RockSizeConfig.Category.LARGE

# Nodos de visualización
var _rocks_container: Node3D = null
var _shared_material: ShaderMaterial = null
var _rock_gen: RockGeneration = null

# Configuración de Cámara Orbital
var _cam_pivot: Node3D = null
var _cam: Camera3D = null
var _cam_distance: float = 20.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = -32.0
var _is_orbiting: bool = false
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# UI Controls Registry
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _toast_label: Label = null
var _toast_timer: float = 0.0
var _file_dialog: FileDialog = null
var _file_dialog_mode: int = 0 # 0: load, 1: save
var _biome_name_edit: LineEdit = null
var _cat_selector: OptionButton = null

func _ready() -> void:
	_rock_config = RockConfig.create_default_taiga()
	_shared_material = RockMaterial.create_rock_material()

	_setup_environment()
	_setup_orbit_camera()
	_setup_rocks_container()
	_populate_showcase()
	_setup_ui()

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_label != null:
			_toast_label.text = ""

func _setup_environment() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnv"
	var sky_env: Environment = Environment.new()
	sky_env.background_mode = Environment.BG_COLOR
	sky_env.background_color = Color(0.14, 0.17, 0.20)
	sky_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky_env.ambient_light_color = Color(0.48, 0.55, 0.60)
	sky_env.ambient_light_energy = 0.95
	sky_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = sky_env
	add_child(env)

	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = Vector2(100, 100)
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.24, 0.30, 0.22)
	ground_mat.roughness = 0.95
	var ground_inst: MeshInstance3D = MeshInstance3D.new()
	ground_inst.name = "Ground"
	ground_inst.mesh = ground_mesh
	ground_inst.material_override = ground_mat
	add_child(ground_inst)

func _setup_orbit_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CameraPivot"
	_cam_pivot.position = Vector3(0.0, 1.5, 0.0)
	add_child(_cam_pivot)

	_cam = Camera3D.new()
	_cam.name = "OrbitCamera"
	_cam.current = true
	_cam_pivot.add_child(_cam)
	_update_camera_transform()

func _update_camera_transform() -> void:
	_cam_pitch = clamp(_cam_pitch, -85.0, -5.0)
	_cam_pivot.rotation_degrees = Vector3(_cam_pitch, _cam_yaw, 0.0)
	_cam.position = Vector3(0.0, 0.0, _cam_distance)

func _setup_rocks_container() -> void:
	_rocks_container = Node3D.new()
	_rocks_container.name = "RocksContainer"
	add_child(_rocks_container)

## Regenera la escena completa utilizando _rock_config
func _populate_showcase() -> void:
	for child in _rocks_container.get_children():
		child.queue_free()

	_rock_gen = RockGeneration.new(_current_seed, _rock_config)
	_shared_material = _rock_gen.get_material()

	var large_profile: RockSizeConfig = _rock_config.get_profile(RockSizeConfig.Category.LARGE)
	var medium_profile: RockSizeConfig = _rock_config.get_profile(RockSizeConfig.Category.MEDIUM)
	var small_profile: RockSizeConfig = _rock_config.get_profile(RockSizeConfig.Category.SMALL)

	# --- COLUMNA 1: ROCAS GRANDES (X = -9.0) ---
	var l_vars: int = max(1, large_profile.num_variants)
	for v in range(l_vars):
		var mesh: ArrayMesh = _rock_gen.get_mesh(RockSizeConfig.Category.LARGE, v)
		var inst: RockInstance = RockInstance.create(
			Vector3(-9.0, 0.0, -6.0 + float(v) * 5.0),
			large_profile,
			_current_seed + 100 + v,
			Vector3.UP,
			RockSizeConfig.Category.LARGE
		)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Large_Variant_%d" % v
		mi.mesh = mesh
		mi.transform = inst.transform
		mi.material_override = _shared_material
		_rocks_container.add_child(mi)

	# --- COLUMNA 2: ROCAS MEDIANAS (X = -2.5) ---
	var m_vars: int = max(1, medium_profile.num_variants)
	for v in range(m_vars):
		var mesh: ArrayMesh = _rock_gen.get_mesh(RockSizeConfig.Category.MEDIUM, v)
		var inst: RockInstance = RockInstance.create(
			Vector3(-2.5, 0.0, -6.0 + float(v) * 3.4),
			medium_profile,
			_current_seed + 200 + v,
			Vector3.UP,
			RockSizeConfig.Category.MEDIUM
		)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Medium_Variant_%d" % v
		mi.mesh = mesh
		mi.transform = inst.transform
		mi.material_override = _shared_material
		_rocks_container.add_child(mi)

	# --- FILA FRONTAL: ROCAS MINÚSCULAS (Z = 5.5) ---
	var s_vars: int = max(1, small_profile.num_variants)
	for v in range(6):
		var mesh: ArrayMesh = _rock_gen.get_mesh(RockSizeConfig.Category.SMALL, v % s_vars)
		var inst: RockInstance = RockInstance.create(
			Vector3(-10.0 + float(v) * 2.2, 0.0, 5.5),
			small_profile,
			_current_seed + 300 + v,
			Vector3.UP,
			RockSizeConfig.Category.SMALL
		)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Small_Variant_%d" % v
		mi.mesh = mesh
		mi.transform = inst.transform
		mi.material_override = _shared_material
		_rocks_container.add_child(mi)

	# --- SECCIÓN DERECHA: CLUSTER SIMULADO BASADO EN ROCKCONFIG ---
	_spawn_cluster_simulation(Vector3(6.5, 0.0, -1.0))

func _spawn_cluster_simulation(center: Vector3) -> void:
	var large_profile: RockSizeConfig = _rock_config.get_profile(RockSizeConfig.Category.LARGE)
	var cl_large_mesh: ArrayMesh = _rock_gen.get_mesh(RockSizeConfig.Category.LARGE, 0)
	var cl_large_inst: RockInstance = RockInstance.create(
		center,
		large_profile,
		_current_seed + 777,
		Vector3.UP,
		RockSizeConfig.Category.LARGE
	)
	var mi_cl_l: MeshInstance3D = MeshInstance3D.new()
	mi_cl_l.name = "Cluster_Large_Master"
	mi_cl_l.mesh = cl_large_mesh
	mi_cl_l.transform = cl_large_inst.transform
	mi_cl_l.material_override = _shared_material
	_rocks_container.add_child(mi_cl_l)

	# Generar satélites de acuerdo con _rock_config.clustering["large"]
	var cl_info: Dictionary = _rock_config.clustering.get("large", {})
	if not cl_info.get("enabled", true):
		return

	var min_sats: int = int(cl_info.get("min_satellites", 2))
	var max_sats: int = int(cl_info.get("max_satellites", 3))
	var count: int = max(min_sats, max_sats)
	var dist_min_mult: float = float(cl_info.get("min_distance_mult", 0.8))
	var dist_max_mult: float = float(cl_info.get("max_distance_mult", 1.6))
	var sat_profiles: Array = cl_info.get("satellite_profiles", [])
	var master_scale: float = (cl_large_inst.scale.x + cl_large_inst.scale.z) * 0.5

	for s_idx in range(count):
		var angle: float = (TAU * float(s_idx) / float(count)) + 0.35
		var dist: float = lerp(dist_min_mult, dist_max_mult, float(s_idx) / float(max(1, count - 1))) * master_scale
		var sat_pos: Vector3 = center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

		var sat_cat: int = RockSizeConfig.Category.SMALL
		var s_sc_min: float = 0.20
		var s_sc_max: float = 0.40

		if not sat_profiles.is_empty():
			var p_info: Dictionary = sat_profiles[s_idx % sat_profiles.size()]
			var cat_str: String = str(p_info.get("category", "small")).to_lower()
			if cat_str == "medium":
				sat_cat = RockSizeConfig.Category.MEDIUM
			s_sc_min = float(p_info.get("scale_min", 0.20))
			s_sc_max = float(p_info.get("scale_max", 0.40))

		var sat_cfg: RockSizeConfig = _rock_config.get_profile(sat_cat)
		var sat_mesh: ArrayMesh = _rock_gen.get_mesh(sat_cat, s_idx)
		var sat_inst: RockInstance = RockInstance.create(
			sat_pos,
			sat_cfg,
			_current_seed + 900 + s_idx,
			Vector3.UP,
			sat_cat
		)
		var mi_sat: MeshInstance3D = MeshInstance3D.new()
		mi_sat.name = "Cluster_Satellite_%d" % s_idx
		mi_sat.mesh = sat_mesh
		mi_sat.transform = sat_inst.transform
		mi_sat.material_override = _shared_material
		_rocks_container.add_child(mi_sat)

# =========================================================================
# INTERFAZ DE USUARIO: PANEL DE CONTROL POR PESTAÑAS (AUTHORING SUITE)
# =========================================================================

func _setup_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "UILayer"
	add_child(canvas)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "LaboratoryPanel"
	panel.custom_minimum_size = Vector2(420, 720)
	panel.position = Vector2(16, 16)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(main_vbox)

	# Encabezado
	var title_lbl: Label = Label.new()
	title_lbl.text = "⚒️ ROCK LABORATORY — AUTHORING TOOL"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	main_vbox.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "Click Der: Orbitar | Rueda: Zoom | Botón Medio: Paneo"
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.60, 0.68, 0.76))
	main_vbox.add_child(sub_lbl)

	# Fila Semilla y Categoría activa
	var top_row: HBoxContainer = HBoxContainer.new()
	var seed_lbl: Label = Label.new()
	seed_lbl.text = "Semilla: %d" % _current_seed
	seed_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_labels["seed_text"] = {"label": seed_lbl, "name": "Semilla"}
	top_row.add_child(seed_lbl)

	var btn_rand: Button = Button.new()
	btn_rand.text = "🎲 Random"
	btn_rand.pressed.connect(func():
		_current_seed = randi() % 999999
		seed_lbl.text = "Semilla: %d" % _current_seed
		_populate_showcase()
	)
	top_row.add_child(btn_rand)
	main_vbox.add_child(top_row)

	# Selector de categoría para pestañas geométricas
	var cat_row: HBoxContainer = HBoxContainer.new()
	var cat_lbl: Label = Label.new()
	cat_lbl.text = "Tamaño a Modificar:"
	cat_row.add_child(cat_lbl)

	_cat_selector = OptionButton.new()
	_cat_selector.add_item("Grandes (Large)", RockSizeConfig.Category.LARGE)
	_cat_selector.add_item("Medianas (Medium)", RockSizeConfig.Category.MEDIUM)
	_cat_selector.add_item("Pequeñas (Small)", RockSizeConfig.Category.SMALL)
	_cat_selector.selected = 0
	_cat_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cat_selector.item_selected.connect(func(idx: int):
		_selected_category = _cat_selector.get_item_id(idx)
		_sync_all_controls()
	)
	cat_row.add_child(_cat_selector)
	main_vbox.add_child(cat_row)

	main_vbox.add_child(HSeparator.new())

	# Contenedor de Pestañas
	var tab_container: TabContainer = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)

	# 1. Pestaña Bioma & Archivos
	_build_tab_biome_io(tab_container)

	# 2. Pestaña Geometría
	_build_tab_geometry(tab_container)

	# 3. Pestaña Silueta & Deformación
	_build_tab_silhouette(tab_container)

	# 4. Pestaña Variación Instancia
	_build_tab_variation(tab_container)

	# 5. Pestaña Clusters & Satélites
	_build_tab_clustering(tab_container)

	# 6. Pestaña Material / Sombreado
	_build_tab_material(tab_container)

	# Notificación Toast y Botones Inferiores
	_toast_label = Label.new()
	_toast_label.text = ""
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	_toast_label.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(_toast_label)

	var bottom_row: HBoxContainer = HBoxContainer.new()
	var btn_regen: Button = Button.new()
	btn_regen.text = "🔄 Regenerar Mallas"
	btn_regen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_regen.pressed.connect(func(): _populate_showcase())
	bottom_row.add_child(btn_regen)

	var btn_save_default: Button = Button.new()
	btn_save_default.text = "💾 Guardar Bioma JSON"
	btn_save_default.pressed.connect(_on_save_default_json)
	bottom_row.add_child(btn_save_default)
	main_vbox.add_child(bottom_row)

	# FileDialog para Guardar/Cargar personalizado
	_setup_file_dialog(canvas)

	_sync_all_controls()

# --- PESTAÑA 1: BIOMA & ARCHIVOS ---
func _build_tab_biome_io(tab_parent: TabContainer) -> void:
	var scroll: ScrollContainer = _create_tab_scroll(tab_parent, "Bioma")
	var vbox: VBoxContainer = scroll.get_child(0)

	var name_lbl: Label = Label.new()
	name_lbl.text = "Nombre del Bioma:"
	vbox.add_child(name_lbl)

	_biome_name_edit = LineEdit.new()
	_biome_name_edit.text = _rock_config.biome
	_biome_name_edit.text_changed.connect(func(new_text: String):
		_rock_config.biome = new_text
	)
	vbox.add_child(_biome_name_edit)

	var pres_lbl: Label = Label.new()
	pres_lbl.text = "Cargar Preset Canónico:"
	vbox.add_child(pres_lbl)

	var preset_opt: OptionButton = OptionButton.new()
	preset_opt.add_item("🌲 Taiga (Crestas y granito)")
	preset_opt.add_item("🏜️ Desierto (Lajas estratificadas)")
	preset_opt.add_item("🏔️ Alta Montaña (Picos escarpados)")
	preset_opt.selected = 0
	preset_opt.item_selected.connect(func(idx: int):
		if idx == 0:
			_rock_config = RockConfig.create_default_taiga()
		elif idx == 1:
			_rock_config = RockConfig.create_default_desert()
		elif idx == 2:
			_rock_config = RockConfig.create_default_mountain()
		_biome_name_edit.text = _rock_config.biome
		_sync_all_controls()
		_populate_showcase()
		_show_toast("Preset aplicado exitosamente.")
	)
	vbox.add_child(preset_opt)

	vbox.add_child(HSeparator.new())

	# Distribución
	_add_slider(vbox, "dist_density", "Densidad Global", 0.01, 0.50, 0.01, func(v: float):
		_rock_config.distribution["density"] = v
	)
	_add_slider(vbox, "dist_min_slope", "Pendiente Mínima (°)", 0.0, 45.0, 1.0, func(v: float):
		_rock_config.distribution["min_slope_degrees"] = v
	)
	_add_slider(vbox, "dist_max_slope", "Pendiente Máxima (°)", 20.0, 85.0, 1.0, func(v: float):
		_rock_config.distribution["max_slope_degrees"] = v
	)

	vbox.add_child(HSeparator.new())

	var io_row: HBoxContainer = HBoxContainer.new()
	var btn_load: Button = Button.new()
	btn_load.text = "📥 Cargar JSON..."
	btn_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_load.pressed.connect(func():
		_file_dialog_mode = 0
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.popup_centered(Vector2i(600, 400))
	)
	io_row.add_child(btn_load)

	var btn_save_as: Button = Button.new()
	btn_save_as.text = "💾 Guardar Como..."
	btn_save_as.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_as.pressed.connect(func():
		_file_dialog_mode = 1
		_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_file_dialog.current_file = "%s_rocks.json" % _rock_config.biome
		_file_dialog.popup_centered(Vector2i(600, 400))
	)
	io_row.add_child(btn_save_as)
	vbox.add_child(io_row)

# --- PESTAÑA 2: GEOMETRÍA ---
func _build_tab_geometry(tab_parent: TabContainer) -> void:
	var scroll: ScrollContainer = _create_tab_scroll(tab_parent, "Geometría")
	var vbox: VBoxContainer = scroll.get_child(0)

	_add_slider(vbox, "rings", "Anillos Verticales (Rings)", 3.0, 8.0, 1.0, func(v: float):
		_get_active_profile().rings = int(v)
		_populate_showcase()
	)
	_add_slider(vbox, "segments", "Segmentos Circulares", 5.0, 16.0, 1.0, func(v: float):
		_get_active_profile().segments = int(v)
		_populate_showcase()
	)
	_add_slider(vbox, "height_ratio", "Relación Altura (Y Ratio)", 0.3, 2.5, 0.05, func(v: float):
		_get_active_profile().height_ratio = v
		_populate_showcase()
	)
	_add_slider(vbox, "irregularity", "Irregularidad Global", 0.0, 1.0, 0.02, func(v: float):
		_get_active_profile().irregularity = v
		_populate_showcase()
	)
	_add_slider(vbox, "base_penetration", "Penetración Base Suelo", 0.0, 0.60, 0.02, func(v: float):
		_get_active_profile().base_penetration = v
		_populate_showcase()
	)
	_add_slider(vbox, "num_variants", "Variantes Pregeneradas", 1.0, 6.0, 1.0, func(v: float):
		_get_active_profile().num_variants = int(v)
		_populate_showcase()
	)

# --- PESTAÑA 3: SILUETA & DEFORMACIÓN ---
func _build_tab_silhouette(tab_parent: TabContainer) -> void:
	var scroll: ScrollContainer = _create_tab_scroll(tab_parent, "Silueta")
	var vbox: VBoxContainer = scroll.get_child(0)

	_add_slider(vbox, "base_radius_factor", "Factor Radio Base", 0.4, 1.6, 0.05, func(v: float):
		_get_active_profile().base_radius_factor = v
		_populate_showcase()
	)
	_add_slider(vbox, "body_bulge_factor", "Abultamiento Cuerpo", 0.8, 1.8, 0.05, func(v: float):
		_get_active_profile().body_bulge_factor = v
		_populate_showcase()
	)
	_add_slider(vbox, "taper_power", "Potencia Estrechamiento (Taper)", 0.2, 2.0, 0.05, func(v: float):
		_get_active_profile().taper_power = v
		_populate_showcase()
	)
	_add_slider(vbox, "peak_convergence_min", "Convergencia Cresta Min", 0.05, 0.40, 0.02, func(v: float):
		_get_active_profile().peak_convergence_min = v
		_populate_showcase()
	)
	_add_slider(vbox, "peak_convergence_max", "Convergencia Cresta Max", 0.15, 0.60, 0.02, func(v: float):
		_get_active_profile().peak_convergence_max = v
		_populate_showcase()
	)
	_add_slider(vbox, "apex_elevation_min", "Elevación Apex Min", 0.02, 0.40, 0.02, func(v: float):
		_get_active_profile().apex_elevation_min = v
		_populate_showcase()
	)
	_add_slider(vbox, "apex_elevation_max", "Elevación Apex Max", 0.10, 0.60, 0.02, func(v: float):
		_get_active_profile().apex_elevation_max = v
		_populate_showcase()
	)
	_add_slider(vbox, "radial_jitter", "Jitter Radial", 0.0, 1.0, 0.05, func(v: float):
		_get_active_profile().radial_jitter = v
		_populate_showcase()
	)
	_add_slider(vbox, "vertical_jitter", "Jitter Vertical", 0.0, 1.0, 0.05, func(v: float):
		_get_active_profile().vertical_jitter = v
		_populate_showcase()
	)
	_add_slider(vbox, "mass_offset_strength", "Fuerza Asimetría (Masa)", 0.0, 0.50, 0.02, func(v: float):
		_get_active_profile().mass_offset_strength = v
		_populate_showcase()
	)

# --- PESTAÑA 4: VARIACIÓN DE INSTANCIA ---
func _build_tab_variation(tab_parent: TabContainer) -> void:
	var scroll: ScrollContainer = _create_tab_scroll(tab_parent, "Variación")
	var vbox: VBoxContainer = scroll.get_child(0)

	_add_slider(vbox, "min_scale", "Escala Mínima", 0.1, 4.0, 0.05, func(v: float):
		_get_active_profile().min_scale = v
		_populate_showcase()
	)
	_add_slider(vbox, "max_scale", "Escala Máxima", 0.2, 8.0, 0.05, func(v: float):
		_get_active_profile().max_scale = v
		_populate_showcase()
	)
	_add_slider(vbox, "max_tilt_degrees", "Inclinación Máxima (°)", 0.0, 25.0, 1.0, func(v: float):
		_get_active_profile().max_tilt_degrees = v
		_populate_showcase()
	)
	_add_slider(vbox, "slope_tilt_factor", "Factor Inclinación Pendiente", 0.0, 12.0, 0.5, func(v: float):
		_get_active_profile().slope_tilt_factor = v
		_populate_showcase()
	)

# --- PESTAÑA 5: CLUSTERS & SATÉLITES ---
func _build_tab_clustering(tab_parent: TabContainer) -> void:
	var scroll: ScrollContainer = _create_tab_scroll(tab_parent, "Clusters")
	var vbox: VBoxContainer = scroll.get_child(0)

	_add_slider(vbox, "cluster_prob", "Probabilidad de Cluster", 0.0, 1.0, 0.05, func(v: float):
		var key: String = _get_active_cat_key()
		_rock_config.clustering[key]["probability"] = v
		_populate_showcase()
	)
	_add_slider(vbox, "cluster_min_sat", "Mínimo de Satélites", 0.0, 5.0, 1.0, func(v: float):
		var key: String = _get_active_cat_key()
		_rock_config.clustering[key]["min_satellites"] = int(v)
		_populate_showcase()
	)
	_add_slider(vbox, "cluster_max_sat", "Máximo de Satélites", 0.0, 8.0, 1.0, func(v: float):
		var key: String = _get_active_cat_key()
		_rock_config.clustering[key]["max_satellites"] = int(v)
		_populate_showcase()
	)
	_add_slider(vbox, "cluster_dist_min", "Distancia Mínima Multiplicador", 0.4, 2.5, 0.1, func(v: float):
		var key: String = _get_active_cat_key()
		_rock_config.clustering[key]["min_distance_mult"] = v
		_populate_showcase()
	)
	_add_slider(vbox, "cluster_dist_max", "Distancia Máxima Multiplicador", 0.8, 3.5, 0.1, func(v: float):
		var key: String = _get_active_cat_key()
		_rock_config.clustering[key]["max_distance_mult"] = v
		_populate_showcase()
	)

# --- PESTAÑA 6: MATERIAL / SHADING ---
func _build_tab_material(tab_parent: TabContainer) -> void:
	var scroll: ScrollContainer = _create_tab_scroll(tab_parent, "Material")
	var vbox: VBoxContainer = scroll.get_child(0)

	_add_slider(vbox, "mat_normal_weight", "Luz Normal UP", 0.0, 1.0, 0.05, func(v: float):
		_rock_config.material["normal_weight"] = v
		if _shared_material != null:
			_shared_material.set_shader_parameter("normal_weight", v)
	)
	_add_slider(vbox, "mat_height_weight", "Gradiente Altura", 0.0, 1.0, 0.05, func(v: float):
		_rock_config.material["height_weight"] = v
		if _shared_material != null:
			_shared_material.set_shader_parameter("height_weight", v)
	)
	_add_slider(vbox, "mat_variation_strength", "Variación Tonal Instancia", 0.0, 0.50, 0.02, func(v: float):
		_rock_config.material["variation_strength"] = v
		if _shared_material != null:
			_shared_material.set_shader_parameter("variation_strength", v)
	)
	_add_slider(vbox, "mat_roughness", "Rugosidad (Roughness)", 0.1, 1.0, 0.05, func(v: float):
		_rock_config.material["roughness"] = v
		if _shared_material != null:
			_shared_material.set_shader_parameter("roughness", v)
	)
	_add_slider(vbox, "mat_specular", "Especularidad (Specular)", 0.0, 1.0, 0.05, func(v: float):
		_rock_config.material["specular"] = v
		if _shared_material != null:
			_shared_material.set_shader_parameter("specular", v)
	)

# =========================================================================
# HELPERS DE UI Y CONTROLADORES
# =========================================================================

func _create_tab_scroll(tab_parent: TabContainer, tab_name: String) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_parent.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	return scroll

func _get_active_profile() -> RockSizeConfig:
	return _rock_config.get_profile(_selected_category)

func _get_active_cat_key() -> String:
	if _selected_category == RockSizeConfig.Category.LARGE:
		return "large"
	elif _selected_category == RockSizeConfig.Category.MEDIUM:
		return "medium"
	return "small"

func _add_slider(
	parent: Container,
	id: String,
	display_name: String,
	min_v: float,
	max_v: float,
	step: float,
	callback: Callable
) -> void:
	var lbl: Label = Label.new()
	lbl.text = "%s: --" % display_name
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)
	_labels[id] = {"label": lbl, "name": display_name}

	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value_changed.connect(func(v: float):
		lbl.text = "%s: %.2f" % [display_name, v]
		callback.call(v)
	)
	parent.add_child(slider)
	_sliders[id] = slider

func _sync_all_controls() -> void:
	var prof: RockSizeConfig = _get_active_profile()
	var cat_key: String = _get_active_cat_key()

	# Bioma
	_set_slider_value("dist_density", _rock_config.distribution.get("density", 0.15))
	_set_slider_value("dist_min_slope", _rock_config.distribution.get("min_slope_degrees", 15.0))
	_set_slider_value("dist_max_slope", _rock_config.distribution.get("max_slope_degrees", 55.0))

	# Geometría
	_set_slider_value("rings", float(prof.rings))
	_set_slider_value("segments", float(prof.segments))
	_set_slider_value("height_ratio", prof.height_ratio)
	_set_slider_value("irregularity", prof.irregularity)
	_set_slider_value("base_penetration", prof.base_penetration)
	_set_slider_value("num_variants", float(prof.num_variants))

	# Silueta
	_set_slider_value("base_radius_factor", prof.base_radius_factor)
	_set_slider_value("body_bulge_factor", prof.body_bulge_factor)
	_set_slider_value("taper_power", prof.taper_power)
	_set_slider_value("peak_convergence_min", prof.peak_convergence_min)
	_set_slider_value("peak_convergence_max", prof.peak_convergence_max)
	_set_slider_value("apex_elevation_min", prof.apex_elevation_min)
	_set_slider_value("apex_elevation_max", prof.apex_elevation_max)
	_set_slider_value("radial_jitter", prof.radial_jitter)
	_set_slider_value("vertical_jitter", prof.vertical_jitter)
	_set_slider_value("mass_offset_strength", prof.mass_offset_strength)

	# Variación
	_set_slider_value("min_scale", prof.min_scale)
	_set_slider_value("max_scale", prof.max_scale)
	_set_slider_value("max_tilt_degrees", prof.max_tilt_degrees)
	_set_slider_value("slope_tilt_factor", prof.slope_tilt_factor)

	# Clusters
	var cl: Dictionary = _rock_config.clustering.get(cat_key, {})
	_set_slider_value("cluster_prob", float(cl.get("probability", 0.4)))
	_set_slider_value("cluster_min_sat", float(cl.get("min_satellites", 1)))
	_set_slider_value("cluster_max_sat", float(cl.get("max_satellites", 2)))
	_set_slider_value("cluster_dist_min", float(cl.get("min_distance_mult", 0.8)))
	_set_slider_value("cluster_dist_max", float(cl.get("max_distance_mult", 1.6)))

	# Material
	_set_slider_value("mat_normal_weight", float(_rock_config.material.get("normal_weight", 0.55)))
	_set_slider_value("mat_height_weight", float(_rock_config.material.get("height_weight", 0.45)))
	_set_slider_value("mat_variation_strength", float(_rock_config.material.get("variation_strength", 0.15)))
	_set_slider_value("mat_roughness", float(_rock_config.material.get("roughness", 0.85)))
	_set_slider_value("mat_specular", float(_rock_config.material.get("specular", 0.15)))

func _set_slider_value(id: String, val: Variant) -> void:
	if val == null:
		return
	if _sliders.has(id):
		var slider: HSlider = _sliders[id]
		slider.set_value_no_signal(float(val))
		if _labels.has(id):
			var info: Dictionary = _labels[id]
			info["label"].text = "%s: %.2f" % [info["name"], float(val)]

func _show_toast(msg: String) -> void:
	if _toast_label != null:
		_toast_label.text = msg
		_toast_timer = 4.0

func _on_save_default_json() -> void:
	var path: String = "res://assets/config/rocks/%s_rocks.json" % _rock_config.biome.to_lower()
	var err: Error = _rock_config.save_to_json(path)
	if err == OK:
		_show_toast("Guardado exitoso en %s" % path)
	else:
		_show_toast("Error al guardar en %s: %d" % [path, err])

func _setup_file_dialog(canvas: CanvasLayer) -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.json ; Archivos de Configuración JSON"])
	_file_dialog.file_selected.connect(_on_file_selected)
	canvas.add_child(_file_dialog)

func _on_file_selected(path: String) -> void:
	if _file_dialog_mode == 0:
		# Cargar
		var err: Error = _rock_config.load_from_json(path)
		if err == OK:
			if _biome_name_edit != null:
				_biome_name_edit.text = _rock_config.biome
			_sync_all_controls()
			_populate_showcase()
			_show_toast("Cargado exitoso: %s" % path.get_file())
		else:
			_show_toast("Error al cargar JSON: %d" % err)
	else:
		# Guardar Como
		var err: Error = _rock_config.save_to_json(path)
		if err == OK:
			_show_toast("Guardado exitoso: %s" % path.get_file())
		else:
			_show_toast("Error al guardar: %d" % err)

# =========================================================================
# ENTRADAS DE USUARIO (CÁMARA ORBITAL Y NAVEGACIÓN)
# =========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = max(4.0, _cam_distance - 1.2)
			_update_camera_transform()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = min(60.0, _cam_distance + 1.2)
			_update_camera_transform()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _is_orbiting:
			var delta: Vector2 = mm.relative
			_cam_yaw -= delta.x * 0.35
			_cam_pitch += delta.y * 0.35
			_update_camera_transform()
		elif _is_panning:
			var delta: Vector2 = mm.relative
			var pan_speed: float = _cam_distance * 0.0018
			var right_dir: Vector3 = _cam.global_transform.basis.x
			var forward_dir: Vector3 = -_cam.global_transform.basis.z
			forward_dir.y = 0.0
			forward_dir = forward_dir.normalized()
			_cam_pivot.position += (-right_dir * delta.x + forward_dir * delta.y) * pan_speed

	elif event is InputEventKey:
		var ek: InputEventKey = event
		if ek.pressed and ek.keycode == KEY_SPACE:
			_cam_pivot.position = Vector3(0.0, 1.5, 0.0)
			_cam_yaw = 0.0
			_cam_pitch = -32.0
			_cam_distance = 20.0
			_update_camera_transform()
