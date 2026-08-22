class_name FixturePalette
extends Resource

## Paleta arquitectónica de fixtures para una habitación o arquetipo.
## Almacena una lista de FixturePaletteEntry con selección ponderada (weighted selection) determinista.

const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

@export var id: StringName = &"default_fixture_palette"
@export var entries: Array[_FixturePaletteEntryScript] = []
@export var wall_fixture_spacing: int = 3
@export var wall_fixture_probability: float = 0.6
@export var floor_fixture_spacing: int = 4
@export var floor_fixture_probability: float = 0.35

# Compatibilidad con lista simple de estilos
var fixtures: Array[_FixtureStyleScript]:
	get:
		var list: Array[_FixtureStyleScript] = []
		for e in entries:
			if e != null and e.style != null:
				list.append(e.style)
		return list

func _init(
	p_id: StringName = &"default_fixture_palette",
	p_entries_or_styles: Array = [],
	p_wall_spacing: int = 3,
	p_wall_prob: float = 0.6,
	p_floor_spacing: int = 4,
	p_floor_prob: float = 0.35
) -> void:
	id = p_id
	entries.clear()
	for item in p_entries_or_styles:
		if item is _FixturePaletteEntryScript:
			entries.append(item)
		elif item is _FixtureStyleScript:
			entries.append(_FixturePaletteEntryScript.new(item, 1.0))
	wall_fixture_spacing = p_wall_spacing
	wall_fixture_probability = p_wall_prob
	floor_fixture_spacing = p_floor_spacing
	floor_fixture_probability = p_floor_prob

## Retorna todas las entradas compatibles con un modo de placement específico con peso > 0.
func get_entries_for_placement(mode: int) -> Array[_FixturePaletteEntryScript]:
	var result: Array[_FixturePaletteEntryScript] = []
	for e in entries:
		if e != null and e.style != null and e.style.placement_mode == mode and e.weight > 0.0:
			result.append(e)
	return result

## Compatibilidad: retorna todos los estilos compatibles con un modo de placement.
func get_fixtures_by_placement(mode: int) -> Array[_FixtureStyleScript]:
	var result: Array[_FixtureStyleScript] = []
	for e in get_entries_for_placement(mode):
		result.append(e.style)
	return result

## Realiza una selección determinista ponderada por peso (weighted selection) para un modo de colocación.
func select_weighted(mode: int, seed_val: int) -> _FixtureStyleScript:
	var valid_entries = get_entries_for_placement(mode)
	if valid_entries.is_empty():
		return null
	if valid_entries.size() == 1:
		return valid_entries[0].style if valid_entries[0].weight > 0.0 else null

	var total_weight: float = 0.0
	for e in valid_entries:
		total_weight += maxf(0.0, e.weight)

	if total_weight <= 0.0:
		return null

	var roll: float = (float(abs(seed_val) % 10000) / 10000.0) * total_weight
	var cumulative: float = 0.0
	for e in valid_entries:
		cumulative += maxf(0.0, e.weight)
		if cumulative >= roll:
			return e.style

	return valid_entries[valid_entries.size() - 1].style
