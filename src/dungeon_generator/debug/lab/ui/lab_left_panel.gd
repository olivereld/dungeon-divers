class_name LabLeftPanel
extends PanelContainer

signal generate_requested()
signal random_seed_requested()
signal seed_changed(new_seed: int)
signal algo_changed(algo_idx: int)
signal algorithm_changed(algo_name: String)
signal floors_changed(count: int)
signal floor_changed(count: int)
signal floor_selected(floor_idx: int)
signal tab_changed(tab_idx: int)
signal overlay_toggled(key: String, enabled: bool)

const _LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")

# Controles de Generación
@onready var mode_tabs: TabBar = %ModeTabs
@onready var gen_scroll: ScrollContainer = %GenScroll
@onready var room_scroll: ScrollContainer = %RoomScroll

@onready var seed_spin: SpinBox = %SeedSpin
@onready var seed_edit: LineEdit = %SeedSpin.get_line_edit() if %SeedSpin != null else null
@onready var random_seed_btn: Button = %RandomSeedBtn
@onready var algo_option: OptionButton = %AlgoOption
@onready var floor_spin: SpinBox = %FloorSpin
@onready var floor_selector: OptionButton = %FloorSelectOption
@onready var generate_btn: Button = %GenerateBtn
@onready var floor_badge_label: Label = %FloorBadgeLabel
@onready var footer_badge: Label = %FloorBadgeLabel

# Checkboxes de Overlays - Estructura
@onready var check_room_bounds: CheckBox = %CheckRoomBounds
@onready var check_template_footprint: CheckBox = %CheckTemplateFootprint
@onready var check_corridors: CheckBox = %CheckCorridors
@onready var check_corridor_details: CheckBox = %CheckCorridorDetails

# Checkboxes de Overlays - Semántica
@onready var check_entrances: CheckBox = %CheckEntrances
@onready var check_internal_doors: CheckBox = %CheckInternalDoors
@onready var check_semantic_labels: CheckBox = %CheckSemanticLabels
@onready var check_stairs: CheckBox = %CheckStairs

# Checkboxes de Overlays - Depuración
@onready var check_spatial_overlay: CheckBox = %CheckSpatialOverlay
@onready var check_semantics_overlay: CheckBox = %CheckSemanticsOverlay
@onready var check_template_id: CheckBox = %CheckTemplateId

var _signals_setup := false

func _ensure_nodes() -> void:
	if mode_tabs == null:
		mode_tabs = find_child("ModeTabs", true, false) as TabBar
	if gen_scroll == null:
		gen_scroll = find_child("GenScroll", true, false) as ScrollContainer
	if room_scroll == null:
		room_scroll = find_child("RoomScroll", true, false) as ScrollContainer
	if seed_spin == null:
		seed_spin = find_child("SeedSpin", true, false) as SpinBox
	if seed_edit == null and seed_spin != null:
		seed_edit = seed_spin.get_line_edit()
	if random_seed_btn == null:
		random_seed_btn = find_child("RandomSeedBtn", true, false) as Button
	if algo_option == null:
		algo_option = find_child("AlgoOption", true, false) as OptionButton
	if floor_spin == null:
		floor_spin = find_child("FloorSpin", true, false) as SpinBox
	if floor_selector == null:
		floor_selector = find_child("FloorSelectOption", true, false) as OptionButton
	if generate_btn == null:
		generate_btn = find_child("GenerateBtn", true, false) as Button
	if floor_badge_label == null:
		floor_badge_label = find_child("FloorBadgeLabel", true, false) as Label
		footer_badge = floor_badge_label

	if check_room_bounds == null:
		check_room_bounds = find_child("CheckRoomBounds", true, false) as CheckBox
	if check_template_footprint == null:
		check_template_footprint = find_child("CheckTemplateFootprint", true, false) as CheckBox
	if check_corridors == null:
		check_corridors = find_child("CheckCorridors", true, false) as CheckBox
	if check_corridor_details == null:
		check_corridor_details = find_child("CheckCorridorDetails", true, false) as CheckBox
	if check_entrances == null:
		check_entrances = find_child("CheckEntrances", true, false) as CheckBox
	if check_internal_doors == null:
		check_internal_doors = find_child("CheckInternalDoors", true, false) as CheckBox
	if check_semantic_labels == null:
		check_semantic_labels = find_child("CheckSemanticLabels", true, false) as CheckBox
	if check_stairs == null:
		check_stairs = find_child("CheckStairs", true, false) as CheckBox
	if check_spatial_overlay == null:
		check_spatial_overlay = find_child("CheckSpatialOverlay", true, false) as CheckBox
	if check_semantics_overlay == null:
		check_semantics_overlay = find_child("CheckSemanticsOverlay", true, false) as CheckBox
	if check_template_id == null:
		check_template_id = find_child("CheckTemplateId", true, false) as CheckBox

