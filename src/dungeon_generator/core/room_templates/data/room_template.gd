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
