class_name BiomeRegistry
extends RefCounted

## Registro centralizado de BiomeDefinition y BiomeSelectionRule.
## Diseñado para acceso de solo lectura desde hilos de trabajo (workers).

const _BiomeDefinitionScript = preload("res://src/world_generator/biomes/biome_definition.gd")
const _BiomeSelectionRuleScript = preload("res://src/world_generator/biomes/biome_selection_rule.gd")
const _BiomeIdScript = preload("res://src/world_generator/biomes/biome_id.gd")
const _EcologyProfileScript = preload("res://src/world_generator/biomes/profiles/ecology_profile.gd")
const _VegetationProfileScript = preload("res://src/world_generator/biomes/profiles/vegetation_profile.gd")
const _RockProfileScript = preload("res://src/world_generator/biomes/profiles/rock_profile.gd")
const _RenderingProfileScript = preload("res://src/world_generator/biomes/profiles/rendering_profile.gd")
const _FoliageProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")

static var _default_instance = null

var _definitions: Dictionary = {}
var _rules: Array = []

static func get_default() -> RefCounted:
	if _default_instance == null:
		_default_instance = create_default_registry()
	return _default_instance

static func create_default_registry() -> RefCounted:
	var reg = (load("res://src/world_generator/biomes/biome_registry.gd") as GDScript).new()

	# 1. TAIGA (Boreal / Coníferas y turberas)
	var taiga_def = _BiomeDefinitionScript.new(
		_BiomeIdScript.TAIGA,
		"Taiga",
		_create_taiga_ecology(),
		_create_taiga_vegetation(),
		_create_taiga_rocks(),
		_create_taiga_rendering(),
		_create_taiga_foliage()
	)
	var taiga_rule = _BiomeSelectionRuleScript.new(_BiomeIdScript.TAIGA, 0.0, 0.40, 0.40, 1.0, 0.0, 1.0, 10)
	reg.register_biome(taiga_def, [taiga_rule])

	# 2. TUNDRA (Frío y seco / Llanuras árticas abiertas)
	var tundra_def = _BiomeDefinitionScript.new(
		_BiomeIdScript.TUNDRA,
		"Tundra",
		_create_tundra_ecology(),
		_create_tundra_vegetation(),
		_create_tundra_rocks(),
		_create_tundra_rendering(),
		_create_tundra_foliage()
	)
	var tundra_rule = _BiomeSelectionRuleScript.new(_BiomeIdScript.TUNDRA, 0.0, 0.35, 0.0, 0.40, 0.0, 1.0, 10)
	reg.register_biome(tundra_def, [tundra_rule])

	# 3. TEMPERATE_FOREST (Templado y húmedo / Bosque caducifolio equilibrado)
	var forest_def = _BiomeDefinitionScript.new(
		_BiomeIdScript.TEMPERATE_FOREST,
		"Temperate Forest",
		_create_forest_ecology(),
		_create_forest_vegetation(),
		_create_forest_rocks(),
		_create_forest_rendering(),
		_create_forest_foliage()
	)
	var forest_rule = _BiomeSelectionRuleScript.new(_BiomeIdScript.TEMPERATE_FOREST, 0.35, 0.70, 0.35, 1.0, 0.0, 1.0, 10)
	# Regla fallback universal con prioridad 0 para garantizar 100% de cobertura del espacio 3D (T/M/E)
	var fallback_rule = _BiomeSelectionRuleScript.new(_BiomeIdScript.TEMPERATE_FOREST, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0)
	reg.register_biome(forest_def, [forest_rule, fallback_rule])

	# 4. DESERT (Cálido y árido / Dunas y vegetación xerófita)
	var desert_def = _BiomeDefinitionScript.new(
		_BiomeIdScript.DESERT,
		"Desert",
		_create_desert_ecology(),
		_create_desert_vegetation(),
		_create_desert_rocks(),
		_create_desert_rendering(),
		_create_desert_foliage()
	)
	var desert_rule = _BiomeSelectionRuleScript.new(_BiomeIdScript.DESERT, 0.65, 1.0, 0.0, 0.35, 0.0, 1.0, 10)
	reg.register_biome(desert_def, [desert_rule])

	# 5. JUNGLE (Cálido y muy húmedo / Selva densa y lluviosa)
	var jungle_def = _BiomeDefinitionScript.new(
		_BiomeIdScript.JUNGLE,
		"Jungle",
		_create_jungle_ecology(),
		_create_jungle_vegetation(),
		_create_jungle_rocks(),
		_create_jungle_rendering(),
		_create_jungle_foliage()
	)
	var jungle_rule = _BiomeSelectionRuleScript.new(_BiomeIdScript.JUNGLE, 0.65, 1.0, 0.60, 1.0, 0.0, 1.0, 10)
	reg.register_biome(jungle_def, [jungle_rule])

	# 6. ALPINE (Alta montaña fría / Riscos rocosos y tundra alpina)
	var alpine_def = _BiomeDefinitionScript.new(
		_BiomeIdScript.ALPINE,
		"Alpine",
		_create_alpine_ecology(),
		_create_alpine_vegetation(),
		_create_alpine_rocks(),
		_create_alpine_rendering(),
		_create_alpine_foliage()
	)
	var alpine_rule = _BiomeSelectionRuleScript.new(_BiomeIdScript.ALPINE, 0.0, 0.45, 0.0, 1.0, 0.70, 1.0, 20)
	reg.register_biome(alpine_def, [alpine_rule])

	return reg

