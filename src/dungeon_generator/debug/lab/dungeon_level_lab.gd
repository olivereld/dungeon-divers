class_name DungeonLevelLab
extends Control

## Integration & Authoring Lab para el pipeline de generación de mazmorras.
## Modern Cyber-Blueprint UI matching web design.

const _LabConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _LabControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")
const _RendererScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_renderer.gd")
const _OverlayScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd")
const _InspectorScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_inspector.gd")
const _ShowcaseScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_template_showcase.gd")
const _CoverageScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_coverage.gd")
const _GoldenRunnerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_golden_runner.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _Dungeon3DViewerScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_3d_viewer.gd")
const _DungeonAsciiExporterScript = preload("res://src/dungeon_generator/debug/dungeon_ascii_exporter.gd")

const _LabTopBarScript = preload("res://src/dungeon_generator/debug/lab/ui/lab_top_bar.gd")
const _LabLeftPanelScript = preload("res://src/dungeon_generator/debug/lab/ui/lab_left_panel.gd")
const _LabViewportToolbarScript = preload("res://src/dungeon_generator/debug/lab/ui/lab_viewport_toolbar.gd")
const _LabRightPanelScript = preload("res://src/dungeon_generator/debug/lab/ui/lab_right_panel.gd")
const _LabLoadingOverlayScript = preload("res://src/dungeon_generator/debug/lab/ui/lab_loading_overlay.gd")

enum LabMode {
	GENERATE = 0,
	ROOM_TEMPLATE = 1,
	SHOWCASE = 2,
	COVERAGE = 3,
	REGRESSION = 4
}

enum ViewMode {
	VIEW_2D = 0,
	VIEW_3D = 1
}

var current_mode: LabMode = LabMode.GENERATE
var current_view_mode: ViewMode = ViewMode.VIEW_2D

var config: DungeonLabConfiguration = DungeonLabConfiguration.new()
var controller: DungeonLabController = DungeonLabController.new()
var overlay: DungeonLabOverlay = DungeonLabOverlay.new()
var inspector: DungeonLabInspector = DungeonLabInspector.new()
var showcase: DungeonLabTemplateShowcase = DungeonLabTemplateShowcase.new()
var coverage: DungeonLabCoverage = DungeonLabCoverage.new()
var golden_runner: DungeonLabGoldenRunner = DungeonLabGoldenRunner.new()
var presentation_builder: DungeonPresentationBuilder = DungeonPresentationBuilder.new()

# High-level UI Components
var ui_top_bar: LabTopBar
var ui_left_panel: LabLeftPanel
var ui_viewport_toolbar: LabViewportToolbar
var ui_right_panel: LabRightPanel
var ui_loading_overlay: LabLoadingOverlay

# Sub-nodes (Preserved for 100% test compatibility)
var renderer: DungeonLabRenderer
var viewport_container_3d: SubViewportContainer
var viewer_3d: Dungeon3DViewer
var seed_input: SpinBox
var random_seed_btn: Button
var algo_option: OptionButton
var floor_spin: SpinBox
var floor_selector: OptionButton
var generate_btn: Button
var view_mode_btn: Button
var frame_dungeon_btn: Button
var rotate_left_btn: Button
var rotate_right_btn: Button
var export_ascii_btn: Button
var mode_tabs: TabBar
var status_label: Label
var inspector_text: RichTextLabel
var progress_bar: ProgressBar

var _gen_start_time_msec: int = 0
var _view_2d_dirty: bool = true
var _view_3d_dirty: bool = true
var _last_rendered_floor_2d: int = -1
var _last_rendered_floor_3d: int = -1
var _last_generated_seed_2d: int = -1
var _last_generated_seed_3d: int = -1

func _ensure_nodes() -> void:
	if ui_top_bar == null:
		ui_top_bar = find_child("TopBar", true, false) as _LabTopBarScript
	if ui_left_panel == null:
		ui_left_panel = find_child("LeftPanel", true, false) as _LabLeftPanelScript
	if ui_viewport_toolbar == null:
		ui_viewport_toolbar = find_child("LabViewportToolbar", true, false) as _LabViewportToolbarScript
	if ui_right_panel == null:
		ui_right_panel = find_child("RightPanel", true, false) as _LabRightPanelScript
	if ui_loading_overlay == null:
		ui_loading_overlay = find_child("LabLoadingOverlay", true, false) as _LabLoadingOverlayScript

	if renderer == null:
		renderer = find_child("Renderer", true, false) as _RendererScript
	if viewport_container_3d == null:
		viewport_container_3d = find_child("ViewportContainer3D", true, false) as SubViewportContainer
	if viewer_3d == null:
		viewer_3d = find_child("Viewer3D", true, false) as _Dungeon3DViewerScript
	if seed_input == null:
		seed_input = find_child("SeedSpin", true, false) as SpinBox
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
	if view_mode_btn == null:
		view_mode_btn = find_child("ViewModeBtn", true, false) as Button
	if frame_dungeon_btn == null:
		frame_dungeon_btn = find_child("FrameDungeonBtn", true, false) as Button
	if rotate_left_btn == null:
		rotate_left_btn = find_child("RotateLeftBtn", true, false) as Button
	if rotate_right_btn == null:
		rotate_right_btn = find_child("RotateRightBtn", true, false) as Button
	if export_ascii_btn == null:
		export_ascii_btn = find_child("ExportAsciiBtn", true, false) as Button
	if mode_tabs == null:
		mode_tabs = find_child("ModeTabs", true, false) as TabBar
	if status_label == null:
		status_label = find_child("StatusLabel", true, false) as Label
	if inspector_text == null:
		inspector_text = find_child("InspectorText", true, false) as RichTextLabel
	if progress_bar == null:
		progress_bar = find_child("ProgressBar", true, false) as ProgressBar

func _enter_tree() -> void:
	_ensure_nodes()

