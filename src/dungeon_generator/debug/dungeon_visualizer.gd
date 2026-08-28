class_name DungeonVisualizer
extends Control

## Visualizador y Generador 2D interactivo a pantalla completa con soporte multinivel (Fase 10 / M8),
## transición a 3D, selector de modos de vista (Generación vs Arquetipos) e inspección interactiva por cursor (Hover / Tooltips).
## Estructura de diseño:
## - Panel Izquierdo: Pestañas de Configuración (Parámetros, Suelos, Arquetipos), Estadísticas, Leyenda dinámica y Botón 3D.
## - Panel Derecho: Barra de Modos de Vista (🗺️ Generación / 🏛️ Arquetipos), Lienzo 2D interactivo con resaltado y Tooltips flotantes.
## - Toolbar 3D Flotante: Controles de navegación 3D y retorno al plano.

signal seed_submitted(seed_val: int)
signal random_seed_requested()
signal floors_changed(total_floors: int)
signal algorithm_changed(algo_name: String)
signal floor_view_mode_changed(floor_index: int)
signal generate_3d_requested()
signal toggle_2d_view_requested()
signal walls_visibility_toggled(visible: bool)
signal doors_visibility_toggled(visible: bool)
signal camera_view_toggled()
signal player_follow_toggled(is_following: bool)
signal archetype_selected(archetype_id: StringName)
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

enum ViewMode {
	GENERATION = 0,
	ARCHETYPE = 1
}