func register_biome(definition: RefCounted, rules: Array = []) -> void:
	assert(definition != null, "BiomeDefinition cannot be null")
	assert(not _definitions.has(definition.id), "Biome ID '%s' is already registered" % String(definition.id))
	_definitions[definition.id] = definition

	for rule in rules:
		assert(rule.biome_id == definition.id, "Rule biome_id '%s' must match definition id '%s'" % [String(rule.biome_id), String(definition.id)])
		_rules.append(rule)

	# Ordenar reglas por prioridad descendente (mayor prioridad se evalúa primero)
	_rules.sort_custom(func(a, b) -> bool:
		return a.priority > b.priority
	)

func get_definition(id: StringName):
	return _definitions.get(id, null)

func has_definition(id: StringName) -> bool:
	return _definitions.has(id)

func get_selection_rules() -> Array:
	return _rules

func get_all_definitions() -> Array:
	return _definitions.values()

# --- Fábricas de perfiles por defecto ---

static func _create_taiga_ecology() -> Resource:
	var eco = _EcologyProfileScript.new()
	eco.preferred_moisture = 0.55
	eco.forest_frequency = 0.015
	eco.clearing_threshold = 0.45
	eco.edge_width = 0.08
	return eco

static func _create_taiga_vegetation() -> Resource:
	var veg = _VegetationProfileScript.new()
	veg.tree_density = 0.35
	veg.shrub_density = 0.35
	veg.min_tree_spacing = 3.2
	veg.allowed_species = [&"conifer"]
	return veg

static func _create_taiga_rocks() -> Resource:
	var rock = _RockProfileScript.new()
	rock.rock_density = 0.15
	rock.category_weights = {"large": 0.20, "medium": 0.45, "small": 0.35}
	return rock

static func _create_taiga_rendering() -> Resource:
	var rend = _RenderingProfileScript.new()
	rend.ground_color = Color("#3f4f34")
	rend.forest_floor_color = Color("#25311e")
	rend.clearing_color = Color("#4a5338")
	rend.rock_color = Color("#464648")
	return rend

static func _create_tundra_ecology() -> Resource:
	var eco = _EcologyProfileScript.new()
	eco.preferred_moisture = 0.20
	eco.forest_frequency = 0.008
	eco.clearing_threshold = 0.85 # Prácticamente solo claros abiertos
	return eco

static func _create_tundra_vegetation() -> Resource:
	var veg = _VegetationProfileScript.new()
	veg.tree_density = 0.06 # Muy pocos árboles aislados
	veg.shrub_density = 0.20
	veg.min_tree_spacing = 4.5
	return veg

static func _create_tundra_rocks() -> Resource:
	var rock = _RockProfileScript.new()
	rock.rock_density = 0.28 # Rocoso / escarpado por heladas
	return rock

static func _create_tundra_rendering() -> Resource:
	var rend = _RenderingProfileScript.new()
	rend.ground_color = Color("#5a6250")
	rend.forest_floor_color = Color("#485040")
	rend.clearing_color = Color("#6b755e")
	rend.rock_color = Color("#555960")
	return rend

static func _create_forest_ecology() -> Resource:
	var eco = _EcologyProfileScript.new()
	eco.preferred_moisture = 0.50
	eco.forest_frequency = 0.015
	eco.clearing_threshold = 0.40
	return eco

