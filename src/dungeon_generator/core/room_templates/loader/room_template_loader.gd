class_name RoomTemplateLoader
extends RefCounted

## Cargador determinista de archivos JSON a instancias tipadas de RoomTemplate.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _SymmetryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")
const _ClearancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd")

func load_from_file(file_path: String) -> _RoomTemplateScript:
	if not FileAccess.file_exists(file_path):
		push_warning("[RoomTemplateLoader] File not found: %s" % file_path)
		return null

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("[RoomTemplateLoader] Failed to open: %s" % file_path)
		return null

	var json_str = file.get_as_text()
	return load_from_json_string(json_str)

func load_from_json_string(json_str: String) -> _RoomTemplateScript:
	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		push_warning("[RoomTemplateLoader] JSON parse error: %s" % json.get_error_message())
		return null

	var data = json.get_data()
	if not (data is Dictionary):
		return null

	return parse_template_dictionary(data)

func parse_template_dictionary(dict: Dictionary) -> _RoomTemplateScript:
	var t_id = StringName(str(dict.get("id", "unnamed_template")))
	var display_name = str(dict.get("display_name", t_id))
	var tags: Array[StringName] = []
	for t in dict.get("tags", []):
		tags.append(StringName(t))

	# 1. Geometry Policy
	var geom_dict = dict.get("geometry", {})
	var geom_policy: _GeometryPolicyScript = null
	if geom_dict is Dictionary:
		var shapes: Array[StringName] = []
		var shape_raw = geom_dict.get("shape", {})
		if shape_raw is Dictionary:
			for sh in shape_raw.get("allowed", []):
				shapes.append(StringName(sh))
		if shapes.is_empty():
			shapes = [&"rectangle"]

		var w_min = int(geom_dict.get("width", {}).get("min", 5) if geom_dict.get("width") is Dictionary else 5)
		var w_max = int(geom_dict.get("width", {}).get("max", 15) if geom_dict.get("width") is Dictionary else 15)
		var d_min = int(geom_dict.get("depth", {}).get("min", 5) if geom_dict.get("depth") is Dictionary else 5)
		var d_max = int(geom_dict.get("depth", {}).get("max", 15) if geom_dict.get("depth") is Dictionary else 15)
		var a_min = int(geom_dict.get("area", {}).get("min", 25) if geom_dict.get("area") is Dictionary else 25)
		var a_max = int(geom_dict.get("area", {}).get("max", 225) if geom_dict.get("area") is Dictionary else 225)
		var r_min = float(geom_dict.get("aspect_ratio", {}).get("min", 0.5) if geom_dict.get("aspect_ratio") is Dictionary else 0.5)
		var r_max = float(geom_dict.get("aspect_ratio", {}).get("max", 2.0) if geom_dict.get("aspect_ratio") is Dictionary else 2.0)

		geom_policy = _GeometryPolicyScript.new(shapes, w_min, w_max, d_min, d_max, a_min, a_max, r_min, r_max)

	# 2. Entrance Policy
	var ent_dict = dict.get("entrances", {})
	var ent_policy: _EntrancePolicyScript = null
	if ent_dict is Dictionary:
		var e_min = int(ent_dict.get("min", 1))
		var e_max = int(ent_dict.get("max", 4))
		var sides: Array[StringName] = []
		for s in ent_dict.get("allowed_sides", []):
			sides.append(StringName(s))
		var allow_corner = bool(ent_dict.get("allow_corner", false))
		var min_spacing = int(ent_dict.get("min_spacing", 2))
		ent_policy = _EntrancePolicyScript.new(e_min, e_max, sides, allow_corner, min_spacing)

	# 3. Symmetry Policy
	var sym_dict = dict.get("symmetry", {})
	var sym_policy: _SymmetryPolicyScript = null
	if sym_dict is Dictionary:
		var req = bool(sym_dict.get("required", false))
		var axis = StringName(str(sym_dict.get("axis", "none")))
		var tol = int(sym_dict.get("tolerance", 0))
		sym_policy = _SymmetryPolicyScript.new(req, axis, tol)

	# 4. Anchors
	var anchors_dict: Dictionary = {}
	var raw_anchors = dict.get("anchors", {})
	if raw_anchors is Dictionary:
		for a_key in raw_anchors:
			var a_data = raw_anchors[a_key]
			if a_data is Dictionary:
				var a_req = bool(a_data.get("required", true))
				var a_loc = StringName(str(a_data.get("location", "center")))
				anchors_dict[StringName(a_key)] = _AnchorDefScript.new(StringName(a_key), a_req, a_loc)

	# 5. Clearances
	var clr_dict = dict.get("clearances", {})
	var clr_policy: _ClearancePolicyScript = null
	if clr_dict is Dictionary:
		var c_ent = int(clr_dict.get("entrance", 1))
		var c_foc = int(clr_dict.get("focal", 1))
		var c_circ = int(clr_dict.get("circulation", 1))
		var c_wall = int(clr_dict.get("walls", 0))
		clr_policy = _ClearancePolicyScript.new(c_ent, c_foc, c_circ, c_wall)

	# 6. Semantic Constraints
	var allowed_p: Array[StringName] = []
	var pref_p: Array[StringName] = []
	var sem = dict.get("semantic_constraints", {})
	if sem is Dictionary:
		for p in sem.get("allowed_purposes", []):
			allowed_p.append(StringName(p))
		for p in sem.get("preferred_purposes", []):
			pref_p.append(StringName(p))

	return _RoomTemplateScript.new(
		t_id, display_name, tags, geom_policy, ent_policy, sym_policy,
		anchors_dict, clr_policy, allowed_p, pref_p
	)