const _DungeonAsciiExporterScript = preload("res://src/dungeon_generator/debug/dungeon_ascii_exporter.gd")
const _DoorPhysicalValidatorScript = preload("res://src/dungeon_generator/core/validation/door_physical_validator.gd")
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _LightingProfileScript = preload("res://src/dungeon_lighting/config/lighting_profile.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _ArchetypeCatalogScript = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var _last_result: RefCounted = null # DungeonResult o DungeonFloorData
var _last_semantic: DungeonSemanticResult = null
var _last_multi_result: DungeonMultiFloorResult = null
var _selected_floor_view: int = -1 # -1 = Todos los pisos en rejilla segmentada, >= 0 = Piso específico
var _current_view_mode: int = ViewMode.GENERATION

# Resolutores para inspección de arquetipos
var _profile_resolver := _PresentationProfileResolverScript.new()
var _dec_resolver := _DecorationPaletteResolverScript.new()
var _comp_resolver := _DecorationCompositionResolverScript.new()

# Estado de interacción por cursor (Hover / Tooltips)
var _hovered_room_id: int = -1
var _hovered_floor_idx: int = -1
var _hovered_mouse_pos := Vector2.ZERO
var _hovered_room_data: Dictionary = {}
var _floor_viewports: Array[Dictionary] = []

# Controles de Pestañas
var _tab_btn_params: Button = null
var _tab_btn_floors: Button = null
var _tab_btn_archetypes: Button = null
var _tab_params_container: VBoxContainer = null
var _tab_floors_container: VBoxContainer = null
var _tab_archetypes_container: VBoxContainer = null

# Controles de Arquetipos en Sidebar
var _arch_info_header: Label = null
var _arch_dist_container: HFlowContainer = null
var _arch_rooms_list: VBoxContainer = null

# Controles de Barra Superior del Canvas 2D
var _btn_view_generation: Button = null
var _btn_view_archetypes: Button = null
var _lbl_canvas_title: Label = null

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
var _legend_label: RichTextLabel = null

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
var _btn_3d_toggle_doors: Button = null
var _btn_3d_toggle_cam: Button = null
var _btn_3d_toggle_player: Button = null
var _walls_visible: bool = true
var _doors_visible: bool = true
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
	# SIDEBAR IZQUIERDA (Configuración + Arquetipos + Estadísticas)
	# ==========================================
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(370, 0)
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

	# --- BARRA DE PESTAÑAS (PARÁMETROS / SUELOS / ARQUETIPOS) ---
	var tab_bar_hbox := HBoxContainer.new()
	tab_bar_hbox.add_theme_constant_override("separation", 4)

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

	_tab_btn_archetypes = Button.new()
	_tab_btn_archetypes.text = "🏛️ Arquetipos"
	_tab_btn_archetypes.size_flags_horizontal = SIZE_EXPAND_FILL
	_tab_btn_archetypes.pressed.connect(func(): _switch_tab(2))
	tab_bar_hbox.add_child(_tab_btn_archetypes)

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
	_populate_archetype_options()
	_opt_archetype.item_selected.connect(func(idx: int):
		var metadata = _opt_archetype.get_item_metadata(idx)
		var arch_id: StringName = metadata if metadata is StringName else &"generic"
		archetype_selected.emit(arch_id)
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

	# Fila Profundidad Misión & Ancho Pasillo
	var params_grid := GridContainer.new()
	params_grid.columns = 2
	params_grid.add_theme_constant_override("h_separation", 8)
	params_grid.add_theme_constant_override("v_separation", 4)

	var depth_lbl := Label.new()
	depth_lbl.text = "Profundidad Misión:"
	depth_lbl.add_theme_font_size_override("font_size", 11)
	depth_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	params_grid.add_child(depth_lbl)

	var corr_lbl := Label.new()
	corr_lbl.text = "Ancho Pasillo:"
	corr_lbl.add_theme_font_size_override("font_size", 11)
	corr_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	params_grid.add_child(corr_lbl)

	_spin_depth = SpinBox.new()
	_spin_depth.min_value = 1
	_spin_depth.max_value = 20
	_spin_depth.value = 5
	_spin_depth.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_depth.value_changed.connect(func(v: float):
		mission_depth_changed.emit(int(v))
	)
	params_grid.add_child(_spin_depth)

	_spin_corridor_w = SpinBox.new()
	_spin_corridor_w.min_value = 1
	_spin_corridor_w.max_value = 4
	_spin_corridor_w.value = 2
	_spin_corridor_w.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_corridor_w.value_changed.connect(func(v: float):
		corridor_width_changed.emit(int(v))
	)
	params_grid.add_child(_spin_corridor_w)

	_tab_params_container.add_child(params_grid)

	# Fila Pisos & Selector de Piso
	var floors_hbox := HBoxContainer.new()
	floors_hbox.add_theme_constant_override("separation", 8)

	var floors_cnt_vbox := VBoxContainer.new()
	floors_cnt_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	var floors_lbl := Label.new()
	floors_lbl.text = "Pisos: 1"
	floors_lbl.add_theme_font_size_override("font_size", 11)
	floors_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	floors_cnt_vbox.add_child(floors_lbl)

	_spin_floors = SpinBox.new()
	_spin_floors.min_value = 1
	_spin_floors.max_value = 6
	_spin_floors.value = 1
	_spin_floors.value_changed.connect(func(v: float):
		floors_lbl.text = "Pisos: %d" % int(v)
		floors_changed.emit(int(v))
	)
	floors_cnt_vbox.add_child(_spin_floors)
	floors_hbox.add_child(floors_cnt_vbox)

	var floor_sel_vbox := VBoxContainer.new()
	floor_sel_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	var fsel_lbl := Label.new()
	fsel_lbl.text = "Vista de Piso:"
	fsel_lbl.add_theme_font_size_override("font_size", 11)
	fsel_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	floor_sel_vbox.add_child(fsel_lbl)

	_opt_floor_view = OptionButton.new()
	_opt_floor_view.add_item("🏢 Todos", -1)
	_opt_floor_view.add_item("🏢 Piso 1", 0)
	_opt_floor_view.item_selected.connect(func(idx: int):
		var f_id = _opt_floor_view.get_item_id(idx)
		_selected_floor_view = f_id
		floor_view_mode_changed.emit(f_id)
	)
	floor_sel_vbox.add_child(_opt_floor_view)
	floors_hbox.add_child(floor_sel_vbox)

	_tab_params_container.add_child(floors_hbox)

	# Fila Acciones 2D
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 6)

	_btn_generate_2d = Button.new()
	_btn_generate_2d.text = "🔄 Regenerar"
	_btn_generate_2d.size_flags_horizontal = SIZE_EXPAND_FILL
	_btn_generate_2d.pressed.connect(_on_generate_pressed)
	actions_hbox.add_child(_btn_generate_2d)

	_btn_copy_ascii = Button.new()
	_btn_copy_ascii.text = "📄 Copiar ASCII"
	_btn_copy_ascii.size_flags_horizontal = SIZE_EXPAND_FILL
	_btn_copy_ascii.pressed.connect(_on_copy_ascii_pressed)
	actions_hbox.add_child(_btn_copy_ascii)

	_tab_params_container.add_child(actions_hbox)

	# =========================================================================
	# PESTAÑA 1: SUELOS PROCEDURALES
	# =========================================================================
	_tab_floors_container = VBoxContainer.new()
	_tab_floors_container.add_theme_constant_override("separation", 10)
	_tab_floors_container.visible = false
	sidebar_vbox.add_child(_tab_floors_container)

	# Fila Patrón de Suelo
	var pattern_floor_vbox := VBoxContainer.new()
	pattern_floor_vbox.add_theme_constant_override("separation", 4)
	var pattern_lbl := Label.new()
	pattern_lbl.text = "Patrón Geométrico de Baldosas:"
	pattern_lbl.add_theme_font_size_override("font_size", 12)
	pattern_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	pattern_floor_vbox.add_child(pattern_lbl)

	_opt_floor_pattern = OptionButton.new()
	_opt_floor_pattern.add_item("Piedra Estilizada (Stylized Stone)", _FloorTileConfigScript.PatternType.STYLIZED_STONE)
	_opt_floor_pattern.add_item("Adoquines Irregulares (Cobblestone)", _FloorTileConfigScript.PatternType.COBBLESTONE)
	_opt_floor_pattern.add_item("Ladrillos (Brick)", _FloorTileConfigScript.PatternType.BRICK)
	_opt_floor_pattern.add_item("Losas Lisas (Smooth Slabs)", _FloorTileConfigScript.PatternType.SMOOTH_SLABS)
	_opt_floor_pattern.add_item("Baldosas Ruinosas (Ruined Tiles)", _FloorTileConfigScript.PatternType.RUINED_TILES)
	_opt_floor_pattern.select(0)
	_opt_floor_pattern.item_selected.connect(func(idx: int):
		floor_pattern_changed.emit(_opt_floor_pattern.get_item_id(idx))
	)
	pattern_floor_vbox.add_child(_opt_floor_pattern)
	_tab_floors_container.add_child(pattern_floor_vbox)

	# Fila Preset de Material PBR
	var preset_floor_vbox := VBoxContainer.new()
	preset_floor_vbox.add_theme_constant_override("separation", 4)
	var preset_mat_lbl := Label.new()
	preset_mat_lbl.text = "Preset de Material PBR:"
	preset_mat_lbl.add_theme_font_size_override("font_size", 12)
	preset_mat_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	preset_floor_vbox.add_child(preset_mat_lbl)

	_opt_floor_preset = OptionButton.new()
	_opt_floor_preset.add_item("Piedra Antigua (Ancient Stone)", 0)
	_opt_floor_preset.add_item("Piedra de Fortaleza (Fortress Stone)", 1)
	_opt_floor_preset.add_item("Cripta Oscura (Dark Crypt)", 2)
	_opt_floor_preset.add_item("Templo Ceremonial (Ceremonial Temple)", 3)
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

	# =========================================================================
	# PESTAÑA 2: ARQUETIPOS Y DESGLOSE SEMÁNTICO (NUEVO)
	# =========================================================================
	_tab_archetypes_container = VBoxContainer.new()
	_tab_archetypes_container.add_theme_constant_override("separation", 10)
	_tab_archetypes_container.visible = false
	sidebar_vbox.add_child(_tab_archetypes_container)

	_arch_info_header = Label.new()
	_arch_info_header.text = "🏛️ Arquetipo: Crypt / Mausoleum"
	_arch_info_header.add_theme_font_size_override("font_size", 12)
	_arch_info_header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40, 1.0))
	_tab_archetypes_container.add_child(_arch_info_header)

	var dist_lbl := Label.new()
	dist_lbl.text = "Distribución de Propósitos:"
	dist_lbl.add_theme_font_size_override("font_size", 11)
	dist_lbl.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95, 1.0))
	_tab_archetypes_container.add_child(dist_lbl)

	_arch_dist_container = HFlowContainer.new()
	_arch_dist_container.add_theme_constant_override("h_separation", 4)
	_arch_dist_container.add_theme_constant_override("v_separation", 4)
	_tab_archetypes_container.add_child(_arch_dist_container)

	var rooms_list_title := Label.new()
	rooms_list_title.text = "Salas y Composición Arquitectónica:"
	rooms_list_title.add_theme_font_size_override("font_size", 11)
	rooms_list_title.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95, 1.0))
	_tab_archetypes_container.add_child(rooms_list_title)

	var arch_scroll := ScrollContainer.new()
	arch_scroll.custom_minimum_size = Vector2(0, 220)
	arch_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_arch_rooms_list = VBoxContainer.new()
	_arch_rooms_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_arch_rooms_list.add_theme_constant_override("separation", 6)
	arch_scroll.add_child(_arch_rooms_list)
	_tab_archetypes_container.add_child(arch_scroll)

	# Inicializar pestaña 0 activa
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

	# --- SECCIÓN 3: LEYENDA VISUAL DINÁMICA ---
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

	_legend_label = RichTextLabel.new()
	_legend_label.bbcode_enabled = true
	_legend_label.fit_content = true
	legend_panel.add_child(_legend_label)
	sidebar_vbox.add_child(legend_panel)
	_update_legend()

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
	# ÁREA PRINCIPAL DERECHA (Barra Superior + Canvas 2D)
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
	right_style.content_margin_top = 10.0
	right_style.content_margin_bottom = 12.0
	right_panel.add_theme_stylebox_override("panel", right_style)
	main_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	# --- BARRA SUPERIOR DEL CANVAS (SELECTOR DE MODO DE VISTA) ---
	var top_canvas_bar := HBoxContainer.new()
	top_canvas_bar.add_theme_constant_override("separation", 10)
	top_canvas_bar.size_flags_horizontal = SIZE_EXPAND_FILL

	_lbl_canvas_title = Label.new()
	_lbl_canvas_title.text = "🗺️ PLANO DE GENERACIÓN"
	_lbl_canvas_title.add_theme_font_size_override("font_size", 14)
	_lbl_canvas_title.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
	top_canvas_bar.add_child(_lbl_canvas_title)

	var bar_spacer := Control.new()
	bar_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top_canvas_bar.add_child(bar_spacer)

	# Botones de alternancia de vista
	var view_mode_box := HBoxContainer.new()
	view_mode_box.add_theme_constant_override("separation", 4)

	_btn_view_generation = Button.new()
	_btn_view_generation.text = "🗺️ Vista Generación"
	_btn_view_generation.tooltip_text = "Vista física del plano (habitaciones, pasillos, puertas y objetivos)"
	_btn_view_generation.pressed.connect(func(): set_view_mode(ViewMode.GENERATION))
	view_mode_box.add_child(_btn_view_generation)

	_btn_view_archetypes = Button.new()
	_btn_view_archetypes.text = "🏛️ Vista Arquetipos"
	_btn_view_archetypes.tooltip_text = "Vista semántica con código de colores y propósitos arquitectónicos"
	_btn_view_archetypes.pressed.connect(func(): set_view_mode(ViewMode.ARCHETYPE))
	view_mode_box.add_child(_btn_view_archetypes)

	top_canvas_bar.add_child(view_mode_box)
	right_vbox.add_child(top_canvas_bar)

	# --- CANVAS DE DIBUJO 2D ---
	_preview_canvas = Control.new()
	_preview_canvas.name = "PreviewCanvas"
	_preview_canvas.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview_canvas.size_flags_vertical = SIZE_EXPAND_FILL
	_preview_canvas.mouse_filter = MOUSE_FILTER_PASS
	_preview_canvas.draw.connect(_on_preview_canvas_draw)
	_preview_canvas.gui_input.connect(_on_preview_canvas_gui_input)
	_preview_canvas.mouse_exited.connect(_on_preview_canvas_mouse_exited)
	right_vbox.add_child(_preview_canvas)

	_update_view_mode_buttons()

