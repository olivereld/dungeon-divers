class_name RoomTemplateDefinitionValidator
extends RefCounted

## Validador estricto de esquema y contratos para definiciones JSON/Dictionary de RoomTemplate.
## Rechaza definiciones incompletas, con rangos invertidos o valores inválidos antes del registro.

const _ValidationResultScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_validation_result.gd")

const VALID_SHAPES: Array[StringName] = [
	&"rectangle", &"open_rectangle", &"square",
	&"octagonal", &"octagonal_chamber", &"octagon",
	&"cruciform", &"cruciform_sanctuary", &"cross",
	&"pillared", &"pillared_hall", &"pillars",
	&"chapel",
	&"central_nave", &"nave",
	&"niched_hall", &"niches",
	&"custom"
]

const VALID_SIDES: Array[StringName] = [&"north", &"south", &"east", &"west", &"corner"]
const VALID_AXES: Array[StringName] = [&"none", &"vertical", &"horizontal", &"both", &"radial"]

func validate_definition(dict: Dictionary) -> _ValidationResultScript:
	var result := _ValidationResultScript.new()

	if dict.is_empty():
		result.add_error("Template definition dictionary is empty")
		return result

	# 1. ID & Display Name
	var id_raw: String = str(dict.get("id", "")).strip_edges()
	if id_raw.is_empty():
		result.add_error("Template 'id' is required and cannot be empty")

	# 2. Geometry
	if not dict.has("geometry") or not (dict["geometry"] is Dictionary):
		result.add_error("Template 'geometry' block is required")
	else:
		var geom: Dictionary = dict["geometry"]

		# Shapes
		var shapes: Array = []
		if geom.has("shape") and geom["shape"] is Dictionary:
			shapes = geom["shape"].get("allowed", [])
		elif geom.has("allowed_shapes") and geom["allowed_shapes"] is Array:
			shapes = geom["allowed_shapes"]

		for sh in shapes:
			if not VALID_SHAPES.has(StringName(str(sh))):
				result.add_error("Unknown geometry shape '%s'" % str(sh))

		# Width / Depth / Area
		var w_min: int = _extract_min(geom, "width", 5)
		var w_max: int = _extract_max(geom, "width", 15)
		if w_min <= 0:
			result.add_error("Geometry min_width must be > 0 (got %d)" % w_min)
		if w_min > w_max:
			result.add_error("Geometry min_width (%d) cannot be greater than max_width (%d)" % [w_min, w_max])

		var d_min: int = _extract_min(geom, "depth", 5)
		var d_max: int = _extract_max(geom, "depth", 15)
		if d_min <= 0:
			result.add_error("Geometry min_depth must be > 0 (got %d)" % d_min)
		if d_min > d_max:
			result.add_error("Geometry min_depth (%d) cannot be greater than max_depth (%d)" % [d_min, d_max])

		var a_min: int = _extract_min(geom, "area", 25)
		var a_max: int = _extract_max(geom, "area", 225)
		if a_min > a_max:
			result.add_error("Geometry min_area (%d) cannot be greater than max_area (%d)" % [a_min, a_max])

		# Aspect ratio
		var r_min: float = _extract_float_min(geom, "aspect_ratio", 0.5)
		var r_max: float = _extract_float_max(geom, "aspect_ratio", 2.0)
		if r_min > r_max:
			result.add_error("Geometry min_aspect_ratio (%.2f) cannot be greater than max_aspect_ratio (%.2f)" % [r_min, r_max])

	# 3. Entrances
	if dict.has("entrances") and dict["entrances"] is Dictionary:
		var ent: Dictionary = dict["entrances"]
		var e_min: int = int(ent.get("min", ent.get("min_count", 1)))
		var e_max: int = int(ent.get("max", ent.get("max_count", 4)))
		if e_min < 0:
			result.add_error("Entrances min_count must be >= 0 (got %d)" % e_min)
		if e_min > e_max:
			result.add_error("Entrances min_count (%d) cannot be greater than max_count (%d)" % [e_min, e_max])

		var sides: Array = ent.get("allowed_sides", [])
		for s in sides:
			if not VALID_SIDES.has(StringName(str(s).to_lower())):
				result.add_error("Invalid allowed_side '%s' (expected north, south, east, west)" % str(s))

	# 4. Symmetry
	if dict.has("symmetry") and dict["symmetry"] is Dictionary:
		var sym: Dictionary = dict["symmetry"]
		var axis: StringName = StringName(str(sym.get("axis", "none")).to_lower())
		if not VALID_AXES.has(axis):
			result.add_error("Invalid symmetry axis '%s'" % str(axis))

	return result

func _extract_min(dict: Dictionary, key: String, default_val: int) -> int:
	if dict.has(key) and dict[key] is Dictionary:
		return int(dict[key].get("min", default_val))
	return int(dict.get("min_" + key, default_val))

func _extract_max(dict: Dictionary, key: String, default_val: int) -> int:
	if dict.has(key) and dict[key] is Dictionary:
		return int(dict[key].get("max", default_val))
	return int(dict.get("max_" + key, default_val))

func _extract_float_min(dict: Dictionary, key: String, default_val: float) -> float:
	if dict.has(key) and dict[key] is Dictionary:
		return float(dict[key].get("min", default_val))
	return float(dict.get("min_" + key, default_val))

func _extract_float_max(dict: Dictionary, key: String, default_val: float) -> float:
	if dict.has(key) and dict[key] is Dictionary:
		return float(dict[key].get("max", default_val))
	return float(dict.get("max_" + key, default_val))
