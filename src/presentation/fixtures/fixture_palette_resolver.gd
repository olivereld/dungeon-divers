class_name FixturePaletteResolver
extends RefCounted

## Resolvedor puro de paletas de fixtures a partir de perfiles arquitectónicos.
## 100% puro: no genera nodos 3D ni mallas.

const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

## Devuelve una FixturePalette configurada según el perfil arquitectónico provisto.
func resolve_palette(profile: _ArchitecturalPresentationProfileScript) -> _FixturePaletteScript:
	if profile == null:
		return _create_default_palette()

	var wall_torch: _FixtureStyleScript = null
	var palette_id: StringName = &"generic_palette"
	var spacing: int = 3
	var prob: float = 0.65

	match profile.wall_style:
		_ArchitecturalStyleScript.WallStyle.DARK_STONE:
			# Criptas / Mausoleos: Antorcha gótica estilizada con llama ambar
			palette_id = &"gothic_crypt_palette"
			wall_torch = _FixtureStyleScript.new(
				&"gothic_crypt_torch",
				_FixtureStyleScript.Type.TORCH,
				1.0,
				Vector3(0.0, 1.2, 0.0),
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.62, 0.25, 1.0), # Ambar cálido
				1.4,
				6.5
			)
			spacing = 3
			prob = 0.70

		_ArchitecturalStyleScript.WallStyle.TEMPLE_STONE:
			# Templos / Santuarios: Antorcha ceremonial con llama dorada brillante
			palette_id = &"ceremonial_temple_palette"
			wall_torch = _FixtureStyleScript.new(
				&"ceremonial_temple_torch",
				_FixtureStyleScript.Type.TORCH,
				1.05,
				Vector3(0.0, 1.3, 0.0),
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.78, 0.35, 1.0), # Dorado radiante
				1.6,
				7.5
			)
			spacing = 4
			prob = 0.60

		_ArchitecturalStyleScript.WallStyle.FORTRESS_STONE:
			# Fortalezas: Antorcha militar de hierro forjado
			palette_id = &"fortress_iron_palette"
			wall_torch = _FixtureStyleScript.new(
				&"fortress_iron_torch",
				_FixtureStyleScript.Type.TORCH,
				1.0,
				Vector3(0.0, 1.2, 0.0),
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.55, 0.20, 1.0), # Fuego intenso
				1.3,
				6.0
			)
			spacing = 3
			prob = 0.75

		_ArchitecturalStyleScript.WallStyle.MINE_ROCK:
			# Minas: Antorcha utilitaria / soporte rústico
			palette_id = &"mine_shaft_palette"
			wall_torch = _FixtureStyleScript.new(
				&"mine_shaft_torch",
				_FixtureStyleScript.Type.TORCH,
				0.95,
				Vector3(0.0, 1.1, 0.0),
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.50, 0.18, 1.0),
				1.2,
				5.5
			)
			spacing = 3
			prob = 0.50

		_:
			return _create_default_palette()

	return _FixturePaletteScript.new(palette_id, wall_torch, null, null, spacing, prob)

func _create_default_palette() -> _FixturePaletteScript:
	var default_torch = _FixtureStyleScript.new(
		&"standard_wall_torch",
		_FixtureStyleScript.Type.TORCH,
		1.0,
		Vector3(0.0, 1.2, 0.0),
		_FixtureCollisionModeScript.Mode.NONE,
		true,
		Color(1.0, 0.65, 0.28, 1.0),
		1.2,
		6.0
	)
	return _FixturePaletteScript.new(&"default_palette", default_torch, null, null, 3, 0.6)