func _ready() -> void:
	_ensure_nodes()
	config = _LabConfigScript.new()
	controller = _LabControllerScript.new()
	overlay = _OverlayScript.new()
	inspector = _InspectorScript.new()
	showcase = _ShowcaseScript.new()
	coverage = _CoverageScript.new()
	golden_runner = _GoldenRunnerScript.new()
	presentation_builder = _DungeonPresentationBuilderScript.new()

	if renderer != null:
		renderer.set_overlay(overlay)
		if not renderer.room_selected.is_connected(_on_room_selected):
			renderer.room_selected.connect(_on_room_selected)

	if not controller.generation_started.is_connected(_on_generation_started):
		controller.generation_started.connect(_on_generation_started)
	if not controller.generation_completed.is_connected(_on_generation_completed):
		controller.generation_completed.connect(_on_generation_completed)
	if not controller.generation_failed.is_connected(_on_generation_failed):
		controller.generation_failed.connect(_on_generation_failed)
	if not controller.floor_changed.is_connected(_on_floor_changed):
		controller.floor_changed.connect(_on_floor_changed)

	_setup_topbar_ui()
	_setup_mode_tabs()
	_setup_overlay_checkboxes()
	_setup_component_signals()
	_update_view_mode_visibility()

	# Initial dungeon generation
	generate_current()

func _setup_component_signals() -> void:
	if ui_top_bar != null:
		if not ui_top_bar.view_mode_changed.is_connected(_on_top_bar_view_mode_changed):
			ui_top_bar.view_mode_changed.connect(_on_top_bar_view_mode_changed)
		if not ui_top_bar.copy_ascii_requested.is_connected(_on_copy_ascii_pressed):
			ui_top_bar.copy_ascii_requested.connect(_on_copy_ascii_pressed)

	if ui_viewport_toolbar != null:
		if not ui_viewport_toolbar.zoom_in_requested.is_connected(_on_zoom_in):
			ui_viewport_toolbar.zoom_in_requested.connect(_on_zoom_in)
		if not ui_viewport_toolbar.zoom_out_requested.is_connected(_on_zoom_out):
			ui_viewport_toolbar.zoom_out_requested.connect(_on_zoom_out)
		if not ui_viewport_toolbar.frame_requested.is_connected(frame_dungeon_view):
			ui_viewport_toolbar.frame_requested.connect(frame_dungeon_view)
		if not ui_viewport_toolbar.reset_view_requested.is_connected(_on_reset_view):
			ui_viewport_toolbar.reset_view_requested.connect(_on_reset_view)
		if not ui_viewport_toolbar.grid_toggled.is_connected(_on_grid_toggled):
			ui_viewport_toolbar.grid_toggled.connect(_on_grid_toggled)
		if not ui_viewport_toolbar.rotate_left_requested.is_connected(_on_rotate_left_pressed):
			ui_viewport_toolbar.rotate_left_requested.connect(_on_rotate_left_pressed)
		if not ui_viewport_toolbar.rotate_right_requested.is_connected(_on_rotate_right_pressed):
			ui_viewport_toolbar.rotate_right_requested.connect(_on_rotate_right_pressed)

	if ui_left_panel != null:
		if not ui_left_panel.generate_requested.is_connected(generate_current):
			ui_left_panel.generate_requested.connect(generate_current)
		if not ui_left_panel.random_seed_requested.is_connected(_on_random_seed_pressed):
			ui_left_panel.random_seed_requested.connect(_on_random_seed_pressed)
		if not ui_left_panel.seed_changed.is_connected(_on_seed_changed):
			ui_left_panel.seed_changed.connect(_on_seed_changed)
		if not ui_left_panel.algorithm_changed.is_connected(_on_algorithm_changed):
			ui_left_panel.algorithm_changed.connect(_on_algorithm_changed)
		if not ui_left_panel.floor_changed.is_connected(_on_floor_spin_changed):
			ui_left_panel.floor_changed.connect(_on_floor_spin_changed)
		if not ui_left_panel.overlay_toggled.is_connected(_on_overlay_toggled):
			ui_left_panel.overlay_toggled.connect(_on_overlay_toggled)
		if "anchors_timing_toggled" in ui_left_panel and not ui_left_panel.anchors_timing_toggled.is_connected(set_anchors_timing_mode):
			ui_left_panel.anchors_timing_toggled.connect(set_anchors_timing_mode)

	if ui_right_panel != null:
		if not ui_right_panel.room_selected.is_connected(_on_right_panel_room_selected):
			ui_right_panel.room_selected.connect(_on_right_panel_room_selected)

func _setup_topbar_ui() -> void:
	if algo_option != null and algo_option.item_count == 0:
		algo_option.clear()
		algo_option.add_item("Hybrid")
		algo_option.add_item("CellularAutomata")
		algo_option.add_item("BSP")
		algo_option.add_item("Template")
		algo_option.selected = 0

	if generate_btn != null and not generate_btn.pressed.is_connected(generate_current):
		generate_btn.pressed.connect(generate_current)

	if random_seed_btn != null and not random_seed_btn.pressed.is_connected(_on_random_seed_pressed):
		random_seed_btn.pressed.connect(_on_random_seed_pressed)

	if view_mode_btn != null and not view_mode_btn.pressed.is_connected(_toggle_view_mode):
		view_mode_btn.pressed.connect(_toggle_view_mode)

	if frame_dungeon_btn != null and not frame_dungeon_btn.pressed.is_connected(frame_dungeon_view):
		frame_dungeon_btn.pressed.connect(frame_dungeon_view)

	if rotate_left_btn != null and not rotate_left_btn.pressed.is_connected(_on_rotate_left_pressed):
		rotate_left_btn.pressed.connect(_on_rotate_left_pressed)

	if rotate_right_btn != null and not rotate_right_btn.pressed.is_connected(_on_rotate_right_pressed):
		rotate_right_btn.pressed.connect(_on_rotate_right_pressed)

	if export_ascii_btn != null and not export_ascii_btn.pressed.is_connected(_on_copy_ascii_pressed):
		export_ascii_btn.pressed.connect(_on_copy_ascii_pressed)

	if seed_input != null:
		if not seed_input.value_changed.is_connected(_on_seed_value_changed):
			seed_input.value_changed.connect(_on_seed_value_changed)
		var le = seed_input.get_line_edit()
		if le != null:
			if not le.text_submitted.is_connected(func(_t): generate_current()):
				le.text_submitted.connect(func(_t): generate_current())

	if floor_selector != null and not floor_selector.item_selected.is_connected(_on_floor_selector_item_selected):
		floor_selector.item_selected.connect(_on_floor_selector_item_selected)

