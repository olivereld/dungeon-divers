class_name RoomTemplateInspector
extends ScrollContainer

## Inspector lateral completo para edición de parámetros, políticas y anclajes del RoomTemplate.

signal auto_fit_requested()
signal save_requested()
signal export_requested()
signal new_requested()

var state: RoomTemplateLabState

# UI Controls
var input_id: LineEdit
var input_name: LineEdit
var input_tags: LineEdit

var spin_min_w: SpinBox
var spin_max_w: SpinBox
var spin_min_d: SpinBox
var spin_max_d: SpinBox
var spin_min_area: SpinBox
var spin_max_area: SpinBox
var spin_min_aspect: SpinBox
var spin_max_aspect: SpinBox
var shape_checkboxes: Dictionary = {} # StringName -> CheckBox

var spin_min_ent: SpinBox
var spin_max_ent: SpinBox
var side_checkboxes: Dictionary = {} # StringName -> CheckBox
var chk_allow_corner: CheckBox
var spin_ent_spacing: SpinBox

var chk_symmetry_req: CheckBox
var opt_symmetry_axis: OptionButton
var chk_mirror_paint: CheckButton

var spin_clr_ent: SpinBox
var spin_clr_focal: SpinBox
var spin_clr_circ: SpinBox
var spin_clr_walls: SpinBox

var input_allowed_purposes: LineEdit
var input_preferred_purposes: LineEdit

var anchors_container: VBoxContainer

func _ready() -> void:
	custom_minimum_size = Vector2(320, 400)
	_build_ui()

