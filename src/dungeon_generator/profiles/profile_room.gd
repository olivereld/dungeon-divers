class_name ProfileRoom
extends RefCounted

## Perfil tipado completo de una sala deserializado desde rooms/*.json.

const _ProfileRoomIntentScript = preload("res://src/dungeon_generator/profiles/profile_room_intent.gd")
const _ProfileRoomArchitectureScript = preload("res://src/dungeon_generator/profiles/profile_room_architecture.gd")
const _ProfileCompositionScript = preload("res://src/dungeon_generator/profiles/profile_composition.gd")
const _ProfileLightingScript = preload("res://src/dungeon_generator/profiles/profile_lighting.gd")
const _ProfileRelationshipScript = preload("res://src/dungeon_generator/profiles/profile_relationship.gd")
const _ProfileRoomTemplateConstraintsScript = preload("res://src/dungeon_generator/profiles/profile_room_template_constraints.gd")

var id: StringName = &""
var display_name: String = ""
var schema_version: int = 1
var intent: _ProfileRoomIntentScript = null
var architecture: _ProfileRoomArchitectureScript = null
var composition: _ProfileCompositionScript = null
var lighting: _ProfileLightingScript = null
var relationships: Array[_ProfileRelationshipScript] = []
var template_constraints: _ProfileRoomTemplateConstraintsScript = null

func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_version: int = 1,
	p_intent: _ProfileRoomIntentScript = null,
	p_arch: _ProfileRoomArchitectureScript = null,
	p_comp: _ProfileCompositionScript = null,
	p_light: _ProfileLightingScript = null,
	p_rels: Array[_ProfileRelationshipScript] = [],
	p_templates: _ProfileRoomTemplateConstraintsScript = null
) -> void:
	id = p_id
	display_name = p_name
	schema_version = p_version
	intent = p_intent if p_intent != null else _ProfileRoomIntentScript.new()
	architecture = p_arch if p_arch != null else _ProfileRoomArchitectureScript.new()
	composition = p_comp if p_comp != null else _ProfileCompositionScript.new()
	lighting = p_light if p_light != null else _ProfileLightingScript.new()
	relationships = p_rels
	template_constraints = p_templates if p_templates != null else _ProfileRoomTemplateConstraintsScript.new()

