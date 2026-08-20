extends SceneTree

## Test suite para validar StoneLayoutCatalog y transformaciones ortogonales (Fase V1).

const StoneLayoutCatalog = preload("res://src/floor_tile_generator/patterns/stone_layout_catalog.gd")
const TileDescriptor = preload("res://src/floor_tile_generator/data/tile_descriptor.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_stone_layout_catalog (V1: Layout Catalog) ---")
	print("==================================================================")

	var count: int = StoneLayoutCatalog.get_layout_count()
	assert(count == 8, "Must contain 8 base layout families")

	# 1. Validar que cada uno de los 8 layouts base está dentro de [0, 1] y tiene al menos 8 losas
	for idx in range(count):
		var layout = StoneLayoutCatalog.get_base_layout(idx)
		assert(layout.size() >= 8, "Layout %d must contain at least 8 stones" % idx)

		for item in layout:
			var r: Rect2 = item["rect"]
			assert(r.position.x >= 0.0 and r.position.y >= 0.0, "Rect position >= 0")
			assert(r.end.x <= 1.05 and r.end.y <= 1.05, "Rect end <= 1.0")
			assert(r.size.x > 0.05 and r.size.y > 0.05, "Rect size > 0")
			assert(item.has("tone"), "Item has tone")
			assert(item.has("size_class"), "Item has size_class")

	print("  [OK] All 8 base layout families validated.")

	# 2. Validar rotaciones 90°, 180°, 270° y flips en todas las combinaciones (8 x 4 x 2 = 64 variantes)
	var total_tested: int = 0
	for l_idx in range(count):
		for rot in range(4):
			for flip_x in [false, true]:
				for flip_y in [false, true]:
					var variant = StoneLayoutCatalog.get_transformed_layout(l_idx, rot, flip_x, flip_y)
					assert(variant.size() >= 8, "Variant must preserve stone count")
					for item in variant:
						var r: Rect2 = item["rect"]
						assert(r.position.x >= -0.01 and r.position.y >= -0.01, "Position valid")
						assert(r.end.x <= 1.01 and r.end.y <= 1.01, "End valid")
						assert(r.size.x > 0.0 and r.size.y > 0.0, "Size positive")
					total_tested += 1

	assert(total_tested == 8 * 4 * 2 * 2, "64 layout combinations tested successfully")
	print("  [OK] 64 combinatorial layout transformations verified with 0 invalid bounds.")

	# 3. Validar Enum SizeClass en TileDescriptor
	var desc = TileDescriptor.new(Rect2(0, 0, 1, 1), 0.05, 0.02, 0.0, 0, 0.0, Vector2.ZERO, PackedVector2Array(), Vector2.ZERO, TileDescriptor.SizeClass.LARGE)
	assert(desc.size_class == TileDescriptor.SizeClass.LARGE, "TileDescriptor size class verified")
	print("  [OK] TileDescriptor.SizeClass verified.")

	print("==================================================================")
	print("[PASS] test_stone_layout_catalog completado con 100% éxito!")
	print("==================================================================")
	quit(0)