func _ready() -> void:
	_ensure_nodes()
	custom_minimum_size = Vector2(230, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _LabColors.BG_PANEL
	sb.border_color = _LabColors.BORDER
	sb.border_width_right = 1
	add_theme_stylebox_override("panel", sb)

	_style_generate_button()
	_setup_signals()
	_update_tab_visibility(0)

func _style_generate_button() -> void:
	if generate_btn == null:
		return
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = _LabColors.AMBER
	sb_normal.border_color = _LabColors.AMBER_DIM
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(4)
	generate_btn.add_theme_stylebox_override("normal", sb_normal)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color("#fbbf24")
	sb_hover.border_color = _LabColors.AMBER
	sb_hover.set_border_width_all(1)
	sb_hover.set_corner_radius_all(4)
	generate_btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color("#d97706")
	sb_pressed.border_color = _LabColors.AMBER_DIM
	sb_pressed.set_border_width_all(1)
	sb_pressed.set_corner_radius_all(4)
	generate_btn.add_theme_stylebox_override("pressed", sb_pressed)

	generate_btn.add_theme_color_override("font_color", Color.BLACK)
	generate_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	generate_btn.add_theme_color_override("font_pressed_color", Color.BLACK)

func _setup_signals() -> void:
	if _signals_setup:
		return
	_signals_setup = true

	if mode_tabs != null:
		mode_tabs.tab_changed.connect(_on_tab_changed)

	if generate_btn != null:
		generate_btn.pressed.connect(func(): generate_requested.emit())

	if random_seed_btn != null:
		random_seed_btn.pressed.connect(func(): random_seed_requested.emit())

	if seed_spin != null:
		seed_spin.value_changed.connect(func(val): seed_changed.emit(int(val)))

	if algo_option != null:
		algo_option.item_selected.connect(func(idx):
			algo_changed.emit(idx)
			var txt := algo_option.get_item_text(idx)
			algorithm_changed.emit(txt)
		)

	if floor_spin != null:
		floor_spin.value_changed.connect(func(val):
			floors_changed.emit(int(val))
			floor_changed.emit(int(val))
			if floor_selector != null:
				floor_selector.visible = (val > 1)
		)
	if floor_selector != null:
		floor_selector.item_selected.connect(func(idx): floor_selected.emit(idx))

	# Conectar checkboxes a señales
	_bind_checkbox(check_room_bounds, "room_bounds")
	_bind_checkbox(check_template_footprint, "template_footprint")
	_bind_checkbox(check_corridors, "corridors")
	_bind_checkbox(check_corridor_details, "corridor_details")
	_bind_checkbox(check_entrances, "entrances")
	_bind_checkbox(check_internal_doors, "internal_doors")
	_bind_checkbox(check_semantic_labels, "semantic_labels")
	_bind_checkbox(check_stairs, "stairs")
	_bind_checkbox(check_spatial_overlay, "spatial_overlay")
	_bind_checkbox(check_semantics_overlay, "semantics_overlay")
	_bind_checkbox(check_template_id, "template_id")

func _bind_checkbox(cb: CheckBox, key: String) -> void:
	if cb != null:
		cb.toggled.connect(func(val): overlay_toggled.emit(key, val))

func _on_tab_changed(idx: int) -> void:
	_update_tab_visibility(idx)
	tab_changed.emit(idx)

func _update_tab_visibility(idx: int) -> void:
	if gen_scroll != null:
		gen_scroll.visible = (idx == 0)
	if room_scroll != null:
		room_scroll.visible = (idx == 1)

func update_footer_badge(floor_num: int, algo_name: String, seed_val: int) -> void:
	if floor_badge_label != null:
		floor_badge_label.text = "FLOOR %d  ·  %s  ·  %d" % [floor_num, algo_name, seed_val]

func update_footer(floor_num: int, algo_name: String, seed_val: int) -> void:
	update_footer_badge(floor_num, algo_name, seed_val)
