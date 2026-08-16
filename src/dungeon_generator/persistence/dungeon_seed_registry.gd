class_name DungeonSeedRegistry
extends RefCounted

## Registro para consistencia multi-piso:
## Garantiza que el mismo piso de una mazmorra siempre use la misma semilla y mantenga su estado si el jugador regresa.

var _registry: Dictionary = {} # String "dungeon_id:floor" -> int seed

func get_or_create_seed(dungeon_id: StringName, floor_number: int, master_seed: int) -> int:
	var key := "%s:%d" % [String(dungeon_id), floor_number]
	if _registry.has(key):
		return int(_registry[key])

	var rng := RandomNumberGenerator.new()
	rng.seed = master_seed + floor_number * 7919
	var floor_seed: int = rng.randi()
	_registry[key] = floor_seed
	return floor_seed

func set_seed(dungeon_id: StringName, floor_number: int, seed_value: int) -> void:
	var key := "%s:%d" % [String(dungeon_id), floor_number]
	_registry[key] = seed_value

func has_seed(dungeon_id: StringName, floor_number: int) -> bool:
	var key := "%s:%d" % [String(dungeon_id), floor_number]
	return _registry.has(key)

func clear_dungeon(dungeon_id: StringName) -> void:
	var prefix := "%s:" % [String(dungeon_id)]
	var keys_to_remove: Array[String] = []
	for k in _registry.keys():
		if (k as String).begins_with(prefix):
			keys_to_remove.append(k)
	for k in keys_to_remove:
		_registry.erase(k)

func clear_all() -> void:
	_registry.clear()

func serialize() -> Dictionary:
	return _registry.duplicate()

func deserialize(data: Dictionary) -> void:
	_registry.clear()
	for k in data.keys():
		_registry[String(k)] = int(data[k])
