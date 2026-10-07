class_name BiomeStage
extends WorldStage

## Etapa de Selección de Bioma (BiomeStage):
## Asigna cell.biome_id evaluando de forma determinista (temperatura, humedad, elevación_normalizada)
## mediante BiomeSelector, sin contener ninguna lógica específica de ningún bioma en particular.

const _BiomeSelectorScript = preload("res://src/world_generator/biomes/biome_selector.gd")

var selector: RefCounted

func _init(p_selector: RefCounted = null) -> void:
	selector = p_selector if p_selector != null else _BiomeSelectorScript.new()

func execute(context: WorldGenerationContext) -> void:
	run(context, selector)

static func run(context: WorldGenerationContext, p_selector: RefCounted = null) -> void:
	if context == null or context.result == null:
		return

	var sel = p_selector if p_selector != null else _BiomeSelectorScript.new()

	for pos in context.result.cells.keys():
		var cell: WorldCell = context.result.cells[pos]
		if cell == null:
			continue
		cell.biome_id = sel.select(cell.temperature, cell.moisture, cell.elevation_normalized)

	context.result.set_meta(&"biome_stage_executed", true)
