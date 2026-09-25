extends Node3D

## Laboratorio Visual Interactivo para el Sistema Procedural de Rocas.
## Incluye cámara orbital completa (giro, zoom, paneo) y panel de control en tiempo real
## para modificar todos los parámetros de generación geométrica, distribución y shader.

const RockSizeProfile = preload("res://src/rock_generation/rock_size_profile.gd")
const RockMeshBuilder = preload("res://src/rock_generation/rock_mesh_builder.gd")
const RockMaterial = preload("res://src/rock_generation/rock_material.gd")
const RockInstance = preload("res://src/rock_generation/rock_instance.gd")
const RockGeneration = preload("res://src/rock_generation/rock_generation.gd")

# Contenedor de nodos de rocas para poder regenerarlas al vuelo
var _rocks_container: Node3D = null
var _shared_material: ShaderMaterial = null
var _profiles: Dictionary = {}
var _current_seed: int = 4242
var _selected_category: int = RockSizeProfile.Category.LARGE

# Configuración de Cámara Orbital
var _cam_pivot: Node3D = null
var _cam: Camera3D = null
var _cam_distance: float = 18.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = -32.0
var _is_orbiting: bool = false
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# Referencias a controles UI
var _sliders: Dictionary = {}
var _labels: Dictionary = {}

func _ready() -> void:
	_profiles = RockSizeProfile.get_all_profiles()
	_shared_material = RockMaterial.create_rock_material()

	_setup_environment()
	_setup_orbit_camera()
	_setup_rocks_container()
	_populate_showcase()
	_setup_ui()

func _setup_environment() -> void:
	# 1. Luz Direccional (Sol estilizado)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	# 2. Luz de relleno ambiente
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnv"
	var sky_env: Environment = Environment.new()
	sky_env.background_mode = Environment.BG_COLOR
	sky_env.background_color = Color(0.18, 0.22, 0.26)
	sky_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky_env.ambient_light_color = Color(0.48, 0.55, 0.60)
	sky_env.ambient_light_energy = 0.95
	sky_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = sky_env
	add_child(env)

	# 3. Suelo de referencia
	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = Vector2(80, 80)
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.28, 0.35, 0.24) # Verde Taiga
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

## Genera y coloca las variantes y el cluster usando la configuración actual
func _populate_showcase() -> void:
	# Limpiar instancias anteriores
	for child in _rocks_container.get_children():
		child.queue_free()

	var rock_gen: RockGeneration = RockGeneration.new(_current_seed, _profiles)
	rock_gen.shared_material = _shared_material

	var large_profile: RockSizeProfile = _profiles[RockSizeProfile.Category.LARGE]
	var medium_profile: RockSizeProfile = _profiles[RockSizeProfile.Category.MEDIUM]
	var small_profile: RockSizeProfile = _profiles[RockSizeProfile.Category.SMALL]

	# --- COLUMNA 1: ROCAS GRANDES (X = -9.0) ---
	for v in range(large_profile.num_variants):
		var mesh: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.LARGE, v)
		var inst: RockInstance = RockInstance.create(
			Vector3(-9.0, 0.0, -6.0 + float(v) * 5.0),
			large_profile,
			_current_seed + 100 + v,
			Vector3.UP,
			RockSizeProfile.Category.LARGE
		)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Large_Variant_%d" % v
		mi.mesh = mesh
		mi.transform = inst.transform
		mi.material_override = _shared_material
		_rocks_container.add_child(mi)

	# --- COLUMNA 2: ROCAS MEDIANAS (X = -2.5) ---
	for v in range(medium_profile.num_variants):
		var mesh: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.MEDIUM, v)
		var inst: RockInstance = RockInstance.create(
			Vector3(-2.5, 0.0, -6.0 + float(v) * 3.4),
			medium_profile,
			_current_seed + 200 + v,
			Vector3.UP,
			RockSizeProfile.Category.MEDIUM
		)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Medium_Variant_%d" % v
		mi.mesh = mesh
		mi.transform = inst.transform
		mi.material_override = _shared_material
		_rocks_container.add_child(mi)

	# --- FILA FRONTAL: ROCAS MINÚSCULAS (Z = 5.5) ---
	for v in range(6):
		var mesh: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.SMALL, v % small_profile.num_variants)
		var inst: RockInstance = RockInstance.create(
			Vector3(-10.0 + float(v) * 2.2, 0.0, 5.5),
			small_profile,
			_current_seed + 300 + v,
			Vector3.UP,
			RockSizeProfile.Category.SMALL
		)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Small_Variant_%d" % v
		mi.mesh = mesh
		mi.transform = inst.transform
		mi.material_override = _shared_material
		_rocks_container.add_child(mi)

	# --- SECCIÓN DERECHA: CLUSTER NATURAL (Centro en X = 6.5, Z = -1.0) ---
	var cl_large_mesh: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.LARGE, 0)
	var cl_large_inst: RockInstance = RockInstance.create(
		Vector3(6.5, 0.0, -1.0),
		large_profile,
		_current_seed + 777,
		Vector3.UP,
		RockSizeProfile.Category.LARGE
	)
	var mi_cl_l: MeshInstance3D = MeshInstance3D.new()
	mi_cl_l.name = "Cluster_Large"
	mi_cl_l.mesh = cl_large_mesh
	mi_cl_l.transform = cl_large_inst.transform
	mi_cl_l.material_override = _shared_material
	_rocks_container.add_child(mi_cl_l)

	var med_offsets: Array[Vector3] = [Vector3(-2.8, 0.0, 1.4), Vector3(2.5, 0.0, -1.6)]
	for i in range(med_offsets.size()):
		var m_mesh: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.MEDIUM, i % medium_profile.num_variants)
		var m_inst: RockInstance = RockInstance.create(
			Vector3(6.5, 0.0, -1.0) + med_offsets[i],
			medium_profile,
			_current_seed + 800 + i,
			Vector3.UP,
			RockSizeProfile.Category.MEDIUM
		)
		var mi_m: MeshInstance3D = MeshInstance3D.new()
		mi_m.name = "Cluster_Medium_%d" % i
		mi_m.mesh = m_mesh
		mi_m.transform = m_inst.transform
		mi_m.material_override = _shared_material
		_rocks_container.add_child(mi_m)

	var small_angles: Array[float] = [0.2, 1.2, 2.3, 3.4, 4.5, 5.6]
	for i in range(small_angles.size()):
		var rad: float = small_angles[i]
		var dist: float = 3.0 + (i % 3) * 0.9
		var s_pos: Vector3 = Vector3(6.5 + cos(rad) * dist, 0.0, -1.0 + sin(rad) * dist)
		var s_mesh: ArrayMesh = rock_gen.get_mesh(RockSizeProfile.Category.SMALL, i % small_profile.num_variants)
		var s_inst: RockInstance = RockInstance.create(
			s_pos,
			small_profile,
			_current_seed + 900 + i,
			Vector3.UP,
			RockSizeProfile.Category.SMALL
		)
		var mi_s: MeshInstance3D = MeshInstance3D.new()
		mi_s.name = "Cluster_Small_%d" % i
		mi_s.mesh = s_mesh
		mi_s.transform = s_inst.transform
		mi_s.material_override = _shared_material
		_rocks_container.add_child(mi_s)

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
			_cam_distance = min(45.0, _cam_distance + 1.2)
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

