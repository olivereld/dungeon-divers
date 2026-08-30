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
const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")

var state: RoomTemplateLabState
var history: CommandHistory
var repo = _RepositoryScript.new()

var opt_templates: OptionButton
var canvas_view = null
var toolbar = null
var inspector = null
var simulator = null
var loading_overlay: PanelContainer = null

var _catalog_items: Array[Dictionary] = []

func _ready() -> void:
	_build_master_layout()
	_create_loading_overlay()
	_refresh_catalog_dropdown()
	if not _catalog_items.is_empty():
		_load_selected_template(0)
	call_deferred("_dismiss_loading_overlay")

func _create_loading_overlay() -> void:
	loading_overlay = PanelContainer.new()
	loading_overlay.anchor_right = 1.0
	loading_overlay.anchor_bottom = 1.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b0d13", 0.98)
	loading_overlay.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	loading_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "🏛️ Room Template Lab 2D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#60a5fa"))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Indexando catálogo y preparando lienzo 2D interactivo..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(subtitle)

	add_child(loading_overlay)

func _dismiss_loading_overlay() -> void:
	if loading_overlay == null:
		return
	var tween = create_tween()
	tween.tween_property(loading_overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		if loading_overlay != null and is_instance_valid(loading_overlay):
			loading_overlay.queue_free()
			loading_overlay = null
	)

func _build_master_layout() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	state = _LabStateScript.new()
	history = _CmdHistoryScript.new(100)
	state.command_history = history

	var main_vbox := VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	add_child(main_vbox)

	# --- Top Navigation Bar ---
	var top_bar := PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color("#131722")
	top_style.content_margin_left = 16
	top_style.content_margin_right = 16
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_bar.add_theme_stylebox_override("panel", top_style)
	main_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏛️ Room Template Lab"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color("#60a5fa"))
	top_hbox.add_child(title_lbl)

	top_hbox.add_child(VSeparator.new())

	var tpl_lbl := Label.new()
	tpl_lbl.text = "Template:"
	top_hbox.add_child(tpl_lbl)

	opt_templates = OptionButton.new()
	opt_templates.custom_minimum_size = Vector2(260, 0)
	opt_templates.focus_mode = FOCUS_NONE
	opt_templates.item_selected.connect(_load_selected_template)
	top_hbox.add_child(opt_templates)

	var btn_clone := Button.new()
	btn_clone.text = "👯 Clone"
	btn_clone.focus_mode = FOCUS_NONE
	btn_clone.pressed.connect(_on_clone_template)
	top_hbox.add_child(btn_clone)

	top_hbox.add_child(VSeparator.new())

	lbl_notification = Label.new()
	lbl_notification.text = ""
	lbl_notification.add_theme_font_size_override("font_size", 13)
	lbl_notification.add_theme_color_override("font_color", Color("#10b981"))
	top_hbox.add_child(lbl_notification)

	# --- Main Workspace Splitter ---
	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.split_offset = 380
	main_vbox.add_child(split)

	# Left / Center: Canvas Workspace Container
	var canvas_container := Control.new()
	canvas_container.size_flags_horizontal = SIZE_EXPAND_FILL
	canvas_container.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(canvas_container)

	canvas_view = _CanvasViewScript.new()
	canvas_view.anchor_right = 1.0
	canvas_view.anchor_bottom = 1.0
	canvas_container.add_child(canvas_view)
	canvas_view.setup(state, history)

	# Stats Simulator HUD (Top-Left of canvas with spacious pill design)
	simulator = _SimulatorScript.new()
	simulator.anchor_left = 0.02
	simulator.anchor_top = 0.02
	canvas_container.add_child(simulator)
	simulator.setup(state)

	# Floating Bottom Toolbar
	toolbar = _ToolbarScript.new()
	toolbar.anchor_left = 0.15
	toolbar.anchor_right = 0.85
	toolbar.anchor_top = 0.88
	toolbar.anchor_bottom = 0.98
	toolbar.center_view_requested.connect(_center_canvas_view)
	toolbar.zoom_in_requested.connect(func(): if canvas_view: canvas_view._zoom_at_point(canvas_view.size * 0.5, 1.25))
	toolbar.zoom_out_requested.connect(func(): if canvas_view: canvas_view._zoom_at_point(canvas_view.size * 0.5, 0.8))
	toolbar.clear_canvas_requested.connect(func(): if state: state.clear_canvas())
	canvas_container.add_child(toolbar)
	toolbar.setup(state, history)

	# Right: Parameter Inspector Dock
	inspector = _InspectorScript.new()
	inspector.custom_minimum_size = Vector2(360, 0)
	inspector.save_requested.connect(_on_save_current_template)
	inspector.export_requested.connect(_on_export_current_template)
	inspector.new_requested.connect(_on_new_template)
	split.add_child(inspector)
	inspector.setup(state)

