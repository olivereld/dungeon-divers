class_name DungeonVisualizer
extends Control

## Visualizador y Generador 2D interactivo a pantalla completa con soporte multinivel (Fase 10 / M8) y transición a 3D.
## Estructura de diseño:
## - Panel Izquierdo: Configuración completa, Estadísticas globales/piso, Leyenda y Botón de Generación 3D.
## - Panel Derecho: Segmentación en rejilla multinivel ("PISO 1", "PISO 2", "PISO 3", "PISO 4") o vista de piso aislado.
## - Toolbar 3D Flotante: Controles limpios de visualización 3D (Selector de pisos aislados, Ocultar/Mostrar paredes, Modo cámara y Regreso al plano).

signal seed_submitted(seed_val: int)
signal random_seed_requested()
signal floors_changed(total_floors: int)
signal algorithm_changed(algo_name: String)
signal floor_view_mode_changed(floor_index: int)
signal generate_3d_requested()
signal toggle_2d_view_requested()
signal walls_visibility_toggled(visible: bool)
signal camera_view_toggled()
signal player_follow_toggled(is_following: bool)

signal archetype_changed(archetype_idx: int)
signal preset_changed(preset_idx: int)
signal grid_size_changed(w: int, h: int)
signal mission_depth_changed(depth: int)
signal corridor_width_changed(width: int)

# Señales de Suelos Procedurales
signal floor_pattern_changed(pattern_idx: int)
signal floor_preset_changed(preset_idx: int)
signal floor_tile_size_changed(tile_size: float)
signal floor_margin_changed(margin: float)
signal floor_collision_mode_changed(mode_idx: int)
signal floor_noise_toggled(enabled: bool)

# Señales de Iluminación 3D y Entorno
signal lighting_torch_color_changed(color: Color)
signal lighting_torch_energy_changed(energy: float)
signal lighting_torch_range_changed(range_m: float)
signal lighting_torch_attenuation_changed(attenuation: float)
signal lighting_torch_flicker_toggled(enabled: bool)
signal lighting_torch_flicker_amp_changed(amp: float)
signal lighting_torch_shadows_toggled(enabled: bool)
signal lighting_ambient_color_changed(color: Color)
signal lighting_ambient_energy_changed(energy: float)
signal lighting_rim_color_changed(color: Color)
signal lighting_rim_energy_changed(energy: float)
signal lighting_fog_density_changed(density: float)

const _DungeonAsciiExporterScript = preload("res://src/dungeon_generator/debug/dungeon_ascii_exporter.gd")
const _DoorPhysicalValidatorScript = preload("res://src/dungeon_generator/core/validation/door_physical_validator.gd")
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _LightingProfileScript = preload("res://src/dungeon_lighting/config/lighting_profile.gd")

var _last_result: RefCounted = null # DungeonResult o DungeonFloorData
var _last_semantic: DungeonSemanticResult = null
var _last_multi_result: DungeonMultiFloorResult = null
var _selected_floor_view: int = -1 # -1 = Todos los pisos en rejilla segmentada, >= 0 = Piso específico

# Controles de Pestañas
var _tab_btn_params: Button = null
var _tab_btn_floors: Button = null
var _tab_params_container: VBoxContainer = null
var _tab_floors_container: VBoxContainer = null

# Controles de Configuración en el Plano 2D (Parámetros)
var _preview_overlay: ColorRect = null
var _preview_canvas: Control = null
var _seed_line_edit: LineEdit = null
var _opt_archetype: OptionButton = null
var _opt_algorithm: OptionButton = null
var _spin_floors: SpinBox = null
var _opt_floor_view: OptionButton = null
var _opt_preset: OptionButton = null
var _spin_grid_w: SpinBox = null
var _spin_grid_h: SpinBox = null
var _spin_depth: SpinBox = null
var _spin_corridor_w: SpinBox = null
var _btn_generate_2d: Button = null
var _btn_random: Button = null
var _btn_copy: Button = null
var _btn_copy_ascii: Button = null
var _btn_build_3d: Button = null
var _btn_back_to_2d: Button = null
var _info_stats_label: RichTextLabel = null

# Controles de Configuración de Suelos 3D
var _opt_floor_pattern: OptionButton = null
var _opt_floor_preset: OptionButton = null
var _slider_floor_size: HSlider = null
var _lbl_floor_size: Label = null
var _slider_floor_margin: HSlider = null
var _lbl_floor_margin: Label = null
var _opt_floor_collision: OptionButton = null
var _check_floor_noise: CheckBox = null

# Controles de la Toolbar 3D
var _hud_3d_panel: PanelContainer = null
var _opt_3d_floor_view: OptionButton = null
var _btn_3d_toggle_walls: Button = null
var _btn_3d_toggle_cam: Button = null
var _btn_3d_toggle_player: Button = null
var _walls_visible: bool = true
var _player_follow_active: bool = true

var is_2d_preview_mode: bool = true

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = MOUSE_FILTER_IGNORE

	_setup_2d_full_interface()
	_setup_3d_hud()