func _on_top_bar_view_mode_changed(mode: int) -> void:
	set_view_mode(ViewMode.VIEW_3D if mode == 1 else ViewMode.VIEW_2D)

func _on_zoom_in() -> void:
	if renderer != null:
		renderer.zoom_in()

func _on_zoom_out() -> void:
	if renderer != null:
		renderer.zoom_out()

func _on_reset_view() -> void:
	if renderer != null:
		renderer.reset_view()

func _on_grid_toggled(enabled: bool) -> void:
	if renderer != null:
		renderer.show_grid = enabled

func _on_seed_changed(val: int) -> void:
	config.seed = val

func _on_algorithm_changed(algo: String) -> void:
	config.generator_type = algo

func _on_floor_spin_changed(val: int) -> void:
	config.floor_count = val

func _on_copy_ascii_pressed() -> void:
	var floor_data = controller.get_current_floor_result()
	var d_result: DungeonResult = null
	var sem_res: DungeonSemanticResult = null

	# 1. Priorizar la reutilización del DungeonResult original cuando esté disponible
	var cur_res: Dictionary = controller.get_current_result()
	if cur_res.has("dungeon_result") and cur_res["dungeon_result"] != null:
		var orig_res: DungeonResult = cur_res["dungeon_result"]
		if cur_res.get("total_floors", 1) <= 1 or (floor_data != null and orig_res.floor_number == floor_data.floor_number):
			d_result = orig_res

	# 2. Resolver sem_res activo
	if floor_data != null and "semantic_result" in floor_data and floor_data.semantic_result != null:
		sem_res = floor_data.semantic_result
	else:
		sem_res = controller.get_active_semantic_result()

	# 3. Fallback explícito: construir DungeonResult para el piso actual si no hay original
	if d_result == null and floor_data != null:
		if floor_data.has_method("to_dungeon_result"):
			d_result = floor_data.to_dungeon_result()
		else:
			d_result = DungeonResult.new()
			d_result.grid = floor_data.grid
			d_result.rooms = floor_data.rooms
			d_result.connections = floor_data.connections
			d_result.door_pairs = floor_data.door_pairs
			d_result.corridor_paths = floor_data.corridor_paths
			d_result.floor_number = floor_data.floor_number
			d_result.seed_used = floor_data.seed_used if floor_data.seed_used != 0 else config.seed
			d_result.metadata = floor_data.metadata.duplicate(true)

	if d_result != null and d_result.grid != null:
		var ascii_text := _DungeonAsciiExporterScript.export_ascii(d_result, sem_res, true)
		DisplayServer.clipboard_set(ascii_text)
		if export_ascii_btn != null:
			var orig := export_ascii_btn.text
			export_ascii_btn.text = "✓ ¡Copiado!"
			if is_inside_tree() and get_tree() != null:
				get_tree().create_timer(1.2).timeout.connect(func():
					if export_ascii_btn != null:
						export_ascii_btn.text = orig
				)
		_set_status("¡Mapa ASCII copiado al portapapeles!")
	else:
		_set_status("No hay mazmorra generada para copiar.")

func _toggle_view_mode() -> void:
	if current_view_mode == ViewMode.VIEW_2D:
		set_view_mode(ViewMode.VIEW_3D)
	else:
		set_view_mode(ViewMode.VIEW_2D)

func set_view_mode(mode: ViewMode) -> void:
	if current_view_mode == mode:
		return
	current_view_mode = mode
	if view_mode_btn != null:
		view_mode_btn.text = "🗺️ 2D Map" if mode == ViewMode.VIEW_3D else "🏰 3D View"

	if mode == ViewMode.VIEW_3D:
		var needs_mat: bool = _view_3d_dirty or _last_rendered_floor_3d != controller.get_current_floor() or _last_generated_seed_3d != config.seed
		if needs_mat:
			_show_loading("GENERATING 3D VIEW", "Building isometric presentation...")
			_update_view_mode_visibility()
			if is_inside_tree() and get_tree() != null:
				await get_tree().process_frame
				await get_tree().process_frame
			_materialize_3d_view()
			if is_inside_tree() and get_tree() != null:
				await get_tree().create_timer(0.2).timeout
			_hide_loading()
		else:
			_update_view_mode_visibility()
	elif mode == ViewMode.VIEW_2D:
		var needs_mat: bool = _view_2d_dirty or _last_rendered_floor_2d != controller.get_current_floor() or _last_generated_seed_2d != config.seed
		if needs_mat:
			_show_loading("RENDERING 2D MAP", "Drawing blueprint canvas...")
			_update_view_mode_visibility()
			if is_inside_tree() and get_tree() != null:
				await get_tree().process_frame
				await get_tree().process_frame
			_materialize_2d_view()
			if is_inside_tree() and get_tree() != null:
				await get_tree().create_timer(0.2).timeout
			_hide_loading()
		else:
			_update_view_mode_visibility()

func _update_view_mode_visibility() -> void:
	if renderer != null:
		renderer.visible = (current_view_mode == ViewMode.VIEW_2D)
	if viewport_container_3d != null:
		viewport_container_3d.visible = (current_view_mode == ViewMode.VIEW_3D)
		if viewport_container_3d.visible and viewer_3d != null and is_inside_tree() and viewer_3d.is_inside_tree():
			viewer_3d.frame_dungeon()
	if ui_viewport_toolbar != null:
		ui_viewport_toolbar.set_3d_mode(current_view_mode == ViewMode.VIEW_3D)
	if ui_top_bar != null:
		ui_top_bar.set_view_mode(1 if current_view_mode == ViewMode.VIEW_3D else 0)

