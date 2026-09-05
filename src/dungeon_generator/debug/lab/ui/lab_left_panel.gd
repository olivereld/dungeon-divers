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
signal anchors_timing_toggled(mode: String)
signal composition_tuning_changed(param_name: String, value: Variant)

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

# Acordeones y Secciones
@onready var gen_header: Button = %GenHeader
@onready var gen_body: Control = %GenBody
@onready var comp_tuning_header: Button = %CompTuningHeader
@onready var comp_tuning_body: Control = %CompTuningBody
@onready var adv_tuning_header: Button = %AdvTuningHeader
@onready var adv_tuning_body: Control = %AdvTuningBody
@onready var struct_header: Button = %StructHeader
@onready var struct_body: Control = %StructBody
@onready var semantic_header: Button = %SemanticHeader
@onready var semantic_body: Control = %SemanticBody
@onready var debug_header: Button = %DebugHeader
@onready var debug_body: Control = %DebugBody
@onready var composition_header: Button = %CompositionHeader
@onready var composition_body: Control = %CompositionBody

# Controles de Composition Tuning
@onready var comp_version_option: OptionButton = %CompVersionOption
@onready var btn_dir_horiz: Button = %BtnDirHoriz
@onready var btn_dir_vert: Button = %BtnDirVert
@onready var btn_dir_diag: Button = %BtnDirDiag
@onready var btn_dir_rand: Button = %BtnDirRand
@onready var dir_status_label: Label = %DirStatusLabel

@onready var anchor_dist_slider: HSlider = %AnchorDistStrengthSlider
@onready var anchor_dist_val: Label = %AnchorDistStrengthVal
@onready var neighbor_coh_slider: HSlider = %NeighborCoherenceStrengthSlider
@onready var neighbor_coh_val: Label = %NeighborCoherenceStrengthVal
@onready var main_path_slider: HSlider = %MainPathAlignmentStrengthSlider
@onready var main_path_val: Label = %MainPathAlignmentStrengthVal
@onready var branch_lat_slider: HSlider = %BranchLateralStrengthSlider
@onready var branch_lat_val: Label = %BranchLateralStrengthVal
@onready var term_spacing_slider: HSlider = %TerminalSpacingStrengthSlider
@onready var term_spacing_val: Label = %TerminalSpacingStrengthVal
@onready var cand_count_slider: HSlider = %CompositionCandidateCountSlider
@onready var cand_count_val: Label = %CompositionCandidateCountVal

# Controles Avanzados (Advanced)
@onready var pref_dist_slider: HSlider = %PrefDistSlider
@onready var pref_dist_val: Label = %PrefDistVal
@onready var dist_jitter_slider: HSlider = %DistJitterSlider
@onready var dist_jitter_val: Label = %DistJitterVal
@onready var density_strength_slider: HSlider = %DensityStrengthSlider
@onready var density_strength_val: Label = %DensityStrengthVal

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

# Checkboxes de Overlays - Composición Espacial Global
var check_composition_anchors: CheckBox = null
var check_progression_axis: CheckBox = null
var check_main_path_comp: CheckBox = null
var check_branch_zones: CheckBox = null
var check_density_zones: CheckBox = null
var btn_anchors_timing: Button = null
var _current_timing_idx: int = 0

