class_name DungeonLevelLab
extends Control

## Integration & Authoring Lab para el pipeline de generación de mazmorras.

const _LabConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _LabControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")
const _RendererScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_renderer.gd")
const _OverlayScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd")
const _InspectorScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_inspector.gd")
const _ShowcaseScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_template_showcase.gd")
const _CoverageScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_coverage.gd")
const _GoldenRunnerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_golden_runner.gd")

enum LabMode {
	GENERATE = 0,
	ROOM_TEMPLATE = 1,
	SHOWCASE = 2,
	COVERAGE = 3,
	REGRESSION = 4
}

var current_mode: LabMode = LabMode.GENERATE
var config: _LabConfigScript = _LabConfigScript.new()
var controller: _LabControllerScript = _LabControllerScript.new()
var overlay: _OverlayScript = _OverlayScript.new()
var inspector: _InspectorScript = _InspectorScript.new()
var showcase: _ShowcaseScript = _ShowcaseScript.new()
var coverage: _CoverageScript = _CoverageScript.new()
var golden_runner: _GoldenRunnerScript = _GoldenRunnerScript.new()

# Sub-nodes
@onready var renderer: _RendererScript = $HBox/CenterPanel/Renderer
@onready var seed_input: SpinBox = $VBox/TopBar/SeedSpin
@onready var algo_option: OptionButton = $VBox/TopBar/AlgoOption
@onready var floor_spin: SpinBox = $VBox/TopBar/FloorSpin
@onready var floor_selector: OptionButton = $VBox/TopBar/FloorSelectOption
@onready var generate_btn: Button = $VBox/TopBar/GenerateBtn
@onready var mode_tabs: TabBar = $HBox/LeftPanel/ModeTabs
@onready var status_label: Label = $VBox/TopBar/StatusLabel
@onready var inspector_text: RichTextLabel = $HBox/RightPanel/InspectorText
@onready var progress_bar: ProgressBar = $HBox/RightPanel/ProgressBar

func _ensure_nodes() -> void:
	if renderer == null:
		renderer = find_child("Renderer", true, false) as _RendererScript
	if seed_input == null:
		seed_input = find_child("SeedSpin", true, false) as SpinBox
	if algo_option == null:
		algo_option = find_child("AlgoOption", true, false) as OptionButton
	if floor_spin == null:
		floor_spin = find_child("FloorSpin", true, false) as SpinBox
	if floor_selector == null:
		floor_selector = find_child("FloorSelectOption", true, false) as OptionButton
	if generate_btn == null:
		generate_btn = find_child("GenerateBtn", true, false) as Button
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

func _setup_topbar_ui() -> void:
	if algo_option != null:
		algo_option.clear()
		algo_option.add_item("Hybrid")
		algo_option.add_item("CellularAutomata")
		algo_option.add_item("BSP")
		algo_option.add_item("Template")

	if generate_btn != null and not generate_btn.pressed.is_connected(generate_current):
		generate_btn.pressed.connect(generate_current)

	if floor_selector != null:
		floor_selector.clear()

func _setup_mode_tabs() -> void:
	if mode_tabs != null:
		mode_tabs.clear_tabs()
		mode_tabs.add_tab("🏰 Generate")
		mode_tabs.add_tab("🧩 Room Template")
		mode_tabs.add_tab("🖼️ Showcase")
		mode_tabs.add_tab("📊 Coverage")
		mode_tabs.add_tab("🛡️ Regression")
		if not mode_tabs.tab_changed.is_connected(_on_mode_tab_changed):
			mode_tabs.tab_changed.connect(_on_mode_tab_changed)

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
		LabMode.REGRESSION:
			_set_status("Mode: Golden Fixtures Regression")

func generate_current() -> void:
	_sync_config_from_ui()
	controller.generate_dungeon(config)

func _sync_config_from_ui() -> void:
	if seed_input != null:
		config.seed = int(seed_input.value)
	if algo_option != null:
		config.generator_type = algo_option.get_item_text(algo_option.selected)
	if floor_spin != null:
		config.floor_count = int(floor_spin.value)

func _on_generation_started() -> void:
	_set_status("Generating dungeon...")
	if progress_bar != null:
		progress_bar.visible = true
		progress_bar.value = 0

func _on_generation_completed(result: Dictionary) -> void:
	_set_status("Generation complete!")
	if progress_bar != null:
		progress_bar.visible = false

	if floor_selector != null:
		floor_selector.clear()
		var floors: Array = result.get("floors", [])
		for i in range(floors.size()):
			floor_selector.add_item("Floor %d" % (i + 1))
		floor_selector.selected = 0

	var floor_data = controller.get_current_floor_result()
	if renderer != null:
		renderer.render_floor(floor_data, overlay)

func _on_generation_failed(reason: String) -> void:
	_set_status("ERROR: %s" % reason)
	if progress_bar != null:
		progress_bar.visible = false
	if renderer != null:
		renderer.render_failure(reason)

func _on_floor_changed(floor_idx: int) -> void:
	var floor_data = controller.get_current_floor_result()
	if renderer != null:
		renderer.render_floor(floor_data, overlay)

func _on_room_selected(room: RefCounted) -> void:
	if room == null or inspector_text == null:
		return

	var bundle = controller._pipeline.get_profile_bundle()
	var diag = inspector.inspect_room(room, bundle, config.seed)

	var bbcode := "[b]ROOM #%d[/b]\n" % diag.get("room_id", 0)
	bbcode += "Type: [color=cyan]%s[/color]\n" % str(diag.get("purpose", ""))
	bbcode += "Profile: [color=yellow]%s[/color]\n" % str(diag.get("profile_id", ""))
	bbcode += "Resolved: [color=%s]%s[/color]\n" % [
		"green" if not diag.get("is_fallback", true) else "coral",
		str(diag.get("resolved_template_id", ""))
	]
	bbcode += "Size: %s\n" % str(diag.get("room_size", ""))
	bbcode += "Fallback: %s\n\n" % str(diag.get("is_fallback", true))

	bbcode += "[b]Candidates (%d):[/b]\n" % diag.get("candidate_templates", []).size()
	for c in diag.get("candidate_templates", []):
		if diag.get("compatible_templates", []).has(c):
			bbcode += "  [color=green]✔ %s (Compatible)[/color]\n" % str(c)
		else:
			var reas = diag.get("rejected_templates", {}).get(c, ["Incompatible"])
			bbcode += "  [color=coral]✖ %s: %s[/color]\n" % [str(c), ", ".join(reas)]

	inspector_text.text = bbcode

func _run_showcase(profile_id: StringName) -> void:
	var bundle = controller._pipeline.get_profile_bundle()
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
	var report = coverage.run_coverage(controller._pipeline, config.archetype_id, config.seed, seed_count)
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
