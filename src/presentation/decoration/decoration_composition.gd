class_name DecorationComposition
extends RefCounted

## Resultado inmutable de la composición espacial integral de una habitación.
## Agrupa directivas de fixtures, directivas de props, mapas de ocupación y reservas,
## así como métricas de rechazos para depuración arquitectónica.
## 100% puro: no crea nodos Node3D ni modifica CellGrid.

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")

var room_id: int = -1
var fixture_directives: Array[_FixtureDirectiveScript] = []
var prop_directives: Array[_PropDirectiveScript] = []

var occupied_cells: Dictionary = {}   ## Vector2i -> prop_id / directive
var reserved_cells: Dictionary = {}   ## Vector2i -> StringName (motivo de reserva)
var rejected_placements: int = 0     ## Contador de intentos descartados por colisión o despejes

func _init(p_room_id: int = -1) -> void:
	room_id = p_room_id

func add_prop_directive(dir: _PropDirectiveScript) -> void:
	if dir == null:
		return
	prop_directives.append(dir)
	for cell in dir.occupied_cells:
		occupied_cells[cell] = dir.prop_id

func add_fixture_directive(dir: _FixtureDirectiveScript) -> void:
	if dir != null:
		fixture_directives.append(dir)

func reserve_cell(cell: Vector2i, reason: StringName) -> void:
	reserved_cells[cell] = reason

func get_focal_props() -> Array[_PropDirectiveScript]:
	return _filter_props_by_role(_DecorationRoleScript.Role.FOCAL)

func get_support_props() -> Array[_PropDirectiveScript]:
	return _filter_props_by_role(_DecorationRoleScript.Role.SUPPORT)

func get_ambient_props() -> Array[_PropDirectiveScript]:
	return _filter_props_by_role(_DecorationRoleScript.Role.AMBIENT)

func get_functional_props() -> Array[_PropDirectiveScript]:
	return _filter_props_by_role(_DecorationRoleScript.Role.FUNCTIONAL)

func _filter_props_by_role(role: int) -> Array[_PropDirectiveScript]:
	var result: Array[_PropDirectiveScript] = []
	for p in prop_directives:
		if p != null and p.style != null and p.style.role == role:
			result.append(p)
	return result

func get_total_prop_count() -> int:
	return prop_directives.size()

func get_total_fixture_count() -> int:
	return fixture_directives.size()

func get_occupied_cell_count() -> int:
	return occupied_cells.size()

func get_reserved_cell_count() -> int:
	return reserved_cells.size()