func _setup_2d_full_interface() -> void:
	if _preview_overlay != null:
		return

	# 1. Fondo completo oscuro y elegante
	_preview_overlay = ColorRect.new()
	_preview_overlay.name = "Preview2DOverlay"
	_preview_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_preview_overlay.anchor_right = 1.0
	_preview_overlay.anchor_bottom = 1.0
	_preview_overlay.offset_right = 0.0
	_preview_overlay.offset_bottom = 0.0
	_preview_overlay.color = Color(0.06, 0.08, 0.12, 1.0)
	_preview_overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(_preview_overlay)

	# 2. Margen principal de pantalla completa
	var margin_container := MarginContainer.new()
	margin_container.anchors_preset = Control.PRESET_FULL_RECT
	margin_container.anchor_right = 1.0
	margin_container.anchor_bottom = 1.0
	margin_container.offset_right = 0.0
	margin_container.offset_bottom = 0.0
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 16)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	_preview_overlay.add_child(margin_container)

	# 3. Contenedor horizontal: Sidebar Izquierda + Canvas Derecho
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = SIZE_EXPAND_FILL
	margin_container.add_child(main_hbox)

	# ==========================================
	# SIDEBAR IZQUIERDA (Configuración + Estadísticas + Acciones)
	# ==========================================
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(360, 0)
	sidebar.size_flags_vertical = SIZE_EXPAND_FILL

	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = Color(0.10, 0.13, 0.18, 0.98)
	sidebar_style.border_color = Color(0.25, 0.35, 0.50, 0.8)
	sidebar_style.set_border_width_all(1)
	sidebar_style.set_corner_radius_all(10)
	sidebar_style.content_margin_left = 16.0
	sidebar_style.content_margin_right = 16.0
	sidebar_style.content_margin_top = 14.0
	sidebar_style.content_margin_bottom = 14.0
	sidebar.add_theme_stylebox_override("panel", sidebar_style)
	main_hbox.add_child(sidebar)

	var scroll_sidebar := ScrollContainer.new()
	scroll_sidebar.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_sidebar.size_flags_vertical = SIZE_EXPAND_FILL
	sidebar.add_child(scroll_sidebar)

	var sidebar_vbox := VBoxContainer.new()
	sidebar_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	sidebar_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	sidebar_vbox.add_theme_constant_override("separation", 12)
	scroll_sidebar.add_child(sidebar_vbox)

	# Título
	var header_box := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "🏰 DUNGEON GENERATOR"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.30, 1.0))
	header_box.add_child(title_lbl)
	sidebar_vbox.add_child(header_box)

	var sep1 := HSeparator.new()
	sidebar_vbox.add_child(sep1)

	# --- BARRA DE PESTAÑAS (PARÁMETROS / SUELOS) ---
	var tab_bar_hbox := HBoxContainer.new()
	tab_bar_hbox.add_theme_constant_override("separation", 6)

	_tab_btn_params = Button.new()
	_tab_btn_params.text = "⚙️ Parámetros"
	_tab_btn_params.size_flags_horizontal = SIZE_EXPAND_FILL
	_tab_btn_params.pressed.connect(func(): _switch_tab(0))
	tab_bar_hbox.add_child(_tab_btn_params)

	_tab_btn_floors = Button.new()
	_tab_btn_floors.text = "🏛️ Suelos"
	_tab_btn_floors.size_flags_horizontal = SIZE_EXPAND_FILL
	_tab_btn_floors.pressed.connect(func(): _switch_tab(1))
	tab_bar_hbox.add_child(_tab_btn_floors)

	sidebar_vbox.add_child(tab_bar_hbox)

	# =========================================================================
	# PESTAÑA 0: PARÁMETROS GENERALES
	# =========================================================================
	_tab_params_container = VBoxContainer.new()
	_tab_params_container.add_theme_constant_override("separation", 10)
	sidebar_vbox.add_child(_tab_params_container)

	# Fila Semilla
	var seed_vbox := VBoxContainer.new()
	seed_vbox.add_theme_constant_override("separation", 4)

	var seed_lbl := Label.new()
	seed_lbl.text = "Semilla Actual:"
	seed_lbl.add_theme_font_size_override("font_size", 12)
	seed_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	seed_vbox.add_child(seed_lbl)

	var seed_input_hbox := HBoxContainer.new()
	seed_input_hbox.add_theme_constant_override("separation", 6)

	_seed_line_edit = LineEdit.new()
	_seed_line_edit.placeholder_text = "Semilla..."
	_seed_line_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_seed_line_edit.select_all_on_focus = true
	_seed_line_edit.text_submitted.connect(_on_line_edit_submitted)
	seed_input_hbox.add_child(_seed_line_edit)

	_btn_copy = Button.new()
	_btn_copy.text = "📋"
	_btn_copy.tooltip_text = "Copiar semilla"
	_btn_copy.pressed.connect(_on_copy_pressed)
	seed_input_hbox.add_child(_btn_copy)

	_btn_random = Button.new()
	_btn_random.text = "🎲 Aleatoria"
	_btn_random.tooltip_text = "Generar semilla aleatoria [R]"
	_btn_random.pressed.connect(_on_random_pressed)
	seed_input_hbox.add_child(_btn_random)

	seed_vbox.add_child(seed_input_hbox)
	_tab_params_container.add_child(seed_vbox)

	# Fila Arquetipo de Mazmorra (Fase 10)
	var arch_vbox := VBoxContainer.new()
	arch_vbox.add_theme_constant_override("separation", 4)

	var arch_lbl := Label.new()
	arch_lbl.text = "Arquetipo Arquitectónico:"
	arch_lbl.add_theme_font_size_override("font_size", 12)
	arch_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	arch_vbox.add_child(arch_lbl)

	_opt_archetype = OptionButton.new()
	_opt_archetype.add_item("Crypt / Mausoleum (Referencia)", 1)
	_opt_archetype.add_item("Fortress", 2)
	_opt_archetype.add_item("Temple", 3)
	_opt_archetype.add_item("Mine", 4)
	_opt_archetype.add_item("Generic", 0)
	_opt_archetype.selected = 0 # Crypt por defecto
	_opt_archetype.item_selected.connect(func(idx: int):
		var arch_id: int = _opt_archetype.get_item_id(idx)
		archetype_changed.emit(arch_id)
	)
	arch_vbox.add_child(_opt_archetype)
	_tab_params_container.add_child(arch_vbox)

	# Fila Algoritmo
	var algo_vbox := VBoxContainer.new()
	algo_vbox.add_theme_constant_override("separation", 4)

	var algo_lbl := Label.new()
	algo_lbl.text = "Algoritmo de Generación:"
	algo_lbl.add_theme_font_size_override("font_size", 12)
	algo_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	algo_vbox.add_child(algo_lbl)

	_opt_algorithm = OptionButton.new()
	_opt_algorithm.add_item("Hybrid (Recomendado)", 0)
	_opt_algorithm.add_item("BSP (Arquitectónico)", 1)
	_opt_algorithm.add_item("CellularAutomata (Cuevas)", 2)
	_opt_algorithm.item_selected.connect(_on_algorithm_selected)
	algo_vbox.add_child(_opt_algorithm)
	_tab_params_container.add_child(algo_vbox)

	# Fila Tamaño / Presets
	var preset_vbox := VBoxContainer.new()
	preset_vbox.add_theme_constant_override("separation", 4)

	var preset_lbl := Label.new()
	preset_lbl.text = "Escala / Preset:"
	preset_lbl.add_theme_font_size_override("font_size", 12)
	preset_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	preset_vbox.add_child(preset_lbl)

	_opt_preset = OptionButton.new()
	_opt_preset.add_item("Estándar (64x64)", 0)
	_opt_preset.add_item("Compacto (32x32)", 1)
	_opt_preset.add_item("Amplio (96x96)", 2)
	_opt_preset.add_item("Monumental (128x128)", 3)
	_opt_preset.item_selected.connect(func(idx: int):
		preset_changed.emit(idx)
	)
	preset_vbox.add_child(_opt_preset)
	_tab_params_container.add_child(preset_vbox)

	# Fila Ancho x Alto de Rejilla
	var dims_vbox := VBoxContainer.new()
	dims_vbox.add_theme_constant_override("separation", 4)

	var dims_lbl := Label.new()
	dims_lbl.text = "Dimensiones de Rejilla (Ancho x Alto):"
	dims_lbl.add_theme_font_size_override("font_size", 12)
	dims_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	dims_vbox.add_child(dims_lbl)

	var dims_hbox := HBoxContainer.new()
	dims_hbox.add_theme_constant_override("separation", 6)

	_spin_grid_w = SpinBox.new()
	_spin_grid_w.min_value = 16
	_spin_grid_w.max_value = 256
	_spin_grid_w.value = 64
	_spin_grid_w.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_grid_w.value_changed.connect(func(_v: float):
		grid_size_changed.emit(int(_spin_grid_w.value), int(_spin_grid_h.value))
	)
	dims_hbox.add_child(_spin_grid_w)

	var times_lbl := Label.new()
	times_lbl.text = "x"
	dims_hbox.add_child(times_lbl)

	_spin_grid_h = SpinBox.new()
	_spin_grid_h.min_value = 16
	_spin_grid_h.max_value = 256
	_spin_grid_h.value = 64
	_spin_grid_h.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_grid_h.value_changed.connect(func(_v: float):
		grid_size_changed.emit(int(_spin_grid_w.value), int(_spin_grid_h.value))
	)
	dims_hbox.add_child(_spin_grid_h)
	dims_vbox.add_child(dims_hbox)
	_tab_params_container.add_child(dims_vbox)

	# Fila Profundidad de Misión & Ancho de Pasillo
	var depth_corridor_hbox := HBoxContainer.new()
	depth_corridor_hbox.add_theme_constant_override("separation", 8)

	var depth_vbox := VBoxContainer.new()
	depth_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	depth_vbox.add_theme_constant_override("separation", 4)
	var depth_lbl := Label.new()
	depth_lbl.text = "Profundidad Misión:"
	depth_lbl.add_theme_font_size_override("font_size", 11)
	depth_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	depth_vbox.add_child(depth_lbl)
	_spin_depth = SpinBox.new()
	_spin_depth.min_value = 2
	_spin_depth.max_value = 20
	_spin_depth.value = 5
	_spin_depth.value_changed.connect(func(v: float):
		mission_depth_changed.emit(int(v))
	)
	depth_vbox.add_child(_spin_depth)
	depth_corridor_hbox.add_child(depth_vbox)

	var corr_vbox := VBoxContainer.new()
	corr_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	corr_vbox.add_theme_constant_override("separation", 4)
	var corr_lbl := Label.new()
	corr_lbl.text = "Ancho Pasillo:"
	corr_lbl.add_theme_font_size_override("font_size", 11)
	corr_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	corr_vbox.add_child(corr_lbl)
	_spin_corridor_w = SpinBox.new()
	_spin_corridor_w.min_value = 1
	_spin_corridor_w.max_value = 4
	_spin_corridor_w.value = 2
	_spin_corridor_w.value_changed.connect(func(v: float):
		corridor_width_changed.emit(int(v))
	)
	corr_vbox.add_child(_spin_corridor_w)
	depth_corridor_hbox.add_child(corr_vbox)
	_tab_params_container.add_child(depth_corridor_hbox)

	# Fila Pisos Multinivel
	var floors_hbox := HBoxContainer.new()
	floors_hbox.add_theme_constant_override("separation", 8)

	var floors_lbl := Label.new()
	floors_lbl.text = "Pisos:"
	floors_lbl.add_theme_font_size_override("font_size", 12)
	floors_hbox.add_child(floors_lbl)

	_spin_floors = SpinBox.new()
	_spin_floors.min_value = 1
	_spin_floors.max_value = 10
	_spin_floors.value = 1
	_spin_floors.value_changed.connect(func(v: float):
		floors_changed.emit(int(v))
	)
	floors_hbox.add_child(_spin_floors)

	_opt_floor_view = OptionButton.new()
	_opt_floor_view.size_flags_horizontal = SIZE_EXPAND_FILL
	_opt_floor_view.item_selected.connect(func(idx: int):
		var floor_id = _opt_floor_view.get_item_id(idx)
		_selected_floor_view = floor_id
		if _opt_3d_floor_view != null:
			_opt_3d_floor_view.select(idx)
		floor_view_mode_changed.emit(floor_id)
		if _preview_canvas != null:
			_preview_canvas.queue_redraw()
		_update_stats_panel()
	)
	floors_hbox.add_child(_opt_floor_view)
	update_floor_view_options(1)
	_tab_params_container.add_child(floors_hbox)

	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 8)

	_btn_generate_2d = Button.new()
	_btn_generate_2d.text = "🔄 Regenerar"
	_btn_generate_2d.size_flags_horizontal = SIZE_EXPAND_FILL
	_btn_generate_2d.pressed.connect(_on_generate_pressed)
	actions_hbox.add_child(_btn_generate_2d)

	_btn_copy_ascii = Button.new()
	_btn_copy_ascii.text = "📝 Copiar ASCII"
	_btn_copy_ascii.tooltip_text = "Copiar el plano de la mazmorra en formato texto / código ASCII para pegar en chats"
	_btn_copy_ascii.size_flags_horizontal = SIZE_EXPAND_FILL
	_btn_copy_ascii.pressed.connect(_on_copy_ascii_pressed)
	actions_hbox.add_child(_btn_copy_ascii)

	_tab_params_container.add_child(actions_hbox)

	# =========================================================================
	# PESTAÑA 1: CONFIGURACIÓN DE SUELOS PROCEDURALES
	# =========================================================================
	_tab_floors_container = VBoxContainer.new()
	_tab_floors_container.add_theme_constant_override("separation", 10)
	_tab_floors_container.visible = false
	sidebar_vbox.add_child(_tab_floors_container)

	# Fila Patrón de Suelo
	var pattern_vbox := VBoxContainer.new()
	pattern_vbox.add_theme_constant_override("separation", 4)
	var pattern_lbl := Label.new()
	pattern_lbl.text = "Patrón de Suelo:"
	pattern_lbl.add_theme_font_size_override("font_size", 12)
	pattern_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	pattern_vbox.add_child(pattern_lbl)

	_opt_floor_pattern = OptionButton.new()
	_opt_floor_pattern.add_item("Stylized Stone (Zelda/Diablo)", _FloorTileConfigScript.PatternType.STYLIZED_STONE)
	_opt_floor_pattern.add_item("Cobblestone (Adoquines)", _FloorTileConfigScript.PatternType.COBBLESTONE)
	_opt_floor_pattern.add_item("Brick (Ladrillos)", _FloorTileConfigScript.PatternType.BRICK)
	_opt_floor_pattern.add_item("Smooth Slabs (Losas Amplias)", _FloorTileConfigScript.PatternType.SMOOTH_SLABS)
	_opt_floor_pattern.add_item("Ruined Tiles (Suelo Agrietado)", _FloorTileConfigScript.PatternType.RUINED_TILES)
	_opt_floor_pattern.select(0)
	_opt_floor_pattern.item_selected.connect(func(idx: int):
		floor_pattern_changed.emit(_opt_floor_pattern.get_item_id(idx))
	)
	pattern_vbox.add_child(_opt_floor_pattern)
	_tab_floors_container.add_child(pattern_vbox)

	# Fila Tema / Color de Material PBR
	var preset_floor_vbox := VBoxContainer.new()
	preset_floor_vbox.add_theme_constant_override("separation", 4)
	var preset_floor_lbl := Label.new()
	preset_floor_lbl.text = "Tema / Color de Suelo PBR:"
	preset_floor_lbl.add_theme_font_size_override("font_size", 12)
	preset_floor_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	preset_floor_vbox.add_child(preset_floor_lbl)

	_opt_floor_preset = OptionButton.new()
	_opt_floor_preset.add_item("Pizarra Estilizada (Slate)", 0)
	_opt_floor_preset.add_item("Piedra Cálida (Warm Stone)", 1)
	_opt_floor_preset.add_item("Cripta Oscura (Dark Crypt)", 2)
	_opt_floor_preset.add_item("Ruinas Arenisca (Sandstone)", 3)
	_opt_floor_preset.select(0)
	_opt_floor_preset.item_selected.connect(func(idx: int):
		floor_preset_changed.emit(_opt_floor_preset.get_item_id(idx))
	)
	preset_floor_vbox.add_child(_opt_floor_preset)
	_tab_floors_container.add_child(preset_floor_vbox)

	# Fila Tamaño de Baldosa
	var size_floor_vbox := VBoxContainer.new()
	size_floor_vbox.add_theme_constant_override("separation", 4)
	_lbl_floor_size = Label.new()
	_lbl_floor_size.text = "Tamaño Baldosa: 2.0m"
	_lbl_floor_size.add_theme_font_size_override("font_size", 12)
	_lbl_floor_size.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	size_floor_vbox.add_child(_lbl_floor_size)

	_slider_floor_size = HSlider.new()
	_slider_floor_size.min_value = 1.0
	_slider_floor_size.max_value = 4.0
	_slider_floor_size.step = 0.5
	_slider_floor_size.value = 2.0
	_slider_floor_size.value_changed.connect(func(v: float):
		_lbl_floor_size.text = "Tamaño Baldosa: %.1fm" % v
		floor_tile_size_changed.emit(v)
	)
	size_floor_vbox.add_child(_slider_floor_size)
	_tab_floors_container.add_child(size_floor_vbox)

	# Fila Mortero / Juntas
	var margin_vbox := VBoxContainer.new()
	margin_vbox.add_theme_constant_override("separation", 4)
	_lbl_floor_margin = Label.new()
	_lbl_floor_margin.text = "Mortero / Junta: 0.035m"
	_lbl_floor_margin.add_theme_font_size_override("font_size", 12)
	_lbl_floor_margin.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	margin_vbox.add_child(_lbl_floor_margin)

	_slider_floor_margin = HSlider.new()
	_slider_floor_margin.min_value = 0.01
	_slider_floor_margin.max_value = 0.08
	_slider_floor_margin.step = 0.005
	_slider_floor_margin.value = 0.035
	_slider_floor_margin.value_changed.connect(func(v: float):
		_lbl_floor_margin.text = "Mortero / Junta: %.3fm" % v
		floor_margin_changed.emit(v)
	)
	margin_vbox.add_child(_slider_floor_margin)
	_tab_floors_container.add_child(margin_vbox)

	# Fila Modo de Colisión
	var col_vbox := VBoxContainer.new()
	col_vbox.add_theme_constant_override("separation", 4)
	var col_lbl := Label.new()
	col_lbl.text = "Modo de Colisión Física:"
	col_lbl.add_theme_font_size_override("font_size", 12)
	col_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	col_vbox.add_child(col_lbl)

	_opt_floor_collision = OptionButton.new()
	_opt_floor_collision.add_item("Compound Box (Optimizado)", _FloorTileConfigScript.CollisionMode.COMPOUND_BOX)
	_opt_floor_collision.add_item("Single Box (Caja Única)", _FloorTileConfigScript.CollisionMode.BOX)
	_opt_floor_collision.add_item("Concave Trimesh (Exacto)", _FloorTileConfigScript.CollisionMode.CONCAVE_TRIMESH)
	_opt_floor_collision.add_item("Sin Colisión (None)", _FloorTileConfigScript.CollisionMode.NONE)
	_opt_floor_collision.select(0)
	_opt_floor_collision.item_selected.connect(func(idx: int):
		floor_collision_mode_changed.emit(_opt_floor_collision.get_item_id(idx))
	)
	col_vbox.add_child(_opt_floor_collision)
	_tab_floors_container.add_child(col_vbox)

	# Checkbox Variación Macro / Perlin Noise
	_check_floor_noise = CheckBox.new()
	_check_floor_noise.text = "Modulación Espacial y Ruido Macro"
	_check_floor_noise.button_pressed = true
	_check_floor_noise.toggled.connect(func(toggled: bool):
		floor_noise_toggled.emit(toggled)
	)
	_tab_floors_container.add_child(_check_floor_noise)

	# Inicializar pestañas activas
	_switch_tab(0)

	var sep2 := HSeparator.new()
	sidebar_vbox.add_child(sep2)

	# --- SECCIÓN 2: ESTADÍSTICAS DEL PLANO ---
	var stats_title := Label.new()
	stats_title.text = "📊 INFORMACIÓN DEL PLANO"
	stats_title.add_theme_font_size_override("font_size", 13)
	stats_title.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95, 1.0))
	sidebar_vbox.add_child(stats_title)

	var stats_panel := PanelContainer.new()
	var stats_box_style := StyleBoxFlat.new()
	stats_box_style.bg_color = Color(0.07, 0.09, 0.13, 0.8)
	stats_box_style.border_color = Color(0.20, 0.28, 0.40, 0.6)
	stats_box_style.set_border_width_all(1)
	stats_box_style.set_corner_radius_all(6)
	stats_box_style.content_margin_left = 10.0
	stats_box_style.content_margin_right = 10.0
	stats_box_style.content_margin_top = 8.0
	stats_box_style.content_margin_bottom = 8.0
	stats_panel.add_theme_stylebox_override("panel", stats_box_style)

	_info_stats_label = RichTextLabel.new()
	_info_stats_label.bbcode_enabled = true
	_info_stats_label.fit_content = true
	_info_stats_label.text = "[color=#8899aa]Calculando...[/color]"
	stats_panel.add_child(_info_stats_label)
	sidebar_vbox.add_child(stats_panel)

	# --- SECCIÓN 3: LEYENDA VISUAL ---
	var legend_title := Label.new()
	legend_title.text = "🗺️ LEYENDA"
	legend_title.add_theme_font_size_override("font_size", 13)
	legend_title.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95, 1.0))
	sidebar_vbox.add_child(legend_title)

	var legend_panel := PanelContainer.new()
	var leg_style := StyleBoxFlat.new()
	leg_style.bg_color = Color(0.07, 0.09, 0.13, 0.8)
	leg_style.set_corner_radius_all(6)
	leg_style.content_margin_left = 10.0
	leg_style.content_margin_right = 10.0
	leg_style.content_margin_top = 8.0
	leg_style.content_margin_bottom = 8.0
	legend_panel.add_theme_stylebox_override("panel", leg_style)

	var leg_lbl := RichTextLabel.new()
	leg_lbl.bbcode_enabled = true
	leg_lbl.fit_content = true
	leg_lbl.text = "[color=#f1d240]■ Habitación[/color]   [color=#38b861]■ Pasillo[/color]\n[color=#ef4444]■ Puerta Roja[/color]   [color=#3b82f6]■ Arco Libre[/color]\n[color=#10b981]● Spawn Jugador[/color]   [color=#ef4444]● Boss[/color]\n[color=#3b82f6]🪜 Escalera Arriba[/color]   [color=#8b5cf6]🪜 Escalera Abajo[/color]"
	legend_panel.add_child(leg_lbl)
	sidebar_vbox.add_child(legend_panel)

	# Espaciador vertical
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	sidebar_vbox.add_child(spacer)

	# --- BOTÓN DE ACCIÓN DESTACADO ---
	_btn_build_3d = Button.new()
	_btn_build_3d.text = "🚀 GENERAR MAZMORRA 3D\n[ Espacio / Enter ]"
	_btn_build_3d.custom_minimum_size = Vector2(0, 56)
	_btn_build_3d.add_theme_font_size_override("font_size", 15)
	_btn_build_3d.pressed.connect(_on_build_3d_pressed)
	sidebar_vbox.add_child(_btn_build_3d)

	# ==========================================
	# ÁREA PRINCIPAL DERECHA (Canvas 2D Segmentado)
	# ==========================================
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = SIZE_EXPAND_FILL

	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	right_style.border_color = Color(0.20, 0.30, 0.45, 0.7)
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(10)
	right_style.content_margin_left = 12.0
	right_style.content_margin_right = 12.0
	right_style.content_margin_top = 12.0
	right_style.content_margin_bottom = 12.0
	right_panel.add_theme_stylebox_override("panel", right_style)
	main_hbox.add_child(right_panel)

	_preview_canvas = Control.new()
	_preview_canvas.name = "PreviewCanvas"
	_preview_canvas.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview_canvas.size_flags_vertical = SIZE_EXPAND_FILL
	_preview_canvas.draw.connect(_on_preview_canvas_draw)
	right_panel.add_child(_preview_canvas)