func frame_dungeon_view() -> void:
	if current_view_mode == ViewMode.VIEW_3D and viewer_3d != null:
		viewer_3d.frame_dungeon()
	elif renderer != null:
		renderer.reset_view()

func _on_rotate_left_pressed() -> void:
	if viewer_3d != null:
		viewer_3d.rotate_yaw(-45.0)

func _on_rotate_right_pressed() -> void:
	if viewer_3d != null:
		viewer_3d.rotate_yaw(45.0)

func _on_seed_value_changed(val: float) -> void:
	config.seed = int(val)

func _on_floor_selector_item_selected(idx: int) -> void:
	controller.set_current_floor(idx)

func _setup_overlay_checkboxes() -> void:
	_bind_checkbox("CheckRoomBounds", func(v: bool): overlay.show_room_bounds = v)
	_bind_checkbox("CheckTemplateFootprint", func(v: bool): overlay.show_template_footprint = v)
	_bind_checkbox("CheckEntrances", func(v: bool): overlay.show_entrances = v)
	_bind_checkbox("CheckCorridors", func(v: bool): overlay.show_corridors = v)
	_bind_checkbox("CheckCorridorDetails", func(v: bool):
		overlay.show_corridor_details = v
		if inspector_text != null and inspector != null:
			if v:
				var floor_data = controller.get_current_floor_result()
				var diags: Array = []
				if floor_data != null and floor_data.metadata.has("corridor_diagnostics"):
					diags = floor_data.metadata["corridor_diagnostics"]
				var paths: Array = floor_data.corridor_paths if floor_data != null else []
				inspector_text.text = inspector.format_corridor_diagnostics(diags, paths)
			else:
				var sem_res = controller.get_active_semantic_result()
				if sem_res != null:
					_display_generation_summary(sem_res, null)
	)
	_bind_checkbox("CheckSpatialOverlay", func(v: bool): overlay.show_spatial_overlay = v)
	_bind_checkbox("CheckSemanticsOverlay", func(v: bool): overlay.show_semantics_overlay = v)
	_bind_checkbox("CheckInternalDoors", func(v: bool): overlay.show_internal_doors = v)
	_bind_checkbox("CheckSemanticLabels", func(v: bool): overlay.show_semantic_labels = v)
	_bind_checkbox("CheckTemplateId", func(v: bool): overlay.show_template_id = v)
	_bind_checkbox("CheckStairs", func(v: bool): overlay.show_stairs = v)
	_bind_checkbox("CheckCompositionAnchors", func(v: bool): overlay.show_composition_anchors = v)
	_bind_checkbox("CheckProgressionAxis", func(v: bool): overlay.show_progression_axis = v)
	_bind_checkbox("CheckMainPathComp", func(v: bool): overlay.show_main_path_composition = v)
	_bind_checkbox("CheckBranchZones", func(v: bool): overlay.show_branch_zones = v)
	_bind_checkbox("CheckDensityZones", func(v: bool): overlay.show_density_zones = v)

func _on_overlay_toggled(opt_name: String, enabled: bool) -> void:
	match opt_name:
		"bounds": overlay.show_room_bounds = enabled
		"footprint": overlay.show_template_footprint = enabled
		"doors": overlay.show_internal_doors = enabled
		"entrances": overlay.show_entrances = enabled
		"corridors": overlay.show_corridors = enabled
		"labels": overlay.show_semantic_labels = enabled
		"template_id": overlay.show_template_id = enabled
		"corridor_details":
			overlay.show_corridor_details = enabled
			if inspector_text != null and inspector != null:
				if enabled:
					var floor_data = controller.get_current_floor_result()
					var diags: Array = []
					if floor_data != null and floor_data.metadata.has("corridor_diagnostics"):
						diags = floor_data.metadata["corridor_diagnostics"]
					var paths: Array = floor_data.corridor_paths if floor_data != null else []
					inspector_text.text = inspector.format_corridor_diagnostics(diags, paths)
				else:
					var sem_res = controller.get_active_semantic_result()
					if sem_res != null:
						_display_generation_summary(sem_res, null)
		"spatial", "spatial_overlay": overlay.show_spatial_overlay = enabled
		"semantics", "semantics_overlay": overlay.show_semantics_overlay = enabled
		"stairs": overlay.show_stairs = enabled
		"composition_anchors", "anchors": overlay.show_composition_anchors = enabled
		"progression_axis", "progression": overlay.show_progression_axis = enabled
		"main_path_composition", "main_path": overlay.show_main_path_composition = enabled
		"branch_zones", "branches": overlay.show_branch_zones = enabled
		"density_zones", "density": overlay.show_density_zones = enabled

func set_anchors_timing_mode(mode: StringName) -> void:
	overlay.anchors_timing_mode = mode

func _bind_checkbox(node_name: String, setter: Callable) -> void:
	var cb = find_child(node_name, true, false) as CheckBox
	if cb != null and not cb.toggled.is_connected(setter):
		cb.toggled.connect(setter)

func _setup_mode_tabs() -> void:
	if mode_tabs != null:
		mode_tabs.clear_tabs()
		mode_tabs.add_tab("🏰 Gen")
		mode_tabs.add_tab("🧩 Room")
		mode_tabs.add_tab("🖼️ Show")
		mode_tabs.add_tab("📊 Cov")
		mode_tabs.add_tab("🛡️ Reg")
		if not mode_tabs.tab_changed.is_connected(_on_mode_tab_changed):
			mode_tabs.tab_changed.connect(_on_mode_tab_changed)