var _current_progression_dir: Vector2 = Vector2.ZERO
var _current_progression_mode: String = "random"
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

	# Acordeones
	if gen_header == null:
		gen_header = find_child("GenHeader", true, false) as Button
	if gen_body == null:
		gen_body = find_child("GenBody", true, false) as Control
	if comp_tuning_header == null:
		comp_tuning_header = find_child("CompTuningHeader", true, false) as Button
	if comp_tuning_body == null:
		comp_tuning_body = find_child("CompTuningBody", true, false) as Control
	if adv_tuning_header == null:
		adv_tuning_header = find_child("AdvTuningHeader", true, false) as Button
	if adv_tuning_body == null:
		adv_tuning_body = find_child("AdvTuningBody", true, false) as Control
	if struct_header == null:
		struct_header = find_child("StructHeader", true, false) as Button
	if struct_body == null:
		struct_body = find_child("StructBody", true, false) as Control
	if semantic_header == null:
		semantic_header = find_child("SemanticHeader", true, false) as Button
	if semantic_body == null:
		semantic_body = find_child("SemanticBody", true, false) as Control
	if debug_header == null:
		debug_header = find_child("DebugHeader", true, false) as Button
	if debug_body == null:
		debug_body = find_child("DebugBody", true, false) as Control
	if composition_header == null:
		composition_header = find_child("CompositionHeader", true, false) as Button
	if composition_body == null:
		composition_body = find_child("CompositionBody", true, false) as Control

	# Composition Tuning
	if comp_version_option == null:
		comp_version_option = find_child("CompVersionOption", true, false) as OptionButton
	if btn_dir_horiz == null:
		btn_dir_horiz = find_child("BtnDirHoriz", true, false) as Button
	if btn_dir_vert == null:
		btn_dir_vert = find_child("BtnDirVert", true, false) as Button
	if btn_dir_diag == null:
		btn_dir_diag = find_child("BtnDirDiag", true, false) as Button
	if btn_dir_rand == null:
		btn_dir_rand = find_child("BtnDirRand", true, false) as Button
	if dir_status_label == null:
		dir_status_label = find_child("DirStatusLabel", true, false) as Label

	if anchor_dist_slider == null:
		anchor_dist_slider = find_child("AnchorDistStrengthSlider", true, false) as HSlider
	if anchor_dist_val == null:
		anchor_dist_val = find_child("AnchorDistStrengthVal", true, false) as Label
	if neighbor_coh_slider == null:
		neighbor_coh_slider = find_child("NeighborCoherenceStrengthSlider", true, false) as HSlider
	if neighbor_coh_val == null:
		neighbor_coh_val = find_child("NeighborCoherenceStrengthVal", true, false) as Label
	if main_path_slider == null:
		main_path_slider = find_child("MainPathAlignmentStrengthSlider", true, false) as HSlider
	if main_path_val == null:
		main_path_val = find_child("MainPathAlignmentStrengthVal", true, false) as Label
	if branch_lat_slider == null:
		branch_lat_slider = find_child("BranchLateralStrengthSlider", true, false) as HSlider
	if branch_lat_val == null:
		branch_lat_val = find_child("BranchLateralStrengthVal", true, false) as Label
	if term_spacing_slider == null:
		term_spacing_slider = find_child("TerminalSpacingStrengthSlider", true, false) as HSlider
	if term_spacing_val == null:
		term_spacing_val = find_child("TerminalSpacingStrengthVal", true, false) as Label
	if cand_count_slider == null:
		cand_count_slider = find_child("CompositionCandidateCountSlider", true, false) as HSlider
	if cand_count_val == null:
		cand_count_val = find_child("CompositionCandidateCountVal", true, false) as Label

	# Advanced Sliders
	if pref_dist_slider == null:
		pref_dist_slider = find_child("PrefDistSlider", true, false) as HSlider
	if pref_dist_val == null:
		pref_dist_val = find_child("PrefDistVal", true, false) as Label
	if dist_jitter_slider == null:
		dist_jitter_slider = find_child("DistJitterSlider", true, false) as HSlider
	if dist_jitter_val == null:
		dist_jitter_val = find_child("DistJitterVal", true, false) as Label
	if density_strength_slider == null:
		density_strength_slider = find_child("DensityStrengthSlider", true, false) as HSlider
	if density_strength_val == null:
		density_strength_val = find_child("DensityStrengthVal", true, false) as Label

	# Overlays
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
	if check_composition_anchors == null:
		check_composition_anchors = find_child("CheckCompositionAnchors", true, false) as CheckBox
	if check_progression_axis == null:
		check_progression_axis = find_child("CheckProgressionAxis", true, false) as CheckBox
	if check_main_path_comp == null:
		check_main_path_comp = find_child("CheckMainPathComp", true, false) as CheckBox
	if check_branch_zones == null:
		check_branch_zones = find_child("CheckBranchZones", true, false) as CheckBox
	if check_density_zones == null:
		check_density_zones = find_child("CheckDensityZones", true, false) as CheckBox
	if btn_anchors_timing == null:
		btn_anchors_timing = find_child("BtnAnchorsTiming", true, false) as Button

func _enter_tree() -> void:
	_ensure_nodes()

