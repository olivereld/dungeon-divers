class_name RoomTemplateCanvasView
extends Control

## Canvas 2D interactivo con cuadrícula de puntos, zoom, paneo, pincel/borrador,
## colocación de entradas/anchors y overlays de zonas.

const _GridTransformScript = preload("res://src/dungeon_generator/tools/room_template_lab/grid_transform.gd")
const _PaintCmdScript = preload("res://src/dungeon_generator/tools/room_template_lab/commands/paint_cells_command.gd")
const _AnchorCmdScript = preload("res://src/dungeon_generator/tools/room_template_lab/commands/place_anchor_command.gd")
const _EntranceCmdScript = preload("res://src/dungeon_generator/tools/room_template_lab/commands/place_entrance_command.gd")

# Paleta de Colores Moderna (Inspirada en la referencia oscura)
const COLOR_BG := Color("#0b0d13")
const COLOR_DOT := Color("#2a384c")
const COLOR_FLOOR := Color("#ffffff")
const COLOR_FLOOR_BORDER := Color("#1a1e29")
const COLOR_BOUNDS := Color("#3b82f6", 0.7)
const COLOR_ENTRANCE := Color("#10b981")
const COLOR_ANCHOR := Color("#f59e0b")
const COLOR_SYMMETRY_AXIS := Color("#ec4899", 0.6)
const COLOR_RECT_PREVIEW := Color("#60a5fa", 0.4)

var state: RoomTemplateLabState
var history: CommandHistory
var grid_transform: GridTransform = _GridTransformScript.new()

var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO

var is_drawing: bool = false
var drag_stroke_cells: Dictionary = {} # Vector2i -> int
var active_stroke_cmd: PaintCellsCommand = null

var rect_drag_start: Vector2i = Vector2i(-999, -999)
var rect_drag_current: Vector2i = Vector2i(-999, -999)
var is_rect_dragging: bool = false

var show_zones_overlay: bool = false
var selected_anchor_id: StringName = &"altar"

func _ready() -> void:
	custom_minimum_size = Vector2(400, 400)
	clip_contents = true
	mouse_filter = MOUSE_FILTER_PASS

func setup(p_state: RoomTemplateLabState, p_history: CommandHistory) -> void:
	state = p_state
	history = p_history

	if state != null:
		if not state.canvas_modified.is_connected(queue_redraw):
			state.canvas_modified.connect(queue_redraw)
		if not state.anchors_modified.is_connected(queue_redraw):
			state.anchors_modified.connect(queue_redraw)
		if not state.entrances_modified.is_connected(queue_redraw):
			state.entrances_modified.connect(queue_redraw)
		if not state.tool_changed.is_connected(_on_tool_changed):
			state.tool_changed.connect(_on_tool_changed)

	grid_transform.center_on_bounds(Rect2i(-4, -4, 8, 8), size if size.x > 0 else Vector2(800, 600))
	queue_redraw()

func _on_tool_changed(_tool_idx: int) -> void:
	is_drawing = false
	is_rect_dragging = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE)):
			if mb.pressed:
				is_panning = true
				pan_start_pos = mb.position
			else:
				is_panning = false
			accept_event()
			return

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_point(mb.position, 1.15)
			accept_event()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_point(mb.position, 1.0 / 1.15)
			accept_event()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			var cell = grid_transform.screen_to_cell(mb.position)
			if mb.pressed:
				_handle_tool_press(cell, 1)
			else:
				_handle_tool_release(cell, 1)
			accept_event()
			return

		if mb.button_index == MOUSE_BUTTON_RIGHT:
			var cell = grid_transform.screen_to_cell(mb.position)
			if mb.pressed:
				_handle_tool_press(cell, 0)
			else:
				_handle_tool_release(cell, 0)
			accept_event()
			return

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_panning:
			grid_transform.pan_offset += mm.relative
			queue_redraw()
			accept_event()
			return

		var cell = grid_transform.screen_to_cell(mm.position)
		if is_drawing:
			_handle_tool_drag(cell)
			accept_event()
			return
		elif is_rect_dragging:
			rect_drag_current = cell
			queue_redraw()
			accept_event()
			return

