class_name FoliageChunkData
extends RefCounted

## Estructura ligera de datos que almacena instancias de foliage generadas en un chunk.
## Producida en worker threads, consumida en Main Thread por FoliageRenderer para MultiMeshInstance3D.

var chunk_coord: Vector2i = Vector2i.ZERO

## Diccionario: species_id (StringName) -> Array[Transform3D]
var instances_by_species: Dictionary = {}

## Diccionario: species_id (StringName) -> PackedColorArray
var colors_by_species: Dictionary = {}

func _init(p_coord: Vector2i = Vector2i.ZERO) -> void:
	chunk_coord = p_coord

func add_instance(species_id: StringName, transform: Transform3D, color: Color = Color.WHITE) -> void:
	if not instances_by_species.has(species_id):
		instances_by_species[species_id] = []
		colors_by_species[species_id] = PackedColorArray()

	instances_by_species[species_id].append(transform)
	colors_by_species[species_id].append(color)

func get_instances_for_species(species_id: StringName) -> Array:
	return instances_by_species.get(species_id, [])

func get_colors_for_species(species_id: StringName) -> PackedColorArray:
	return colors_by_species.get(species_id, PackedColorArray())

func get_total_instance_count() -> int:
	var total := 0
	for sp_id in instances_by_species:
		total += instances_by_species[sp_id].size()
	return total

func clear() -> void:
	instances_by_species.clear()
	colors_by_species.clear()
