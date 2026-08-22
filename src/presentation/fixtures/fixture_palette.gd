class_name FixturePalette
extends Resource

## Paleta arquitectónica de fixtures para una habitación o arquetipo.
## Define qué estilos de fixtures se usan en paredes, esquinas o centros, y su densidad de colocación.

const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")

@export var id: StringName = &"default_fixture_palette"
@export var wall_fixture: _FixtureStyleScript = null
@export var corner_fixture: _FixtureStyleScript = null
@export var center_fixture: _FixtureStyleScript = null
@export var wall_fixture_spacing: int = 3 ## Distancia mínima en celdas entre fixtures de pared
@export var wall_fixture_probability: float = 0.6 ## Probabilidad de spawn en punto válido

func _init(
	p_id: StringName = &"default_fixture_palette",
	p_wall_fixture: _FixtureStyleScript = null,
	p_corner_fixture: _FixtureStyleScript = null,
	p_center_fixture: _FixtureStyleScript = null,
	p_spacing: int = 3,
	p_prob: float = 0.6
) -> void:
	id = p_id
	wall_fixture = p_wall_fixture
	corner_fixture = p_corner_fixture
	center_fixture = p_center_fixture
	wall_fixture_spacing = p_spacing
	wall_fixture_probability = p_prob