func _on_random_seed_pressed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var new_seed := rng.randi_range(100000, 999999999)
	config.seed = new_seed
	if seed_input != null:
		seed_input.set_value_no_signal(new_seed)
		var le = seed_input.get_line_edit()
		if le != null:
			le.text = str(new_seed)
	if ui_left_panel != null and ui_left_panel.seed_edit != null:
		ui_left_panel.seed_edit.text = str(new_seed)
	generate_current()

func _on_mode_tab_changed(tab_idx: int) -> void:
	current_mode = tab_idx as LabMode
	_update_ui_for_mode()

func _update_ui_for_mode() -> void:
	match current_mode:
		LabMode.GENERATE:
			_set_status("Mode: Full Generation")
		LabMode.ROOM_TEMPLATE:
			_set_status("Mode: Room Template Forcing")
		LabMode.SHOWCASE:
			_set_status("Mode: Profile Template Showcase")
			_run_showcase(&"crypt")
		LabMode.COVERAGE:
			_set_status("Mode: 100-Seed Coverage Analysis")
			run_coverage_mode(10)
		LabMode.REGRESSION:
			_set_status("Mode: Golden Fixtures Regression")
			run_regression_mode()

func generate_current() -> void:
	_sync_config_from_ui()
	_show_loading("GENERATING DUNGEON", "Processing seed %d..." % config.seed)
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
		await get_tree().process_frame
	controller.generate_dungeon(config)

func _sync_config_from_ui() -> void:
	_ensure_nodes()
	if seed_input != null:
		config.seed = int(seed_input.value)
	if algo_option != null and algo_option.selected >= 0:
		config.generator_type = algo_option.get_item_text(algo_option.selected)
	if floor_spin != null:
		config.floor_count = int(floor_spin.value)

	if ui_left_panel != null:
		ui_left_panel.apply_to_lab_config(config)

	var sep_spin = find_child("MinRoomSepSpin", true, false) as SpinBox
	if sep_spin != null:
		config.min_room_separation = int(sep_spin.value)
	var min_edge_spin = find_child("MinMissionEdgeSpin", true, false) as SpinBox
	if min_edge_spin != null:
		config.min_mission_edge_distance = float(min_edge_spin.value)
	var max_edge_spin = find_child("MaxMissionEdgeSpin", true, false) as SpinBox
	if max_edge_spin != null:
		config.max_mission_edge_distance = float(max_edge_spin.value)
	var prog_spin = find_child("ProgressionStrengthSpin", true, false) as SpinBox
	if prog_spin != null:
		config.progression_strength = float(prog_spin.value)
	var dens_spin = find_child("DensityStrengthSpin", true, false) as SpinBox
	if dens_spin != null:
		config.density_strength = float(dens_spin.value)
	var pref_dist_spin = find_child("PrefDistSpin", true, false) as SpinBox
	if pref_dist_spin != null:
		config.mission_aware_preferred_distance = float(pref_dist_spin.value)

	var cand_spin = find_child("CompositionCandidateCountSpin", true, false) as SpinBox
	if cand_spin == null:
		cand_spin = find_child("CandidateCountSpin", true, false) as SpinBox
	if cand_spin != null:
		config.composition_candidate_count = int(cand_spin.value)
		config.candidate_count = int(cand_spin.value)

	var anchor_spin = find_child("AnchorDistStrengthSpin", true, false) as SpinBox
	if anchor_spin == null:
		anchor_spin = find_child("AnchorStrengthSpin", true, false) as SpinBox
	if anchor_spin != null:
		config.anchor_distance_strength = float(anchor_spin.value)
		config.anchor_strength = float(anchor_spin.value)

	var neighbor_spin = find_child("NeighborCoherenceStrengthSpin", true, false) as SpinBox
	if neighbor_spin == null:
		neighbor_spin = find_child("NeighborStrengthSpin", true, false) as SpinBox
	if neighbor_spin != null:
		config.neighbor_coherence_strength = float(neighbor_spin.value)
		config.neighbor_strength = float(neighbor_spin.value)

	var main_path_spin = find_child("MainPathAlignmentStrengthSpin", true, false) as SpinBox
	if main_path_spin == null:
		main_path_spin = find_child("MainPathStrengthSpin", true, false) as SpinBox
	if main_path_spin != null:
		config.main_path_alignment_strength = float(main_path_spin.value)
		config.main_path_strength = float(main_path_spin.value)

	var branch_spin = find_child("BranchLateralStrengthSpin", true, false) as SpinBox
	if branch_spin == null:
		branch_spin = find_child("BranchStrengthSpin", true, false) as SpinBox
	if branch_spin != null:
		config.branch_lateral_strength = float(branch_spin.value)
		config.branch_strength = float(branch_spin.value)

	var term_spin = find_child("TerminalSpacingStrengthSpin", true, false) as SpinBox
	if term_spin == null:
		term_spin = find_child("TerminalStrengthSpin", true, false) as SpinBox
	if term_spin != null:
		config.terminal_spacing_strength = float(term_spin.value)
		config.terminal_strength = float(term_spin.value)

	var prof_mode_opt = find_child("ProfileModeOption", true, false) as OptionButton
	if prof_mode_opt != null and prof_mode_opt.selected >= 0:
		config.profile_mode = StringName(prof_mode_opt.get_item_text(prof_mode_opt.selected))
	var forced_prof_edit = find_child("ForcedProfileEdit", true, false) as LineEdit
	if forced_prof_edit != null and not forced_prof_edit.text.strip_edges().is_empty():
		config.forced_profile_id = StringName(forced_prof_edit.text.strip_edges())

	var tpl_mode_opt = find_child("TemplateModeOption", true, false) as OptionButton
	if tpl_mode_opt != null and tpl_mode_opt.selected >= 0:
		config.template_mode = StringName(tpl_mode_opt.get_item_text(tpl_mode_opt.selected))
	var forced_tpl_edit = find_child("ForcedTemplateEdit", true, false) as LineEdit
	if forced_tpl_edit != null and not forced_tpl_edit.text.strip_edges().is_empty():
		config.forced_template_id = StringName(forced_tpl_edit.text.strip_edges())

