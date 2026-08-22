class_name StairsPresentationContext
extends RefCounted

## Contexto inmutable de presentación arquitectónica para escaleras de ascenso y descenso.
## Vincula el punto de conexión vertical (StairData) con el perfil arquitectónico de la sala
## anfitriona para determinar el estilo de peldaños y barandillas (Stone vs Wood).
## 100% puro: no contiene nodos 3D.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")

var stair_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var room_id: int = -1
var profile: _ArchitecturalPresentationProfileScript = null
var is_downward: bool = false
var resolved_style: _ArchitecturalStyleScript.StairsStyle = _ArchitecturalStyleScript.StairsStyle.STONE

func _init(
	p_stair_id: String = "",
	p_cell: Vector2i = Vector2i.ZERO,
	p_room_id: int = -1,
	p_profile: _ArchitecturalPresentationProfileScript = null,
	p_is_downward: bool = false,
	p_style: _ArchitecturalStyleScript.StairsStyle = _ArchitecturalStyleScript.StairsStyle.STONE
) -> void:
	stair_id = p_stair_id
	cell = p_cell
	room_id = p_room_id
	profile = p_profile
	is_downward = p_is_downward
	resolved_style = p_style

static func create_from_stair(
	stair: _StairDataScript,
	partition
) -> RefCounted:
	if stair == null:
		return null

	var r_id: int = -1
	var prof: _ArchitecturalPresentationProfileScript = null
	var style: _ArchitecturalStyleScript.StairsStyle = _ArchitecturalStyleScript.StairsStyle.STONE

	if partition != null:
		r_id = partition.get_room_id_at(stair.cell)
		if r_id != -1:
			var geom = partition.get_room_geometry(r_id)
			if geom != null and geom.profile != null:
				prof = geom.profile
				style = prof.stairs_style

	var cls = load("res://src/presentation/architecture/stairs_presentation_context.gd") as GDScript
	return cls.new(
		stair.stair_id, stair.cell, r_id, prof, stair.is_downward, style
	)
