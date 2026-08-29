class_name RoomTemplateSimulator
extends PanelContainer

## HUD flotante de estadísticas en vivo, validación de reglas con debounce y simulación de tallado.

const _DefValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_definition_validator.gd")
const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")

signal simulation_carved(result)

var state: RoomTemplateLabState
var _def_validator := _DefValidatorScript.new()

var lbl_dimensions: Label
var lbl_area: Label
var lbl_ratio: Label
var lbl_status: Label
var btn_simulate: Button

var _debounce_timer: Timer

func _ready() -> void:
	_build_ui()
	_debounce_timer = Timer.new()
	_debounce_timer.wait_time = 0.15
	_debounce_timer.one_shot = true
	_debounce_timer.timeout.connect(_run_validation_and_stats)
	add_child(_debounce_timer)

func setup(p_state: RoomTemplateLabState) -> void:
	if lbl_dimensions == null:
		_build_ui()
	state = p_state
	if state != null:
		if not state.canvas_modified.is_connected(_on_canvas_modified):
			state.canvas_modified.connect(_on_canvas_modified)
		if not state.template_changed.is_connected(_on_canvas_modified):
			state.template_changed.connect(_on_canvas_modified)
	_run_validation_and_stats()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f131d", 0.95)
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)

	lbl_dimensions = _create_badge("📐 0x0", hbox)
	lbl_area = _create_badge("🟩 0 cells", hbox)
	lbl_ratio = _create_badge("📊 0%", hbox)
	lbl_status = _create_badge("✅ Valid", hbox)

	hbox.add_child(VSeparator.new())
	btn_simulate = Button.new()
	btn_simulate.text = "🎲 Simulate Carve"
	btn_simulate.focus_mode = FOCUS_NONE
	btn_simulate.pressed.connect(_on_simulate_pressed)
	hbox.add_child(btn_simulate)

func _create_badge(p_text: String, parent: Control) -> Label:
	var pill := PanelContainer.new()
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color("#1e2638", 0.8)
	pill_style.corner_radius_bottom_left = 6
	pill_style.corner_radius_bottom_right = 6
	pill_style.corner_radius_top_left = 6
	pill_style.corner_radius_top_right = 6
	pill_style.content_margin_left = 8
	pill_style.content_margin_right = 8
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", pill_style)

	var l := Label.new()
	l.text = p_text
	l.add_theme_font_size_override("font_size", 12)
	pill.add_child(l)
	parent.add_child(pill)
	return l

func _on_canvas_modified(_unused = null) -> void:
	if _debounce_timer != null:
		_debounce_timer.start()

func _run_validation_and_stats() -> void:
	if state == null or lbl_dimensions == null:
		return

	var geom = state.auto_calculate_geometry()
	var w: int = geom["width"]
	var h: int = geom["height"]
	var area: int = geom["area"]
	var bbox_area: int = maxi(1, w * h)
	var ratio: float = float(area) / float(bbox_area)

	lbl_dimensions.text = "📐 Size: %dx%d" % [w, h]
	lbl_area.text = "🟩 Area: %d" % area
	lbl_ratio.text = "📊 %d%% Walkable" % int(round(ratio * 100.0))

	if ratio >= 0.70 or area == 0:
		lbl_ratio.add_theme_color_override("font_color", Color("#10b981"))
	else:
		lbl_ratio.add_theme_color_override("font_color", Color("#ef4444"))

	# Validar definición del template
	var tpl = state.build_template_from_state()
	var def_dict = {
		"id": str(tpl.id),
		"display_name": tpl.display_name,
		"geometry": {
			"shape": { "allowed": tpl.geometry.allowed_shapes },
			"width": { "min": tpl.geometry.min_width, "max": tpl.geometry.max_width },
			"depth": { "min": tpl.geometry.min_depth, "max": tpl.geometry.max_depth },
			"area": { "min": tpl.geometry.min_area, "max": tpl.geometry.max_area }
		},
		"entrances": {
			"min": tpl.entrances.min_count,
			"max": tpl.entrances.max_count,
			"allowed_sides": tpl.entrances.allowed_sides
		}
	}
	var val_res = _def_validator.validate_definition(def_dict)
	if val_res.is_valid:
		lbl_status.text = "✅ Valid Schema"
		lbl_status.add_theme_color_override("font_color", Color("#10b981"))
	else:
		lbl_status.text = "⚠️ %d Issues" % val_res.errors.size()
		lbl_status.add_theme_color_override("font_color", Color("#f59e0b"))

	state.validation_updated.emit(val_res.is_valid, val_res.errors, { "width": w, "height": h, "area": area, "ratio": ratio })

func _on_simulate_pressed() -> void:
	if state == null:
		return
	var geom = state.auto_calculate_geometry()
	var sim_w: int = maxi(10, geom["width"])
	var sim_h: int = maxi(10, geom["height"])

	var grid := CellGrid.new(sim_w + 4, sim_h + 4, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(2, 2, sim_w, sim_h), &"simulated_room")
	var tpl = state.build_template_from_state()

	var entrances: Array[Vector2i] = []
	for ent in state.get_entrances():
		entrances.append(ent + Vector2i(2, 2))
	if entrances.is_empty():
		entrances.append(Vector2i(2 + sim_w / 2, 2 + sim_h - 1)) # Default south entrance

	var rng := RandomNumberGenerator.new()
	var res = _ShapeCarverScript.carve(grid, room, tpl, entrances, rng, 0)
	if res != null:
		simulation_carved.emit(res)
