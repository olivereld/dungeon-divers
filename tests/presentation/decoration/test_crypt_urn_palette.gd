extends SceneTree

## Test suite para validar la integración de Urnas en las paletas de Criptas / Catacumbas / Tumbas / Templos.

const DecorationPaletteResolver = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const RoomPurpose = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const PropStyle = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementMode = preload("res://src/presentation/props/prop_placement_mode.gd")
const PropAssetProvider = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_urn_palette ---")
	print("==================================================================")

	var resolver := DecorationPaletteResolver.new()
	var provider := PropAssetProvider.new()

	# 1. Validar Catacumbas / Criptas (Mausoleum Archetype)
	var crypt_palette = resolver.resolve_prop_palette(1, RoomPurpose.Type.CATACOMB)
	assert(crypt_palette != null, "FAIL: Crypt palette is null")
	var has_floor_urn: bool = false
	var has_corner_urn: bool = false

	for entry in crypt_palette.entries:
		var style: PropStyle = entry.style
		if style.prop_type == PropStyle.Type.URN:
			if style.placement_mode == PropPlacementMode.Mode.FLOOR:
				has_floor_urn = true
			elif style.placement_mode == PropPlacementMode.Mode.CORNER:
				has_corner_urn = true

	assert(has_floor_urn == true, "FAIL: Catacomb palette must include floor urns")
	assert(has_corner_urn == true, "FAIL: Catacomb palette must include corner urns")
	print("  [OK] Catacomb & Crypt palette includes FLOOR and CORNER urns.")

	# 2. Validar Tumbas y Tumbas Reales
	var tomb_palette = resolver.resolve_prop_palette(1, RoomPurpose.Type.TOMB)
	assert(tomb_palette != null, "FAIL: Tomb palette is null")
	var tomb_has_urn = false
	for entry in tomb_palette.entries:
		if entry.style.prop_type == PropStyle.Type.URN:
			tomb_has_urn = true
			break
	assert(tomb_has_urn, "FAIL: Tomb palette must contain urns")
	print("  [OK] Tomb palette includes urns.")

	# 3. Validar Materialización de todos los IDs de Urna registrados en PropAssetProvider
	var urn_ids: Array[StringName] = [
		&"crypt_urn_banded_floor",
		&"crypt_urn_relic_floor",
		&"crypt_urn_canopic_surface",
		&"temple_urn_pedestal_floor",
		&"temple_urn_canopic_surface"
	]

	for u_id in urn_ids:
		var node = provider.materialize_by_id(u_id)
		assert(node != null, "FAIL: Materialization failed for prop_id: %s" % str(u_id))
		assert(node.get_child_count() > 0, "FAIL: Node has no children for: %s" % str(u_id))
		node.free()

	print("  [OK] PropAssetProvider successfully materialized all 5 Urn asset variants.")

	print("==================================================================")
	print("[PASS] test_crypt_urn_palette completado con 100% éxito!")
	print("==================================================================")
	quit(0)
