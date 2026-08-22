class_name PropPalette
extends Resource

## Paleta de Props para una habitación o contexto temático.
## Contiene una colección de PropPaletteEntry y permite selección determinista ponderada
## según el modo de colocación (FLOOR, WALL, CENTER, CORNER).

const _PropPaletteEntryScript = preload("res://src/presentation/props/prop_palette_entry.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")

@export var palette_id: StringName = &""
@export var entries: Array[_PropPaletteEntryScript] = []
@export var density: float = 0.20          ## Probabilidad/densidad de ocupación de anchors
@export var max_props_per_room: int = 5    ## Límite máximo de props por sala

func _init(p_id: StringName = &"", p_entries: Array[_PropPaletteEntryScript] = []) -> void:
	palette_id = p_id
	entries = p_entries

func get_entries_for_placement(placement: int) -> Array[_PropPaletteEntryScript]:
	var result: Array[_PropPaletteEntryScript] = []
	for entry in entries:
		if entry != null and entry.style != null and entry.style.placement_mode == placement and entry.weight > 0.0:
			result.append(entry)
	return result

## Selección determinista ponderada utilizando una semilla sin invocar randomize().
func select_weighted(placement: int, seed_val: int) -> _PropStyleScript:
	var valid_entries = get_entries_for_placement(placement)
	if valid_entries.is_empty():
		return null
	if valid_entries.size() == 1:
		return valid_entries[0].style if valid_entries[0].weight > 0.0 else null

	var total_weight: float = 0.0
	for entry in valid_entries:
		total_weight += maxf(0.0, entry.weight)

	if total_weight <= 0.0:
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var roll: float = rng.randf_range(0.0, total_weight)

	var cumulative: float = 0.0
	for entry in valid_entries:
		cumulative += maxf(0.0, entry.weight)
		if roll <= cumulative:
			return entry.style

	return valid_entries[valid_entries.size() - 1].style
