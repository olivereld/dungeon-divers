class_name DoorPresentationContext
extends RefCounted

## Contexto inmutable de presentación arquitectónica para puertas y portales.
## Relaciona un DungeonDoorManifest con los perfiles arquitectónicos de las salas conectadas
## para determinar el estilo de marco y hoja (Stone Arch, Heavy Iron, Wood Leaf, Mine Frame).
## 100% puro: no contiene nodos 3D.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _DungeonDoorManifestScript = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")

var door_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var adjacent_cell: Vector2i = Vector2i.ZERO
var room_a_id: int = -1
var room_b_id: int = -1
var profile_a: _ArchitecturalPresentationProfileScript = null
var profile_b: _ArchitecturalPresentationProfileScript = null
var resolved_style: _ArchitecturalStyleScript.DoorStyle = _ArchitecturalStyleScript.DoorStyle.STONE_ARCH

func _init(
	p_door_id: String = "",
	p_cell: Vector2i = Vector2i.ZERO,
	p_adj_cell: Vector2i = Vector2i.ZERO,
	p_a_id: int = -1,
	p_b_id: int = -1,
	p_prof_a: _ArchitecturalPresentationProfileScript = null,
	p_prof_b: _ArchitecturalPresentationProfileScript = null,
	p_style: _ArchitecturalStyleScript.DoorStyle = _ArchitecturalStyleScript.DoorStyle.STONE_ARCH
) -> void:
	door_id = p_door_id
	cell = p_cell
	adjacent_cell = p_adj_cell
	room_a_id = p_a_id
	room_b_id = p_b_id
	profile_a = p_prof_a
	profile_b = p_prof_b
	resolved_style = p_style

static func create_from_manifest(
	manifest: _DungeonDoorManifestScript,
	partition
) -> RefCounted:
	if manifest == null:
		return null

	var r_a_id: int = -1
	var r_b_id: int = -1

	if partition != null:
		r_a_id = partition.get_room_id_at(manifest.cell)
		r_b_id = partition.get_room_id_at(manifest.adjacent_cell)

		# Si una celda no tiene sala directa, buscar en vecinas ortogonales
		if r_a_id == -1:
			for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var candidate: int = partition.get_room_id_at(manifest.cell + offset)
				if candidate != -1:
					r_a_id = candidate
					break
		if r_b_id == -1:
			for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var candidate: int = partition.get_room_id_at(manifest.adjacent_cell + offset)
				if candidate != -1 and candidate != r_a_id:
					r_b_id = candidate
					break

	var prof_a: _ArchitecturalPresentationProfileScript = null
	var prof_b: _ArchitecturalPresentationProfileScript = null

	if partition != null:
		if r_a_id != -1:
			var geom_a = partition.get_room_geometry(r_a_id)
			if geom_a != null:
				prof_a = geom_a.profile
		if r_b_id != -1:
			var geom_b = partition.get_room_geometry(r_b_id)
			if geom_b != null:
				prof_b = geom_b.profile

	# Resolver estilo prioritario entre ambas salas
	var style: _ArchitecturalStyleScript.DoorStyle = _ArchitecturalStyleScript.DoorStyle.STONE_ARCH
	if prof_a != null and prof_a.door_style != _ArchitecturalStyleScript.DoorStyle.STONE_ARCH:
		style = prof_a.door_style
	elif prof_b != null and prof_b.door_style != _ArchitecturalStyleScript.DoorStyle.STONE_ARCH:
		style = prof_b.door_style
	elif prof_a != null:
		style = prof_a.door_style

	var cls = load("res://src/presentation/architecture/door_presentation_context.gd") as GDScript
	return cls.new(
		manifest.door_id, manifest.cell, manifest.adjacent_cell, r_a_id, r_b_id, prof_a, prof_b, style
	)