func _refresh_catalog_dropdown() -> void:
	if opt_templates == null:
		return
	opt_templates.clear()
	_catalog_items = repo.list_templates()
	for i in range(_catalog_items.size()):
		var item = _catalog_items[i]
		opt_templates.add_item("[%s] %s" % [item["category"], item["id"]], i)

func _load_selected_template(idx: int) -> void:
	if opt_templates == null or idx < 0 or idx >= _catalog_items.size():
		return
	var item = _catalog_items[idx]
	var tpl = repo.load_template_by_id(item["id"])
	if tpl != null:
		_preview_template_shape_on_canvas(tpl)

func _preview_template_shape_on_canvas(tpl: _RoomTemplateScript) -> void:
	if tpl == null or state == null:
		return

	state.clear_canvas()
	state.load_from_template(tpl)

	# 1. Si la plantilla tiene un diseño personalizado dibujado por el usuario, cargarlo tal cual:
	if tpl.custom_layout is Dictionary and tpl.custom_layout.has("cells") and not tpl.custom_layout["cells"].is_empty():
		var l_w: int = int(tpl.custom_layout.get("width", 10))
		var l_h: int = int(tpl.custom_layout.get("height", 10))
		var start_x := -int(l_w / 2)
		var start_y := -int(l_h / 2)
		var base_pos := Vector2i(start_x, start_y)

		for c_arr in tpl.custom_layout["cells"]:
			var cell_pos := base_pos + Vector2i(int(c_arr[0]), int(c_arr[1]))
			state.set_cell(cell_pos, 1)

		var custom_a = tpl.custom_layout.get("anchors", {})
		if custom_a is Dictionary:
			for a_id in custom_a:
				var val = custom_a[a_id]
				var a_x: int = 0
				var a_y: int = 0
				if val is Array and val.size() >= 2:
					a_x = int(val[0])
					a_y = int(val[1])
				elif val is Vector2i:
					a_x = val.x
					a_y = val.y
				elif val is Dictionary:
					if val.has("grid_position") and val["grid_position"] is Array:
						a_x = int(val["grid_position"][0])
						a_y = int(val["grid_position"][1])
					elif val.has("position") and val["position"] is Array:
						a_x = int(val["position"][0])
						a_y = int(val["position"][1])
					else:
						a_x = int(val.get("x", 0))
						a_y = int(val.get("y", 0))
				var a_pos := base_pos + Vector2i(a_x, a_y)
				state.set_anchor(StringName(a_id), a_pos)

		var custom_e = tpl.custom_layout.get("entrances", [])
		if custom_e is Array:
			for e_val in custom_e:
				if e_val is Array and e_val.size() >= 2:
					var e_pos := base_pos + Vector2i(int(e_val[0]), int(e_val[1]))
					state.add_entrance(e_pos)
				elif e_val is Vector2i:
					state.add_entrance(base_pos + e_val)
				elif e_val is Dictionary:
					var e_pos := base_pos + Vector2i(int(e_val.get("x", 0)), int(e_val.get("y", 0)))
					state.add_entrance(e_pos)

		var custom_d = tpl.custom_layout.get("internal_doors", [])
		if custom_d is Array:
			for d_obj in custom_d:
				if d_obj is Dictionary:
					var d_pos := base_pos + Vector2i(int(d_obj.get("x", 0)), int(d_obj.get("y", 0)))
					var d_type: StringName = StringName(d_obj.get("type", "door"))
					state.set_internal_door(d_pos, d_type)

		_center_canvas_view()
		return

	# 2. Si no tiene diseño dibujado, tallar la forma canónica procedural:
	var w: int = 10
	var h: int = 10
	if tpl.geometry != null:
		w = int(round(float(tpl.geometry.min_width + tpl.geometry.max_width) * 0.5))
		h = int(round(float(tpl.geometry.min_depth + tpl.geometry.max_depth) * 0.5))
	w = maxi(8, w)
	h = maxi(8, h)

	var start_x := -int(w / 2)
	var start_y := -int(h / 2)
	var rect := Rect2i(start_x, start_y, w, h)

	var grid_w := w + 8
	var grid_h := h + 8
	var grid := CellGrid.new(grid_w, grid_h, CellGrid.CellType.WALL)
	var offset := Vector2i(4 - start_x, 4 - start_y)
	var offset_rect := Rect2i(rect.position + offset, rect.size)
	var room := RoomData.new(1, offset_rect, &"preview_room")

	# Generate standard entrance at south side
	var south_ent_cell := Vector2i(offset_rect.position.x + int(offset_rect.size.x / 2), offset_rect.end.y - 1)
	var entrances: Array[Vector2i] = [south_ent_cell]

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var res = _ShapeCarverScript.carve(grid, room, tpl, entrances, rng, 0)
	if res != null:
		# Transfer carved floor cells to state
		for cell in res.carved_cells:
			var world_cell: Vector2i = cell - offset
			state.set_cell(world_cell, 1)

		# Transfer resolved anchors to state
		for a_id in res.resolved_anchors:
			var a_pos: Vector2i = res.resolved_anchors[a_id] - offset
			state.set_anchor(a_id, a_pos)

		# Transfer entrances
		for ent in entrances:
			var ent_world: Vector2i = ent - offset
			state.add_entrance(ent_world)

	_center_canvas_view()

