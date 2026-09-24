class_name DungeonIdentity
extends RefCounted

## Identidad canónica y formal de una mazmorra en el universo procedural.
## Autoridad inmutable derivada exclusivamente de MasterSeed + MacroCoord + CandidateIndex.
## NO almacena world_position, archetype, tier, orientación o chunk_coord como autoridad.

var dungeon_id: StringName = &""
var macro_coord: Vector2i = Vector2i.ZERO
var candidate_index: int = 0
var dungeon_seed: int = 0

func _init(p_dungeon_id: StringName = &"", p_macro_coord: Vector2i = Vector2i.ZERO, p_candidate_index: int = 0, p_dungeon_seed: int = 0) -> void:
	dungeon_id = p_dungeon_id
	macro_coord = p_macro_coord
	candidate_index = p_candidate_index
	dungeon_seed = p_dungeon_seed

static func create(master_seed: int, macro_coord: Vector2i, candidate_index: int = 0) -> RefCounted:
	var id_str: String = "dungeon_m%d_%d_%d" % [macro_coord.x, macro_coord.y, candidate_index]
	var d_id: StringName = StringName(id_str)
	var d_seed: int = WorldSeedSystem.derive_dungeon_seed(master_seed, d_id)
	var inst := new()
	inst.dungeon_id = d_id
	inst.macro_coord = macro_coord
	inst.candidate_index = candidate_index
	inst.dungeon_seed = d_seed
	return inst
