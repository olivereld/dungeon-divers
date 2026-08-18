extends SceneTree

## Test unitario para Task 5: Materialización 3D de Arcos Abiertos en Presentation (Fase Reforced).
## Valida que los portales marcados como OPEN_PASSAGE generen el arco de piedra sin crear la entidad de puerta de madera.

func _init() -> void:
	print("--- Running test_door_spawner_passage ---")
	var SpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
	var ManifestScript = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

	var spawner = SpawnerScript.new()
	var staging := Node3D.new()

	# Caso 1: Vano Abierto (OPEN_PASSAGE)
	var m_open = ManifestScript.new("1", "open_0", Vector2i(5, 5), Vector2i(5, 6), 0, DoorTypeScript.DoorType.OPEN_PASSAGE)

	# Caso 2: Puerta Cerrada (CLOSED_DOOR)
	var m_closed = ManifestScript.new("1", "closed_0", Vector2i(10, 5), Vector2i(10, 6), 0, DoorTypeScript.DoorType.CLOSED_DOOR)

	var res = spawner.spawn_doors([m_open, m_closed], staging, null, 2.0, 2, 1337)
	assert(res.spawned_doors.size() == 2, "Must process both manifests")

	var portal_open = staging.get_node_or_null("Doors/DoorPortal_open_0")
	assert(portal_open != null, "Portal node for OPEN_PASSAGE must be created")
	assert(portal_open.has_node("StoneArch"), "StoneArch must be created for OPEN_PASSAGE")
	assert(portal_open.has_node("DoorEntity") == false, "OPEN_PASSAGE must NOT instantiate DoorEntity (wooden door)")
	print("  [OK] OPEN_PASSAGE created with StoneArch and NO wooden door")

	var portal_closed = staging.get_node_or_null("Doors/DoorPortal_closed_0")
	assert(portal_closed != null, "Portal node for CLOSED_DOOR must be created")
	assert(portal_closed.has_node("DoorEntity") == true, "CLOSED_DOOR MUST instantiate DoorEntity (wooden door)")
	print("  [OK] CLOSED_DOOR created with interactive wooden door")

	staging.free()
	print("[PASS] test_door_spawner_passage completed successfully!")
	quit(0)
