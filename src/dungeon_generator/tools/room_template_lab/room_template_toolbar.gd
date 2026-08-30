class_name RoomTemplateToolbar
extends PanelContainer

## Barra de herramientas flotante inferior con atajos de teclado y sincronización con CommandHistory.

signal center_view_requested()
signal zoom_in_requested()
signal zoom_out_requested()
signal clear_canvas_requested()

var state: RoomTemplateLabState
var history: CommandHistory

var btn_brush: Button
var btn_eraser: Button
var btn_rect: Button
var btn_entrance: Button
var btn_anchor: Button
var btn_undo: Button
var btn_redo: Button
var btn_clear: Button
var btn_center: Button
var btn_zoom_in: Button
var btn_zoom_out: Button

var _tool_buttons: Array[Button] = []

func _ready() -> void:
	_build_ui()

func setup(p_state: RoomTemplateLabState, p_history: CommandHistory) -> void:
	if btn_brush == null:
		_build_ui()
	state = p_state
	history = p_history

	if history != null:
		if not history.history_changed.is_connected(_update_undo_redo_state):
			history.history_changed.connect(_update_undo_redo_state)
	if state != null:
		if not state.tool_changed.is_connected(_on_tool_changed):
			state.tool_changed.connect(_on_tool_changed)

	_update_undo_redo_state()
	_update_active_tool_highlight(state.active_tool if state != null else 0)

func _build_ui() -> void:
	# Estilo oscuro y redondeado moderno
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#181c26", 0.96)
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)

	btn_brush = _create_btn("✏️ Pincel", func(): _select_tool(RoomTemplateLabState.Tool.BRUSH), "Pincel [B]")
	btn_eraser = _create_btn("🧹 Borrar", func(): _select_tool(RoomTemplateLabState.Tool.ERASER), "Borrador [E]")
	btn_rect = _create_btn("⬜ Rect", func(): _select_tool(RoomTemplateLabState.Tool.RECT_FILL), "Rectángulo [R]")
	btn_entrance = _create_btn("🚪 Entrada", func(): _select_tool(RoomTemplateLabState.Tool.PLACE_ENTRANCE), "Punto de Entrada [D]")

	# MenuButton para puertas internas y arcos
	var btn_doors := MenuButton.new()
	btn_doors.text = "🚪 Puerta ▾"
	btn_doors.tooltip_text = "Puerta / Arco Interno [P]"
	btn_doors.flat = true
	btn_doors.focus_mode = FOCUS_NONE
	btn_doors.add_theme_font_size_override("font_size", 12)
	var d_popup: PopupMenu = btn_doors.get_popup()
	d_popup.add_item("🚪 Puerta Estándar", 0)
	d_popup.add_item("🔒 Puerta Bloqueada (Llave)", 1)
	d_popup.add_item("🏛️ Arco Abierto", 2)
	d_popup.id_pressed.connect(func(id: int):
		if state != null:
			match id:
				0:
					state.active_door_type = &"door"
					btn_doors.text = "🚪 Puerta ▾"
				1:
					state.active_door_type = &"locked_door"
					btn_doors.text = "🔒 Llave ▾"
				2:
					state.active_door_type = &"arch"
					btn_doors.text = "🏛️ Arco ▾"
			state.set_tool(RoomTemplateLabState.Tool.PLACE_DOOR)
	)
	btn_doors.pressed.connect(func():
		if state != null:
			state.set_tool(RoomTemplateLabState.Tool.PLACE_DOOR)
	)

	btn_anchor = _create_btn("⭐ Ancla", func(): _select_tool(RoomTemplateLabState.Tool.PLACE_ANCHOR), "Punto de Ancla [A]")

	_tool_buttons = [btn_brush, btn_eraser, btn_rect, btn_entrance, btn_doors, btn_anchor]
	for b in _tool_buttons:
		hbox.add_child(b)

	hbox.add_child(VSeparator.new())

	btn_undo = _create_btn("↩", func(): _on_undo(), "Deshacer [Ctrl+Z]")
	btn_redo = _create_btn("↪", func(): _on_redo(), "Rehacer [Ctrl+Y]")
	hbox.add_child(btn_undo)
	hbox.add_child(btn_redo)

	hbox.add_child(VSeparator.new())

	btn_clear = _create_btn("🗑️", func(): clear_canvas_requested.emit(), "Limpiar lienzo")
	btn_center = _create_btn("🎯", func(): center_view_requested.emit(), "Encuadrar vista [F]")
	btn_zoom_in = _create_btn("➕", func(): zoom_in_requested.emit(), "Acercar zoom")
	btn_zoom_out = _create_btn("➖", func(): zoom_out_requested.emit(), "Alejar zoom")

	hbox.add_child(btn_clear)
	hbox.add_child(btn_center)
	hbox.add_child(btn_zoom_in)
	hbox.add_child(btn_zoom_out)

func _create_btn(p_text: String, p_callable: Callable, p_tooltip: String = "") -> Button:
	var btn := Button.new()
	btn.text = p_text
	btn.add_theme_font_size_override("font_size", 12)
	if not p_tooltip.is_empty():
		btn.tooltip_text = p_tooltip
	btn.flat = true
	btn.focus_mode = FOCUS_NONE
	btn.pressed.connect(p_callable)
	return btn

func _select_tool(tool_idx: int) -> void:
	if state != null:
		state.set_tool(tool_idx)

func _on_tool_changed(tool_idx: int) -> void:
	_update_active_tool_highlight(tool_idx)

func _update_active_tool_highlight(tool_idx: int) -> void:
	for i in range(_tool_buttons.size()):
		var b = _tool_buttons[i]
		if i == tool_idx:
			b.flat = false
		else:
			b.flat = true

func _on_undo() -> void:
	if history != null:
		history.undo()

func _on_redo() -> void:
	if history != null:
		history.redo()

func _update_undo_redo_state() -> void:
	if btn_undo != null and history != null:
		btn_undo.disabled = not history.can_undo()
	if btn_redo != null and history != null:
		btn_redo.disabled = not history.can_redo()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var ek := event as InputEventKey

	if ek.ctrl_pressed:
		if ek.keycode == KEY_Z:
			if ek.shift_pressed:
				_on_redo()
			else:
				_on_undo()
			get_viewport().set_input_as_handled()
			return
		elif ek.keycode == KEY_Y:
			_on_redo()
			get_viewport().set_input_as_handled()
			return

	match ek.keycode:
		KEY_B:
			_select_tool(RoomTemplateLabState.Tool.BRUSH)
			get_viewport().set_input_as_handled()
		KEY_E:
			_select_tool(RoomTemplateLabState.Tool.ERASER)
			get_viewport().set_input_as_handled()
		KEY_R:
			_select_tool(RoomTemplateLabState.Tool.RECT_FILL)
			get_viewport().set_input_as_handled()
		KEY_D:
			_select_tool(RoomTemplateLabState.Tool.PLACE_ENTRANCE)
			get_viewport().set_input_as_handled()
		KEY_P:
			_select_tool(RoomTemplateLabState.Tool.PLACE_DOOR)
			get_viewport().set_input_as_handled()
		KEY_A:
			_select_tool(RoomTemplateLabState.Tool.PLACE_ANCHOR)
			get_viewport().set_input_as_handled()
		KEY_F:
			center_view_requested.emit()
			get_viewport().set_input_as_handled()
