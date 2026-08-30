class_name DungeonLabRenderer
extends Control

signal room_selected(room: RefCounted)

const _TransformScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_grid_transform.gd")
const _OverlayScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd")

var transform: _TransformScript
var overlay: _OverlayScript

var _current_floor_data: RefCounted = null
var _selected_room: RefCounted = null
var _error_message: String = ""
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# Colors
const COLOR_BG := Color(0.08, 0.09, 0.11, 1.0)
const COLOR_GRID_LINE := Color(0.15, 0.17, 0.20, 0.5)
const COLOR_WALL := Color(0.20, 0.22, 0.25, 1.0)
const COLOR_FLOOR := Color(0.35, 0.38, 0.42, 1.0)
const COLOR_CORRIDOR := Color(0.45, 0.48, 0.52, 1.0)
const COLOR_ROOM_BOUNDS := Color(0.2, 0.7, 0.9, 0.8)
const COLOR_TEMPLATE_FOOTPRINT := Color(0.3, 0.9, 0.5, 0.7)
const COLOR_ENTRANCE := Color(0.95, 0.85, 0.2, 0.9)
const COLOR_DOOR := Color(0.9, 0.4, 0.1, 0.9)
const COLOR_ARCH := Color(0.6, 0.4, 0.9, 0.9)
const COLOR_STAIR := Color(0.9, 0.2, 0.6, 0.9)
const COLOR_SELECTED_ROOM := Color(1.0, 0.9, 0.2, 0.9)

func _init() -> void:
	transform = _TransformScript.new()
	overlay = _OverlayScript.new()
	overlay.overlay_changed.connect(queue_redraw)
	clip_contents = true

func set_overlay(p_overlay: _OverlayScript) -> void:
	if overlay != null and overlay.overlay_changed.is_connected(queue_redraw):
		overlay.overlay_changed.disconnect(queue_redraw)
	overlay = p_overlay
	if overlay != null:
		overlay.overlay_changed.connect(queue_redraw)
	queue_redraw()

func render_floor(floor_data: RefCounted, p_overlay: _OverlayScript = null) -> void:
	_error_message = ""
	_current_floor_data = floor_data
	if p_overlay != null:
		set_overlay(p_overlay)
	queue_redraw()

func render_failure(reason: String) -> void:
	_current_floor_data = null
	_selected_room = null
	_error_message = reason
	queue_redraw()

func has_error_state() -> bool:
	return not _error_message.is_empty()

func get_rendered_room_count() -> int:
	if _current_floor_data == null or not ("rooms" in _current_floor_data):
		return 0
	return _current_floor_data.rooms.size()

func select_room_at_world(world_pos: Vector2) -> RefCounted:
	if _current_floor_data == null or not ("rooms" in _current_floor_data):
		return null
	var cell_pos := Vector2i(floor(world_pos.x / transform.cell_size), floor(world_pos.y / transform.cell_size))
	for room in _current_floor_data.rooms:
		if "rect" in room and room.rect.has_point(cell_pos):
			_selected_room = room
			room_selected.emit(room)
			queue_redraw()
			return room
	return null

func select_room_at_screen(screen_pos: Vector2) -> RefCounted:
	var world_pos = transform.screen_to_world(screen_pos)
	return select_room_at_world(world_pos)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			select_room_at_screen(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			transform.zoom_at(mb.position, 1.1)
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			transform.zoom_at(mb.position, 0.9)
			queue_redraw()
	elif event is InputEventMouseMotion and _is_panning:
		var mm := event as InputEventMouseMotion
		transform.pan(mm.position - _last_mouse_pos)
		_last_mouse_pos = mm.position
		queue_redraw()

func _draw() -> void:
	# 1. Background
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)

	if not _error_message.is_empty():
		var font := ThemeDB.fallback_font
		var font_size := ThemeDB.fallback_font_size
		draw_string(font, Vector2(20, 40), "GENERATION FAILED: %s" % _error_message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.RED)
		return

	if _current_floor_data == null:
		var font := ThemeDB.fallback_font
		var font_size := ThemeDB.fallback_font_size
		draw_string(font, Vector2(20, 40), "No dungeon loaded. Press Generate to begin.", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.DARK_GRAY)
		return

	var grid = _current_floor_data.grid
	if grid == null:
		return

	var vis_cells = transform.visible_cell_rect(size)
	var start_x = clampi(vis_cells.position.x, 0, grid.width)
	var end_x = clampi(vis_cells.end.x, 0, grid.width)
	var start_y = clampi(vis_cells.position.y, 0, grid.height)
	var end_y = clampi(vis_cells.end.y, 0, grid.height)

	# 2. Draw Cells
	for cy in range(start_y, end_y):
		for cx in range(start_x, end_x):
			var cell_pos := Vector2i(cx, cy)
			var ctype = grid.get_cell(cell_pos)
			var rect = transform.cell_to_screen_rect(cell_pos)

			match ctype:
				1: # CellGrid.CellType.WALL
					draw_rect(rect, COLOR_WALL, true)
				2: # CellGrid.CellType.FLOOR
					draw_rect(rect, COLOR_FLOOR, true)
				3: # CellGrid.CellType.CORRIDOR
					draw_rect(rect, COLOR_CORRIDOR, true)
				4: # CellGrid.CellType.DOOR
					draw_rect(rect, COLOR_DOOR, true)
				_:
					pass

			draw_rect(rect, COLOR_GRID_LINE, false, 0.5)

	# 3. Draw Room Overlays
	if "rooms" in _current_floor_data and _current_floor_data.rooms != null:
		for room in _current_floor_data.rooms:
			var r_rect: Rect2i = room.rect
			var s_rect := Rect2(
				transform.world_to_screen(Vector2(r_rect.position) * transform.cell_size),
				Vector2(r_rect.size) * transform.cell_size * transform.zoom
			)

			if overlay.show_room_bounds:
				var is_sel: bool = (_selected_room != null and _selected_room == room)
				var bound_col = COLOR_SELECTED_ROOM if is_sel else COLOR_ROOM_BOUNDS
				draw_rect(s_rect, bound_col, false, 2.0 if is_sel else 1.0)

			if overlay.show_semantic_labels:
				var label_pos = s_rect.position + Vector2(4, 14)
				var prof: String = room.custom_data.get("profile_id", str(room.room_type)) if "custom_data" in room else str(room.room_type)
				var font := ThemeDB.fallback_font
				draw_string(font, label_pos, "#%d %s" % [room.id, prof], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

			if overlay.show_template_id and "custom_data" in room:
				var tpl_id: String = room.custom_data.get("resolved_template_id", "")
				if not tpl_id.is_empty():
					var tpl_pos = s_rect.position + Vector2(4, 26)
					var font := ThemeDB.fallback_font
					var tpl_col = Color.GREEN_YELLOW if tpl_id != "procedural_fallback" else Color.LIGHT_CORAL
					draw_string(font, tpl_pos, tpl_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tpl_col)

	# 4. Draw Stairs
	if overlay.show_stairs and "stairs" in _current_floor_data and _current_floor_data.stairs != null:
		for stair in _current_floor_data.stairs:
			var s_cell: Vector2i = stair.cell if "cell" in stair else Vector2i.ZERO
			var s_rect = transform.cell_to_screen_rect(s_cell)
			draw_rect(s_rect, COLOR_STAIR, true)
			draw_rect(s_rect, Color.WHITE, false, 1.5)