## Cambia el modo de visualización 2D (Generación vs Arquetipos)
func set_view_mode(mode: int) -> void:
	if _current_view_mode == mode:
		return
	_current_view_mode = mode
	_update_view_mode_buttons()
	_update_legend()
	if _current_view_mode == ViewMode.ARCHETYPE:
		_switch_tab(2)
	elif _current_view_mode == ViewMode.GENERATION and _tab_archetypes_container != null and _tab_archetypes_container.visible:
		_switch_tab(0)
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()

func _update_view_mode_buttons() -> void:
	if _lbl_canvas_title != null:
		_lbl_canvas_title.text = "🗺️ PLANO DE GENERACIÓN FÍSICA" if _current_view_mode == ViewMode.GENERATION else "🏛️ PLANO DE ARQUETIPOS SEMÁNTICOS"

	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.20, 0.35, 0.55, 0.95)
	active_style.border_color = Color(0.45, 0.70, 1.0, 1.0)
	active_style.set_border_width_all(1)
	active_style.set_corner_radius_all(6)

	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.10, 0.13, 0.18, 0.8)
	inactive_style.border_color = Color(0.25, 0.30, 0.40, 0.5)
	inactive_style.set_border_width_all(1)
	inactive_style.set_corner_radius_all(6)

	if _btn_view_generation != null:
		if _current_view_mode == ViewMode.GENERATION:
			_btn_view_generation.add_theme_stylebox_override("normal", active_style)
			_btn_view_generation.add_theme_color_override("font_color", Color.WHITE)
		else:
			_btn_view_generation.add_theme_stylebox_override("normal", inactive_style)
			_btn_view_generation.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80))

	if _btn_view_archetypes != null:
		if _current_view_mode == ViewMode.ARCHETYPE:
			_btn_view_archetypes.add_theme_stylebox_override("normal", active_style)
			_btn_view_archetypes.add_theme_color_override("font_color", Color.WHITE)
		else:
			_btn_view_archetypes.add_theme_stylebox_override("normal", inactive_style)
			_btn_view_archetypes.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80))