## Configura la barra flotante superior de herramientas de visualización 3D
func _setup_3d_hud() -> void:
	if _hud_3d_panel != null:
		return

	_hud_3d_panel = PanelContainer.new()
	_hud_3d_panel.name = "HUD3DPanel"
	_hud_3d_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_hud_3d_panel.anchor_left = 1.0
	_hud_3d_panel.anchor_right = 1.0
	_hud_3d_panel.offset_left = -690.0
	_hud_3d_panel.offset_right = -18.0
	_hud_3d_panel.offset_top = 16.0
	_hud_3d_panel.offset_bottom = 66.0
	_hud_3d_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.18, 0.94)
	style.border_color = Color(0.30, 0.42, 0.60, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_hud_3d_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	_hud_3d_panel.add_child(hbox)

	# 1. Selector de Pisos en 3D
	_opt_3d_floor_view = OptionButton.new()
	_opt_3d_floor_view.tooltip_text = "Filtrar visualización a un piso específico o ver la torre completa"
	_opt_3d_floor_view.item_selected.connect(func(idx: int):
		var floor_id = _opt_3d_floor_view.get_item_id(idx)
		_selected_floor_view = floor_id
		if _opt_floor_view != null:
			_opt_floor_view.select(idx)
		floor_view_mode_changed.emit(floor_id)
	)
	hbox.add_child(_opt_3d_floor_view)

	# 2. Toggle de Visibilidad de Paredes
	_btn_3d_toggle_walls = Button.new()
	_btn_3d_toggle_walls.text = "🧱 Paredes: ON"
	_btn_3d_toggle_walls.tooltip_text = "Ocultar o mostrar las paredes de la mazmorra 3D"
	_btn_3d_toggle_walls.pressed.connect(func():
		_walls_visible = not _walls_visible
		_btn_3d_toggle_walls.text = "🧱 Paredes: ON" if _walls_visible else "🧱 Paredes: OFF"
		walls_visibility_toggled.emit(_walls_visible)
	)
	hbox.add_child(_btn_3d_toggle_walls)

	# 3. Toggle de Modo de Jugador / Cámara Libre
	_btn_3d_toggle_player = Button.new()
	_btn_3d_toggle_player.text = "👤 Jugador: ON"
	_btn_3d_toggle_player.tooltip_text = "Alternar entre modo de Jugador centrado y Cámara Libre [F]"
	_btn_3d_toggle_player.pressed.connect(func():
		_player_follow_active = not _player_follow_active
		_update_player_follow_btn_text()
		player_follow_toggled.emit(_player_follow_active)
	)
	hbox.add_child(_btn_3d_toggle_player)

	# 4. Toggle de Modo de Cámara
	_btn_3d_toggle_cam = Button.new()
	_btn_3d_toggle_cam.text = "🎥 Cámara [T]"
	_btn_3d_toggle_cam.tooltip_text = "Alternar entre cámara Isométrica y Cenital Top-Down"
	_btn_3d_toggle_cam.pressed.connect(func():
		camera_view_toggled.emit()
	)
	hbox.add_child(_btn_3d_toggle_cam)

	# 5. Botón Volver al Plano 2D
	_btn_back_to_2d = Button.new()
	_btn_back_to_2d.text = "🗺️ Plano 2D [Tab]"
	_btn_back_to_2d.tooltip_text = "Regresar al visor y generador de planos 2D"
	_btn_back_to_2d.pressed.connect(_on_back_to_2d_pressed)
	hbox.add_child(_btn_back_to_2d)

	add_child(_hud_3d_panel)

func set_player_follow_active(active: bool) -> void:
	_player_follow_active = active
	_update_player_follow_btn_text()

func _update_player_follow_btn_text() -> void:
	if _btn_3d_toggle_player != null:
		_btn_3d_toggle_player.text = "👤 Jugador: ON" if _player_follow_active else "🎥 Modo: Libre"

## Dibuja el mapa 2D segmentado en cuadrícula multinivel o vista individual
func _on_preview_canvas_draw() -> void:
	if _preview_canvas == null:
		return

	var canvas_size: Vector2 = _preview_canvas.size
	if canvas_size.x <= 20 or canvas_size.y <= 20:
		return

	# CASO MULTINIVEL
	if _last_multi_result != null and _last_multi_result.get_floor_count() > 0:
		var floor_count: int = _last_multi_result.get_floor_count()

		if _selected_floor_view >= 0 and _selected_floor_view < floor_count:
			# Mostrar solo el piso seleccionado en pantalla completa
			var f_data = _last_multi_result.get_floor(_selected_floor_view)
			if f_data != null:
				var is_entry: bool = (_selected_floor_view == 0)
				var is_boss: bool = (_selected_floor_view == floor_count - 1)
				_draw_floor_blueprint(f_data.grid, f_data.rooms, f_data.door_pairs, f_data.stairs, Rect2(Vector2.ZERO, canvas_size), "PISO %d" % (_selected_floor_view + 1), is_entry, is_boss, _selected_floor_view + 1)
			return

		# Vista segmentada de todos los pisos ("TODOS")
		var cols: int = 1
		var rows: int = 1
		if floor_count == 2:
			cols = 2; rows = 1
		elif floor_count in [3, 4]:
			cols = 2; rows = 2
		elif floor_count in [5, 6]:
			cols = 3; rows = 2
		elif floor_count in [7, 8, 9]:
			cols = 3; rows = 3
		else:
			cols = 4; rows = 3

		var cell_w: float = canvas_size.x / float(cols)
		var cell_h: float = canvas_size.y / float(rows)

		for f_idx in range(floor_count):
			var col: int = f_idx % cols
			var row: int = f_idx / cols
			var cell_rect := Rect2(Vector2(float(col) * cell_w, float(row) * cell_h), Vector2(cell_w, cell_h))

			var f_data = _last_multi_result.get_floor(f_idx)
			if f_data != null and f_data.grid != null:
				var is_entry: bool = (f_idx == 0)
				var is_boss: bool = (f_idx == floor_count - 1)
				_draw_floor_blueprint(f_data.grid, f_data.rooms, f_data.door_pairs, f_data.stairs, cell_rect, "PISO %d" % (f_idx + 1), is_entry, is_boss, f_idx + 1)

		# Dibujar líneas divisorias de cuadrícula
		for c in range(1, cols):
			var x_pos: float = float(c) * cell_w
			_preview_canvas.draw_line(Vector2(x_pos, 0), Vector2(x_pos, canvas_size.y), Color(0.20, 0.28, 0.40, 0.5), 1.0)
		for r in range(1, rows):
			var y_pos: float = float(r) * cell_h
			_preview_canvas.draw_line(Vector2(0, y_pos), Vector2(canvas_size.x, y_pos), Color(0.20, 0.28, 0.40, 0.5), 1.0)
		return

	# CASO MONO-PISO ESTÁNDAR
	if _last_result != null and _last_result.grid != null:
		var rooms: Array = _last_result.rooms
		var door_pairs: Array = _last_result.door_pairs
		var stairs: Array = []
		if "stairs" in _last_result:
			stairs = _last_result.stairs
		_draw_floor_blueprint(_last_result.grid, rooms, door_pairs, stairs, Rect2(Vector2.ZERO, canvas_size), "PISO 1", true, true, 1)

func _draw_floor_blueprint(
	grid: CellGrid,
	rooms: Array,
	door_pairs: Array,
	stairs: Array,
	bounds_rect: Rect2,
	floor_title: String,
	is_entry_floor: bool,
	is_boss_floor: bool,
	floor_number: int = 1
) -> void:
	if grid == null or _preview_canvas == null:
		return

	var gw: int = grid.width
	var gh: int = grid.height
	var margin_top: float = 26.0
	var margin_side: float = 12.0

	var available_w: float = bounds_rect.size.x - (margin_side * 2.0)
	var available_h: float = bounds_rect.size.y - margin_top - margin_side

	if available_w <= 10 or available_h <= 10:
		return

	var tile_scale: float = minf(available_w / float(gw), available_h / float(gh))
	var origin := Vector2(
		bounds_rect.position.x + margin_side + ((available_w - (float(gw) * tile_scale)) * 0.5),
		bounds_rect.position.y + margin_top + ((available_h - (float(gh) * tile_scale)) * 0.5)
	)

	# 1. Dibujar Título del Piso (con estilo nítido y tamaño proporcional)
	var title_pos := bounds_rect.position + Vector2(margin_side, 18.0)
	_preview_canvas.draw_string(
		ThemeDB.fallback_font,
		title_pos,
		floor_title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(0.95, 0.95, 0.95, 0.9)
	)

	# 2. Dibujar celdas base
	for y in range(gh):
		for x in range(gw):
			var pos := Vector2i(x, y)
			var ctype: int = grid.get_cell(pos)
			var rect := Rect2(origin + Vector2(x, y) * tile_scale, Vector2(tile_scale, tile_scale))

			match ctype:
				CellGrid.CellType.FLOOR:
					_preview_canvas.draw_rect(rect, Color("#f1d240")) # Amarillo
				CellGrid.CellType.CORRIDOR:
					_preview_canvas.draw_rect(rect, Color("#38b861")) # Verde
				CellGrid.CellType.DOOR:
					_preview_canvas.draw_rect(rect, Color("#38b861"))
				CellGrid.CellType.WALL:
					_preview_canvas.draw_rect(rect, Color("#181b22")) # Muro oscuro
				CellGrid.CellType.COLUMN:
					_preview_canvas.draw_rect(rect, Color("#475569"))
				CellGrid.CellType.STAIRS_UP:
					_preview_canvas.draw_rect(rect, Color("#3b82f6")) # Azul
				CellGrid.CellType.STAIRS_DOWN:
					_preview_canvas.draw_rect(rect, Color("#8b5cf6")) # Púrpura
				CellGrid.CellType.SPAWN:
					_preview_canvas.draw_rect(rect, Color("#10b981"))
				_:
					_preview_canvas.draw_rect(rect, Color("#0d1017"))

	# 3. Dibujar puertas y arcos
	if door_pairs != null:
		for dp in door_pairs:
			if dp == null:
				continue
			_draw_door_marker(dp.door_a, grid, origin, tile_scale)
			_draw_door_marker(dp.door_b, grid, origin, tile_scale)

	# 4. Dibujar contornos de habitaciones y etiquetas compactas
	for r in rooms:
		if r != null:
			var c_pos: Vector2 = origin + Vector2(r.rect.position.x, r.rect.position.y) * tile_scale
			var r_size: Vector2 = Vector2(r.rect.size.x, r.rect.size.y) * tile_scale
			var r_rect := Rect2(c_pos, r_size)
			_preview_canvas.draw_rect(r_rect, Color(1, 1, 1, 0.40), false, 1.0)

			var is_special_objective = (r.room_type == &"boss" and is_boss_floor) or (r.room_type == &"start" and is_entry_floor) or (r.room_type == &"goal") or (r.room_type == &"treasure")

			# Solo dibujar etiqueta de número de habitación si NO es una sala con objetivo especial central
			if not is_special_objective and tile_scale >= 3.0:
				var label_text: String = "#%d" % r.id
				var tag_font_size: int = clampi(int(tile_scale * 0.9), 9, 11)
				var tag_pos := c_pos + Vector2(3, 3)
				_draw_text_pill(tag_pos, label_text, tag_font_size, Color(0.92, 0.92, 0.92, 0.95), Color(0.10, 0.12, 0.16, 0.85))

			# Iconos y badges de objetivos centrales específicos
			var center_cell = r.get_center()
			if r.room_type == &"boss" and is_boss_floor:
				_draw_objective_badge(center_cell, origin, tile_scale, Color("#ef4444"), "💀 BOSS")
			elif r.room_type == &"start" and is_entry_floor:
				_draw_objective_badge(center_cell, origin, tile_scale, Color("#10b981"), "🧑 SPAWN")
			elif r.room_type == &"goal":
				_draw_objective_badge(center_cell, origin, tile_scale, Color("#eab308"), "🏆 META")
			elif r.room_type == &"treasure":
				_draw_objective_badge(center_cell, origin, tile_scale, Color("#f59e0b"), "🗝️ TESORO")

	# 5. Dibujar marcadores de escaleras
	if stairs != null:
		for st in stairs:
			if st != null:
				var stair_color: Color = Color("#8b5cf6") if st.is_downward else Color("#3b82f6")
				var stair_lbl: String = "🪜 BAJADA" if st.is_downward else "🪜 SUBIDA"
				_draw_objective_badge(st.cell, origin, tile_scale, stair_color, stair_lbl)

## Dibuja un badge de objetivo (Spawn, Boss, Goal, Escaleras) centrado con píldora de fondo legible
func _draw_objective_badge(grid_pos: Vector2i, origin: Vector2, tile_scale: float, color: Color, label: String) -> void:
	var center_pt: Vector2 = origin + (Vector2(grid_pos.x, grid_pos.y) + Vector2(0.5, 0.5)) * tile_scale
	var radius: float = maxf(2.0, tile_scale * 0.7)

	# Círculo del objetivo
	_preview_canvas.draw_circle(center_pt, radius, color)
	_preview_canvas.draw_circle(center_pt, radius, Color.WHITE, false, 1.2)

	# Etiqueta con fondo píldora legible
	if tile_scale >= 4.0:
		var font_size: int = clampi(int(tile_scale * 0.8), 9, 11)
		var str_size: Vector2 = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var pill_w: float = str_size.x + 8.0
		var pill_h: float = str_size.y + 4.0
		var pill_rect := Rect2(
			Vector2(center_pt.x - pill_w * 0.5, center_pt.y - radius - pill_h - 2.0),
			Vector2(pill_w, pill_h)
		)

		_preview_canvas.draw_rect(pill_rect, Color(0.08, 0.10, 0.14, 0.90))
		_preview_canvas.draw_rect(pill_rect, Color(1, 1, 1, 0.25), false, 1.0)
		_preview_canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(pill_rect.position.x + 4.0, pill_rect.position.y + pill_h - 3.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)

## Dibuja una pequeña etiqueta tipo píldora en la esquina de una habitación regular
func _draw_text_pill(top_left: Vector2, text: String, font_size: int, text_col: Color, bg_col: Color) -> void:
	var str_size: Vector2 = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pill_w: float = str_size.x + 6.0
	var pill_h: float = str_size.y + 2.0
	var pill_rect := Rect2(top_left, Vector2(pill_w, pill_h))

	_preview_canvas.draw_rect(pill_rect, bg_col)
	_preview_canvas.draw_rect(pill_rect, Color(1, 1, 1, 0.20), false, 1.0)
	_preview_canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(top_left.x + 3.0, top_left.y + pill_h - 3.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		text_col
	)

func _draw_door_marker(door, grid: CellGrid, origin: Vector2, tile_scale: float) -> void:
	if door == null or _preview_canvas == null or grid == null:
		return

	if not _DoorPhysicalValidatorScript.validate_door_jambs(grid, door.position, door.side):
		return

	var pos: Vector2i = door.position
	var rect := Rect2(origin + Vector2(pos.x, pos.y) * tile_scale, Vector2(tile_scale, tile_scale))
	var is_open: bool = (door.door_type == _DoorTypeScript.DoorType.OPEN_PASSAGE)
	var col: Color = Color("#3b82f6") if is_open else Color("#ef4444")

	_preview_canvas.draw_rect(rect, col)
	_preview_canvas.draw_rect(rect, Color.WHITE, false, 1.0)

## Muestra la vista previa 2D de un resultado mono-piso
func show_2d_preview(res: RefCounted, semantic: DungeonSemanticResult = null) -> void:
	_last_result = res
	_last_semantic = semantic
	_last_multi_result = null
	is_2d_preview_mode = true

	if _preview_overlay != null:
		_preview_overlay.visible = true
	if _hud_3d_panel != null:
		_hud_3d_panel.visible = false
	if _seed_line_edit != null and res != null:
		_seed_line_edit.text = str(res.seed_used)
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()

	_update_stats_panel()

## Muestra la vista previa 2D de un resultado multi-piso
func show_multi_floor_preview(multi_res: DungeonMultiFloorResult, selected_floor_idx: int = -1) -> void:
	_last_multi_result = multi_res
	_selected_floor_view = selected_floor_idx
	_last_result = null
	_last_semantic = null
	is_2d_preview_mode = true

	if _preview_overlay != null:
		_preview_overlay.visible = true
	if _hud_3d_panel != null:
		_hud_3d_panel.visible = false
	if _seed_line_edit != null and multi_res != null:
		_seed_line_edit.text = str(multi_res.master_seed)
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()

	_update_stats_panel()

func hide_2d_preview() -> void:
	is_2d_preview_mode = false
	if _preview_overlay != null:
		_preview_overlay.visible = false
	if _hud_3d_panel != null:
		_hud_3d_panel.visible = true

func _switch_tab(tab_idx: int) -> void:
	if _tab_params_container != null:
		_tab_params_container.visible = (tab_idx == 0)
	if _tab_floors_container != null:
		_tab_floors_container.visible = (tab_idx == 1)

	# Estilos visuales de los botones de pestañas
	var btns = [_tab_btn_params, _tab_btn_floors]
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.20, 0.32, 0.50, 0.95)
	active_style.border_color = Color(0.40, 0.60, 0.90, 1.0)
	active_style.set_border_width_all(1)
	active_style.set_corner_radius_all(6)

	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.12, 0.15, 0.20, 0.8)
	inactive_style.border_color = Color(0.25, 0.30, 0.40, 0.4)
	inactive_style.set_border_width_all(1)
	inactive_style.set_corner_radius_all(6)

	for i in range(btns.size()):
		var b: Button = btns[i]
		if b == null:
			continue
		if i == tab_idx:
			b.add_theme_stylebox_override("normal", active_style)
			b.add_theme_color_override("font_color", Color.WHITE)
		else:
			b.add_theme_stylebox_override("normal", inactive_style)
			b.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80))