func _ready() -> void:
	_ensure_nodes()
	custom_minimum_size = Vector2(230, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _LabColors.BG_PANEL
	sb.border_color = _LabColors.BORDER
	sb.border_width_right = 1
	add_theme_stylebox_override("panel", sb)

	_style_generate_button()
	_setup_accordions()
	_setup_composition_controls()
	_setup_signals()
	_update_tab_visibility(0)

func _style_accordion_header(btn: Button) -> void:
	if btn == null:
		return
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", _LabColors.AMBER)
	btn.add_theme_color_override("font_hover_color", Color("#fbbf24"))
	btn.add_theme_color_override("font_pressed_color", _LabColors.AMBER)

func _setup_accordions() -> void:
	_setup_accordion(gen_header, gen_body, "GENERATION", true)
	_setup_accordion(comp_tuning_header, comp_tuning_body, "COMPOSITION TUNING", true)
	_setup_accordion(adv_tuning_header, adv_tuning_body, "ADVANCED", false)
	_setup_accordion(struct_header, struct_body, "OVERLAYS · STRUCTURE", true)
	_setup_accordion(semantic_header, semantic_body, "OVERLAYS · SEMANTIC", true)
	_setup_accordion(debug_header, debug_body, "OVERLAYS · DEBUG", true)
	_setup_accordion(composition_header, composition_body, "OVERLAYS · COMPOSICIÓN", true)

func _setup_accordion(header_btn: Button, body_node: Control, title: String, default_open: bool = true) -> void:
	if header_btn == null or body_node == null:
		return
	_style_accordion_header(header_btn)
	body_node.visible = default_open
	header_btn.text = ("▼ " if default_open else "▶ ") + title
	var callable := _toggle_accordion.bind(header_btn, body_node, title)
	if not header_btn.pressed.is_connected(callable):
		header_btn.pressed.connect(callable)

func _toggle_accordion(header_btn: Button, body_node: Control, title: String) -> void:
	if header_btn == null or body_node == null:
		return
	var now_open: bool = not body_node.visible
	body_node.visible = now_open
	header_btn.text = ("▼ " if now_open else "▶ ") + title

func _setup_composition_controls() -> void:
	# Inicializar CompVersionOption
	if comp_version_option != null and comp_version_option.item_count == 0:
		comp_version_option.add_item("V2 (Global Spatial)", 2)
		comp_version_option.add_item("V1 (Local)", 1)
		comp_version_option.selected = 0
		comp_version_option.item_selected.connect(func(idx):
			var v = comp_version_option.get_item_id(idx)
			composition_tuning_changed.emit("composition_version", v)
		)

	# Inicializar botones direccionales
	if btn_dir_horiz != null and not btn_dir_horiz.pressed.is_connected(set_progression_direction_mode.bind("horizontal")):
		btn_dir_horiz.pressed.connect(set_progression_direction_mode.bind("horizontal"))
	if btn_dir_vert != null and not btn_dir_vert.pressed.is_connected(set_progression_direction_mode.bind("vertical")):
		btn_dir_vert.pressed.connect(set_progression_direction_mode.bind("vertical"))
	if btn_dir_diag != null and not btn_dir_diag.pressed.is_connected(set_progression_direction_mode.bind("diagonal")):
		btn_dir_diag.pressed.connect(set_progression_direction_mode.bind("diagonal"))
	if btn_dir_rand != null and not btn_dir_rand.pressed.is_connected(set_progression_direction_mode.bind("random")):
		btn_dir_rand.pressed.connect(set_progression_direction_mode.bind("random"))
	set_progression_direction_mode("random")

	# Vincular sliders con sus etiquetas de valor
	_bind_slider_label(anchor_dist_slider, anchor_dist_val, "%.2f", "anchor_distance_strength")
	_bind_slider_label(neighbor_coh_slider, neighbor_coh_val, "%.2f", "neighbor_coherence_strength")
	_bind_slider_label(main_path_slider, main_path_val, "%.2f", "main_path_alignment_strength")
	_bind_slider_label(branch_lat_slider, branch_lat_val, "%.2f", "branch_lateral_strength")
	_bind_slider_label(term_spacing_slider, term_spacing_val, "%.2f", "terminal_spacing_strength")
	_bind_slider_label(cand_count_slider, cand_count_val, "%d", "composition_candidate_count")

	# Sliders Avanzados
	_bind_slider_label(pref_dist_slider, pref_dist_val, "%.1f", "mission_aware_preferred_distance")
	_bind_slider_label(dist_jitter_slider, dist_jitter_val, "%.1f", "mission_aware_distance_jitter")
	_bind_slider_label(density_strength_slider, density_strength_val, "%.2f", "density_strength")

func _bind_slider_label(slider: HSlider, label: Label, format_str: String, param_key: String = "") -> void:
	if slider == null:
		return
	if label != null:
		label.text = format_str % slider.value
	slider.value_changed.connect(func(v: float):
		if label != null:
			label.text = format_str % v
		if not param_key.is_empty():
			composition_tuning_changed.emit(param_key, v)
	)

func set_progression_direction_mode(mode: String) -> void:
	_current_progression_mode = mode.to_lower()
	match _current_progression_mode:
		"horizontal":
			_current_progression_dir = Vector2(1, 0)
			if dir_status_label != null:
				dir_status_label.text = "DIR: HORIZONTAL (1, 0)"
		"vertical":
			_current_progression_dir = Vector2(0, 1)
			if dir_status_label != null:
				dir_status_label.text = "DIR: VERTICAL (0, 1)"
		"diagonal":
			_current_progression_dir = Vector2(1, 1).normalized()
			if dir_status_label != null:
				dir_status_label.text = "DIR: DIAGONAL (0.7, 0.7)"
		_:
			_current_progression_mode = "random"
			_current_progression_dir = Vector2.ZERO
			if dir_status_label != null:
				dir_status_label.text = "DIR: RANDOM (0, 0)"
	_update_direction_button_styles()
	composition_tuning_changed.emit("preferred_progression_direction", _current_progression_dir)

func _update_direction_button_styles() -> void:
	var buttons = {
		"horizontal": btn_dir_horiz,
		"vertical": btn_dir_vert,
		"diagonal": btn_dir_diag,
		"random": btn_dir_rand
	}
	for m in buttons.keys():
		var btn = buttons[m] as Button
		if btn == null:
			continue
		var is_active: bool = (_current_progression_mode == m)
		if is_active:
			btn.add_theme_color_override("font_color", _LabColors.AMBER)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.96, 0.62, 0.04, 0.2)
			sb.border_color = _LabColors.AMBER
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(3)
			btn.add_theme_stylebox_override("normal", sb)
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.12, 0.16, 0.5)
			sb.border_color = Color(0.2, 0.24, 0.32, 1)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(3)
			btn.add_theme_stylebox_override("normal", sb)