func _update_legend() -> void:
	if _legend_label == null:
		return
	if _current_view_mode == ViewMode.GENERATION:
		_legend_label.text = "[color=#f1d240]■ Habitación[/color]   [color=#38b861]■ Pasillo[/color]\n[color=#ef4444]■ Puerta Roja[/color]   [color=#3b82f6]■ Arco Libre[/color]\n[color=#10b981]● Spawn Jugador[/color]   [color=#ef4444]● Boss[/color]\n[color=#3b82f6]🪜 Escalera Arriba[/color]   [color=#8b5cf6]🪜 Escalera Abajo[/color]"
	else:
		_legend_label.text = "[color=#4ade80]■ ENTRANCE[/color]   [color=#f87171]■ ROYAL_TOMB/BOSS[/color]\n[color=#fb923c]■ CRYPT/ARMORY[/color]   [color=#38bdf8]■ TOMB/STORAGE[/color]\n[color=#c084fc]■ SACRISTY/SHRINE[/color]   [color=#94a3b8]■ HALL/EXPLORE[/color]"

## Configura la barra flotante superior de herramientas de visualización 3D
func _setup_3d_hud() -> void:
	if _hud_3d_panel != null:
		return

	_hud_3d_panel = PanelContainer.new()
	_hud_3d_panel.name = "HUD3DPanel"
	_hud_3d_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_hud_3d_panel.anchor_left = 1.0
	_hud_3d_panel.anchor_right = 1.0
	_hud_3d_panel.offset_left = -820.0
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

	# 2.5 Toggle de Visibilidad de Puertas
	_btn_3d_toggle_doors = Button.new()
	_btn_3d_toggle_doors.text = "🚪 Puertas: ON"
	_btn_3d_toggle_doors.tooltip_text = "Ocultar o mostrar las puertas de la mazmorra 3D"
	_btn_3d_toggle_doors.pressed.connect(func():
		_doors_visible = not _doors_visible
		_btn_3d_toggle_doors.text = "🚪 Puertas: ON" if _doors_visible else "🚪 Puertas: OFF"
		doors_visibility_toggled.emit(_doors_visible)
	)
	hbox.add_child(_btn_3d_toggle_doors)

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

# ==============================================================================
# MANEJO DE EVENTOS DE RATÓN (HOVER / INSPECCIÓN)
# ==============================================================================

func _on_preview_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var m_pos: Vector2 = event.position
		var found_room_id: int = -1
		var found_floor_idx: int = -1
		var found_room_obj = null
		var found_sem = null

		for vp in _floor_viewports:
			if vp.get("bounds", Rect2()).has_point(m_pos):
				var origin: Vector2 = vp.get("origin", Vector2.ZERO)
				var t_scale: float = vp.get("tile_scale", 1.0)
				if t_scale > 0.0:
					var gx: int = int(floor((m_pos.x - origin.x) / t_scale))
					var gy: int = int(floor((m_pos.y - origin.y) / t_scale))
					var cell := Vector2i(gx, gy)
					var rooms: Array = vp.get("rooms", [])
					for r in rooms:
						if r != null and r.rect.has_point(cell):
							found_room_id = r.id
							found_floor_idx = vp.get("floor_idx", 0)
							found_room_obj = r
							found_sem = vp.get("semantic", null)
							break
				if found_room_id != -1:
					break

		if found_room_id != _hovered_room_id or found_floor_idx != _hovered_floor_idx:
			_hovered_room_id = found_room_id
			_hovered_floor_idx = found_floor_idx
			_hovered_mouse_pos = m_pos
			if found_room_id != -1 and found_room_obj != null:
				_build_hover_room_data(found_room_obj, found_floor_idx, found_sem)
			else:
				_hovered_room_data.clear()
			if _preview_canvas != null:
				_preview_canvas.queue_redraw()
		elif found_room_id != -1:
			_hovered_mouse_pos = m_pos
			if _preview_canvas != null:
				_preview_canvas.queue_redraw()

