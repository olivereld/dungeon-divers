class_name DungeonLabRenderer
extends Control

signal room_selected(room: RefCounted)

const _TransformScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_grid_transform.gd")
const _OverlayScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")

var transform: _TransformScript
var overlay: _OverlayScript

var _current_floor_data: RefCounted = null
var _selected_room: RefCounted = null
var _error_message: String = ""
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# Cyber-blueprint color palette
const COLOR_BG := Color(0.04, 0.05, 0.06, 1.0) # #0a0c10
const COLOR_GRID_LINE := Color(0.14, 0.16, 0.25, 0.25)
const COLOR_WALL := Color(0.07, 0.08, 0.11, 1.0)
const COLOR_FLOOR := Color(0.10, 0.12, 0.17, 1.0)
const COLOR_CORRIDOR := Color(0.13, 0.83, 0.93, 0.55) # Glowing Cyan
const COLOR_DOOR := Color(0.96, 0.62, 0.04, 1.0) # Amber
const COLOR_LOCKED_DOOR := Color(0.97, 0.44, 0.44, 1.0) # Red
const COLOR_COLUMN := Color(0.09, 0.10, 0.13, 1.0)
const COLOR_STAIR := Color(0.75, 0.55, 0.98, 1.0) # Violet
const COLOR_ROOM_BOUNDS := Color(0.14, 0.83, 0.93, 0.85) # Cyan
const COLOR_SELECTED_ROOM := Color(0.96, 0.62, 0.04, 1.0) # Amber highlight

var show_grid: bool = true:
	set(v):
		show_grid = v
		queue_redraw()

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
	frame_dungeon()
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

func zoom_in() -> void:
	transform.zoom_at(size * 0.5, 1.25)
	queue_redraw()

func zoom_out() -> void:
	transform.zoom_at(size * 0.5, 0.8)
	queue_redraw()

func reset_view() -> void:
	frame_dungeon()