func get_composition_version() -> int:
	if comp_version_option == null or comp_version_option.selected < 0:
		return 2
	var id = comp_version_option.get_item_id(comp_version_option.selected)
	return id if id > 0 else 2

func get_preferred_progression_direction() -> Vector2:
	return _current_progression_dir

func get_anchor_distance_strength() -> float:
	return anchor_dist_slider.value if anchor_dist_slider != null else 1.0

func get_neighbor_coherence_strength() -> float:
	return neighbor_coh_slider.value if neighbor_coh_slider != null else 1.0

func get_main_path_alignment_strength() -> float:
	return main_path_slider.value if main_path_slider != null else 1.0

func get_branch_lateral_strength() -> float:
	return branch_lat_slider.value if branch_lat_slider != null else 0.75

func get_terminal_spacing_strength() -> float:
	return term_spacing_slider.value if term_spacing_slider != null else 0.75

func get_composition_candidate_count() -> int:
	return int(cand_count_slider.value) if cand_count_slider != null else 24

func get_preferred_distance() -> float:
	return pref_dist_slider.value if pref_dist_slider != null else 12.0

func get_distance_jitter() -> float:
	return dist_jitter_slider.value if dist_jitter_slider != null else 4.0

func get_density_strength() -> float:
	return density_strength_slider.value if density_strength_slider != null else 0.5

