class_name RoomTemplateLabState
extends RefCounted

## Estado reactivo y modelo de datos del Laboratorio/Editor de RoomTemplates.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _SymPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd")
const _ClrPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")

enum Tool {
	BRUSH = 0,
	ERASER = 1,
	RECT_FILL = 2,
	PLACE_ENTRANCE = 3,
	PLACE_ANCHOR = 4,
	PLACE_DOOR = 5,
	SELECT = 6
}

signal template_changed(template: _RoomTemplateScript)
signal canvas_modified()
signal tool_changed(tool_idx: int)
signal anchors_modified()
signal entrances_modified()
signal doors_modified()
signal validation_updated(is_valid: bool, errors: Array[String], stats: Dictionary)

# Identidad
var template_id: StringName = &"new_template"
var display_name: String = "New Template"
var tags: Array[StringName] = []

# Geometría declarativa
var allowed_shapes: Array[StringName] = [&"rectangle"]
var min_width: int = 6
var max_width: int = 16
var min_depth: int = 6
var max_depth: int = 16
var min_area: int = 36
var max_area: int = 256
var min_aspect_ratio: float = 0.5
var max_aspect_ratio: float = 2.0

# Políticas
var min_entrances: int = 1
var max_entrances: int = 4
var allowed_sides: Array[StringName] = [&"north", &"south", &"east", &"west"]
var allow_corner_entrances: bool = false
var min_entrance_spacing: int = 2

var symmetry_required: bool = false
var symmetry_axis: StringName = &"none" # none, vertical, horizontal, both
var mirror_paint_enabled: bool = false

var clearance_entrance: int = 1
var clearance_focal: int = 1
var clearance_circulation: int = 1
var clearance_walls: int = 0

var allowed_purposes: Array[StringName] = []
var preferred_purposes: Array[StringName] = []

# Canvas State
var painted_cells: Dictionary = {} # Vector2i -> int (1: Floor, 0: Wall/Empty)
var entrances: Array[Vector2i] = []
var anchors: Dictionary = {} # StringName -> Vector2i
var anchor_defs: Dictionary = {} # StringName -> RoomTemplateAnchorDef
var internal_doors: Dictionary = {} # Vector2i -> StringName (&"door", &"locked_door", &"arch")
var active_door_type: StringName = &"door"
var active_tool: int = Tool.BRUSH

# Command History Reference
var command_history = null

func set_cell(pos: Vector2i, type: int) -> void:
	if type > 0:
		painted_cells[pos] = type
	else:
		painted_cells.erase(pos)
		internal_doors.erase(pos)
	canvas_modified.emit()

func get_cell(pos: Vector2i) -> int:
	return painted_cells.get(pos, 0)

func is_cell_walkable(pos: Vector2i) -> bool:
	return painted_cells.get(pos, 0) > 0

func get_painted_cell_count() -> int:
	return painted_cells.size()

func clear_canvas() -> void:
	painted_cells.clear()
	entrances.clear()
	anchors.clear()
	internal_doors.clear()
	canvas_modified.emit()
	entrances_modified.emit()
	anchors_modified.emit()
	doors_modified.emit()

func fill_rect(rect: Rect2i, type: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := Vector2i(x, y)
			if type > 0:
				painted_cells[p] = type
			else:
				painted_cells.erase(p)
				internal_doors.erase(p)
	canvas_modified.emit()

func set_tool(tool_idx: int) -> void:
	active_tool = tool_idx
	tool_changed.emit(tool_idx)

# --- Anchors ---
func set_anchor(id: StringName, pos: Vector2i, is_required: bool = true, loc_hint: StringName = &"center") -> void:
	anchors[id] = pos
	if not anchor_defs.has(id):
		anchor_defs[id] = _AnchorDefScript.new(id, is_required, loc_hint)
	anchors_modified.emit()

func remove_anchor(id: StringName) -> void:
	anchors.erase(id)
	anchor_defs.erase(id)
	anchors_modified.emit()

func get_anchor(id: StringName) -> Vector2i:
	return anchors.get(id, Vector2i(-999, -999))

func has_anchor(id: StringName) -> bool:
	return anchors.has(id)

# --- Entrances ---
func add_entrance(pos: Vector2i) -> void:
	if not entrances.has(pos):
		entrances.append(pos)
		entrances_modified.emit()

func remove_entrance(pos: Vector2i) -> void:
	if entrances.has(pos):
		entrances.erase(pos)
		entrances_modified.emit()

func get_entrances() -> Array[Vector2i]:
	return entrances

# --- Internal Doors & Archways ---
func set_internal_door(pos: Vector2i, door_type: StringName) -> void:
	internal_doors[pos] = door_type
	# Automatically ensure floor cell is painted underneath
	if not painted_cells.has(pos):
		painted_cells[pos] = 1
	doors_modified.emit()
	canvas_modified.emit()

func remove_internal_door(pos: Vector2i) -> void:
	if internal_doors.has(pos):
		internal_doors.erase(pos)
		doors_modified.emit()
		canvas_modified.emit()

func has_internal_door(pos: Vector2i) -> bool:
	return internal_doors.has(pos)

func get_internal_door_type(pos: Vector2i) -> StringName:
	return internal_doors.get(pos, &"door")

# --- Auto Calculation ---
func auto_calculate_geometry() -> Dictionary:
	if painted_cells.is_empty():
		return {
			"min_x": 0, "max_x": 0,
			"min_y": 0, "max_y": 0,
			"width": 0, "height": 0,
			"area": 0, "aspect_ratio": 1.0,
			"bounds": Rect2i(0, 0, 0, 0)
		}

	var min_x: int = 999999
	var max_x: int = -999999
	var min_y: int = 999999
	var max_y: int = -999999

	for p in painted_cells.keys():
		min_x = mini(min_x, p.x)
		max_x = maxi(max_x, p.x)
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y)

	var w: int = (max_x - min_x) + 1
	var h: int = (max_y - min_y) + 1
	var area: int = painted_cells.size()
	var aspect: float = float(w) / float(maxi(1, h))
	var bounds := Rect2i(min_x, min_y, w, h)

	return {
		"min_x": min_x, "max_x": max_x,
		"min_y": min_y, "max_y": max_y,
		"width": w, "height": h,
		"area": area, "aspect_ratio": aspect,
		"bounds": bounds
	}

