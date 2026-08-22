extends SceneTree

const RoomArchetypeLabGeneratorScript = preload("res://src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd")
const RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crypt_asset_coverage ---")
	print("==================================================================")

	var generator := RoomArchetypeLabGeneratorScript.new()
	var registry := PropAssetRegistryScript.new()
	var provider := PropAssetProviderScript.new()

	var purposes = [
		RoomPurposeScript.Type.TOMB,
		RoomPurposeScript.Type.ROYAL_TOMB,
		RoomPurposeScript.Type.SACRISTY,
		RoomPurposeScript.Type.MORTUARY,
		RoomPurposeScript.Type.CRYPT,
		RoomPurposeScript.Type.GENERIC
	]

	var total_props_checked: int = 0

	for purp in purposes:
		var req := RoomPreviewRequestScript.new(
			DungeonArchetypeScript.Type.MAUSOLEUM, purp, 13579, Vector2i(10, 8)
		)
		var res = generator.generate_preview(req)
		assert(res.success, "FAIL: Preview generation failed for %s" % RoomPurposeScript.to_name(purp))

		for prop_dir in res.composition.prop_directives:
			var p_id: StringName = prop_dir.prop_id
			assert(registry.has_definition(p_id), "FAIL: Prop ID %s missing from PropAssetRegistry!" % String(p_id))

			var node = provider.materialize_by_id(p_id)
			assert(node != null and node is Node3D, "FAIL: Failed to materialize asset for %s" % String(p_id))
			node.free()
			total_props_checked += 1

		res.room_root.free()

	print("  [OK] 100%% asset coverage verified across %d generated props in CRYPT." % total_props_checked)
	print("[PASS] test_crypt_asset_coverage completed successfully!")
	quit(0)