func get_composition_tuning_settings() -> Dictionary:
	return {
		"composition_version": get_composition_version(),
		"preferred_progression_direction": get_preferred_progression_direction(),
		"anchor_distance_strength": get_anchor_distance_strength(),
		"neighbor_coherence_strength": get_neighbor_coherence_strength(),
		"main_path_alignment_strength": get_main_path_alignment_strength(),
		"branch_lateral_strength": get_branch_lateral_strength(),
		"terminal_spacing_strength": get_terminal_spacing_strength(),
		"composition_candidate_count": get_composition_candidate_count(),
		"preferred_distance": get_preferred_distance(),
		"distance_jitter": get_distance_jitter(),
		"density_strength": get_density_strength()
	}

func set_composition_version(version: int) -> void:
	_ensure_nodes()
	if comp_version_option != null:
		for i in range(comp_version_option.item_count):
			if comp_version_option.get_item_id(i) == version:
				comp_version_option.selected = i
				composition_tuning_changed.emit("composition_version", version)
				break

func set_anchor_distance_strength(val: float) -> void:
	_ensure_nodes()
	if anchor_dist_slider != null:
		anchor_dist_slider.value = val
	if anchor_dist_val != null:
		anchor_dist_val.text = "%.2f" % val
	composition_tuning_changed.emit("anchor_distance_strength", val)

func set_neighbor_coherence_strength(val: float) -> void:
	_ensure_nodes()
	if neighbor_coh_slider != null:
		neighbor_coh_slider.value = val
	if neighbor_coh_val != null:
		neighbor_coh_val.text = "%.2f" % val
	composition_tuning_changed.emit("neighbor_coherence_strength", val)

func set_main_path_alignment_strength(val: float) -> void:
	_ensure_nodes()
	if main_path_slider != null:
		main_path_slider.value = val
	if main_path_val != null:
		main_path_val.text = "%.2f" % val
	composition_tuning_changed.emit("main_path_alignment_strength", val)

func set_branch_lateral_strength(val: float) -> void:
	_ensure_nodes()
	if branch_lat_slider != null:
		branch_lat_slider.value = val
	if branch_lat_val != null:
		branch_lat_val.text = "%.2f" % val
	composition_tuning_changed.emit("branch_lateral_strength", val)

func set_terminal_spacing_strength(val: float) -> void:
	_ensure_nodes()
	if term_spacing_slider != null:
		term_spacing_slider.value = val
	if term_spacing_val != null:
		term_spacing_val.text = "%.2f" % val
	composition_tuning_changed.emit("terminal_spacing_strength", val)

func set_composition_candidate_count(val: int) -> void:
	_ensure_nodes()
	if cand_count_slider != null:
		cand_count_slider.value = val
	if cand_count_val != null:
		cand_count_val.text = "%d" % val
	composition_tuning_changed.emit("composition_candidate_count", val)

func set_preferred_distance(val: float) -> void:
	_ensure_nodes()
	if pref_dist_slider != null:
		pref_dist_slider.value = val
	if pref_dist_val != null:
		pref_dist_val.text = "%.1f" % val
	composition_tuning_changed.emit("mission_aware_preferred_distance", val)

func set_distance_jitter(val: float) -> void:
	_ensure_nodes()
	if dist_jitter_slider != null:
		dist_jitter_slider.value = val
	if dist_jitter_val != null:
		dist_jitter_val.text = "%.1f" % val
	composition_tuning_changed.emit("mission_aware_distance_jitter", val)

func set_density_strength(val: float) -> void:
	_ensure_nodes()
	if density_strength_slider != null:
		density_strength_slider.value = val
	if density_strength_val != null:
		density_strength_val.text = "%.2f" % val
	composition_tuning_changed.emit("density_strength", val)

func apply_to_lab_config(l_cfg) -> void:
	if l_cfg == null:
		return
	l_cfg.composition_version = get_composition_version()
	l_cfg.preferred_progression_direction = get_preferred_progression_direction()
	l_cfg.anchor_distance_strength = get_anchor_distance_strength()
	l_cfg.anchor_strength = get_anchor_distance_strength()
	l_cfg.neighbor_coherence_strength = get_neighbor_coherence_strength()
	l_cfg.neighbor_strength = get_neighbor_coherence_strength()
	l_cfg.main_path_alignment_strength = get_main_path_alignment_strength()
	l_cfg.main_path_strength = get_main_path_alignment_strength()
	l_cfg.branch_lateral_strength = get_branch_lateral_strength()
	l_cfg.branch_strength = get_branch_lateral_strength()
	l_cfg.terminal_spacing_strength = get_terminal_spacing_strength()
	l_cfg.terminal_strength = get_terminal_spacing_strength()
	l_cfg.composition_candidate_count = get_composition_candidate_count()
	l_cfg.candidate_count = get_composition_candidate_count()
	l_cfg.mission_aware_preferred_distance = get_preferred_distance()
	l_cfg.mission_aware_distance_jitter = get_distance_jitter()
	l_cfg.density_strength = get_density_strength()