func frame_dungeon() -> void:
	if _current_floor_data != null and ("grid" in _current_floor_data) and _current_floor_data.grid != null:
		var gw: float = _current_floor_data.grid.width * transform.cell_size
		var gh: float = _current_floor_data.grid.height * transform.cell_size
		if gw > 0.0 and gh > 0.0 and size.x > 50.0 and size.y > 50.0:
			var margin_x: float = 40.0
			var margin_y: float = 40.0
			var scale_x = (size.x - margin_x) / gw
			var scale_y = (size.y - margin_y) / gh
			transform.zoom = clampf(minf(scale_x, scale_y), transform.min_zoom, transform.max_zoom)
			transform.offset = (size - Vector2(gw, gh) * transform.zoom) * 0.5
			queue_redraw()
			return
	transform.reset()
	queue_redraw()

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

	# 2. Draw Grid Cells based on CellGrid.CellType exact enum values
	for cy in range(start_y, end_y):
		for cx in range(start_x, end_x):
			var cell_pos := Vector2i(cx, cy)
			var ctype = grid.get_cell(cell_pos)
			var rect = transform.cell_to_screen_rect(cell_pos)

			match ctype:
				0: # CellGrid.CellType.WALL
					draw_rect(rect, COLOR_WALL, true)
				1: # CellGrid.CellType.FLOOR
					draw_rect(rect, COLOR_FLOOR, true)
				2: # CellGrid.CellType.DOOR
					draw_rect(rect, COLOR_DOOR, true)
				3: # CellGrid.CellType.LOCKED_DOOR
					draw_rect(rect, COLOR_LOCKED_DOOR, true)
				4, 5: # STAIRS_DOWN, STAIRS_UP
					draw_rect(rect, COLOR_STAIR, true)
				8: # CellGrid.CellType.CORRIDOR
					if overlay.show_corridors:
						draw_rect(rect, COLOR_CORRIDOR, true)
					else:
						draw_rect(rect, COLOR_WALL, true)
				9: # CellGrid.CellType.COLUMN
					draw_rect(rect, COLOR_COLUMN, true)
				_:
					pass

			if show_grid:
				draw_rect(rect, COLOR_GRID_LINE, false, 0.5)

	var font := ThemeDB.fallback_font

	# 3. Draw Room Overlays with Cyber-Blueprint styling
	if "rooms" in _current_floor_data and _current_floor_data.rooms != null:
		for room in _current_floor_data.rooms:
			var r_rect: Rect2i = room.rect
			var s_rect := Rect2(
				transform.world_to_screen(Vector2(r_rect.position) * transform.cell_size),
				Vector2(r_rect.size) * transform.cell_size * transform.zoom
			)

			var r_type: String = str(room.room_type) if "room_type" in room else "none"
			var base_color: Color = LabColors.get_room_color(r_type)
			var is_sel: bool = (_selected_room != null and _selected_room == room)
			var stroke_col: Color = COLOR_SELECTED_ROOM if is_sel else base_color

			# Semi-transparent room fill
			var fill_col := Color(stroke_col.r, stroke_col.g, stroke_col.b, 0.08)
			draw_rect(s_rect, fill_col, true)

			# Room border
			if overlay.show_room_bounds:
				draw_rect(s_rect, stroke_col, false, 2.0 if is_sel else 1.5)

			# Template Footprint (inner boundary)
			if overlay.show_template_footprint and "custom_data" in room:
				var t_sz: Vector2i = room.custom_data.get("template_size", r_rect.size)
				var t_s_rect := Rect2(
					s_rect.position,
					Vector2(t_sz) * transform.cell_size * transform.zoom
				)
				draw_rect(t_s_rect, Color(stroke_col.r, stroke_col.g, stroke_col.b, 0.35), false, 1.0)

			# Template Watermark in center of room
			if overlay.show_template_id and "custom_data" in room:
				var tpl_id: String = room.custom_data.get("resolved_template_id", "")
				if not tpl_id.is_empty():
					var wm_text := "T#%s" % (tpl_id if tpl_id.length() <= 8 else tpl_id.substr(0, 8))
					var wm_sz: Vector2 = font.get_string_size(wm_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
					var center_pt = s_rect.get_center()
					draw_string(font, center_pt + Vector2(-wm_sz.x * 0.5, wm_sz.y * 0.35), wm_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 0.12))

			# Semantic Labels
			if overlay.show_semantic_labels:
				var label_pos = s_rect.position + Vector2(4, 14)
				var prof: String = room.custom_data.get("profile_id", str(room.room_type)) if "custom_data" in room else str(room.room_type)
				var label_str := "#%d %s" % [room.id, prof]
				var l_sz := font.get_string_size(label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
				draw_rect(Rect2(label_pos + Vector2(-2, -10), l_sz + Vector2(4, 4)), Color(0.06, 0.07, 0.10, 0.8), true)
				draw_string(font, label_pos, label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

			if overlay.show_template_id and "custom_data" in room:
				var tpl_id: String = room.custom_data.get("resolved_template_id", "")
				if not tpl_id.is_empty():
					var tpl_pos = s_rect.position + Vector2(4, 26)
					var tpl_col = Color.GREEN_YELLOW if tpl_id != "procedural_fallback" else Color.LIGHT_CORAL
					draw_string(font, tpl_pos, tpl_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tpl_col)

	# 4. Draw Stairs Overlay
	if overlay.show_stairs and "stairs" in _current_floor_data and _current_floor_data.stairs != null:
		for stair in _current_floor_data.stairs:
			var s_cell: Vector2i = stair.cell if "cell" in stair else Vector2i.ZERO
			var s_rect = transform.cell_to_screen_rect(s_cell)
			draw_rect(s_rect, COLOR_STAIR, true)
			draw_rect(s_rect, Color.WHITE, false, 1.5)

	# 5. Draw Corridors & Corridor Details Overlay
	_draw_corridors_overlay(font)

	# 6. Draw Spatial Overlay (Mission edges, Progression direction, Room separation)
	_draw_spatial_overlay(font)

	# 7. Draw Semantics Overlay (START, BOSS, Critical Path, Objectives, Keys, Locks)
	_draw_semantics_overlay(font)

	# 8. Draw Composition Overlays
	_draw_density_zones_overlay(font)
	_draw_branch_zones_overlay(font)
	_draw_progression_axis_overlay(font)
	_draw_main_path_composition_overlay(font)
	_draw_composition_anchors_overlay(font)

func _draw_corridors_overlay(font: Font) -> void:
	if not overlay.show_corridors and not overlay.show_corridor_details:
		return
	if not ("corridor_paths" in _current_floor_data) or _current_floor_data.corridor_paths == null:
		return

	for cp in _current_floor_data.corridor_paths:
		if cp == null or cp.centerline_cells.is_empty():
			continue
		var pts: PackedVector2Array = []
		for cell in cp.centerline_cells:
			pts.append(transform.cell_to_screen_rect(cell).get_center())
		if pts.size() >= 2:
			# Glowing cyan line
			draw_polyline(pts, Color(0.13, 0.83, 0.93, 0.35), 4.5)
			draw_polyline(pts, Color(0.13, 0.83, 0.93, 0.9), 2.0)

		if overlay.show_corridor_details:
			var mid_idx: int = pts.size() / 2
			var tag_pos: Vector2 = pts[mid_idx]
			var strat: String = cp.routing_strategy if cp.routing_strategy != "Unknown" else "DIR"
			var text: String = "L:%d T:%d [%s]" % [cp.centerline_cells.size(), cp.turn_count, strat]
			if ("expanded_states" in cp and cp.expanded_states > 0) or ("elapsed_ms" in cp and cp.elapsed_ms > 0):
				text += " S:%d (%.1fms)" % [cp.expanded_states, cp.elapsed_ms]
			var str_sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
			draw_rect(Rect2(tag_pos + Vector2(-2, -11), str_sz + Vector2(4, 3)), Color(0.08, 0.09, 0.12, 0.85), true)
			draw_string(font, tag_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.8, 0.2))

func _draw_spatial_overlay(font: Font) -> void:
	if not overlay.show_spatial_overlay:
		return

	var room_map: Dictionary = {}
	if "rooms" in _current_floor_data and _current_floor_data.rooms != null:
		for r in _current_floor_data.rooms:
			room_map[r.id] = r
			# Room separation buffer
			var r_rect: Rect2i = r.rect
			var s_rect := Rect2(
				transform.world_to_screen(Vector2(r_rect.position) * transform.cell_size),
				Vector2(r_rect.size) * transform.cell_size * transform.zoom
			)
			draw_rect(s_rect.grow(3.0 * transform.zoom), Color(0.3, 0.6, 1.0, 0.35), false, 1.0)

	# Mission Edges / Connections
	if "connections" in _current_floor_data and _current_floor_data.connections != null:
		for conn in _current_floor_data.connections:
			if conn == null:
				continue
			var ra = room_map.get(conn.room_a_id)
			var rb = room_map.get(conn.room_b_id)
			if ra == null or rb == null:
				continue
			var pa: Vector2 = transform.cell_to_screen_rect(ra.get_center()).get_center()
			var pb: Vector2 = transform.cell_to_screen_rect(rb.get_center()).get_center()

			var col := Color(0.2, 0.85, 0.95, 0.7)
			draw_line(pa, pb, col, 2.0)

			# Midpoint progression indicator
			var mid: Vector2 = (pa + pb) * 0.5
			var edge_label: String = "%d→%d" % [conn.room_a_id, conn.room_b_id]
			draw_rect(Rect2(mid + Vector2(-12, -9), Vector2(24, 12)), Color(0.05, 0.1, 0.15, 0.75), true)
			draw_string(font, mid + Vector2(-10, 0), edge_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.CYAN)

func _draw_semantics_overlay(font: Font) -> void:
	if not overlay.show_semantics_overlay:
		return

	var sem = _current_floor_data.semantic_result if ("semantic_result" in _current_floor_data) else null
	if sem == null:
		return

	var room_map: Dictionary = {}
	if "rooms" in _current_floor_data and _current_floor_data.rooms != null:
		for r in _current_floor_data.rooms:
			room_map[r.id] = r

	# Critical Path Line
	if sem.critical_path_rooms != null and sem.critical_path_rooms.size() >= 2:
		var cp_pts: PackedVector2Array = []
		for r_id in sem.critical_path_rooms:
			if room_map.has(r_id):
				cp_pts.append(transform.cell_to_screen_rect(room_map[r_id].get_center()).get_center())
		if cp_pts.size() >= 2:
			draw_polyline(cp_pts, Color(1.0, 0.85, 0.1, 0.85), 4.0)

	# START & BOSS & GOAL Markers
	if room_map.has(sem.start_room_id):
		var s_pt = transform.cell_to_screen_rect(room_map[sem.start_room_id].get_center()).get_center()
		draw_circle(s_pt, 14.0 * transform.zoom, Color(0.1, 0.8, 0.2, 0.5))
		draw_rect(Rect2(s_pt + Vector2(-22, -18), Vector2(44, 14)), Color(0.0, 0.4, 0.1, 0.9), true)
		draw_string(font, s_pt + Vector2(-18, -8), "★ START", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.WHITE)

	if room_map.has(sem.boss_room_id):
		var b_pt = transform.cell_to_screen_rect(room_map[sem.boss_room_id].get_center()).get_center()
		draw_circle(b_pt, 16.0 * transform.zoom, Color(0.9, 0.15, 0.15, 0.5))
		draw_rect(Rect2(b_pt + Vector2(-20, -18), Vector2(40, 14)), Color(0.5, 0.05, 0.05, 0.9), true)
		draw_string(font, b_pt + Vector2(-16, -8), "💀 BOSS", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.WHITE)

	# Objectives
	if sem.objectives != null:
		for obj in sem.objectives:
			if obj != null and room_map.has(obj.room_id):
				var opt = transform.cell_to_screen_rect(room_map[obj.room_id].get_center()).get_center()
				var o_type_str: String = _ObjectiveDataScript.type_to_string(obj.type) if _ObjectiveDataScript != null else "OBJ"
				draw_string(font, opt + Vector2(6, 6), "🎯 %s" % o_type_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.ORANGE)

	# Keys
	if sem.keys != null:
		for k in sem.keys:
			if k != null and room_map.has(k.room_id):
				var kpt = transform.cell_to_screen_rect(room_map[k.room_id].get_center()).get_center()
				draw_string(font, kpt + Vector2(-10, 18), "🔑 K%d (L%d)" % [k.id, k.unlocks], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.GOLD)

	# Locks
	if sem.locks != null:
		for l in sem.locks:
			if l != null:
				var lpt: Vector2 = Vector2.ZERO
				if l.room_id >= 0 and room_map.has(l.room_id):
					lpt = transform.cell_to_screen_rect(room_map[l.room_id].get_center()).get_center()
				if lpt != Vector2.ZERO:
					draw_string(font, lpt + Vector2(-10, -8), "🔒 L%d (Req:%d)" % [l.id, l.required_key_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.SALMON)

func _get_composition() -> RefCounted:
	if _current_floor_data == null:
		return null
	if "spatial_composition" in _current_floor_data and _current_floor_data.spatial_composition != null:
		return _current_floor_data.spatial_composition
	if "metadata" in _current_floor_data and _current_floor_data.metadata.has("spatial_composition"):
		return _current_floor_data.metadata["spatial_composition"]
	return null

func _get_room_maps() -> Dictionary:
	var by_id: Dictionary = {}
	var by_node: Dictionary = {}
	if _current_floor_data != null and ("rooms" in _current_floor_data) and _current_floor_data.rooms != null:
		for r in _current_floor_data.rooms:
			by_id[r.id] = r
			if r.mission_node_id >= 0:
				by_node[r.mission_node_id] = r
	return {"by_id": by_id, "by_node": by_node}

func _draw_composition_anchors_overlay(font: Font) -> void:
	if not overlay.show_composition_anchors:
		return
	var comp = _get_composition()
	if comp == null:
		return

	var maps = _get_room_maps()
	var by_id: Dictionary = maps["by_id"]
	var by_node: Dictionary = maps["by_node"]
	var mode: StringName = overlay.anchors_timing_mode

	# Color tokens
	var col_planned := Color(0.14, 0.9, 0.95, 0.9) # Cyan diamond / crosshair
	var col_actual := Color(0.96, 0.62, 0.04, 0.9)  # Amber circle
	var col_delta := Color(1.0, 0.84, 0.2, 0.6)    # Connecting line

	for r in by_id.values():
		var nid: int = r.mission_node_id if r.mission_node_id >= 0 else r.id
		var planned_pos: Vector2 = comp.get_anchor_target(nid)
		var actual_pos: Vector2 = Vector2(r.get_center())

		var s_actual: Vector2 = transform.cell_to_screen_rect(r.get_center()).get_center()
		var has_planned: bool = not planned_pos.is_zero_approx()
		var s_planned: Vector2 = transform.world_to_screen(planned_pos * transform.cell_size) if has_planned else s_actual

		# 1. Planned Anchor ("before" or "both")
		if (mode == &"before" or mode == &"both") and has_planned:
			var r_sz: float = 7.0 * transform.zoom
			# Diamond
			var diamond_pts: PackedVector2Array = [
				s_planned + Vector2(0, -r_sz),
				s_planned + Vector2(r_sz, 0),
				s_planned + Vector2(0, r_sz),
				s_planned + Vector2(-r_sz, 0)
			]
			draw_colored_polygon(diamond_pts, Color(col_planned, 0.3))
			draw_polyline(diamond_pts + PackedVector2Array([diamond_pts[0]]), col_planned, 1.8)
			# Crosshair
			draw_line(s_planned + Vector2(-r_sz * 1.4, 0), s_planned + Vector2(r_sz * 1.4, 0), col_planned, 1.0)
			draw_line(s_planned + Vector2(0, -r_sz * 1.4), s_planned + Vector2(0, r_sz * 1.4), col_planned, 1.0)

			var tag := "Anchor #%d (pre)" % nid
			draw_string(font, s_planned + Vector2(-15, -r_sz - 3), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col_planned)

		# 2. Actual Center ("after" or "both")
		if mode == &"after" or mode == &"both":
			var r_sz: float = 5.0 * transform.zoom
			draw_circle(s_actual, r_sz, Color(col_actual, 0.4))
			draw_arc(s_actual, r_sz, 0, TAU, 16, col_actual, 1.8)
			draw_circle(s_actual, 2.0 * transform.zoom, col_actual)

			var tag := "Room #%d (post)" % r.id
			draw_string(font, s_actual + Vector2(-15, r_sz + 11), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col_actual)

		# 3. Connecting Vector & Displacement Measurement ("both")
		if mode == &"both" and has_planned and s_planned.distance_to(s_actual) > 4.0:
			draw_line(s_planned, s_actual, col_delta, 1.2)
			var mid: Vector2 = (s_planned + s_actual) * 0.5
			var dist_cells: float = planned_pos.distance_to(actual_pos)
			var delta_str := "Δ: %.1f" % dist_cells
			draw_rect(Rect2(mid + Vector2(-12, -7), Vector2(24, 10)), Color(0.04, 0.05, 0.08, 0.8), true)
			draw_string(font, mid + Vector2(-10, 1), delta_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.YELLOW)

func _draw_progression_axis_overlay(font: Font) -> void:
	if not overlay.show_progression_axis:
		return
	var comp = _get_composition()
	if comp == null:
		return
	var prog_dir: Vector2 = comp.progression_direction
	if prog_dir.is_zero_approx():
		return

	if not ("grid" in _current_floor_data) or _current_floor_data.grid == null:
		return

	var gw: float = float(_current_floor_data.grid.width)
	var gh: float = float(_current_floor_data.grid.height)
	var center: Vector2 = Vector2(gw, gh) * 0.5
	var span: float = minf(gw, gh) * 0.72

	var axis_p0: Vector2 = center - prog_dir * (span * 0.5)
	var axis_p1: Vector2 = center + prog_dir * (span * 0.5)
	var s0: Vector2 = transform.world_to_screen(axis_p0 * transform.cell_size)
	var s1: Vector2 = transform.world_to_screen(axis_p1 * transform.cell_size)

	var perp := Vector2(-prog_dir.y, prog_dir.x)
	var perp_screen := Vector2(-perp.y, perp.x).normalized()

	# Glowing progression axis line
	var col_axis := Color(0.96, 0.62, 0.04, 0.9)
	draw_line(s0, s1, Color(col_axis, 0.3), 6.0)
	draw_line(s0, s1, col_axis, 2.5)

	# Arrowhead at end
	var arrow_dir := (s1 - s0).normalized()
	var s_perp := Vector2(-arrow_dir.y, arrow_dir.x)
	var head_sz: float = 14.0 * transform.zoom
	draw_line(s1, s1 - arrow_dir * head_sz + s_perp * (head_sz * 0.6), col_axis, 2.5)
	draw_line(s1, s1 - arrow_dir * head_sz - s_perp * (head_sz * 0.6), col_axis, 2.5)

	# Ticks & milestone labels
	var milestones: Array = [0.0, 0.25, 0.50, 0.75, 1.0]
	var milestone_names: Array = ["0% (START)", "25% (EARLY)", "50% (MID)", "75% (LATE)", "100% (BOSS)"]
	for i in range(milestones.size()):
		var f: float = milestones[i]
		var tick_s: Vector2 = s0.lerp(s1, f)
		var tick_len: float = 8.0 * transform.zoom
		draw_line(tick_s - s_perp * tick_len, tick_s + s_perp * tick_len, Color.WHITE, 1.5)
		draw_string(font, tick_s + s_perp * (tick_len + 4.0), milestone_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.9, 0.9))

	# Axis Header
	var title := "PROGRESSION AXIS (dir: %.2f, %.2f)" % [prog_dir.x, prog_dir.y]
	draw_rect(Rect2(s0 + Vector2(-15, -20), Vector2(170, 14)), Color(0.04, 0.05, 0.08, 0.85), true)
	draw_string(font, s0 + Vector2(-12, -9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col_axis)

func _draw_main_path_composition_overlay(font: Font) -> void:
	if not overlay.show_main_path_composition:
		return
	var comp = _get_composition()
	if comp == null:
		return
	var main_ids: Array[int] = comp.main_path_node_ids
	if main_ids.size() < 2:
		return

	var maps = _get_room_maps()
	var by_node: Dictionary = maps["by_node"]

	var pts: PackedVector2Array = []
	var node_pts: Array[Dictionary] = []

	for i in range(main_ids.size()):
		var nid: int = main_ids[i]
		var target: Vector2 = comp.get_anchor_target(nid)
		if target.is_zero_approx() and by_node.has(nid):
			target = Vector2(by_node[nid].get_center())
		var s_pt: Vector2 = transform.world_to_screen(target * transform.cell_size)
		pts.append(s_pt)
		node_pts.append({
			"nid": nid,
			"pt": s_pt,
			"factor": comp.get_main_path_factor(nid),
			"region": comp.get_region(nid)
		})

	if pts.size() >= 2:
		# Glowing emerald path polyline
		draw_polyline(pts, Color(0.1, 0.9, 0.5, 0.3), 6.5)
		draw_polyline(pts, Color(0.1, 0.9, 0.5, 0.85), 2.5)

	for i in range(node_pts.size()):
		var item: Dictionary = node_pts[i]
		var pt: Vector2 = item["pt"]
		var nid: int = item["nid"]
		var factor: float = item["factor"]
		var region: StringName = item["region"]

		draw_circle(pt, 9.0 * transform.zoom, Color(0.1, 0.9, 0.5, 0.4))
		draw_arc(pt, 9.0 * transform.zoom, 0, TAU, 16, Color(0.1, 0.9, 0.5, 1.0), 2.0)
		draw_string(font, pt + Vector2(-3, 3), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)

		var badge := "MP #%d (f=%.2f %s)" % [nid, factor, str(region).replace("region_", "")]
		draw_rect(Rect2(pt + Vector2(12, -8), Vector2(font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6, 12)), Color(0.04, 0.05, 0.08, 0.8), true)
		draw_string(font, pt + Vector2(15, 1), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.9, 0.6))

func _draw_branch_zones_overlay(font: Font) -> void:
	if not overlay.show_branch_zones:
		return
	var comp = _get_composition()
	if comp == null:
		return

	var maps = _get_room_maps()
	var by_node: Dictionary = maps["by_node"]
	var main_ids: Array[int] = comp.main_path_node_ids
	var all_ids: Array[int] = comp.get_all_node_ids()

	var col_branch := Color(0.82, 0.35, 0.98, 0.85) # Electric Purple

	for nid in all_ids:
		if nid in main_ids:
			continue
		var anchor_nid: int = comp.get_branch_anchor(nid)
		if anchor_nid < 0:
			continue

		var b_pos: Vector2 = comp.get_anchor_target(nid)
		if b_pos.is_zero_approx() and by_node.has(nid):
			b_pos = Vector2(by_node[nid].get_center())

		var a_pos: Vector2 = comp.get_anchor_target(anchor_nid)
		if a_pos.is_zero_approx() and by_node.has(anchor_nid):
			a_pos = Vector2(by_node[anchor_nid].get_center())

		if not b_pos.is_zero_approx() and not a_pos.is_zero_approx():
			var s_a: Vector2 = transform.world_to_screen(a_pos * transform.cell_size)
			var s_b: Vector2 = transform.world_to_screen(b_pos * transform.cell_size)

			# Branch linkage line
			draw_line(s_a, s_b, Color(col_branch, 0.3), 4.0)
			draw_line(s_a, s_b, col_branch, 1.8)

			# Branch zone envelope around branch target
			var zone_sz: float = 18.0 * transform.zoom
			var zone_rect := Rect2(s_b - Vector2(zone_sz, zone_sz) * 0.5, Vector2(zone_sz, zone_sz))
			draw_rect(zone_rect, Color(col_branch, 0.15), true)
			draw_rect(zone_rect, col_branch, false, 1.2)

			var branch_label := "BRANCH #%d ➔ Anchor #%d" % [nid, anchor_nid]
			draw_string(font, s_b + Vector2(-15, zone_sz * 0.5 + 11), branch_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col_branch)

func _draw_density_zones_overlay(font: Font) -> void:
	if not overlay.show_density_zones:
		return
	var comp = _get_composition()
	if comp == null:
		return

	var maps = _get_room_maps()
	var by_node: Dictionary = maps["by_node"]
	var all_ids: Array[int] = comp.get_all_node_ids()

	for nid in all_ids:
		var d_val: float = comp.get_density(nid)
		var pos: Vector2 = comp.get_anchor_target(nid)
		if pos.is_zero_approx() and by_node.has(nid):
			pos = Vector2(by_node[nid].get_center())
		if pos.is_zero_approx():
			continue

		var s_pt: Vector2 = transform.world_to_screen(pos * transform.cell_size)
		var halo_radius: float = clampf(14.0 * d_val * transform.zoom, 8.0, 45.0)

		var col_fill: Color
		var col_border: Color
		var label_tag: String

		if d_val > 1.05:
			col_fill = Color(0.96, 0.45, 0.1, 0.2)
			col_border = Color(0.96, 0.45, 0.1, 0.8)
			label_tag = "D:%.2f (Dense)" % d_val
		elif d_val < 0.95:
			col_fill = Color(0.2, 0.65, 0.95, 0.18)
			col_border = Color(0.2, 0.65, 0.95, 0.75)
			label_tag = "D:%.2f (Sparse)" % d_val
		else:
			col_fill = Color(0.1, 0.8, 0.4, 0.15)
			col_border = Color(0.1, 0.8, 0.4, 0.7)
			label_tag = "D:%.2f (Normal)" % d_val

		draw_circle(s_pt, halo_radius, col_fill)
		draw_arc(s_pt, halo_radius, 0, TAU, 24, col_border, 1.2)
		draw_string(font, s_pt + Vector2(-15, halo_radius + 9), label_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col_border)
