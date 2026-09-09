class_name WorldSeedSystem
extends RefCounted

const VERSION_TAG: String = "world_v1"

const DOMAIN_TERRAIN: String = "terrain"
const DOMAIN_ECOLOGY: String = "ecology"
const DOMAIN_VEGETATION: String = "vegetation"
const DOMAIN_POI: String = "poi"

static func derive_seed(master_seed: int, domain: String, index: int = 0) -> int:
	var hash_input: String = "%s:%d:%s:%d" % [VERSION_TAG, master_seed, domain, index]
	return int(hash_input.hash()) & 0x7FFFFFFF

static func derive_poi_seed(master_seed: int, poi_id: StringName, coord: Vector2i, archetype: StringName) -> int:
	var hash_input: String = "%s:%d:poi:%s:%d,%d:%s" % [VERSION_TAG, master_seed, poi_id, coord.x, coord.y, archetype]
	return int(hash_input.hash()) & 0x7FFFFFFF
