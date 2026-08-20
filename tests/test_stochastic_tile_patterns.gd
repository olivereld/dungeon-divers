extends SceneTree

## Test suite para validar la variación estocástica entre celdas vecinas y determinismo (Fases V1 y V2).

const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorTilePattern = preload("res://src/floor_tile_generator/patterns/floor_tile_pattern.gd")
const FloorNoiseField = preload("res://src/floor_tile_generator/patterns/floor_noise_field.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_stochastic_tile_patterns (V1/V2: Stochastic Variance) ---")
	print("==================================================================")

	var pattern_gen := FloorTilePattern.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0
	cfg.pattern = FloorTileConfig.PatternType.STYLIZED_STONE
	cfg.use_noise_modulation = true

	var noise_field := FloorNoiseField.new(1337, cfg.noise_frequency)

	# 1. Validar que celdas contiguas tienen layouts diferentes (rompiendo repetición)
	var d_00 = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 0), cfg, 1337, noise_field)
	var d_10 = pattern_gen.generate_descriptors_for_cell(Vector2i(1, 0), cfg, 1337, noise_field)
	var d_01 = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 1), cfg, 1337, noise_field)

	assert(d_00.size() >= 8, "Cell (0,0) has valid stone count")
	assert(d_10.size() >= 8, "Cell (1,0) has valid stone count")

	# Validar que los rectángulos relativos de las losas no son idénticos entre celdas contiguas
	var r00_first: Rect2 = d_00[0].rect
	var r10_first: Rect2 = d_10[0].rect
	var is_identical: bool = (d_00.size() == d_10.size()) and (r00_first == r10_first)
	assert(not is_identical, "Adjacent cells (0,0) and (1,0) must have different stochastic layout variations")
	print("  [OK] Adjacent cell diversity confirmed: (0,0) has %d stones, (1,0) has %d stones, distinct layouts." % [d_00.size(), d_10.size()])

	# 2. Validar que todas las piedras respetan los límites de la celda [0, 2.0]
	for d in d_00 + d_10 + d_01:
		var r: Rect2 = d.rect
		assert(r.position.x >= 0.0 and r.position.y >= 0.0, "Position non-negative")
		assert(r.end.x <= cfg.tile_size + 0.05 and r.end.y <= cfg.tile_size + 0.05, "End within tile size")
		assert(r.size.x > 0.02 and r.size.y > 0.02, "Size positive")

	print("  [OK] 100% surface boundary compliance verified across all tested cells.")

	# 3. Validar Determinismo estricto: misma celda + misma semilla = idéntico resultado
	var d_00_repeat = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 0), cfg, 1337, noise_field)
	assert(d_00.size() == d_00_repeat.size(), "Descriptor count matches on repeat")
	for i in range(d_00.size()):
		assert(d_00[i].rect == d_00_repeat[i].rect, "Descriptor rect matches identically")
		assert(d_00[i].height == d_00_repeat[i].height, "Descriptor height matches identically")
		assert(d_00[i].color_mod == d_00_repeat[i].color_mod, "Descriptor tone matches identically")

	print("  [OK] Determinism confirmed: 100% exact reproduction with same seed and coordinates.")

	print("==================================================================")
	print("[PASS] test_stochastic_tile_patterns completado con 100% éxito!")
	print("==================================================================")
	quit(0)