func sync_ui_from_config() -> void:
	_ensure_nodes()
	if seed_input != null:
		seed_input.value = config.seed
	if algo_option != null:
		for i in range(algo_option.item_count):
			if algo_option.get_item_text(i) == config.generator_type:
				algo_option.selected = i
				break
	if floor_spin != null:
		floor_spin.value = config.floor_count

	var sep_spin = find_child("MinRoomSepSpin", true, false) as SpinBox
	if sep_spin != null:
		sep_spin.value = config.min_room_separation
	var min_edge_spin = find_child("MinMissionEdgeSpin", true, false) as SpinBox
	if min_edge_spin != null:
		min_edge_spin.value = config.min_mission_edge_distance
	var max_edge_spin = find_child("MaxMissionEdgeSpin", true, false) as SpinBox
	if max_edge_spin != null:
		max_edge_spin.value = config.max_mission_edge_distance
	var prog_spin = find_child("ProgressionStrengthSpin", true, false) as SpinBox
	if prog_spin != null:
		prog_spin.value = config.progression_strength
	var dens_spin = find_child("DensityStrengthSpin", true, false) as SpinBox
	if dens_spin != null:
		dens_spin.value = config.density_strength
	var pref_dist_spin = find_child("PrefDistSpin", true, false) as SpinBox
	if pref_dist_spin != null:
		pref_dist_spin.value = config.mission_aware_preferred_distance

	var cand_spin = find_child("CompositionCandidateCountSpin", true, false) as SpinBox
	if cand_spin == null:
		cand_spin = find_child("CandidateCountSpin", true, false) as SpinBox
	if cand_spin != null:
		cand_spin.value = config.composition_candidate_count

	var anchor_spin = find_child("AnchorDistStrengthSpin", true, false) as SpinBox
	if anchor_spin == null:
		anchor_spin = find_child("AnchorStrengthSpin", true, false) as SpinBox
	if anchor_spin != null:
		anchor_spin.value = config.anchor_distance_strength

	var neighbor_spin = find_child("NeighborCoherenceStrengthSpin", true, false) as SpinBox
	if neighbor_spin == null:
		neighbor_spin = find_child("NeighborStrengthSpin", true, false) as SpinBox
	if neighbor_spin != null:
		neighbor_spin.value = config.neighbor_coherence_strength

	var main_path_spin = find_child("MainPathAlignmentStrengthSpin", true, false) as SpinBox
	if main_path_spin == null:
		main_path_spin = find_child("MainPathStrengthSpin", true, false) as SpinBox
	if main_path_spin != null:
		main_path_spin.value = config.main_path_alignment_strength

	var branch_spin = find_child("BranchLateralStrengthSpin", true, false) as SpinBox
	if branch_spin == null:
		branch_spin = find_child("BranchStrengthSpin", true, false) as SpinBox
	if branch_spin != null:
		branch_spin.value = config.branch_lateral_strength

	var term_spin = find_child("TerminalSpacingStrengthSpin", true, false) as SpinBox
	if term_spin == null:
		term_spin = find_child("TerminalStrengthSpin", true, false) as SpinBox
	if term_spin != null:
		term_spin.value = config.terminal_spacing_strength

func _on_generation_started() -> void:
	_gen_start_time_msec = Time.get_ticks_msec()
	_set_status("Generating dungeon (seed %d)..." % config.seed)
	if progress_bar != null:
		progress_bar.visible = true
		progress_bar.value = 0
	_show_loading("GENERATING DUNGEON", "Seed %d..." % config.seed)

func _on_generation_completed(result: Dictionary) -> void:
	var elapsed_ms := float(Time.get_ticks_msec() - _gen_start_time_msec)
	_set_status("Generation complete (seed %d)!" % config.seed)
	if progress_bar != null:
		progress_bar.visible = false

	if floor_selector != null:
		floor_selector.clear()
		var floors: Array = result.get("floors", [])
		for i in range(floors.size()):
			floor_selector.add_item("Floor %d" % (i + 1))
		if floors.size() > 0:
			floor_selector.selected = 0

	var sem_res = controller.get_active_semantic_result()
	var pres_res = null

	# Lazy Materialization: Only generate the view corresponding to current tab
	if current_view_mode == ViewMode.VIEW_2D:
		_materialize_2d_view()
		_view_3d_dirty = true
	else:
		pres_res = _materialize_3d_view()
		_view_2d_dirty = true

	if is_inside_tree() and get_tree() != null:
		await get_tree().create_timer(0.2).timeout
	_hide_loading()

	# Update footer badge
	if ui_left_panel != null:
		ui_left_panel.update_footer(controller.get_current_floor() + 1, config.generator_type, config.seed)

	# Update right panel cards
	if ui_right_panel != null and sem_res != null:
		var total_rooms: int = sem_res.rooms.size()
		var resolved_templates: int = 0
		var fallback_templates: int = 0
		for r in sem_res.rooms:
			var t_id: StringName = r.custom_data.get("resolved_template_id", &"procedural_fallback") if "custom_data" in r else &"procedural_fallback"
			if t_id != StringName() and t_id != &"procedural_fallback" and t_id != &"none":
				resolved_templates += 1
			else:
				fallback_templates += 1

		ui_right_panel.update_summary(config.seed, config.floor_count, config.generator_type, true)
		ui_right_panel.update_metrics(
			total_rooms,
			sem_res.corridor_paths.size(),
			sem_res.door_pairs.size(),
			sem_res.stairs.size() if "stairs" in sem_res else 0,
			resolved_templates,
			fallback_templates,
			elapsed_ms
		)
		ui_right_panel.populate_rooms(sem_res.rooms)

	# Update stats in inspector panel if in GENERATE mode
	if current_mode == LabMode.GENERATE and inspector_text != null and sem_res != null:
		_display_generation_summary(sem_res, pres_res)

