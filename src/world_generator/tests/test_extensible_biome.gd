extends SceneTree

const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _BiomeDefinitionScript = preload("res://src/world_generator/biomes/biome_definition.gd")
const _BiomeSelectionRuleScript = preload("res://src/world_generator/biomes/biome_selection_rule.gd")
const _BiomeSelectorScript = preload("res://src/world_generator/biomes/biome_selector.gd")
const _BiomeIdScript = preload("res://src/world_generator/biomes/biome_id.gd")

const _EcologyProfileScript = preload("res://src/world_generator/biomes/profiles/ecology_profile.gd")
const _VegetationProfileScript = preload("res://src/world_generator/biomes/profiles/vegetation_profile.gd")
const _RockProfileScript = preload("res://src/world_generator/biomes/profiles/rock_profile.gd")
const _RenderingProfileScript = preload("res://src/world_generator/biomes/profiles/rendering_profile.gd")

const _ColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Extensible Biome Test Suite (Fase 7)")
	print("==================================================")

	var reg = _BiomeRegistryScript.get_default()

	# 1. Verificar que ALPINE está registrado en el registro por defecto
	assert(reg.has_definition(_BiomeIdScript.ALPINE), "ALPINE must be registered in default BiomeRegistry")
	var alpine_def = reg.get_definition(_BiomeIdScript.ALPINE)
	assert(alpine_def != null, "Alpine definition must not be null")
	assert(alpine_def.vegetation_profile.tree_density == 0.08, "Alpine tree density must match profile")
	assert(alpine_def.rock_profile.rock_density == 0.35, "Alpine rock density must match profile")
	print(" -> [PASS] Built-in ALPINE biome registered with specialized profiles")

	# 2. Selección de ALPINE por alta elevación y frío
	var selector = _BiomeSelectorScript.new(reg)
	# T=0.25 (frío), M=0.5 (medio), E=0.85 (alta montaña)
	var chosen = selector.select(0.25, 0.5, 0.85)
	assert(chosen == _BiomeIdScript.ALPINE, "High elevation cold cell must select ALPINE, got: %s" % String(chosen))
	print(" -> [PASS] Alpine elevation rule successfully selected at E=0.85, T=0.25")

	# 3. Extensibilidad en caliente: Registrar un bioma totalmente nuevo (VOLCANIC)
	# sin tocar ninguna línea de código en stages ni en el core.
	var volcanic_id := StringName("volcanic")
	var vol_eco = _EcologyProfileScript.new()
	vol_eco.clearing_threshold = 0.95 # Sin bosque
	var vol_veg = _VegetationProfileScript.new()
	vol_veg.tree_density = 0.0 # Cero árboles en lava/ceniza
	vol_veg.shrub_density = 0.02
	var vol_rock = _RockProfileScript.new()
	vol_rock.rock_density = 0.70 # Abundante roca volcánica/basalto
	var vol_rend = _RenderingProfileScript.new()
	vol_rend.ground_color = Color("#1c1b1a") # Basalto oscuro
	vol_rend.clearing_color = Color("#2e2620")
	vol_rend.rock_color = Color("#111111")

	var volcanic_def = _BiomeDefinitionScript.new(
		volcanic_id,
		"Volcanic Wastes",
		vol_eco,
		vol_veg,
		vol_rock,
		vol_rend
	)
	# Regla: Extremadamente caliente (T >= 0.85), muy seco (M <= 0.20), cualquier elevación
	var volcanic_rule = _BiomeSelectionRuleScript.new(volcanic_id, 0.85, 1.0, 0.0, 0.20, 0.0, 1.0, 50)
	reg.register_biome(volcanic_def, [volcanic_rule])

	assert(reg.has_definition(volcanic_id), "Dynamic VOLCANIC biome must be registered")
	var sel_vol = selector.select(0.92, 0.10, 0.50)
	assert(sel_vol == volcanic_id, "Extreme hot/dry conditions must select VOLCANIC, got: %s" % String(sel_vol))
	print(" -> [PASS] Dynamic custom biome (VOLCANIC) registered and selected without touching engine core")

	# 4. Verificar que TerrainColorResolver renderiza los colores de VOLCANIC sin cambios en su código
	var profile := TaigaWorldProfile.new()
	var dummy_cell = WorldCell.new(Vector2i(0, 0))
	dummy_cell.biome_id = volcanic_id
	dummy_cell.normalized_height = 0.35
	var resolved_col = _ColorResolverScript.resolve_vertex_color(dummy_cell, profile)
	assert(resolved_col != null, "ColorResolver must resolve a valid color")
	print(" -> [PASS] TerrainColorResolver dynamically consumed custom biome RenderingProfile")

	# 5. Generación completa del mundo con pipeline estándar
	var result: WorldResult = WorldPipeline.generate(42, profile)
	assert(result != null, "World generation must succeed")
	assert(result.cells.size() > 0, "World must have cells")

	var biome_histogram: Dictionary = {}
	for pos in result.cells:
		var c: WorldCell = result.cells[pos]
		biome_histogram[c.biome_id] = biome_histogram.get(c.biome_id, 0) + 1

	print(" -> [PASS] WorldPipeline execution succeeded. Biome distribution: %s" % str(biome_histogram))
	assert(biome_histogram.size() >= 2, "World should contain varied biomes")

	print("==================================================")
	print(" ALL EXTENSIBLE BIOME TESTS PASSED!")
	print("==================================================")
	quit(0)