func get_current_lighting_profile() -> LightingProfile:
	return _LightingProfileScript.new()

func toggle_2d_preview() -> void:
	if is_2d_preview_mode:
		generate_3d_requested.emit()
	else:
		toggle_2d_view_requested.emit()

func _update_stats_panel() -> void:
	if _info_stats_label == null:
		return

	# Estadísticas de Multi-piso
	if _last_multi_result != null:
		var m_res := _last_multi_result
		var total_rooms: int = 0
		var total_doors: int = 0
		var total_stairs: int = 0
		var total_corridors: int = 0
		var total_floors: int = m_res.get_floor_count()

		for f_num in m_res.get_floor_numbers():
			var f_data: DungeonFloorData = m_res.get_floor(f_num)
			if f_data != null:
				total_rooms += f_data.rooms.size()
				total_doors += f_data.door_pairs.size() * 2
				total_stairs += f_data.stairs.size()
				if "corridor_paths" in f_data:
					total_corridors += f_data.corridor_paths.size()
				else:
					total_corridors += f_data.rooms.size() + 1

		var bb := "• [b]Semilla:[/b] [color=#60a5fa]%d[/color]\n" % m_res.master_seed
		bb += "• [b]Pisos Totales:[/b] [color=#34d399]%d[/color]\n" % total_floors
		bb += "• [b]Habitaciones:[/b] [color=#f1d240]%d[/color]\n" % total_rooms
		bb += "• [b]Corredores:[/b] [color=#38b861]%d[/color]\n" % total_corridors
		bb += "• [b]Puertas Totales:[/b] [color=#ef4444]%d[/color]\n" % total_doors
		bb += "• [b]Escaleras:[/b] [color=#3b82f6]%d[/color]\n" % total_stairs
		bb += "• [b]Spawn Jugador:[/b] [color=#10b981](Piso 1)[/color]\n"
		bb += "• [b]Boss:[/b] [color=#ef4444](Piso %d)[/color]\n" % total_floors
		bb += "• [b]Tiempo Lógico:[/b] %.1f ms" % m_res.total_generation_time_ms

		_info_stats_label.text = bb
		return

	# Estadísticas de Mono-piso
	if _last_result == null or _last_result.grid == null:
		return

	var res = _last_result
	var closed_doors: int = 0
	var open_passages: int = 0

	for dp in res.door_pairs:
		if dp.door_a != null and _DoorPhysicalValidatorScript.validate_door_jambs(res.grid, dp.door_a.position, dp.door_a.side):
			if dp.door_a.door_type == _DoorTypeScript.DoorType.OPEN_PASSAGE: open_passages += 1
			else: closed_doors += 1
		if dp.door_b != null and _DoorPhysicalValidatorScript.validate_door_jambs(res.grid, dp.door_b.position, dp.door_b.side):
			if dp.door_b.door_type == _DoorTypeScript.DoorType.OPEN_PASSAGE: open_passages += 1
			else: closed_doors += 1

	var spawn_pos_str := "N/A"
	if _last_semantic != null:
		for obj in _last_semantic.objectives:
			if obj.type == ObjectiveData.ObjectiveType.SPAWN:
				spawn_pos_str = "(%d, %d)" % [obj.position.x, obj.position.y]
				break

	var corr_count: int = res.corridor_paths.size() if ("corridor_paths" in res) else res.rooms.size()
	var bb_mono := "• [b]Semilla:[/b] [color=#60a5fa]%d[/color]\n" % res.seed_used
	bb_mono += "• [b]Piso:[/b] %d\n" % (res.floor_number + 1)
	bb_mono += "• [b]Habitaciones:[/b] [color=#f1d240]%d[/color]\n" % res.rooms.size()
	bb_mono += "• [b]Corredores:[/b] [color=#38b861]%d[/color]\n" % corr_count
	bb_mono += "• [b]Puertas Rojas:[/b] [color=#ef4444]%d[/color]\n" % closed_doors
	bb_mono += "• [b]Arcos Azules:[/b] [color=#3b82f6]%d[/color]\n" % open_passages
	bb_mono += "• [b]Spawn Jugador:[/b] [color=#10b981]%s[/color]\n" % spawn_pos_str
	bb_mono += "• [b]Tiempo Lógico:[/b] %.1f ms" % (res.generation_time_ms if ("generation_time_ms" in res) else 0.0)

	_info_stats_label.text = bb_mono