func _on_preview_canvas_mouse_exited() -> void:
	if _hovered_room_id != -1:
		_hovered_room_id = -1
		_hovered_floor_idx = -1
		_hovered_room_data.clear()
		if _preview_canvas != null:
			_preview_canvas.queue_redraw()

func _build_hover_room_data(room_obj, floor_idx: int, sem_result: DungeonSemanticResult) -> void:
	_hovered_room_data.clear()
	if room_obj == null:
		return

	var r_id: int = room_obj.id
	var purpose_id: StringName = &"generic"
	var purpose_name: String = "GENERIC"
	var arch_type: int = 1

	if sem_result != null:
		purpose_id = sem_result.get_room_purpose(r_id)
		purpose_name = sem_result.get_room_purpose_name(r_id)
		arch_type = sem_result.dungeon_archetype

	var role: String = "EXPLORE"
	if sem_result != null:
		if r_id == sem_result.start_room_id:
			role = "START"
		elif r_id == sem_result.boss_room_id:
			role = "BOSS"
		else:
			for obj in sem_result.objectives:
				if obj.room_id == r_id:
					role = "TREASURE" if obj.type == 0 else "COMBAT"
					break
	else:
		if room_obj.room_type == &"start": role = "START"
		elif room_obj.room_type == &"boss": role = "BOSS"
		elif room_obj.room_type == &"treasure": role = "TREASURE"
		elif room_obj.room_type == &"goal": role = "META"

	var arch_prof = _profile_resolver.resolve(arch_type, purpose_id)
	var p_col: Color = _get_purpose_color(purpose_id)

	# Resolver conteo de composiciones
	var focal_cnt: int = 0
	var support_cnt: int = 0
	var ambient_cnt: int = 0
	if sem_result != null:
		var dec_palette = _dec_resolver.resolve_palette(arch_type, purpose_id, arch_prof)
		var r_geom = _PresentationRoomGeometryScript.new()
		r_geom.room_id = r_id
		r_geom.bounds = room_obj.rect
		var r_ctx = _PresentationRoomContextScript.new()
		r_ctx.room_id = r_id
		r_ctx.purpose = purpose_id
		r_ctx.profile = arch_prof
		var comp = _comp_resolver.resolve_room_composition(r_ctx, dec_palette, r_geom, null, sem_result.seed if ("seed" in sem_result) else 1337, 2.0)
		focal_cnt = comp.get_focal_props().size()
		support_cnt = comp.get_support_props().size()
		ambient_cnt = comp.get_ambient_props().size()

	_hovered_room_data = {
		"room_id": r_id,
		"floor_idx": floor_idx,
		"role": role,
		"purpose_id": purpose_id,
		"purpose_name": purpose_name,
		"purpose_color": p_col,
		"dimensions": "%d×%d celdas (%d m²)" % [room_obj.rect.size.x, room_obj.rect.size.y, room_obj.rect.size.x * room_obj.rect.size.y * 4],
		"wall_style": _ArchitecturalStyleScript.wall_to_name(arch_prof.wall_style),
		"floor_style": _ArchitecturalStyleScript.floor_to_name(arch_prof.floor_style),
		"door_style": _ArchitecturalStyleScript.door_to_name(arch_prof.door_style),
		"focal_cnt": focal_cnt,
		"support_cnt": support_cnt,
		"ambient_cnt": ambient_cnt
	}

# ==============================================================================
# RENDERIZADO DEL MAPA 2D Y TOOLTIPS
# ==============================================================================

## Dibuja el mapa 2D segmentado en cuadrícula multinivel o vista individual
func _on_preview_canvas_draw() -> void:
	if _preview_canvas == null:
		return

	_floor_viewports.clear()
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
				_draw_floor_blueprint(f_data.grid, f_data.rooms, f_data.door_pairs, f_data.stairs, Rect2(Vector2.ZERO, canvas_size), "PISO %d" % (_selected_floor_view + 1), is_entry, is_boss, _selected_floor_view + 1, f_data.semantic_result)
		else:
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
					_draw_floor_blueprint(f_data.grid, f_data.rooms, f_data.door_pairs, f_data.stairs, cell_rect, "PISO %d" % (f_idx + 1), is_entry, is_boss, f_idx + 1, f_data.semantic_result)

			# Dibujar líneas divisorias de cuadrícula
			for c in range(1, cols):
				var x_pos: float = float(c) * cell_w
				_preview_canvas.draw_line(Vector2(x_pos, 0), Vector2(x_pos, canvas_size.y), Color(0.20, 0.28, 0.40, 0.5), 1.0)
			for r in range(1, rows):
				var y_pos: float = float(r) * cell_h
				_preview_canvas.draw_line(Vector2(0, y_pos), Vector2(canvas_size.x, y_pos), Color(0.20, 0.28, 0.40, 0.5), 1.0)

	# CASO MONO-PISO ESTÁNDAR
	elif _last_result != null and _last_result.grid != null:
		var rooms: Array = _last_result.rooms
		var door_pairs: Array = _last_result.door_pairs
		var stairs: Array = []
		if "stairs" in _last_result:
			stairs = _last_result.stairs
		_draw_floor_blueprint(_last_result.grid, rooms, door_pairs, stairs, Rect2(Vector2.ZERO, canvas_size), "PISO 1", true, true, 1, _last_semantic)

	# DIBUJAR TOOLTIP FLOTANTE SOBRE SALA EN HOVER
	_draw_hover_tooltip_card(canvas_size)