func _center_canvas_view() -> void:
	if canvas_view != null and state != null:
		var geom = state.auto_calculate_geometry()
		var bounds: Rect2i = geom["bounds"] if geom["width"] > 0 else Rect2i(-4, -4, 8, 8)
		canvas_view.grid_transform.center_on_bounds(bounds, canvas_view.size)
		canvas_view.queue_redraw()

func _on_new_template() -> void:
	if state == null:
		return
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
	if state == null:
		return
	var cur_tpl = state.build_template_from_state()
	var new_id = StringName(str(cur_tpl.id) + "_copy")
	var cloned = repo.clone_template(cur_tpl, new_id, cur_tpl.display_name + " (Copy)")
	if cloned != null:
		state.load_from_template(cloned)
		state.template_id = new_id

var export_file_dialog: FileDialog = null
var lbl_notification: Label = null

func _build_file_dialog() -> void:
	export_file_dialog = FileDialog.new()
	export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_file_dialog.access = FileDialog.ACCESS_RESOURCES
	export_file_dialog.current_dir = "res://resources/dungeon_profiles/room_templates"
	export_file_dialog.filters = ["*.json ; JSON Room Templates"]
	export_file_dialog.file_selected.connect(_on_file_dialog_saved)
	add_child(export_file_dialog)

func _on_save_current_template() -> void:
	if state == null:
		return
	var tpl = state.build_template_from_state()
	var path := "res://resources/dungeon_profiles/room_templates/generic/%s_template.json" % str(tpl.id)
	var ok = repo.save_template_to_json(tpl, path)
	if ok:
		_refresh_catalog_dropdown()
		_show_notification("💾 Guardado en: %s" % path)

func _on_export_current_template() -> void:
	if export_file_dialog == null:
		_build_file_dialog()
	var tpl = state.build_template_from_state() if state else null
	var default_name = "%s_template.json" % (str(tpl.id) if tpl else "new_room")
	export_file_dialog.current_file = default_name
	export_file_dialog.popup_centered(Vector2i(700, 500))

func _on_file_dialog_saved(chosen_path: String) -> void:
	if state == null:
		return
	var tpl = state.build_template_from_state()
	var ok = repo.save_template_to_json(tpl, chosen_path)
	if ok:
		_refresh_catalog_dropdown()
		_show_notification("📤 Exportado con éxito a: %s" % chosen_path)

func _show_notification(msg: String) -> void:
	if lbl_notification == null:
		return
	lbl_notification.text = msg
	lbl_notification.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(lbl_notification, "modulate:a", 0.0, 0.5)
