class_name RoomTemplate
extends RefCounted

## Modelo central inmutable de RoomTemplate (Contrato Declarativo).
## Describe las reglas, geometrías y restricciones espaciales de una categoría de sala
## sin acoplar nodos Godot, mallas 3D ni escenas visuales.

const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _SymmetryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")
const _ClearancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd")

var schema_version: int = 1
var id: StringName = &""
var display_name: String = ""
var tags: Array[StringName] = []

var geometry: _GeometryPolicyScript = null
var entrances: _EntrancePolicyScript = null
var symmetry: _SymmetryPolicyScript = null
var anchors: Dictionary = {} # StringName -> RoomTemplateAnchorDef
var clearances: _ClearancePolicyScript = null
var allowed_purposes: Array[StringName] = []
var preferred_purposes: Array[StringName] = []
var custom_layout: Dictionary = {}

func _init(
	p_id: StringName = &"",
	p_display_name: String = "",
	p_tags: Array[StringName] = [],
	p_geometry: _GeometryPolicyScript = null,
	p_entrances: _EntrancePolicyScript = null,
	p_symmetry: _SymmetryPolicyScript = null,
	p_anchors: Dictionary = {},
	p_clearances: _ClearancePolicyScript = null,
	p_allowed_purposes: Array[StringName] = [],
	p_preferred_purposes: Array[StringName] = []
) -> void:
	id = p_id
	display_name = p_display_name
	tags = p_tags
	geometry = p_geometry if p_geometry != null else _GeometryPolicyScript.new()
	entrances = p_entrances if p_entrances != null else _EntrancePolicyScript.new()
	symmetry = p_symmetry if p_symmetry != null else _SymmetryPolicyScript.new()
	anchors = p_anchors
	clearances = p_clearances if p_clearances != null else _ClearancePolicyScript.new()
	allowed_purposes = p_allowed_purposes
	preferred_purposes = p_preferred_purposes

func get_anchor(anchor_id: StringName) -> _AnchorDefScript:
	return anchors.get(anchor_id, null)

func has_anchor(anchor_id: StringName) -> bool:
	return anchors.has(anchor_id)

func is_purpose_allowed(purpose_id: StringName) -> bool:
	if allowed_purposes.is_empty():
		return true
	return allowed_purposes.has(purpose_id)