func _zoom_at_point(pivot_screen: Vector2, factor: float) -> void:
	var old_eff: float = grid_transform.get_effective_cell_size()
	var new_zoom: float = clampf(grid_transform.zoom * factor, 0.2, 5.0)
	var new_eff: float = grid_transform.cell_size * new_zoom
	var local: Vector2 = (pivot_screen - grid_transform.pan_offset)
	grid_transform.pan_offset = pivot_screen - (local * (new_eff / old_eff))
	grid_transform.zoom = new_zoom
	queue_redraw()

# --- Tool Execution ---
func _handle_tool_press(cell: Vector2i, brush_val: int) -> void:
	if state == null:
		return
	var tool_mode = state.active_tool

	match tool_mode:
		RoomTemplateLabState.Tool.BRUSH, RoomTemplateLabState.Tool.ERASER:
			is_drawing = true
			drag_stroke_cells.clear()
			var val = brush_val if tool_mode == RoomTemplateLabState.Tool.BRUSH else 0
			_paint_cell_with_symmetry(cell, val)

		RoomTemplateLabState.Tool.RECT_FILL:
			is_rect_dragging = true
			rect_drag_start = cell
			rect_drag_current = cell
			queue_redraw()

		RoomTemplateLabState.Tool.PLACE_ANCHOR:
			if history != null:
				var cmd = _AnchorCmdScript.new(state, selected_anchor_id, cell)
				history.execute(cmd)
			else:
				state.set_anchor(selected_anchor_id, cell)

		RoomTemplateLabState.Tool.PLACE_ENTRANCE:
			var already_has = state.get_entrances().has(cell)
			if history != null:
				var cmd = _EntranceCmdScript.new(state, cell, not already_has)
				history.execute(cmd)
			else:
				if already_has:
					state.remove_entrance(cell)
				else:
					state.add_entrance(cell)

func _handle_tool_drag(cell: Vector2i) -> void:
	if not is_drawing or state == null:
		return
	var tool_mode = state.active_tool
	var val = 1 if tool_mode == RoomTemplateLabState.Tool.BRUSH else 0
	_paint_cell_with_symmetry(cell, val)

func _handle_tool_release(cell: Vector2i, _brush_val: int) -> void:
	if is_drawing:
		is_drawing = false
		if not drag_stroke_cells.is_empty() and history != null:
			var cmd = _PaintCmdScript.new(state, drag_stroke_cells)
			history.execute(cmd)
		drag_stroke_cells.clear()

	if is_rect_dragging:
		is_rect_dragging = false
		rect_drag_current = cell
		var min_x = mini(rect_drag_start.x, rect_drag_current.x)
		var max_x = maxi(rect_drag_start.x, rect_drag_current.x)
		var min_y = mini(rect_drag_start.y, rect_drag_current.y)
		var max_y = maxi(rect_drag_start.y, rect_drag_current.y)
		var r := Rect2i(min_x, min_y, (max_x - min_x) + 1, (max_y - min_y) + 1)
		var mutations: Dictionary = {}
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				mutations[Vector2i(x, y)] = 1
		if history != null:
			var cmd = _PaintCmdScript.new(state, mutations)
			history.execute(cmd)
		elif state != null:
			state.fill_rect(r, 1)
		queue_redraw()

func _paint_cell_with_symmetry(cell: Vector2i, val: int) -> void:
	drag_stroke_cells[cell] = val
	state.set_cell(cell, val)

	if state.mirror_paint_enabled:
		var geom = state.auto_calculate_geometry()
		var center_x: int = int(round(float(geom["min_x"] + geom["max_x"]) * 0.5)) if geom["width"] > 0 else 0
		var center_y: int = int(round(float(geom["min_y"] + geom["max_y"]) * 0.5)) if geom["height"] > 0 else 0

		if state.symmetry_axis == &"vertical" or state.symmetry_axis == &"both":
			var sym_x := center_x - (cell.x - center_x)
			var sym_cell_v := Vector2i(sym_x, cell.y)
			drag_stroke_cells[sym_cell_v] = val
			state.set_cell(sym_cell_v, val)

		if state.symmetry_axis == &"horizontal" or state.symmetry_axis == &"both":
			var sym_y := center_y - (cell.y - center_y)
			var sym_cell_h := Vector2i(cell.x, sym_y)
			drag_stroke_cells[sym_cell_h] = val
			state.set_cell(sym_cell_h, val)