static func _create_forest_vegetation() -> Resource:
	var veg = _VegetationProfileScript.new()
	veg.tree_density = 0.30
	veg.shrub_density = 0.30
	veg.min_tree_spacing = 3.0
	return veg

static func _create_forest_rocks() -> Resource:
	var rock = _RockProfileScript.new()
	rock.rock_density = 0.15
	return rock

static func _create_forest_rendering() -> Resource:
	var rend = _RenderingProfileScript.new()
	rend.ground_color = Color("#4b6038")
	rend.forest_floor_color = Color("#314224")
	rend.clearing_color = Color("#5a7243")
	rend.rock_color = Color("#4d4d4f")
	return rend

static func _create_desert_ecology() -> Resource:
	var eco = _EcologyProfileScript.new()
	eco.preferred_moisture = 0.10
	eco.forest_frequency = 0.005
	eco.clearing_threshold = 0.98
	return eco

static func _create_desert_vegetation() -> Resource:
	var veg = _VegetationProfileScript.new()
	veg.tree_density = 0.0
	veg.shrub_density = 0.08
	veg.min_tree_spacing = 6.0
	return veg

static func _create_desert_rocks() -> Resource:
	var rock = _RockProfileScript.new()
	rock.rock_density = 0.22
	return rock

static func _create_desert_rendering() -> Resource:
	var rend = _RenderingProfileScript.new()
	rend.ground_color = Color("#8c764e")
	rend.forest_floor_color = Color("#7c6843")
	rend.clearing_color = Color("#9b8457")
	rend.rock_color = Color("#6e5538")
	return rend

static func _create_jungle_ecology() -> Resource:
	var eco = _EcologyProfileScript.new()
	eco.preferred_moisture = 0.85
	eco.forest_frequency = 0.020
	eco.clearing_threshold = 0.20 # Selva muy cerrada
	return eco

static func _create_jungle_vegetation() -> Resource:
	var veg = _VegetationProfileScript.new()
	veg.tree_density = 0.50
	veg.shrub_density = 0.45
	veg.min_tree_spacing = 2.5
	return veg

static func _create_jungle_rocks() -> Resource:
	var rock = _RockProfileScript.new()
	rock.rock_density = 0.12
	return rock

static func _create_jungle_rendering() -> Resource:
	var rend = _RenderingProfileScript.new()
	rend.ground_color = Color("#2b5922")
	rend.forest_floor_color = Color("#1a3c14")
	rend.clearing_color = Color("#386e2d")
	rend.rock_color = Color("#3c4a38")
	return rend

static func _create_alpine_ecology() -> Resource:
	var eco = _EcologyProfileScript.new()
	eco.preferred_moisture = 0.35
	eco.forest_frequency = 0.02
	eco.clearing_threshold = 0.65
	eco.edge_width = 0.08
	eco.dense_forest_threshold = 0.90
	return eco

static func _create_alpine_vegetation() -> Resource:
	var veg = _VegetationProfileScript.new()
	veg.tree_density = 0.08
	veg.shrub_density = 0.40
	veg.min_tree_spacing = 4.0
	veg.tree_scale_min = 0.5
	veg.tree_scale_max = 0.85
	veg.allowed_species = [&"conifer"]
	return veg

static func _create_alpine_rocks() -> Resource:
	var rock = _RockProfileScript.new()
	rock.rock_density = 0.35
	rock.min_slope_degrees = 10.0
	rock.max_slope_degrees = 60.0
	rock.category_weights = {"large": 0.35, "medium": 0.45, "small": 0.20}
	return rock

static func _create_alpine_rendering() -> Resource:
	var rend = _RenderingProfileScript.new()
	rend.ground_color = Color("#5a6358")
	rend.forest_floor_color = Color("#3d453b")
	rend.clearing_color = Color("#6c786a")
	rend.rock_color = Color("#757a73")
	return rend

