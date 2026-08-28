extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _RoomProfileResolverScript = preload("res://src/dungeon_generator/profiles/room_profile_resolver.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_room_profile_resolution ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var available_archetypes = loader.list_available_archetypes()
	assert(not available_archetypes.is_empty(), "FAIL: ArchetypeCatalog must contain available archetypes")

	# Validar de forma universal para cada arquetipo descubierto en datos
	for arch_id in available_archetypes:
		var bundle = loader.load_full_archetype_bundle(str(arch_id))
		assert(bundle != null and bundle.archetype != null, "FAIL: Bundle '%s' must load properly" % str(arch_id))

		var resolver := _RoomProfileResolverScript.new(bundle)

		for purpose_key in bundle.rooms:
			var room_prof = resolver.resolve(purpose_key)
			assert(room_prof != null, "FAIL: Room profile for purpose '%s' in archetype '%s' must resolve" % [str(purpose_key), str(arch_id)])
			assert(room_prof.id != &"", "FAIL: Room profile must have a non-empty ID")
			assert(room_prof.schema_version == 1, "FAIL: Room profile '%s' must have schema_version 1" % str(room_prof.id))
			assert(room_prof.intent != null, "FAIL: Room profile '%s' must define an intent" % str(room_prof.id))
			assert(room_prof.architecture != null, "FAIL: Room profile '%s' must define architecture" % str(room_prof.id))
			assert(room_prof.composition != null, "FAIL: Room profile '%s' must define composition" % str(room_prof.id))
			assert(room_prof.lighting != null, "FAIL: Room profile '%s' must define lighting" % str(room_prof.id))
			assert(resolver.has_profile_for(purpose_key), "FAIL: has_profile_for('%s') must return true" % str(purpose_key))

		# Validar fallback en propósito desconocido
		var fallback_room = resolver.resolve(&"unknown_nonexistent_purpose_xyz")
		assert(fallback_room != null, "FAIL: Unknown purpose must resolve to a valid fallback room profile without crashing")

		print("  [OK] All room profiles resolved and validated for archetype: %s" % str(arch_id))

	print("[PASS] test_room_profile_resolution completed successfully!")
	quit(0)
