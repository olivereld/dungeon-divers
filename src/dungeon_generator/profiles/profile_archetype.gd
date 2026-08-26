class_name ProfileArchetype
extends RefCounted

## Perfil tipado completo de un Arquetipo de mazmorra deserializado desde archetypes/*.json.

const _ProfileArchetypeGlobalSettingsScript = preload("res://src/dungeon_generator/profiles/profile_archetype_global_settings.gd")
const _ProfileArchetypeStyleScript = preload("res://src/dungeon_generator/profiles/profile_archetype_style.gd")
const _ProfileArchetypeRoomRulesScript = preload("res://src/dungeon_generator/profiles/profile_archetype_room_rules.gd")

var id: StringName = &""
var display_name: String = ""
var schema_version: int = 1
var purpose_weights: Dictionary = {} # StringName -> float (contextual weight)
var gameplay_purpose_map: Dictionary = {} # StringName ("START", "BOSS", etc.) -> Array[StringName]
var room_purpose_distribution: Dictionary = {} # StringName -> float (macro frequency, sum == 1.0)
var global_settings: _ProfileArchetypeGlobalSettingsScript = null
var architectural_style: _ProfileArchetypeStyleScript = null
var room_rules: _ProfileArchetypeRoomRulesScript = null
var rooms: Dictionary = {} # StringName -> StringName (purpose_id -> filename)

func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_version: int = 1,
	p_weights: Dictionary = {},
	p_gameplay_map: Dictionary = {},
	p_dist: Dictionary = {},
	p_global: _ProfileArchetypeGlobalSettingsScript = null,
	p_style: _ProfileArchetypeStyleScript = null,
	p_rules: _ProfileArchetypeRoomRulesScript = null,
	p_rooms: Dictionary = {}
) -> void:
	id = p_id
	display_name = p_name
	schema_version = p_version
	purpose_weights = p_weights
	gameplay_purpose_map = p_gameplay_map
	room_purpose_distribution = p_dist
	global_settings = p_global if p_global != null else _ProfileArchetypeGlobalSettingsScript.new()
	architectural_style = p_style if p_style != null else _ProfileArchetypeStyleScript.new()
	room_rules = p_rules if p_rules != null else _ProfileArchetypeRoomRulesScript.new()
	rooms = p_rooms

func get_allowed_purposes_for_gameplay(role: StringName) -> Array[StringName]:
	if gameplay_purpose_map.has(role):
		var list = gameplay_purpose_map[role]
		var result: Array[StringName] = []
		for item in list:
			result.append(StringName(item))
		return result
	return [&"generic"]

func get_contextual_weight(purpose_id: StringName) -> float:
	return float(purpose_weights.get(purpose_id, 1.0))

func get_distribution_weight(purpose_id: StringName) -> float:
	return float(room_purpose_distribution.get(purpose_id, 0.0))
