class_name FixturePalette
extends Resource

## Paleta arquitectónica de fixtures para una habitación o arquetipo.
## Almacena la colección de estilos disponibles y parámetros de densidad de colocación.

const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

@export var id: StringName = &"default_fixture_palette"
@export var fixtures: Array[_FixtureStyleScript] = []
@export var wall_fixture_spacing: int = 3 ## Distancia mínima en celdas entre fixtures de pared
@export var wall_fixture_probability: float = 0.6 ## Probabilidad de spawn en punto válido
@export var floor_fixture_spacing: int = 4 ## Distancia mínima en celdas para fixtures de suelo
@export var floor_fixture_probability: float = 0.35 ## Probabilidad de spawn en suelo

func _init(
	p_id: StringName = &"default_fixture_palette",
	p_fixtures: Array = [],
	p_wall_spacing: int = 3,
	p_wall_prob: float = 0.6,
	p_floor_spacing: int = 4,
	p_floor_prob: float = 0.35
) -> void:
	id = p_id
	fixtures.clear()
	for f in p_fixtures:
		if f != null:
			fixtures.append(f)
	wall_fixture_spacing = p_wall_spacing
	wall_fixture_probability = p_wall_prob
	floor_fixture_spacing = p_floor_spacing
	floor_fixture_probability = p_floor_prob

## Retorna todos los estilos de fixtures compatibles con un modo de placement específico.
func get_fixtures_by_placement(mode: int) -> Array[_FixtureStyleScript]:
	var result: Array[_FixtureStyleScript] = []
	for f in fixtures:
		if f != null and f.placement_mode == mode:
			result.append(f)
	return result

## Helper para obtener el primer fixture de pared disponible
func get_primary_wall_fixture() -> _FixtureStyleScript:
	var wall_fixtures = get_fixtures_by_placement(_FixturePlacementModeScript.Mode.WALL)
	return wall_fixtures[0] if not wall_fixtures.is_empty() else null