func update_floor_view_options(total_floors: int, selected_floor: int = -1) -> void:
	if _opt_floor_view != null:
		_opt_floor_view.clear()
		_opt_floor_view.add_item("🏢 Todos", -1)
		for f in range(total_floors):
			_opt_floor_view.add_item("🏢 Piso %d" % (f + 1), f)
		var select_idx: int = 0
		if selected_floor >= 0 and selected_floor < total_floors:
			select_idx = selected_floor + 1
		_opt_floor_view.select(select_idx)

	if _opt_3d_floor_view != null:
		_opt_3d_floor_view.clear()
		_opt_3d_floor_view.add_item("🏢 Todos los Pisos", -1)
		for f in range(total_floors):
			_opt_3d_floor_view.add_item("🏢 Piso %d" % (f + 1), f)
		var select_3d_idx: int = 0
		if selected_floor >= 0 and selected_floor < total_floors:
			select_3d_idx = selected_floor + 1
		_opt_3d_floor_view.select(select_3d_idx)

func _on_algorithm_selected(idx: int) -> void:
	var algo_names = ["Hybrid", "BSP", "CellularAutomata"]
	if idx >= 0 and idx < algo_names.size():
		algorithm_changed.emit(algo_names[idx])

func _on_line_edit_submitted(new_text: String) -> void:
	_apply_seed_input(new_text)

