class_name RoomTemplateLab
extends Control

## Escena Master del Laboratorio y Editor Visual 2D de Room Templates.

const _LabStateScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_lab_state.gd")
const _CmdHistoryScript = preload("res://src/dungeon_generator/tools/room_template_lab/command_history.gd")
const _CanvasViewScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_canvas_view.gd")
const _ToolbarScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_toolbar.gd")
const _InspectorScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_inspector.gd")
const _SimulatorScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_simulator.gd")
const _RepositoryScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_repository.gd")

var state: RoomTemplateLabState
var history: CommandHistory
var repo = _RepositoryScript.new()

var opt_templates: OptionButton
var canvas_view = null
var toolbar = null
var inspector = null
var simulator = null

var _catalog_items: Array[Dictionary] = []

func _ready() -> void:
	_init_lab()

func _init_lab() -> void:
	state = _LabStateScript.new()
	history = _CmdHistoryScript.new(100)
	state.command_history = history

	_build_master_layout()
	_refresh_catalog_dropdown()

	if not _catalog_items.is_empty():
		_load_selected_template(0)

func _build_master_layout() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var main_vbox := VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	add_child(main_vbox)

	# --- Top Navigation Bar ---
	var top_bar := PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color("#131722")
	top_style.content_margin_left = 12
	top_style.content_margin_right = 12
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_bar.add_theme_stylebox_override("panel", top_style)
	main_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏛️ Room Template Lab 2D"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color("#60a5fa"))
	top_hbox.add_child(title_lbl)

	top_hbox.add_child(VSeparator.new())

	var tpl_lbl := Label.new()
	tpl_lbl.text = "Template:"
	top_hbox.add_child(tpl_lbl)

	opt_templates = OptionButton.new()
	opt_templates.custom_minimum_size = Vector2(220, 0)
	opt_templates.item_selected.connect(_load_selected_template)
	top_hbox.add_child(opt_templates)

	var btn_clone := Button.new()
	btn_clone.text = "👯 Clone"
	btn_clone.pressed.connect(_on_clone_template)
	top_hbox.add_child(btn_clone)

	# --- Main Workspace Splitter ---
	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	main_vbox.add_child(split)

	# Left / Center: Canvas Container
	var canvas_container := Control.new()
	canvas_container.size_flags_horizontal = SIZE_EXPAND_FILL
	canvas_container.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(canvas_container)

	canvas_view = _CanvasViewScript.new()
	canvas_view.anchor_right = 1.0
	canvas_view.anchor_bottom = 1.0
	canvas_view.setup(state, history)
	canvas_container.add_child(canvas_view)

	# Stats Simulator HUD (Top Right of canvas)
	simulator = _SimulatorScript.new()
	simulator.anchor_left = 0.6
	simulator.anchor_right = 0.98
	simulator.anchor_top = 0.02
	simulator.setup(state)
	canvas_container.add_child(simulator)

	# Floating Bottom Toolbar
	toolbar = _ToolbarScript.new()
	toolbar.anchor_left = 0.25
	toolbar.anchor_right = 0.75
	toolbar.anchor_top = 0.90
	toolbar.anchor_bottom = 0.98
	toolbar.setup(state, history)
	toolbar.center_view_requested.connect(_center_canvas_view)
	toolbar.zoom_in_requested.connect(func(): canvas_view._zoom_at_point(canvas_view.size * 0.5, 1.25))
	toolbar.zoom_out_requested.connect(func(): canvas_view._zoom_at_point(canvas_view.size * 0.5, 0.8))
	toolbar.clear_canvas_requested.connect(func(): state.clear_canvas())
	canvas_container.add_child(toolbar)

	# Right: Parameter Inspector Dock
	inspector = _InspectorScript.new()
	inspector.setup(state)
	inspector.save_requested.connect(_on_save_current_template)
	inspector.export_requested.connect(_on_export_current_template)
	inspector.new_requested.connect(_on_new_template)
	split.add_child(inspector)

func _refresh_catalog_dropdown() -> void:
	opt_templates.clear()
	_catalog_items = repo.list_templates()
	for i in range(_catalog_items.size()):
		var item = _catalog_items[i]
		opt_templates.add_item("[%s] %s" % [item["category"], item["id"]], i)

func _load_selected_template(idx: int) -> void:
	if idx < 0 or idx >= _catalog_items.size():
		return
	var item = _catalog_items[idx]
	var tpl = repo.load_template_by_id(item["id"])
	if tpl != null:
		state.clear_canvas()
		state.load_from_template(tpl)
		_center_canvas_view()

func _center_canvas_view() -> void:
	if canvas_view != null and state != null:
		var geom = state.auto_calculate_geometry()
		var bounds: Rect2i = geom["bounds"] if geom["width"] > 0 else Rect2i(-4, -4, 8, 8)
		canvas_view.grid_transform.center_on_bounds(bounds, canvas_view.size)
		canvas_view.queue_redraw()

func _on_new_template() -> void:
	state.clear_canvas()
	state.template_id = &"custom_room_template"
	state.display_name = "Custom Room Template"
	state.tags = [&"custom"]
	state.allowed_shapes = [&"rectangle"]
	state.min_width = 8
	state.max_width = 16
	state.min_depth = 8
	state.max_depth = 16
	state.min_area = 64
	state.max_area = 256
	state.template_changed.emit(null)
	_center_canvas_view()

func _on_clone_template() -> void:
	var cur_tpl = state.build_template_from_state()
	var new_id = StringName(str(cur_tpl.id) + "_copy")
	var cloned = repo.clone_template(cur_tpl, new_id, cur_tpl.display_name + " (Copy)")
	if cloned != null:
		state.load_from_template(cloned)
		state.template_id = new_id

func _on_save_current_template() -> void:
	var tpl = state.build_template_from_state()
	var path := "res://resources/dungeon_profiles/room_templates/generic/%s_template.json" % str(tpl.id)
	var ok = repo.save_template_to_json(tpl, path)
	if ok:
		_refresh_catalog_dropdown()

func _on_export_current_template() -> void:
	_on_save_current_template()