func apply_to_dungeon_config(d_cfg) -> void:
	if d_cfg == null:
		return
	d_cfg.composition_version = get_composition_version()
	d_cfg.preferred_progression_direction = get_preferred_progression_direction()
	d_cfg.anchor_distance_strength = get_anchor_distance_strength()
	d_cfg.anchor_strength = get_anchor_distance_strength()
	d_cfg.neighbor_coherence_strength = get_neighbor_coherence_strength()
	d_cfg.neighbor_strength = get_neighbor_coherence_strength()
	d_cfg.main_path_alignment_strength = get_main_path_alignment_strength()
	d_cfg.main_path_strength = get_main_path_alignment_strength()
	d_cfg.branch_lateral_strength = get_branch_lateral_strength()
	d_cfg.branch_strength = get_branch_lateral_strength()
	d_cfg.terminal_spacing_strength = get_terminal_spacing_strength()
	d_cfg.terminal_strength = get_terminal_spacing_strength()
	d_cfg.composition_candidate_count = get_composition_candidate_count()
	d_cfg.candidate_count = get_composition_candidate_count()
	d_cfg.mission_aware_preferred_distance = get_preferred_distance()
	d_cfg.mission_aware_distance_jitter = get_distance_jitter()
	d_cfg.density_strength = get_density_strength()

	if "space_grammar_config" in d_cfg and d_cfg.space_grammar_config != null:
		var sgc = d_cfg.space_grammar_config
		sgc.composition_candidate_count = d_cfg.composition_candidate_count
		sgc.candidate_count = d_cfg.candidate_count
		sgc.anchor_distance_strength = d_cfg.anchor_distance_strength
		sgc.anchor_strength = d_cfg.anchor_strength
		sgc.neighbor_coherence_strength = d_cfg.neighbor_coherence_strength
		sgc.neighbor_strength = d_cfg.neighbor_strength
		sgc.main_path_alignment_strength = d_cfg.main_path_alignment_strength
		sgc.main_path_strength = d_cfg.main_path_strength
		sgc.branch_lateral_strength = d_cfg.branch_lateral_strength
		sgc.branch_strength = d_cfg.branch_strength
		sgc.terminal_spacing_strength = d_cfg.terminal_spacing_strength
		sgc.terminal_strength = d_cfg.terminal_strength
		sgc.mission_aware_preferred_distance = d_cfg.mission_aware_preferred_distance
		sgc.mission_aware_distance_jitter = d_cfg.mission_aware_distance_jitter
		sgc.density_strength = d_cfg.density_strength
		sgc.preferred_progression_direction = d_cfg.preferred_progression_direction

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
	_bind_checkbox(check_composition_anchors, "composition_anchors")
	_bind_checkbox(check_progression_axis, "progression_axis")
	_bind_checkbox(check_main_path_comp, "main_path_composition")
	_bind_checkbox(check_branch_zones, "branch_zones")
	_bind_checkbox(check_density_zones, "density_zones")

	if btn_anchors_timing != null and not btn_anchors_timing.pressed.is_connected(_on_anchors_timing_btn_pressed):
		btn_anchors_timing.pressed.connect(_on_anchors_timing_btn_pressed)

func _on_anchors_timing_btn_pressed() -> void:
	var modes: Array[String] = ["both", "before", "after"]
	var mode_labels: Array[String] = [
		"Anchors: Both (Pre+Post)",
		"Anchors: Before (Planned)",
		"Anchors: After (Placed)"
	]
	_current_timing_idx = (_current_timing_idx + 1) % modes.size()
	if btn_anchors_timing != null:
		btn_anchors_timing.text = mode_labels[_current_timing_idx]
	anchors_timing_toggled.emit(modes[_current_timing_idx])

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
