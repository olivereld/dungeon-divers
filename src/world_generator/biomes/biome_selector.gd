class_name BiomeSelector
extends RefCounted

## Selector puro y determinista de biomas.
## Aplica reglas de datos (BiomeSelectionRule) ordenadas por prioridad
## sobre los campos normalizados de temperatura, humedad y elevación [0.0, 1.0].

const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _BiomeIdScript = preload("res://src/world_generator/biomes/biome_id.gd")

var registry: RefCounted

func _init(p_registry: RefCounted = null) -> void:
	if p_registry != null:
		registry = p_registry
	else:
		registry = _BiomeRegistryScript.get_default()

func select(temperature: float, moisture: float, elevation: float) -> StringName:
	var rules: Array = registry.get_selection_rules()
	for rule in rules:
		if rule.matches(temperature, moisture, elevation):
			return rule.biome_id
	return _BiomeIdScript.TAIGA # Fallback de seguridad