func _draw_floor_blueprint(
	grid: CellGrid,
	rooms: Array,
	door_pairs: Array,
	stairs: Array,
	bounds_rect: Rect2,
	floor_title: String,
	is_entry_floor: bool,
	is_boss_floor: bool,
	floor_number: int = 1,
	semantic_res: DungeonSemanticResult = null
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

	# Registrar viewport activo para interacción por ratón
	_floor_viewports.append({
		"floor_idx": floor_number - 1,
		"origin": origin,
		"tile_scale": tile_scale,
		"bounds": bounds_rect,
		"rooms": rooms,
		"semantic": semantic_res,
		"grid": grid
	})

	# 1. Dibujar Título del Piso
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

	# 2. Dibujar celdas base según el Modo de Vista
	for y in range(gh):
		for x in range(gw):
			var pos := Vector2i(x, y)
			var ctype: int = grid.get_cell(pos)
			var rect := Rect2(origin + Vector2(x, y) * tile_scale, Vector2(tile_scale, tile_scale))

			if _current_view_mode == ViewMode.GENERATION:
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
			else:
				# VISTA DE ARQUETIPOS
				match ctype:
					CellGrid.CellType.FLOOR:
						_preview_canvas.draw_rect(rect, Color(0.14, 0.17, 0.24, 0.8))
					CellGrid.CellType.CORRIDOR, CellGrid.CellType.DOOR:
						_preview_canvas.draw_rect(rect, Color(0.22, 0.28, 0.36, 0.9))
					CellGrid.CellType.WALL:
						_preview_canvas.draw_rect(rect, Color("#10131a"))
					CellGrid.CellType.COLUMN:
						_preview_canvas.draw_rect(rect, Color("#334155"))
					CellGrid.CellType.STAIRS_UP:
						_preview_canvas.draw_rect(rect, Color("#3b82f6"))
					CellGrid.CellType.STAIRS_DOWN:
						_preview_canvas.draw_rect(rect, Color("#8b5cf6"))
					_:
						_preview_canvas.draw_rect(rect, Color("#090b10"))

	# 3. Dibujar puertas y arcos
	if door_pairs != null:
		for dp in door_pairs:
			if dp == null:
				continue
			_draw_door_marker(dp.door_a, grid, origin, tile_scale)
			_draw_door_marker(dp.door_b, grid, origin, tile_scale)

	# 4. Dibujar habitaciones y etiquetas según Modo de Vista
	for r in rooms:
		if r == null:
			continue

		var c_pos: Vector2 = origin + Vector2(r.rect.position.x, r.rect.position.y) * tile_scale
		var r_size: Vector2 = Vector2(r.rect.size.x, r.rect.size.y) * tile_scale
		var r_rect := Rect2(c_pos, r_size)
		var is_hovered: bool = (_hovered_room_id == r.id and _hovered_floor_idx == (floor_number - 1))

		if _current_view_mode == ViewMode.ARCHETYPE:
			var purpose_id: StringName = &"generic"
			var purpose_name: String = "GENERIC"
			if semantic_res != null:
				purpose_id = semantic_res.get_room_purpose(r.id)
				purpose_name = semantic_res.get_room_purpose_name(r.id)
			var p_col: Color = _get_purpose_color(purpose_id)

			# Relleno del color del propósito
			_preview_canvas.draw_rect(r_rect, Color(p_col.r, p_col.g, p_col.b, 0.45 if not is_hovered else 0.65))
			_preview_canvas.draw_rect(r_rect, p_col if not is_hovered else Color.WHITE, false, 3.0 if is_hovered else 1.8)

			# Etiqueta central con fondo oscuro
			if tile_scale >= 2.5:
				var tag_text: String = "#%d\n%s" % [r.id, purpose_name]
				var tag_font_size: int = clampi(int(tile_scale * 0.85), 9, 13)
				var center_pt := r_rect.position + r_rect.size * 0.5
				var str_sz := ThemeDB.fallback_font.get_string_size(purpose_name, HORIZONTAL_ALIGNMENT_CENTER, -1, tag_font_size)
				var pill_w: float = maxf(str_sz.x + 10.0, 42.0)
				var pill_h: float = str_sz.y * 2.0 + 6.0
				var p_rect := Rect2(center_pt - Vector2(pill_w * 0.5, pill_h * 0.5), Vector2(pill_w, pill_h))

				_preview_canvas.draw_rect(p_rect, Color(0.08, 0.10, 0.14, 0.88))
				_preview_canvas.draw_rect(p_rect, p_col, false, 1.0)
				_preview_canvas.draw_string(
					ThemeDB.fallback_font,
					Vector2(p_rect.position.x, center_pt.y - 2.0),
					"#%d" % r.id,
					HORIZONTAL_ALIGNMENT_CENTER,
					int(pill_w),
					tag_font_size,
					Color.WHITE
				)
				_preview_canvas.draw_string(
					ThemeDB.fallback_font,
					Vector2(p_rect.position.x, center_pt.y + str_sz.y - 1.0),
					purpose_name,
					HORIZONTAL_ALIGNMENT_CENTER,
					int(pill_w),
					maxi(8, tag_font_size - 2),
					p_col
				)
		else:
			# VISTA DE GENERACIÓN
			_preview_canvas.draw_rect(r_rect, Color(1, 1, 1, 0.35 if not is_hovered else 0.65), false, 2.5 if is_hovered else 1.0)
			if is_hovered:
				_preview_canvas.draw_rect(r_rect, Color(1.0, 0.95, 0.40, 0.25))

			var is_special_objective = (r.room_type == &"boss" and is_boss_floor) or (r.room_type == &"start" and is_entry_floor) or (r.room_type == &"goal") or (r.room_type == &"treasure")

			if not is_special_objective and tile_scale >= 3.0:
				var label_text: String = "#%d" % r.id
				var tag_font_size: int = clampi(int(tile_scale * 0.9), 9, 11)
				var tag_pos := c_pos + Vector2(3, 3)
				_draw_text_pill(tag_pos, label_text, tag_font_size, Color(0.92, 0.92, 0.92, 0.95), Color(0.10, 0.12, 0.16, 0.85))

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

## Dibuja la tarjeta flotante de inspección detallada de una sala al pasar el cursor
func _draw_hover_tooltip_card(canvas_size: Vector2) -> void:
	if _hovered_room_id == -1 or _hovered_room_data.is_empty():
		return

	var d = _hovered_room_data
	var card_w: float = 270.0
	var card_h: float = 126.0

	var card_pos := _hovered_mouse_pos + Vector2(18.0, 18.0)
	if card_pos.x + card_w > canvas_size.x - 10.0:
		card_pos.x = _hovered_mouse_pos.x - card_w - 18.0
	if card_pos.y + card_h > canvas_size.y - 10.0:
		card_pos.y = canvas_size.y - card_h - 10.0
	card_pos.x = maxf(10.0, card_pos.x)
	card_pos.y = maxf(10.0, card_pos.y)

	var card_rect := Rect2(card_pos, Vector2(card_w, card_h))
	var p_col: Color = d.get("purpose_color", Color(0.3, 0.8, 0.4))

	# Fondo y borde resplandeciente
	_preview_canvas.draw_rect(card_rect, Color(0.08, 0.11, 0.16, 0.96))
	_preview_canvas.draw_rect(card_rect, p_col, false, 1.5)

	# Cabecera
	var header_rect := Rect2(card_pos, Vector2(card_w, 28.0))
	_preview_canvas.draw_rect(header_rect, Color(p_col.r, p_col.g, p_col.b, 0.22))

	var head_text: String = "🏛️ SALA #%d  [%s]  → %s" % [d.room_id, d.role, d.purpose_name]
	_preview_canvas.draw_string(ThemeDB.fallback_font, card_pos + Vector2(8, 19), head_text, HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 16), 12, Color.WHITE)

	# Línea 1: Dimensiones y Rol
	var l1_text: String = "📐 Tamaño: %s" % d.dimensions
	_preview_canvas.draw_string(ThemeDB.fallback_font, card_pos + Vector2(10, 48), l1_text, HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 20), 11, Color(0.85, 0.88, 0.94))

	# Línea 2: Estilos Arquitectónicos
	var l2_text: String = "🧱 %s | 🔲 %s | 🚪 %s" % [d.wall_style, d.floor_style, d.door_style]
	_preview_canvas.draw_string(ThemeDB.fallback_font, card_pos + Vector2(10, 72), l2_text, HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 20), 10, Color(0.70, 0.80, 0.95))

	# Línea 3: Composición de Props / Decoración
	var l3_text: String = "👑 Focal: %d | 📦 Support: %d | 🪨 Ambient: %d" % [d.focal_cnt, d.support_cnt, d.ambient_cnt]
	_preview_canvas.draw_string(ThemeDB.fallback_font, card_pos + Vector2(10, 96), l3_text, HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 20), 10, Color(0.95, 0.80, 0.35))

	# Línea 4: Indicador de piso
	var l4_text: String = "🏢 Piso %d" % (d.floor_idx + 1)
	_preview_canvas.draw_string(ThemeDB.fallback_font, card_pos + Vector2(10, 116), l4_text, HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 20), 9, Color(0.55, 0.60, 0.70))

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