static func _create_taiga_foliage() -> Resource:
	var sp_med = _FoliageSpeciesScript.new(
		&"grass_medium",
		"Medium Boreal Grass",
		"res://assets/texture/foliage/grass/medium_grass_01.jpg",
		1.0,
		Vector3(0.85, 0.9, 0.85),
		Vector3(1.2, 1.3, 1.2),
		26.0,
		Color(0.18, 0.25, 0.14),
		Color(0.42, 0.58, 0.28),
		2
	)
	var sp_large = _FoliageSpeciesScript.new(
		&"grass_large",
		"Large Boreal Grass",
		"res://assets/texture/foliage/grass/large_grass_01.jpg",
		0.6,
		Vector3(0.9, 1.0, 0.9),
		Vector3(1.3, 1.4, 1.3),
		24.0,
		Color(0.15, 0.22, 0.12),
		Color(0.38, 0.52, 0.25),
		3
	)
	return _FoliageProfileScript.new(0.9, [sp_med, sp_large], 26.0, 0.8)

static func _create_forest_foliage() -> Resource:
	var sp_med = _FoliageSpeciesScript.new(
		&"grass_medium",
		"Temperate Grass",
		"res://assets/texture/foliage/grass/medium_grass_01.jpg",
		1.0,
		Vector3(0.85, 0.9, 0.85),
		Vector3(1.2, 1.3, 1.2),
		28.0,
		Color(0.18, 0.28, 0.12),
		Color(0.52, 0.75, 0.35),
		2
	)
	var sp_single = _FoliageSpeciesScript.new(
		&"grass_single",
		"Meadow Grass",
		"res://assets/texture/foliage/grass/single_grass_01.jpg",
		0.8,
		Vector3(0.8, 0.8, 0.8),
		Vector3(1.1, 1.2, 1.1),
		28.0,
		Color(0.20, 0.32, 0.14),
		Color(0.58, 0.82, 0.40),
		2
	)
	return _FoliageProfileScript.new(1.1, [sp_med, sp_single], 28.0, 0.75)

static func _create_tundra_foliage() -> Resource:
	var sp_single = _FoliageSpeciesScript.new(
		&"grass_single",
		"Tundra Lichen Grass",
		"res://assets/texture/foliage/grass/single_grass_01.jpg",
		1.0,
		Vector3(0.7, 0.6, 0.7),
		Vector3(0.95, 0.85, 0.95),
		22.0,
		Color(0.28, 0.27, 0.20),
		Color(0.55, 0.52, 0.38),
		2
	)
	return _FoliageProfileScript.new(0.4, [sp_single], 22.0, 0.7)

static func _create_desert_foliage() -> Resource:
	var sp_single = _FoliageSpeciesScript.new(
		&"grass_single",
		"Arid Scrub Grass",
		"res://assets/texture/foliage/grass/single_grass_01.jpg",
		1.0,
		Vector3(0.7, 0.7, 0.7),
		Vector3(1.0, 1.0, 1.0),
		20.0,
		Color(0.42, 0.36, 0.22),
		Color(0.78, 0.68, 0.42),
		2
	)
	return _FoliageProfileScript.new(0.15, [sp_single], 20.0, 0.5)

static func _create_jungle_foliage() -> Resource:
	var sp_large = _FoliageSpeciesScript.new(
		&"grass_large",
		"Jungle Fern Grass",
		"res://assets/texture/foliage/grass/large_grass_01.jpg",
		1.0,
		Vector3(1.0, 1.1, 1.0),
		Vector3(1.4, 1.6, 1.4),
		30.0,
		Color(0.12, 0.28, 0.10),
		Color(0.35, 0.78, 0.25),
		3
	)
	var sp_med = _FoliageSpeciesScript.new(
		&"grass_medium",
		"Rainforest Grass",
		"res://assets/texture/foliage/grass/medium_grass_01.jpg",
		1.0,
		Vector3(0.9, 0.9, 0.9),
		Vector3(1.3, 1.3, 1.3),
		30.0,
		Color(0.15, 0.32, 0.12),
		Color(0.40, 0.82, 0.30),
		2
	)
	return _FoliageProfileScript.new(1.4, [sp_large, sp_med], 30.0, 0.6)

static func _create_alpine_foliage() -> Resource:
	var sp_single = _FoliageSpeciesScript.new(
		&"grass_single",
		"Alpine Tuft Grass",
		"res://assets/texture/foliage/grass/single_grass_01.jpg",
		1.0,
		Vector3(0.7, 0.65, 0.7),
		Vector3(0.95, 0.9, 0.95),
		24.0,
		Color(0.22, 0.28, 0.22),
		Color(0.48, 0.58, 0.46),
		2
	)
	return _FoliageProfileScript.new(0.35, [sp_single], 24.0, 0.7)