# --- Template Import / Export ---
func load_from_template(tpl: _RoomTemplateScript) -> void:
	if tpl == null:
		return
	template_id = tpl.id
	display_name = tpl.display_name
	tags = tpl.tags.duplicate()
	allowed_purposes = tpl.allowed_purposes.duplicate()
	preferred_purposes = tpl.preferred_purposes.duplicate()

	if tpl.geometry != null:
		allowed_shapes = tpl.geometry.allowed_shapes.duplicate()
		min_width = tpl.geometry.min_width
		max_width = tpl.geometry.max_width
		min_depth = tpl.geometry.min_depth
		max_depth = tpl.geometry.max_depth
		min_area = tpl.geometry.min_area
		max_area = tpl.geometry.max_area
		min_aspect_ratio = tpl.geometry.min_aspect_ratio
		max_aspect_ratio = tpl.geometry.max_aspect_ratio

	if tpl.entrances != null:
		min_entrances = tpl.entrances.min_count
		max_entrances = tpl.entrances.max_count
		allowed_sides = tpl.entrances.allowed_sides.duplicate()
		allow_corner_entrances = tpl.entrances.allow_corner
		min_entrance_spacing = tpl.entrances.min_spacing

	if tpl.symmetry != null:
		symmetry_required = tpl.symmetry.required
		symmetry_axis = tpl.symmetry.axis

	if tpl.clearances != null:
		clearance_entrance = tpl.clearances.entrance
		clearance_focal = tpl.clearances.focal
		clearance_circulation = tpl.clearances.circulation
		clearance_walls = tpl.clearances.walls

	anchors.clear()
	anchor_defs.clear()
	if tpl.anchors is Dictionary:
		for a_id in tpl.anchors:
			var ad = tpl.anchors[a_id]
			anchor_defs[a_id] = ad
			# Assign center baseline for coordinates
			anchors[a_id] = Vector2i(0, 0)

	template_changed.emit(tpl)

func build_template_from_state() -> _RoomTemplateScript:
	var geom := _GeomPolicyScript.new(
		allowed_shapes,
		min_width, max_width,
		min_depth, max_depth,
		min_area, max_area,
		min_aspect_ratio, max_aspect_ratio
	)
	var ent := _EntPolicyScript.new(
		min_entrances, max_entrances,
		allowed_sides,
		allow_corner_entrances,
		min_entrance_spacing
	)
	var sym := _SymPolicyScript.new(symmetry_required, symmetry_axis)
	var clr := _ClrPolicyScript.new(
		clearance_entrance,
		clearance_focal,
		clearance_circulation,
		clearance_walls
	)
	var tpl = _RoomTemplateScript.new(
		template_id,
		display_name,
		tags,
		geom,
		ent,
		sym,
		anchor_defs,
		clr,
		allowed_purposes,
		preferred_purposes
	)

	# Si hay celdas pintadas en el canvas, guardar el diseño exacto en custom_layout
	var geom_info = auto_calculate_geometry()
	if geom_info["width"] > 0 and geom_info["height"] > 0:
		var bounds: Rect2i = geom_info["bounds"]
		var rel_cells: Array[Array] = []
		for c in painted_cells:
			if painted_cells[c] == 1:
				var rel: Vector2i = c - bounds.position
				rel_cells.append([rel.x, rel.y])

		var rel_anchors: Dictionary = {}
		for a_id in anchors:
			var a_pos: Vector2i = anchors[a_id]
			if bounds.has_point(a_pos):
				var rel_a: Vector2i = a_pos - bounds.position
				rel_anchors[str(a_id)] = [rel_a.x, rel_a.y]

		var rel_entrances: Array[Array] = []
		for e in entrances:
			var rel_e: Vector2i = e - bounds.position
			rel_entrances.append([rel_e.x, rel_e.y])

		var rel_doors: Array[Dictionary] = []
		for d_pos in internal_doors:
			if bounds.has_point(d_pos):
				var rel_d: Vector2i = d_pos - bounds.position
				rel_doors.append({
					"x": rel_d.x,
					"y": rel_d.y,
					"type": str(internal_doors[d_pos])
				})

		tpl.custom_layout = {
			"width": bounds.size.x,
			"height": bounds.size.y,
			"cells": rel_cells,
			"anchors": rel_anchors,
			"entrances": rel_entrances,
			"internal_doors": rel_doors
		}

	return tpl