func _get_purpose_color(p: Variant) -> Color:
	match str(p).to_lower():
		"entrance": return Color(0.3, 0.8, 0.4) # Verde esmeralda
		"throne_room", "royal_tomb", "sanctum", "forge":
			return Color(0.95, 0.3, 0.3) # Rojo carmesí / Jefe
		"armory", "guard_room", "crypt", "excavation":
			return Color(0.9, 0.6, 0.2) # Naranja cobrizo / Combate
		"tomb", "storage", "library", "mine_storage":
			return Color(0.3, 0.7, 0.95) # Azul zafiro / Tesoro
		"shrine", "altar_room", "sacristy", "meditation_room":
			return Color(0.8, 0.4, 0.9) # Púrpura místico / Sagrado
		_: return Color(0.7, 0.7, 0.75) # Gris pizarra / Neutro

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
	_update_archetypes_panel()

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
	_update_archetypes_panel()

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
	if _tab_archetypes_container != null:
		_tab_archetypes_container.visible = (tab_idx == 2)

	var btns = [_tab_btn_params, _tab_btn_floors, _tab_btn_archetypes]
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

func _update_archetypes_panel() -> void:
	if _tab_archetypes_container == null:
		return

	var sem: DungeonSemanticResult = _last_semantic
	if _last_multi_result != null:
		var target_f: int = 0 if _selected_floor_view == -1 else _selected_floor_view
		var f_data = _last_multi_result.get_floor(target_f)
		if f_data != null and f_data.semantic_result != null:
			sem = f_data.semantic_result

	if sem == null:
		if _arch_info_header != null:
			_arch_info_header.text = "🏛️ Sin datos semánticos disponibles"
		return

	if _arch_info_header != null:
		var arch_name: String = sem.dungeon_archetype_name
		var room_cnt: int = sem.rooms.size()
		var is_valid_str: String = "VALID" if sem.gameplay_valid else "INVALID"
		_arch_info_header.text = "🏛️ %s | Salas: %d | Estado: %s" % [arch_name, room_cnt, is_valid_str]

	# Distribución
	if _arch_dist_container != null:
		for c in _arch_dist_container.get_children():
			c.queue_free()

		var dist := sem.get_purpose_distribution()
		for p_type in dist:
			var p_name: String = str(p_type).to_upper()
			var p_count: int = int(dist[p_type])
			var badge := Label.new()
			badge.text = " [%s: %d] " % [p_name, p_count]
			badge.add_theme_color_override("font_color", _get_purpose_color(p_type))
			badge.add_theme_font_size_override("font_size", 10)
			_arch_dist_container.add_child(badge)

	# Lista de Salas
	if _arch_rooms_list != null:
		for c in _arch_rooms_list.get_children():
			c.queue_free()

		var sorted_ids: Array = sem.room_purposes.keys()
		sorted_ids.sort()

		for r_id in sorted_ids:
			var purpose_id: int = int(sem.room_purposes[r_id])
			var p_name: String = sem.get_room_purpose_name(r_id)
			var role: String = "EXPLORE"

			if r_id == sem.start_room_id:
				role = "START"
			elif r_id == sem.boss_room_id:
				role = "BOSS"
			else:
				for obj in sem.objectives:
					if obj.room_id == r_id:
						role = "TREASURE" if obj.type == 0 else "COMBAT"
						break

			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 1)

			var top_line := HBoxContainer.new()
			top_line.add_theme_constant_override("separation", 6)

			var lbl_id := Label.new()
			lbl_id.custom_minimum_size.x = 55
			lbl_id.text = "Sala #%d" % r_id
			lbl_id.add_theme_font_size_override("font_size", 11)

			var lbl_role := Label.new()
			lbl_role.custom_minimum_size.x = 75
			lbl_role.text = "[%s]" % role
			lbl_role.add_theme_font_size_override("font_size", 10)
			lbl_role.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3) if role in ["START", "BOSS", "TREASURE"] else Color(0.70, 0.75, 0.80))

			var lbl_purpose := Label.new()
			lbl_purpose.text = "→ %s" % p_name
			lbl_purpose.add_theme_font_size_override("font_size", 11)
			lbl_purpose.add_theme_color_override("font_color", _get_purpose_color(purpose_id))

			top_line.add_child(lbl_id)
			top_line.add_child(lbl_role)
			top_line.add_child(lbl_purpose)

			var arch_prof = _profile_resolver.resolve(sem.dungeon_archetype, purpose_id)
			var bot_line := Label.new()
			bot_line.add_theme_font_size_override("font_size", 9)
			bot_line.add_theme_color_override("font_color", Color(0.60, 0.65, 0.72))
			bot_line.text = "   🧱 %s | 🔲 %s | 🚪 %s" % [
				_ArchitecturalStyleScript.wall_to_name(arch_prof.wall_style),
				_ArchitecturalStyleScript.floor_to_name(arch_prof.floor_style),
				_ArchitecturalStyleScript.door_to_name(arch_prof.door_style)
			]

			row.add_child(top_line)
			row.add_child(bot_line)
			_arch_rooms_list.add_child(row)

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