func setup(p_state: RoomTemplateLabState) -> void:
	if input_id == null:
		_build_ui()
	state = p_state
	if state != null:
		if not state.template_changed.is_connected(_sync_from_state):
			state.template_changed.connect(_sync_from_state)
		if not state.anchors_modified.is_connected(_refresh_anchors_list):
			state.anchors_modified.connect(_refresh_anchors_list)
		_sync_from_state(null)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# --- Header Buttons ---
	var header_box := HBoxContainer.new()
	var btn_new := Button.new()
	btn_new.text = "📄 New"
	btn_new.pressed.connect(func(): new_requested.emit())
	var btn_save := Button.new()
	btn_save.text = "💾 Save"
	btn_save.pressed.connect(func(): save_requested.emit())
	var btn_export := Button.new()
	btn_export.text = "📤 Export JSON"
	btn_export.pressed.connect(func(): export_requested.emit())
	header_box.add_child(btn_new)
	header_box.add_child(btn_save)
	header_box.add_child(btn_export)
	vbox.add_child(header_box)

	# --- 1. Identity Section ---
	vbox.add_child(_create_section_label("1. Identity & Metadata"))
	input_id = _create_line_edit("ID", func(txt): if state: state.template_id = StringName(txt.strip_edges()), vbox)
	input_name = _create_line_edit("Display Name", func(txt): if state: state.display_name = txt, vbox)
	input_tags = _create_line_edit("Tags (comma-separated)", func(txt): _update_tags(txt), vbox)

	# --- 2. Geometry Policy ---
	vbox.add_child(_create_section_label("2. Geometry Policy"))
	var btn_autofit := Button.new()
	btn_autofit.text = "⚡ Auto-Calculate from Painted Canvas"
	btn_autofit.pressed.connect(_on_autofit_clicked)
	vbox.add_child(btn_autofit)

	# Allowed Shapes Checkboxes
	var shapes_label := Label.new()
	shapes_label.text = "Allowed Shapes:"
	vbox.add_child(shapes_label)
	var shapes_grid := GridContainer.new()
	shapes_grid.columns = 2
	var shape_names = [&"rectangle", &"octagonal", &"cruciform", &"pillared", &"chapel", &"central_nave", &"niched_hall"]
	for s_name in shape_names:
		var cb := CheckBox.new()
		cb.text = str(s_name).capitalize()
		cb.toggled.connect(func(_on): _update_allowed_shapes())
		shape_checkboxes[s_name] = cb
		shapes_grid.add_child(cb)
	vbox.add_child(shapes_grid)

	spin_min_w = _create_spin_row("Min Width", 4, 32, vbox, func(v): if state: state.min_width = int(v))
	spin_max_w = _create_spin_row("Max Width", 4, 32, vbox, func(v): if state: state.max_width = int(v))
	spin_min_d = _create_spin_row("Min Depth", 4, 32, vbox, func(v): if state: state.min_depth = int(v))
	spin_max_d = _create_spin_row("Max Depth", 4, 32, vbox, func(v): if state: state.max_depth = int(v))
	spin_min_area = _create_spin_row("Min Area", 16, 1024, vbox, func(v): if state: state.min_area = int(v))
	spin_max_area = _create_spin_row("Max Area", 16, 1024, vbox, func(v): if state: state.max_area = int(v))
	spin_min_aspect = _create_spin_row("Min Aspect Ratio", 0.1, 5.0, vbox, func(v): if state: state.min_aspect_ratio = v, 0.05)
	spin_max_aspect = _create_spin_row("Max Aspect Ratio", 0.1, 5.0, vbox, func(v): if state: state.max_aspect_ratio = v, 0.05)

	# --- 3. Entrance Policy ---
	vbox.add_child(_create_section_label("3. Entrance Policy"))
	spin_min_ent = _create_spin_row("Min Entrances", 1, 8, vbox, func(v): if state: state.min_entrances = int(v))
	spin_max_ent = _create_spin_row("Max Entrances", 1, 8, vbox, func(v): if state: state.max_entrances = int(v))

	var sides_grid := GridContainer.new()
	sides_grid.columns = 2
	for side in [&"north", &"south", &"east", &"west"]:
		var cb := CheckBox.new()
		cb.text = str(side).capitalize()
		cb.toggled.connect(func(_on): _update_allowed_sides())
		side_checkboxes[side] = cb
		sides_grid.add_child(cb)
	vbox.add_child(sides_grid)

	chk_allow_corner = CheckBox.new()
	chk_allow_corner.text = "Allow Corner Entrances"
	chk_allow_corner.toggled.connect(func(on): if state: state.allow_corner_entrances = on)
	vbox.add_child(chk_allow_corner)
	spin_ent_spacing = _create_spin_row("Min Entrance Spacing", 1, 8, vbox, func(v): if state: state.min_entrance_spacing = int(v))

	# --- 4. Symmetry & Live Mirror Painting ---
	vbox.add_child(_create_section_label("4. Symmetry & Mirror Painting"))
	chk_symmetry_req = CheckBox.new()
	chk_symmetry_req.text = "Symmetry Required"
	chk_symmetry_req.toggled.connect(func(on): if state: state.symmetry_required = on)
	vbox.add_child(chk_symmetry_req)

	var sym_box := HBoxContainer.new()
	sym_box.add_child(Label.new())
	(sym_box.get_child(0) as Label).text = "Symmetry Axis:"
	opt_symmetry_axis = OptionButton.new()
	opt_symmetry_axis.add_item("none", 0)
	opt_symmetry_axis.add_item("vertical", 1)
	opt_symmetry_axis.add_item("horizontal", 2)
	opt_symmetry_axis.add_item("both", 3)
	opt_symmetry_axis.item_selected.connect(_on_symmetry_axis_selected)
	sym_box.add_child(opt_symmetry_axis)
	vbox.add_child(sym_box)

	chk_mirror_paint = CheckButton.new()
	chk_mirror_paint.text = "🪞 Live Mirror Paint Mode"
	chk_mirror_paint.toggled.connect(func(on): if state: state.mirror_paint_enabled = on)
	vbox.add_child(chk_mirror_paint)

	# --- 5. Anchors Editor ---
	vbox.add_child(_create_section_label("5. Anchors List"))
	var btn_add_anchor := Button.new()
	btn_add_anchor.text = "➕ Add Anchor"
	btn_add_anchor.pressed.connect(_on_add_anchor_clicked)
	vbox.add_child(btn_add_anchor)

	anchors_container = VBoxContainer.new()
	vbox.add_child(anchors_container)

	# --- 6. Clearances ---
	vbox.add_child(_create_section_label("6. Clearances"))
	spin_clr_ent = _create_spin_row("Entrance Clearance", 0, 4, vbox, func(v): if state: state.clearance_entrance = int(v))
	spin_clr_focal = _create_spin_row("Focal Clearance", 0, 4, vbox, func(v): if state: state.clearance_focal = int(v))
	spin_clr_circ = _create_spin_row("Circulation Clearance", 0, 4, vbox, func(v): if state: state.clearance_circulation = int(v))
	spin_clr_walls = _create_spin_row("Wall Clearance", 0, 4, vbox, func(v): if state: state.clearance_walls = int(v))

	# --- 7. Semantics ---
	vbox.add_child(_create_section_label("7. Semantic Purposes"))
	input_allowed_purposes = _create_line_edit("Allowed Purposes", func(t): _update_purposes(t, true), vbox)
	input_preferred_purposes = _create_line_edit("Preferred Purposes", func(t): _update_purposes(t, false), vbox)

func _create_section_label(title: String) -> Label:
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color("#60a5fa"))
	return l

func _create_line_edit(placeholder: String, p_callback: Callable, parent: Control) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text_changed.connect(p_callback)
	parent.add_child(le)
	return le

func _create_spin_row(label_text: String, min_v: float, max_v: float, parent: Control, p_callback: Callable, step_v: float = 1.0) -> SpinBox:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text + ":"
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = step_v
	sb.value_changed.connect(p_callback)
	hb.add_child(l)
	hb.add_child(sb)
	parent.add_child(hb)
	return sb

func _on_autofit_clicked() -> void:
	if state == null:
		return
	var geom = state.auto_calculate_geometry()
	if geom["width"] > 0 and geom["height"] > 0:
		state.min_width = mini(state.min_width, geom["width"])
		state.max_width = maxi(state.max_width, geom["width"])
		state.min_depth = mini(state.min_depth, geom["height"])
		state.max_depth = maxi(state.max_depth, geom["height"])
		state.min_area = mini(state.min_area, geom["area"])
		state.max_area = maxi(state.max_area, geom["area"])
		_sync_from_state(null)
		auto_fit_requested.emit()

