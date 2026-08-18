class_name DoorManifestFactory
extends RefCounted

## Fábrica y extractor canónico de manifiestos geométricos de puertas y vanos (Fase 9).
## Transforma los pares de puertas del Core (DoorPair / DoorPlacement) en
## DungeonDoorManifest y WallOpeningManifest desacoplados para Presentation.

const _DungeonDoorManifestScript = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

## Extrae los manifiestos geométricos de puerta de una lista de DoorPair.
static func create_door_manifests(door_pairs: Array) -> Array[DungeonDoorManifest]:
	var manifests: Array[DungeonDoorManifest] = []
	if door_pairs == null:
		return manifests

	var seen_door_ids: Dictionary = {}

	for dp in door_pairs:
		if dp == null:
			continue

		var conn_str: String = str(dp.connection_id)

		# Procesar Door A
		if dp.door_a != null:
			var door_a_id: String = "conn_%s_room_%s_a" % [conn_str, str(dp.door_a.room_id)]
			if not seen_door_ids.has(door_a_id):
				seen_door_ids[door_a_id] = true
				var m_a := _DungeonDoorManifestScript.new(
					conn_str,
					door_a_id,
					dp.door_a.position,
					dp.door_a.corridor_cell,
					dp.door_a.side,
					dp.door_a.door_type
				)
				manifests.append(m_a)

		# Procesar Door B
		if dp.door_b != null:
			var door_b_id: String = "conn_%s_room_%s_b" % [conn_str, str(dp.door_b.room_id)]
			if not seen_door_ids.has(door_b_id):
				seen_door_ids[door_b_id] = true
				var m_b := _DungeonDoorManifestScript.new(
					conn_str,
					door_b_id,
					dp.door_b.position,
					dp.door_b.corridor_cell,
					dp.door_b.side,
					dp.door_b.door_type
				)
				manifests.append(m_b)

	return manifests

## Genera el WallOpeningManifest registrando los vanos perimetrales orientados.
static func create_wall_opening_manifest(door_pairs: Array) -> WallOpeningManifest:
	var opening_manifest := _WallOpeningManifestScript.new()
	if door_pairs == null:
		return opening_manifest

	for dp in door_pairs:
		if dp == null:
			continue

		var conn_str: String = str(dp.connection_id)

		if dp.door_a != null:
			# Vano desde la celda de la puerta hacia el exterior
			opening_manifest.add_opening(dp.door_a.position, dp.door_a.side, conn_str)
			# Vano opuesto desde la celda vecina hacia la puerta
			var opp_side_a: int = _get_opposite_side(dp.door_a.side)
			opening_manifest.add_opening(dp.door_a.corridor_cell, opp_side_a, conn_str)

		if dp.door_b != null:
			opening_manifest.add_opening(dp.door_b.position, dp.door_b.side, conn_str)
			var opp_side_b: int = _get_opposite_side(dp.door_b.side)
			opening_manifest.add_opening(dp.door_b.corridor_cell, opp_side_b, conn_str)

	return opening_manifest

static func _get_opposite_side(side: int) -> int:
	match side:
		_RoomEntranceScript.NORTH: return _RoomEntranceScript.SOUTH
		_RoomEntranceScript.SOUTH: return _RoomEntranceScript.NORTH
		_RoomEntranceScript.WEST:  return _RoomEntranceScript.EAST
		_RoomEntranceScript.EAST:  return _RoomEntranceScript.WEST
	return 0