func _populate_archetype_options() -> void:
	if _opt_archetype == null:
		return
	_opt_archetype.clear()
	var catalog := _ArchetypeCatalogScript.new()
	var loader := _ProfileLoaderScript.new()
	var ids := catalog.get_ids()

	var idx := 0
	for id in ids:
		var arch = loader.load_archetype(str(id))
		var display_name: String = str(id).capitalize()
		if arch != null and not arch.display_name.is_empty():
			display_name = str(arch.display_name)
		_opt_archetype.add_item(display_name, idx)
		_opt_archetype.set_item_metadata(idx, id)
		idx += 1

	_opt_archetype.add_item("Generic (Sin Arquetipo)", idx)
	_opt_archetype.set_item_metadata(idx, &"generic")
	_opt_archetype.selected = 0

func set_selected_archetype(p_arch: Variant) -> void:
	if _opt_archetype == null:
		return
	var target_id: StringName = _DungeonArchetypeScript.resolve_id(p_arch) if (p_arch is int or p_arch is float) else StringName(str(p_arch).to_lower())
	for idx in range(_opt_archetype.item_count):
		var meta = _opt_archetype.get_item_metadata(idx)
		if meta is StringName and meta == target_id:
			_opt_archetype.select(idx)
			return
		elif meta != null and str(meta).to_lower() == str(target_id).to_lower():
			_opt_archetype.select(idx)
			return