func _process(delta: float) -> void:
	# Movimiento suave de pivote con teclado (WASD / Flechas)
	var move_vec: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0

	if move_vec != Vector3.ZERO:
		var move_speed: float = 12.0 * delta
		var right_dir: Vector3 = _cam.global_transform.basis.x
		right_dir.y = 0.0
		right_dir = right_dir.normalized()
		var forward_dir: Vector3 = -_cam.global_transform.basis.z
		forward_dir.y = 0.0
		forward_dir = forward_dir.normalized()
		_cam_pivot.position += (right_dir * move_vec.x + forward_dir * move_vec.z) * move_speed

# =========================================================================
# INTERFAZ DE USUARIO (PANEL DE CONTROL INTERACTIVO)
# =========================================================================

func _setup_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "UILayer"
	add_child(canvas)

	# Panel contenedor semi-transparente
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ControlPanel"
	panel.custom_minimum_size = Vector2(360, 680)
	panel.position = Vector2(16, 16)
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.15, 0.88)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Título
	var title: Label = Label.new()
	title.text = "Configuración de Rocas Taiga"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(title)

	var help_lbl: Label = Label.new()
	help_lbl.text = "Click Der: Orbitar | Rueda: Zoom | WASD/Medio: Paneo"
	help_lbl.add_theme_font_size_override("font_size", 11)
	help_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.80))
	vbox.add_child(help_lbl)

	vbox.add_child(HSeparator.new())

	# Fila de Semilla
	var seed_row: HBoxContainer = HBoxContainer.new()
	var seed_lbl: Label = Label.new()
	seed_lbl.text = "Semilla: %d" % _current_seed
	seed_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_labels["seed"] = seed_lbl
	seed_row.add_child(seed_lbl)

	var btn_rand: Button = Button.new()
	btn_rand.text = "🎲 Random"
	btn_rand.pressed.connect(func():
		_current_seed = randi() % 999999
		seed_lbl.text = "Semilla: %d" % _current_seed
		_populate_showcase()
	)
	seed_row.add_child(btn_rand)
	vbox.add_child(seed_row)

	# Selector de Categoría a editar
	var cat_label: Label = Label.new()
	cat_label.text = "Categoría a Modificar:"
	vbox.add_child(cat_label)

	var cat_select: OptionButton = OptionButton.new()
	cat_select.add_item("Rocas Grandes", RockSizeProfile.Category.LARGE)
	cat_select.add_item("Rocas Medianas", RockSizeProfile.Category.MEDIUM)
	cat_select.add_item("Rocas Minúsculas", RockSizeProfile.Category.SMALL)
	cat_select.selected = 0
	cat_select.item_selected.connect(func(idx: int):
		_selected_category = cat_select.get_item_id(idx)
		_sync_sliders_with_profile()
	)
	vbox.add_child(cat_select)

	vbox.add_child(HSeparator.new())

	# --- PARÁMETROS GEOMÉTRICOS ---
	_add_slider(vbox, "irregularity", "Irregularidad", 0.0, 1.0, 0.02, func(v: float):
		_get_active_profile().irregularity = v
		_populate_showcase()
	)
	_add_slider(vbox, "rings", "Anillos (Rings)", 3.0, 7.0, 1.0, func(v: float):
		_get_active_profile().rings = int(v)
		_populate_showcase()
	)
	_add_slider(vbox, "segments", "Segmentos (Segments)", 5.0, 14.0, 1.0, func(v: float):
		_get_active_profile().segments = int(v)
		_populate_showcase()
	)
	_add_slider(vbox, "height_ratio", "Relación Altura (Y)", 0.4, 2.2, 0.05, func(v: float):
		_get_active_profile().height_ratio = v
		_populate_showcase()
	)
	_add_slider(vbox, "min_scale", "Escala Mínima", 0.1, 4.0, 0.05, func(v: float):
		_get_active_profile().min_scale = v
		_populate_showcase()
	)
	_add_slider(vbox, "max_scale", "Escala Máxima", 0.2, 8.0, 0.05, func(v: float):
		_get_active_profile().max_scale = v
		_populate_showcase()
	)
	_add_slider(vbox, "base_penetration", "Penetración Base", 0.0, 0.5, 0.02, func(v: float):
		_get_active_profile().base_penetration = v
		_populate_showcase()
	)

	vbox.add_child(HSeparator.new())

	# --- PARÁMETROS DE SHADER / MATERIAL ---
	var mat_title: Label = Label.new()
	mat_title.text = "Material & Shader:"
	mat_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(mat_title)

	_add_slider(vbox, "normal_weight", "Luz Normal (UP)", 0.0, 1.0, 0.05, func(v: float):
		if _shared_material != null:
			_shared_material.set_shader_parameter("normal_weight", v)
	)
	_add_slider(vbox, "height_weight", "Gradiente Altura", 0.0, 1.0, 0.05, func(v: float):
		if _shared_material != null:
			_shared_material.set_shader_parameter("height_weight", v)
	)
	_add_slider(vbox, "variation_strength", "Variación Instancia", 0.0, 0.4, 0.02, func(v: float):
		if _shared_material != null:
			_shared_material.set_shader_parameter("variation_strength", v)
	)
	_add_slider(vbox, "roughness", "Rugosidad (Roughness)", 0.1, 1.0, 0.05, func(v: float):
		if _shared_material != null:
			_shared_material.set_shader_parameter("roughness", v)
	)

	vbox.add_child(HSeparator.new())

	# Botón Regenerar
	var btn_regen: Button = Button.new()
	btn_regen.text = "🔄 Regenerar Mallas"
	btn_regen.pressed.connect(func(): _populate_showcase())
	vbox.add_child(btn_regen)

	# Botón Reset Perfiles por defecto
	var btn_reset: Button = Button.new()
	btn_reset.text = "↩️ Restaurar Valores Canónicos"
	btn_reset.pressed.connect(func():
		_profiles = RockSizeProfile.get_all_profiles()
		_sync_sliders_with_profile()
		_populate_showcase()
	)
	vbox.add_child(btn_reset)

	_sync_sliders_with_profile()