func apply_brush_at_cell(cell: Vector2i, val: int) -> void:
	var mut = { cell: val }
	if history != null:
		var cmd = _PaintCmdScript.new(state, mut)
		history.execute(cmd)
	elif state != null:
		state.set_cell(cell, val)

func apply_brush_with_symmetry(cell: Vector2i, val: int, center_x: int) -> void:
	var sym_x := center_x - (cell.x - center_x)
	var mut = { cell: val, Vector2i(sym_x, cell.y): val }
	if history != null:
		var cmd = _PaintCmdScript.new(state, mut)
		history.execute(cmd)
	elif state != null:
		state.set_cell(cell, val)
		state.set_cell(Vector2i(sym_x, cell.y), val)

# --- Drawing ---
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)

	var visible_range = grid_transform.visible_cell_range(size)
	var eff := grid_transform.get_effective_cell_size()

	# 1. Draw Dot Grid (Culling optimized)
	var dot_radius: float = clampf(eff * 0.08, 1.0, 3.0)
	for cy in range(visible_range.position.y, visible_range.end.y + 1):
		for cx in range(visible_range.position.x, visible_range.end.x + 1):
			var dot_pos = grid_transform.cell_to_screen(Vector2i(cx, cy))
			draw_circle(dot_pos, dot_radius, COLOR_DOT)

	if state == null:
		return

	# 2. Draw Painted Floor Cells
	for cell in state.painted_cells:
		if visible_range.has_point(cell):
			var cr = grid_transform.get_cell_rect(cell)
			draw_rect(cr, COLOR_FLOOR)
			draw_rect(cr, COLOR_FLOOR_BORDER, false, 1.0)

	# 3. Draw Bounding Rect Guide
	var geom = state.auto_calculate_geometry()
	if geom["width"] > 0 and geom["height"] > 0:
		var b_pos = grid_transform.cell_to_screen(Vector2i(geom["min_x"], geom["min_y"]))
		var b_size = Vector2(float(geom["width"]) * eff, float(geom["height"]) * eff)
		draw_rect(Rect2(b_pos, b_size), COLOR_BOUNDS, false, 2.0)

	# 4. Draw Symmetry Guides
	if state.mirror_paint_enabled and geom["width"] > 0:
		var c_x := float(geom["min_x"] + geom["max_x"]) * 0.5 + 0.5
		var line_top = grid_transform.cell_to_screen(Vector2i(int(c_x), geom["min_y"] - 2))
		var line_bot = grid_transform.cell_to_screen(Vector2i(int(c_x), geom["max_y"] + 3))
		draw_line(line_top, line_bot, COLOR_SYMMETRY_AXIS, 2.0)

	# 5. Draw Entrances
	for ent in state.get_entrances():
		if visible_range.has_point(ent):
			var er = grid_transform.get_cell_rect(ent)
			draw_rect(er, COLOR_ENTRANCE, true)
			draw_rect(er, Color.WHITE, false, 2.0)

	# 6. Draw Anchors
	for a_id in state.anchors:
		var a_pos = state.get_anchor(a_id)
		if visible_range.has_point(a_pos):
			var center_px = grid_transform.cell_to_screen(a_pos) + Vector2.ONE * (eff * 0.5)
			draw_circle(center_px, eff * 0.35, COLOR_ANCHOR)
			draw_circle(center_px, eff * 0.15, Color.WHITE)

	# 7. Draw Rect Drag Preview
	if is_rect_dragging:
		var min_x = mini(rect_drag_start.x, rect_drag_current.x)
		var max_x = maxi(rect_drag_start.x, rect_drag_current.x)
		var min_y = mini(rect_drag_start.y, rect_drag_current.y)
		var max_y = maxi(rect_drag_start.y, rect_drag_current.y)
		var r_pos = grid_transform.cell_to_screen(Vector2i(min_x, min_y))
		var r_size = Vector2(float((max_x - min_x) + 1) * eff, float((max_y - min_y) + 1) * eff)
		draw_rect(Rect2(r_pos, r_size), COLOR_RECT_PREVIEW, true)
		draw_rect(Rect2(r_pos, r_size), Color.WHITE, false, 1.5)