func _update_tags(txt: String) -> void:
	if state == null:
		return
	var parts = txt.split(",", false)
	var out: Array[StringName] = []
	for p in parts:
		var s = p.strip_edges()
		if not s.is_empty():
			out.append(StringName(s))
	state.tags = out

func _update_purposes(txt: String, is_allowed: bool) -> void:
	if state == null:
		return
	var parts = txt.split(",", false)
	var out: Array[StringName] = []
	for p in parts:
		var s = p.strip_edges()
		if not s.is_empty():
			out.append(StringName(s))
	if is_allowed:
		state.allowed_purposes = out
	else:
		state.preferred_purposes = out

func _update_allowed_shapes() -> void:
	if state == null:
		return
	var out: Array[StringName] = []
	for s_name in shape_checkboxes:
		if (shape_checkboxes[s_name] as CheckBox).button_pressed:
			out.append(s_name)
	state.allowed_shapes = out

func _update_allowed_sides() -> void:
	if state == null:
		return
	var out: Array[StringName] = []
	for side in side_checkboxes:
		if (side_checkboxes[side] as CheckBox).button_pressed:
			out.append(side)
	state.allowed_sides = out

func _on_symmetry_axis_selected(idx: int) -> void:
	if state == null:
		return
	match idx:
		0: state.symmetry_axis = &"none"
		1: state.symmetry_axis = &"vertical"
		2: state.symmetry_axis = &"horizontal"
		3: state.symmetry_axis = &"both"

func _on_add_anchor_clicked() -> void:
	if state == null:
		return
	var new_id = StringName("anchor_%d" % (state.anchors.size() + 1))
	state.set_anchor(new_id, Vector2i(0, 0))

func _refresh_anchors_list() -> void:
	if anchors_container == null or state == null:
		return
	for c in anchors_container.get_children():
		c.queue_free()

	for a_id in state.anchors:
		var a_pos = state.get_anchor(a_id)
		var row := HBoxContainer.new()
		var l_id := Label.new()
		l_id.text = str(a_id)
		l_id.size_flags_horizontal = SIZE_EXPAND_FILL

		var sb_x := SpinBox.new()
		sb_x.min_value = -50
		sb_x.max_value = 50
		sb_x.value = a_pos.x
		sb_x.value_changed.connect(func(v): state.set_anchor(a_id, Vector2i(int(v), a_pos.y)))

		var sb_y := SpinBox.new()
		sb_y.min_value = -50
		sb_y.max_value = 50
		sb_y.value = a_pos.y
		sb_y.value_changed.connect(func(v): state.set_anchor(a_id, Vector2i(a_pos.x, int(v))))

		var btn_del := Button.new()
		btn_del.text = "❌"
		btn_del.pressed.connect(func(): state.remove_anchor(a_id))

		row.add_child(l_id)
		row.add_child(sb_x)
		row.add_child(sb_y)
		row.add_child(btn_del)
		anchors_container.add_child(row)

func _sync_from_state(_unused = null) -> void:
	if state == null:
		return
	input_id.text = str(state.template_id)
	input_name.text = state.display_name
	input_tags.text = ", ".join(state.tags)

	spin_min_w.value = state.min_width
	spin_max_w.value = state.max_width
	spin_min_d.value = state.min_depth
	spin_max_d.value = state.max_depth
	spin_min_area.value = state.min_area
	spin_max_area.value = state.max_area
	spin_min_aspect.value = state.min_aspect_ratio
	spin_max_aspect.value = state.max_aspect_ratio

	for s_name in shape_checkboxes:
		shape_checkboxes[s_name].button_pressed = state.allowed_shapes.has(s_name)

	spin_min_ent.value = state.min_entrances
	spin_max_ent.value = state.max_entrances
	for side in side_checkboxes:
		side_checkboxes[side].button_pressed = state.allowed_sides.has(side)
	chk_allow_corner.button_pressed = state.allow_corner_entrances
	spin_ent_spacing.value = state.min_entrance_spacing

	chk_symmetry_req.button_pressed = state.symmetry_required
	match state.symmetry_axis:
		&"none": opt_symmetry_axis.selected = 0
		&"vertical": opt_symmetry_axis.selected = 1
		&"horizontal": opt_symmetry_axis.selected = 2
		&"both": opt_symmetry_axis.selected = 3
	chk_mirror_paint.button_pressed = state.mirror_paint_enabled

	spin_clr_ent.value = state.clearance_entrance
	spin_clr_focal.value = state.clearance_focal
	spin_clr_circ.value = state.clearance_circulation
	spin_clr_walls.value = state.clearance_walls

	input_allowed_purposes.text = ", ".join(state.allowed_purposes)
	input_preferred_purposes.text = ", ".join(state.preferred_purposes)

	_refresh_anchors_list()