static func from_dictionary(dict: Dictionary) -> RoomTemplate:
	var t_id := StringName(str(dict.get("id", "unnamed_template")))
	var display_name := str(dict.get("display_name", t_id))
	var tags: Array[StringName] = []
	for t in dict.get("tags", []):
		tags.append(StringName(t))

	# Geometry Policy
	var geom_dict = dict.get("geometry", {})
	var geom_policy: _GeometryPolicyScript = null
	if geom_dict is Dictionary:
		var shapes: Array[StringName] = []
		var shape_raw = geom_dict.get("shape", {})
		if shape_raw is Dictionary:
			for sh in shape_raw.get("allowed", []):
				shapes.append(StringName(sh))
		elif geom_dict.get("allowed_shapes") is Array:
			for sh in geom_dict.get("allowed_shapes"):
				shapes.append(StringName(sh))
		if shapes.is_empty():
			shapes = [&"rectangle"]

		var w_min := int(geom_dict.get("width", {}).get("min", geom_dict.get("min_width", 5)) if geom_dict.get("width") is Dictionary else geom_dict.get("min_width", 5))
		var w_max := int(geom_dict.get("width", {}).get("max", geom_dict.get("max_width", 15)) if geom_dict.get("width") is Dictionary else geom_dict.get("max_width", 15))
		var d_min := int(geom_dict.get("depth", {}).get("min", geom_dict.get("min_depth", 5)) if geom_dict.get("depth") is Dictionary else geom_dict.get("min_depth", 5))
		var d_max := int(geom_dict.get("depth", {}).get("max", geom_dict.get("max_depth", 15)) if geom_dict.get("depth") is Dictionary else geom_dict.get("max_depth", 15))
		var a_min := int(geom_dict.get("area", {}).get("min", geom_dict.get("min_area", 25)) if geom_dict.get("area") is Dictionary else geom_dict.get("min_area", 25))
		var a_max := int(geom_dict.get("area", {}).get("max", geom_dict.get("max_area", 225)) if geom_dict.get("area") is Dictionary else geom_dict.get("max_area", 225))
		var r_min := float(geom_dict.get("aspect_ratio", {}).get("min", geom_dict.get("min_aspect_ratio", 0.5)) if geom_dict.get("aspect_ratio") is Dictionary else geom_dict.get("min_aspect_ratio", 0.5))
		var r_max := float(geom_dict.get("aspect_ratio", {}).get("max", geom_dict.get("max_aspect_ratio", 2.0)) if geom_dict.get("aspect_ratio") is Dictionary else geom_dict.get("max_aspect_ratio", 2.0))

		geom_policy = _GeometryPolicyScript.new(shapes, w_min, w_max, d_min, d_max, a_min, a_max, r_min, r_max)

	# Entrance Policy
	var ent_dict = dict.get("entrances", {})
	var ent_policy: _EntrancePolicyScript = null
	if ent_dict is Dictionary:
		var e_min := int(ent_dict.get("min", ent_dict.get("min_count", 1)))
		var e_max := int(ent_dict.get("max", ent_dict.get("max_count", 4)))
		var sides: Array[StringName] = []
		for s in ent_dict.get("allowed_sides", []):
			sides.append(StringName(s))
		var allow_corner := bool(ent_dict.get("allow_corner", false))
		var min_spacing := int(ent_dict.get("min_spacing", 2))
		ent_policy = _EntrancePolicyScript.new(e_min, e_max, sides, allow_corner, min_spacing)

	# Symmetry Policy
	var sym_dict = dict.get("symmetry", {})
	var sym_policy: _SymmetryPolicyScript = null
	if sym_dict is Dictionary:
		var req := bool(sym_dict.get("required", false))
		var axis := StringName(str(sym_dict.get("axis", "none")))
		var tol := int(sym_dict.get("tolerance", 0))
		sym_policy = _SymmetryPolicyScript.new(req, axis, tol)

	# Anchors
	var anchors_dict: Dictionary = {}
	var raw_anchors = dict.get("anchors", {})
	if raw_anchors is Dictionary:
		for a_key in raw_anchors:
			var a_data = raw_anchors[a_key]
			if a_data is Dictionary:
				var a_req := bool(a_data.get("required", true))
				var a_loc := StringName(str(a_data.get("location", "center")))
				anchors_dict[StringName(a_key)] = _AnchorDefScript.new(StringName(a_key), a_req, a_loc)

	# Clearances
	var clr_dict = dict.get("clearances", {})
	var clr_policy: _ClearancePolicyScript = null
	if clr_dict is Dictionary:
		var c_ent := int(clr_dict.get("entrance", 1))
		var c_foc := int(clr_dict.get("focal", 1))
		var c_circ := int(clr_dict.get("circulation", 1))
		var c_wall := int(clr_dict.get("walls", 0))
		clr_policy = _ClearancePolicyScript.new(c_ent, c_foc, c_circ, c_wall)

	# Semantic Constraints / Purposes
	var allowed_p: Array[StringName] = []
	var pref_p: Array[StringName] = []
	var purp_dict = dict.get("purposes", {})
	if purp_dict is Dictionary and not purp_dict.is_empty():
		for p in purp_dict.get("allowed", []):
			allowed_p.append(StringName(p))
		for p in purp_dict.get("preferred", []):
			pref_p.append(StringName(p))

	var sem = dict.get("semantic_constraints", {})
	if sem is Dictionary and not sem.is_empty():
		for p in sem.get("allowed_purposes", []):
			if not allowed_p.has(StringName(p)):
				allowed_p.append(StringName(p))
		for p in sem.get("preferred_purposes", []):
			if not pref_p.has(StringName(p)):
				pref_p.append(StringName(p))

	for p in dict.get("allowed_purposes", []):
		if not allowed_p.has(StringName(p)):
			allowed_p.append(StringName(p))
	for p in dict.get("preferred_purposes", []):
		if not pref_p.has(StringName(p)):
			pref_p.append(StringName(p))

	var tpl = RoomTemplate.new(
		t_id, display_name, tags, geom_policy, ent_policy, sym_policy,
		anchors_dict, clr_policy, allowed_p, pref_p
	)

	var custom_lay = dict.get("custom_layout", {})
	if custom_lay is Dictionary and not custom_lay.is_empty():
		tpl.custom_layout = custom_lay

	return tpl
