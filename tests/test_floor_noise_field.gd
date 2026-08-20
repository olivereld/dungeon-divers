extends SceneTree

## Test suite para validar FloorNoiseField (Fase V2: Modulación Espacial).

const FloorNoiseField = preload("res://src/floor_tile_generator/patterns/floor_noise_field.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_noise_field (V2: Spatial Noise Field) ---")
	print("==================================================================")

	var noise_field := FloorNoiseField.new(1337, 0.05)

	# 1. Validar rango de sample_noise y sample_noise_norm
	var val_raw = noise_field.sample_noise(10.0, 20.0)
	assert(val_raw >= -1.0 and val_raw <= 1.0, "sample_noise in [-1, 1]")

	var val_norm = noise_field.sample_noise_norm(10.0, 20.0)
	assert(val_norm >= 0.0 and val_norm <= 1.0, "sample_noise_norm in [0, 1]")
	print("  [OK] Noise sampling ranges verified: raw=%.3f, norm=%.3f" % [val_raw, val_norm])

	# 2. Validar continuidad suave (puntos contiguos cercanos tienen valores cercanos)
	var v1 = noise_field.sample_noise(10.0, 10.0)
	var v2 = noise_field.sample_noise(10.5, 10.0)
	assert(absf(v1 - v2) < 0.15, "Low frequency noise must be spatially continuous and smooth")
	print("  [OK] Spatial continuity verified (gradient difference < 0.15).")

	# 3. Validar sesgos de tamaño y desgaste
	var size_bias = noise_field.get_preferred_size_bias(5.0, 5.0)
	assert(size_bias >= 0 and size_bias <= 2, "Size bias in [0, 2]")

	var wear = noise_field.get_wear_factor(5.0, 5.0)
	assert(wear >= 0.0 and wear <= 1.0, "Wear factor in [0, 1]")

	var tone = noise_field.get_tone_offset(5.0, 5.0, 0.06)
	assert(absf(tone) <= 0.065, "Tone offset within bounds")
	print("  [OK] Bias helpers (size, wear, tone) verified.")

	# 4. Determinismo estricto
	var field2 := FloorNoiseField.new(1337, 0.05)
	assert(field2.sample_noise(42.0, 84.0) == noise_field.sample_noise(42.0, 84.0), "Identical seed produces identical noise values")
	print("  [OK] Noise field determinism confirmed.")

	print("==================================================================")
	print("[PASS] test_floor_noise_field completado con 100% éxito!")
	print("==================================================================")
	quit(0)