func _get_active_profile() -> RockSizeProfile:
	return _profiles[_selected_category]

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

func _sync_sliders_with_profile() -> void:
	var prof: RockSizeProfile = _get_active_profile()
	_set_slider_value("irregularity", prof.irregularity)
	_set_slider_value("rings", float(prof.rings))
	_set_slider_value("segments", float(prof.segments))
	_set_slider_value("height_ratio", prof.height_ratio)
	_set_slider_value("min_scale", prof.min_scale)
	_set_slider_value("max_scale", prof.max_scale)
	_set_slider_value("base_penetration", prof.base_penetration)

	if _shared_material != null:
		_set_slider_value("normal_weight", _shared_material.get_shader_parameter("normal_weight"))
		_set_slider_value("height_weight", _shared_material.get_shader_parameter("height_weight"))
		_set_slider_value("variation_strength", _shared_material.get_shader_parameter("variation_strength"))
		_set_slider_value("roughness", _shared_material.get_shader_parameter("roughness"))

func _set_slider_value(id: String, val: Variant) -> void:
	if val == null:
		return
	if _sliders.has(id):
		var slider: HSlider = _sliders[id]
		slider.set_value_no_signal(float(val))
		if _labels.has(id):
			var info: Dictionary = _labels[id]
			info["label"].text = "%s: %.2f" % [info["name"], float(val)]