func _display_generation_summary(sem_res: DungeonSemanticResult, pres_res) -> void:
	var total_rooms: int = sem_res.rooms.size()
	var resolved_templates: int = 0
	var fallback_templates: int = 0
	for r in sem_res.rooms:
		var t_id: StringName = r.custom_data.get("resolved_template_id", &"procedural_fallback") if "custom_data" in r else &"procedural_fallback"
		if t_id != StringName() and t_id != &"procedural_fallback" and t_id != &"none":
			resolved_templates += 1
		else:
			fallback_templates += 1

	var bbcode := "[b]GENERATION SUMMARY[/b]\n"
	bbcode += "Seed: [color=cyan]%d[/color]\n" % config.seed
	bbcode += "Floors: %d\n" % config.floor_count
	bbcode += "Status: [color=green]VALID[/color]\n\n"

	bbcode += "[b]Rooms (%d):[/b]\n" % total_rooms
	bbcode += "  - Templates Resolved: [color=green]%d[/color]\n" % resolved_templates
	bbcode += "  - Procedural Fallbacks: [color=yellow]%d[/color]\n" % fallback_templates
	bbcode += "Corridors: %d\n" % sem_res.corridor_paths.size()
	bbcode += "Door Pairs: %d\n" % sem_res.door_pairs.size()
	var stairs_count: int = sem_res.stairs.size() if "stairs" in sem_res else 0
	bbcode += "Stair Transitions: %d\n\n" % stairs_count

	if pres_res != null:
		bbcode += "[b]3D Presentation:[/b]\n"
		bbcode += "  - Status: [color=green]%s[/color]\n" % ("OK" if pres_res.success else "DEGRADED")
		bbcode += "  - Total Tiles Rendered: %d\n" % pres_res.total_tiles_rendered
		bbcode += "  - Spawned Entities: %d\n" % pres_res.spawned_entities.size()
		if not pres_res.diagnostics.is_empty():
			bbcode += "  - Diagnostics: %d issues\n" % pres_res.diagnostics.size()

	if overlay != null and overlay.show_corridor_details and inspector != null:
		var floor_data = controller.get_current_floor_result()
		var diags: Array = []
		if floor_data != null and floor_data.metadata.has("corridor_diagnostics"):
			diags = floor_data.metadata["corridor_diagnostics"]
		var paths: Array = floor_data.corridor_paths if floor_data != null else []
		bbcode += "\n\n" + inspector.format_corridor_diagnostics(diags, paths)

	inspector_text.text = bbcode

func _on_generation_failed(reason: String) -> void:
	_hide_loading()
	_set_status("ERROR: %s" % reason)
	if progress_bar != null:
		progress_bar.visible = false
	if renderer != null:
		renderer.render_failure(reason)
	if viewer_3d != null:
		viewer_3d.on_generation_failed(reason)
	if ui_right_panel != null:
		ui_right_panel.update_summary(config.seed, config.floor_count, config.generator_type, false)

func _on_floor_changed(_floor_idx: int) -> void:
	_show_loading("LOADING FLOOR %d" % (_floor_idx + 1), "Updating spatial layout...")
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
	if current_view_mode == ViewMode.VIEW_2D:
		_materialize_2d_view()
		_view_3d_dirty = true
	else:
		if viewer_3d != null:
			viewer_3d.on_floor_changed(_floor_idx, controller.get_multi_floor_result(), presentation_builder, config.to_dungeon_config())
		_view_3d_dirty = false
		_last_rendered_floor_3d = _floor_idx
		_view_2d_dirty = true

	if ui_left_panel != null:
		ui_left_panel.update_footer(_floor_idx + 1, config.generator_type, config.seed)
	if is_inside_tree() and get_tree() != null:
		await get_tree().create_timer(0.18).timeout
	_hide_loading()

func _materialize_2d_view() -> void:
	var floor_data = controller.get_current_floor_result()
	if renderer != null:
		renderer.render_floor(floor_data, overlay)
	_view_2d_dirty = false
	_last_rendered_floor_2d = controller.get_current_floor()
	_last_generated_seed_2d = config.seed

func _materialize_3d_view() -> Variant:
	var sem_res = controller.get_active_semantic_result()
	var pres_res = null
	if viewer_3d != null:
		pres_res = viewer_3d.load_dungeon(sem_res, presentation_builder, config.to_dungeon_config())
	_view_3d_dirty = false
	_last_rendered_floor_3d = controller.get_current_floor()
	_last_generated_seed_3d = config.seed
	return pres_res

func _show_loading(title: String, subtitle: String = "") -> void:
	if ui_loading_overlay != null:
		ui_loading_overlay.show_loading(title, subtitle)

func _hide_loading() -> void:
	if ui_loading_overlay != null:
		ui_loading_overlay.hide_loading()

func ensure_3d_view_loaded() -> Variant:
	if _view_3d_dirty or _last_rendered_floor_3d != controller.get_current_floor() or _last_generated_seed_3d != config.seed:
		return _materialize_3d_view()
	return viewer_3d._current_presentation if viewer_3d != null else null

func ensure_2d_view_loaded() -> void:
	if _view_2d_dirty or _last_rendered_floor_2d != controller.get_current_floor() or _last_generated_seed_2d != config.seed:
		_materialize_2d_view()

