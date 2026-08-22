class_name DecorationPalette
extends Resource

## Contenedor arquitectónico de paletas decorativas para una habitación o zona.
## Agrupa la paleta de fixtures arquitectónicos (pared, suelo, superficie, colgante)
## y deja preparado el slot para la futura PropPalette (muebles, cofres, mesas, altares).

const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _PropPaletteScript = preload("res://src/presentation/props/prop_palette.gd")

@export var id: StringName = &"default_decoration_palette"
@export var fixtures: _FixturePaletteScript = null
@export var props: _PropPaletteScript = null

func _init(
	p_id: StringName = &"default_decoration_palette",
	p_fixtures: _FixturePaletteScript = null,
	p_props: _PropPaletteScript = null
) -> void:
	id = p_id
	fixtures = p_fixtures
	props = p_props