func _on_generate_pressed() -> void:
	if _seed_line_edit != null:
		_apply_seed_input(_seed_line_edit.text)

func _apply_seed_input(text: String) -> void:
	var trimmed := text.strip_edges()
	var final_seed: int = 0
	if trimmed.is_valid_int():
		final_seed = int(trimmed)
	elif trimmed != "":
		final_seed = trimmed.hash()
	else:
		random_seed_requested.emit()
		if _seed_line_edit != null:
			_seed_line_edit.text = ""
		return

	seed_submitted.emit(final_seed)

func _on_random_pressed() -> void:
	random_seed_requested.emit()

func _on_copy_pressed() -> void:
	var cur_seed: int = 0
	if _last_multi_result != null:
		cur_seed = _last_multi_result.master_seed
	elif _last_result != null:
		cur_seed = _last_result.seed_used
	if cur_seed != 0:
		DisplayServer.clipboard_set(str(cur_seed))
		_show_temporary_feedback("✓")

func _on_copy_ascii_pressed() -> void:
	if _last_result != null and _last_result is DungeonResult:
		var ascii_text := _DungeonAsciiExporterScript.export_ascii(_last_result, _last_semantic, true)
		DisplayServer.clipboard_set(ascii_text)
		if _btn_copy_ascii != null:
			var orig := _btn_copy_ascii.text
			_btn_copy_ascii.text = "✓ ¡Copiado!"
			get_tree().create_timer(1.2).timeout.connect(func():
				if _btn_copy_ascii != null:
					_btn_copy_ascii.text = orig
			)

func _show_temporary_feedback(msg: String) -> void:
	if _btn_copy != null:
		var orig := _btn_copy.text
		_btn_copy.text = msg
		get_tree().create_timer(1.0).timeout.connect(func():
			if _btn_copy != null:
				_btn_copy.text = orig
		)

func _on_build_3d_pressed() -> void:
	generate_3d_requested.emit()

func _on_back_to_2d_pressed() -> void:
	toggle_2d_view_requested.emit()

func set_selected_archetype(p_arch_id: int) -> void:
	if _opt_archetype == null:
		return
	for idx in range(_opt_archetype.item_count):
		if _opt_archetype.get_item_id(idx) == p_arch_id:
			_opt_archetype.select(idx)
			return