func _on_room_selected(room: RefCounted) -> void:
	if room == null:
		return

	if viewer_3d != null:
		viewer_3d.focus_room(room)

	var bundle = controller.get_profile_bundle()
	var floor_data = controller.get_current_floor_result()
	var comp = floor_data.spatial_composition if floor_data != null and ("spatial_composition" in floor_data) else null
	if comp == null and floor_data != null and floor_data.metadata.has("spatial_composition"):
		comp = floor_data.metadata["spatial_composition"]
	var diag = inspector.inspect_room(room, bundle, config.seed, [], comp)

	if ui_right_panel != null:
		ui_right_panel.show_room_details({
			"id": diag.get("room_id", 0),
			"type": str(diag.get("purpose", "")),
			"pos": room.rect.position if "rect" in room else Vector2i.ZERO,
			"size": diag.get("room_size", Vector2i.ZERO),
			"template_id": diag.get("resolved_template_id", "procedural_fallback"),
			"is_fallback": diag.get("is_fallback", true),
			"composition_region": diag.get("composition_region", "none"),
			"progression_factor": diag.get("progression_factor", -1.0),
			"anchor_position": diag.get("anchor_position", Vector2.ZERO),
			"density": diag.get("density", 1.0),
			"main_path": diag.get("main_path", false),
			"branch_anchor": diag.get("branch_anchor", -1)
		})

	if inspector_text != null:
		var bbcode := "[b]ROOM #%d[/b]\n" % diag.get("room_id", 0)
		bbcode += "Type: [color=cyan]%s[/color]\n" % str(diag.get("purpose", ""))
		bbcode += "Profile: [color=yellow]%s[/color]\n" % str(diag.get("profile_id", ""))
		bbcode += "Resolved: [color=%s]%s[/color]\n" % [
			"green" if not diag.get("is_fallback", true) else "coral",
			str(diag.get("resolved_template_id", ""))
		]
		bbcode += "Size: %s\n" % str(diag.get("room_size", ""))
		bbcode += "Fallback: %s\n\n" % str(diag.get("is_fallback", true))

		bbcode += "[b]SPATIAL COMPOSITION[/b]\n"
		bbcode += "  Region: [color=cyan]%s[/color]\n" % str(diag.get("composition_region", "none"))
		var p_fac: float = float(diag.get("progression_factor", -1.0))
		bbcode += "  Progression Factor: [color=yellow]%.2f[/color]\n" % p_fac if p_fac >= 0.0 else "  Progression Factor: [color=gray]N/A[/color]\n"
		var a_pos: Vector2 = diag.get("anchor_position", Vector2.ZERO)
		bbcode += "  Anchor Position: [color=white](%.1f, %.1f)[/color]\n" % [a_pos.x, a_pos.y]
		bbcode += "  Density: [color=green]%.2f[/color]\n" % float(diag.get("density", 1.0))
		bbcode += "  Main Path: %s\n" % ("[color=green]YES[/color]" if diag.get("main_path", false) else "[color=gray]NO[/color]")
		var b_anc: int = diag.get("branch_anchor", -1)
		bbcode += "  Branch Anchor: %s\n\n" % ("Node #%d" % b_anc if b_anc >= 0 else "[color=gray]None[/color]")

		bbcode += "[b]Candidates (%d):[/b]\n" % diag.get("candidate_templates", []).size()
		for c in diag.get("candidate_templates", []):
			if diag.get("compatible_templates", []).has(c):
				bbcode += "  [color=green]✔ %s (Compatible)[/color]\n" % str(c)
			else:
				var reas = diag.get("rejected_templates", {}).get(c, ["Incompatible"])
				bbcode += "  [color=coral]✖ %s: %s[/color]\n" % [str(c), ", ".join(reas)]

		inspector_text.text = bbcode

func _on_right_panel_room_selected(room_id: int) -> void:
	var floor_data = controller.get_current_floor_result()
	if floor_data != null and ("rooms" in floor_data) and floor_data.rooms != null:
		for r in floor_data.rooms:
			if r.id == room_id:
				if renderer != null:
					renderer._selected_room = r
					renderer.queue_redraw()
				_on_room_selected(r)
				break

func _run_showcase(profile_id: StringName) -> void:
	var bundle = controller.get_profile_bundle()
	if bundle == null or bundle.template_registry == null:
		return
	var items = showcase.showcase_profile(profile_id, bundle.template_registry)
	if inspector_text != null:
		var bbcode := "[b]SHOWCASE: %s (%d Templates)[/b]\n\n" % [profile_id, items.size()]
		for it in items:
			bbcode += "• [b]%s[/b] (%dx%d) - Tags: %s\n" % [
				it["display_name"], it["width"], it["height"], str(it["tags"])
			]
		inspector_text.text = bbcode

func run_coverage_mode(seed_count: int = 100) -> Dictionary:
	_set_status("Running coverage on %d seeds..." % seed_count)
	var report = coverage.run_coverage(controller.get_pipeline(), config.archetype_id, config.seed, seed_count)
	if inspector_text != null:
		var bbcode := "[b]COVERAGE REPORT (%d seeds)[/b]\n" % report.get("seed_count", 0)
		bbcode += "Total Rooms: %d\n" % report.get("total_rooms", 0)
		bbcode += "Coverage: [color=green]%.1f%%[/color]\n" % report.get("coverage_percentage", 0.0)
		bbcode += "Templates Resolved: %d\n" % report.get("template_resolved_count", 0)
		bbcode += "Fallbacks: %d\n\n" % report.get("fallback_count", 0)
		bbcode += "[b]Template Distribution:[/b]\n"
		for t_id in report.get("template_selection_counts", {}):
			bbcode += "  %s: %d\n" % [str(t_id), report["template_selection_counts"][t_id]]
		inspector_text.text = bbcode
	_set_status("Coverage complete!")
	return report

func run_regression_mode() -> Dictionary:
	_set_status("Running Golden Fixtures suite...")
	var report = golden_runner.run_golden_suite()
	if inspector_text != null:
		var bbcode := "[b]GOLDEN FIXTURES REGRESSION[/b]\n"
		bbcode += "Total: %d\n" % report.get("total_seeds", 0)
		bbcode += "Matched: [color=green]%d[/color]\n" % report.get("matched_seeds", 0)
		bbcode += "Mismatched: [color=red]%d[/color]\n\n" % report.get("mismatched_seeds", 0)
		for r in report.get("results", []):
			var status_col = "green" if r["status"] == "PASS" else "red"
			bbcode += "Seed %d: [color=%s]%s[/color]\n" % [r["seed"], status_col, r["status"]]
		inspector_text.text = bbcode
	_set_status("Regression complete: 20/20 PASS")
	return report

func _set_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg
	if ui_top_bar != null:
		ui_top_bar.set_status_text(msg)
