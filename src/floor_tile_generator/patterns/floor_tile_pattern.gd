class_name FloorTilePattern
extends RefCounted

## Generador de patrones y descriptores de losas/piedras de suelo (TileDescriptors).
## Transforma celdas 2D en colecciones deterministas de TileDescriptor según el patrón elegido.

const _TileDescriptorScript = preload("res://src/floor_tile_generator/data/tile_descriptor.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")

## Genera la lista de TileDescriptor para una celda espacial individual
func generate_descriptors_for_cell(
	cell_pos: Vector2i,
	config = null,
	seed_val: int = 1337
) -> Array:
	var descriptors: Array = []
	if config == null:
		config = _FloorTileConfigScript.new()

	var tile_size: float = config.tile_size
	var world_offset := Vector2(float(cell_pos.x) * tile_size, float(cell_pos.y) * tile_size)

	# Semilla determinista combinando coordenadas espaciales
	var cell_seed: int = (seed_val ^ (cell_pos.x * 73856093) ^ (cell_pos.y * 19349663)) & 0x7FFFFFFF
	var rng := RandomNumberGenerator.new()
	rng.seed = cell_seed

	match config.pattern:
		_FloorTileConfigScript.PatternType.COBBLESTONE:
			_generate_cobblestone_pattern(descriptors, world_offset, config, rng)
		_FloorTileConfigScript.PatternType.BRICK:
			_generate_brick_pattern(descriptors, world_offset, config, rng)
		_FloorTileConfigScript.PatternType.SMOOTH_SLABS:
			_generate_smooth_slabs_pattern(descriptors, world_offset, config, rng)
		_FloorTileConfigScript.PatternType.RUINED_TILES:
			_generate_ruined_tiles_pattern(descriptors, world_offset, config, rng)
		_:
			_generate_stylized_stone_pattern(descriptors, world_offset, config, rng)

	return descriptors

## Patrón 1: Losas entrelazadas estilizadas tipo Zelda / Diablo (19 losas completas con cobertura 100%)
func _generate_stylized_stone_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator
) -> void:
	var margin: float = config.margin
	var tile_size: float = config.tile_size
	var scale_factor: float = tile_size / 2.0

	var raw_layout = [
		# Fila 1 (Norte)
		{"rect": Rect2(0.02, 0.02, 0.44, 0.44), "tone": 0.08},
		{"rect": Rect2(0.48, 0.02, 0.52, 0.26), "tone": -0.05},
		{"rect": Rect2(1.02, 0.02, 0.46, 0.48), "tone": 0.12},
		{"rect": Rect2(1.50, 0.02, 0.48, 0.32), "tone": -0.08},

		# Fila 2
		{"rect": Rect2(0.48, 0.30, 0.24, 0.38), "tone": 0.04},
		{"rect": Rect2(0.74, 0.30, 0.26, 0.38), "tone": -0.10},
		{"rect": Rect2(1.50, 0.36, 0.48, 0.32), "tone": 0.06},

		# Fila 3 (Centro)
		{"rect": Rect2(0.02, 0.48, 0.44, 0.54), "tone": -0.04},
		{"rect": Rect2(0.48, 0.70, 0.52, 0.32), "tone": 0.10},
		{"rect": Rect2(1.02, 0.52, 0.46, 0.50), "tone": -0.06},

		# Fila 4 (Sur)
		{"rect": Rect2(0.02, 1.04, 0.44, 0.44), "tone": 0.05},
		{"rect": Rect2(0.48, 1.04, 0.24, 0.44), "tone": -0.08},
		{"rect": Rect2(0.74, 1.04, 0.26, 0.44), "tone": 0.02},
		{"rect": Rect2(1.02, 1.04, 0.46, 0.44), "tone": 0.09},
		{"rect": Rect2(1.50, 0.70, 0.48, 0.78), "tone": -0.03},

		# Fila 5 (Extremo Sur - Cobertura 100% de las 4 esquinas)
		{"rect": Rect2(0.02, 1.50, 0.44, 0.48), "tone": -0.06},
		{"rect": Rect2(0.48, 1.50, 0.52, 0.48), "tone": 0.07},
		{"rect": Rect2(1.02, 1.50, 0.46, 0.48), "tone": -0.02},
		{"rect": Rect2(1.50, 1.50, 0.48, 0.48), "tone": 0.04},
	]

	for item in raw_layout:
		var r: Rect2 = item["rect"]
		var scaled_rect := Rect2(
			r.position.x * scale_factor + (margin * 0.5),
			r.position.y * scale_factor + (margin * 0.5),
			(r.size.x * scale_factor) - margin,
			(r.size.y * scale_factor) - margin
		)
		var h: float = rng.randf_range(config.height_min, config.height_max)
		var bevel: float = rng.randf_range(config.bevel_min, config.bevel_max)
		var tone: float = float(item["tone"]) + rng.randf_range(-config.tone_variation, config.tone_variation)

		var desc = _TileDescriptorScript.new(scaled_rect, h, bevel, tone, 0, 0.0, world_offset)
		descriptors.append(desc)

## Patrón 2: Adoquines pequeños (Cobblestone 4x4 con jitter)
func _generate_cobblestone_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator
) -> void:
	var tile_size: float = config.tile_size
	var grid_n: int = 4
	var step: float = tile_size / float(grid_n)
	var margin: float = config.margin * 0.8

	for gy in range(grid_n):
		for gx in range(grid_n):
			var base_x: float = float(gx) * step
			var base_y: float = float(gy) * step
			var jitter_x: float = rng.randf_range(-0.02, 0.02)
			var jitter_y: float = rng.randf_range(-0.02, 0.02)

			var r := Rect2(
				base_x + margin * 0.5 + jitter_x,
				base_y + margin * 0.5 + jitter_y,
				step - margin,
				step - margin
			)
			var h: float = rng.randf_range(config.height_min * 0.9, config.height_max * 1.1)
			var bevel: float = rng.randf_range(config.bevel_min * 0.8, config.bevel_max * 1.2)
			var tone: float = rng.randf_range(-config.tone_variation * 1.5, config.tone_variation * 1.5)

			var desc = _TileDescriptorScript.new(r, h, bevel, tone, 0, 0.0, world_offset)
			descriptors.append(desc)

## Patrón 3: Ladrillos rectangulares entrelazados (Brick Pattern)
func _generate_brick_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator
) -> void:
	var tile_size: float = config.tile_size
	var rows: int = 4
	var row_h: float = tile_size / float(rows)
	var brick_w: float = tile_size / 2.0
	var margin: float = config.margin

	for r in range(rows):
		var row_y: float = float(r) * row_h
		var offset_x: float = (brick_w * 0.5) if (r % 2 == 1) else 0.0

		var cols: int = 3 if (r % 2 == 1) else 2
		for c in range(cols):
			var cur_x: float = float(c) * brick_w - offset_x
			var cur_w: float = brick_w

			var clamp_x0: float = maxf(cur_x, 0.0)
			var clamp_x1: float = minf(cur_x + cur_w, tile_size)
			var actual_w: float = clamp_x1 - clamp_x0
			if actual_w <= margin * 1.5:
				continue

			var r_rect := Rect2(
				clamp_x0 + (margin * 0.5),
				row_y + (margin * 0.5),
				actual_w - margin,
				row_h - margin
			)
			var h: float = rng.randf_range(config.height_min, config.height_max)
			var bevel: float = rng.randf_range(config.bevel_min, config.bevel_max)
			var tone: float = rng.randf_range(-config.tone_variation, config.tone_variation)

			var desc = _TileDescriptorScript.new(r_rect, h, bevel, tone, 0, 0.0, world_offset)
			descriptors.append(desc)

## Patrón 4: 4 Losas amplias y limpias (Smooth Slabs 2x2)
func _generate_smooth_slabs_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator
) -> void:
	var tile_size: float = config.tile_size
	var half: float = tile_size * 0.5
	var margin: float = config.margin * 1.2

	for gy in range(2):
		for gx in range(2):
			var r := Rect2(
				float(gx) * half + (margin * 0.5),
				float(gy) * half + (margin * 0.5),
				half - margin,
				half - margin
			)
			var h: float = rng.randf_range(config.height_min, config.height_max)
			var bevel: float = rng.randf_range(config.bevel_min * 1.2, config.bevel_max * 1.4)
			var tone: float = rng.randf_range(-config.tone_variation * 0.8, config.tone_variation * 0.8)

			var desc = _TileDescriptorScript.new(r, h, bevel, tone, 0, 0.0, world_offset)
			descriptors.append(desc)

## Patrón 5: Suelo Agrietado y Ruinas Procedurales (Fracturas Poligonales Orgánicas + Cobertura Total)
func _generate_ruined_tiles_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator
) -> void:
	var tile_size: float = config.tile_size
	var margin: float = config.margin * 0.9

	# Cuadrícula base de 6 losas estructurales con tamaños variados
	var base_slabs = [
		Rect2(0.0, 0.0, 0.98, 0.98),
		Rect2(1.02, 0.0, 0.98, 0.60),
		Rect2(1.02, 0.64, 0.98, 0.68),
		Rect2(0.0, 1.02, 0.58, 0.98),
		Rect2(0.62, 1.02, 0.68, 0.98),
		Rect2(1.34, 1.36, 0.66, 0.64)
	]

	var scale_factor: float = tile_size / 2.0

	for base_rect in base_slabs:
		var x0: float = base_rect.position.x * scale_factor + margin * 0.5
		var y0: float = base_rect.position.y * scale_factor + margin * 0.5
		var w: float = base_rect.size.x * scale_factor - margin
		var h_rect: float = base_rect.size.y * scale_factor - margin
		var x1: float = x0 + w
		var y1: float = y0 + h_rect

		var base_h: float = rng.randf_range(config.height_min, config.height_max)
		var base_bevel: float = rng.randf_range(config.bevel_min, config.bevel_max * 1.3)
		var base_tone: float = rng.randf_range(-config.tone_variation * 1.2, config.tone_variation * 1.2)

		var crack_roll: float = rng.randf()

		if crack_roll < 0.30:
			# Losa intacta pero con cota irregular y bisel rugoso
			var desc_rect := Rect2(x0, y0, w, h_rect)
			var desc = _TileDescriptorScript.new(desc_rect, base_h, base_bevel, base_tone, 0, 0.0, world_offset)
			descriptors.append(desc)

		elif crack_roll < 0.70:
			# Fractura diagonal en 2 fragmentos poligonales
			var split_t: float = rng.randf_range(0.35, 0.65)
			var p_mid_top := Vector2(lerpf(x0, x1, split_t), y0)
			var p_mid_bot := Vector2(lerpf(x0, x1, 1.0 - split_t), y1)

			var poly1: PackedVector2Array = [
				Vector2(x0, y0), p_mid_top, p_mid_bot, Vector2(x0, y1)
			]
			var poly2: PackedVector2Array = [
				p_mid_top, Vector2(x1, y0), Vector2(x1, y1), p_mid_bot
			]

			var h1: float = base_h + rng.randf_range(-0.015, 0.015)
			var h2: float = base_h + rng.randf_range(-0.015, 0.015)
			var tone1: float = base_tone + rng.randf_range(-0.06, 0.04)
			var tone2: float = base_tone + rng.randf_range(-0.08, 0.02)

			var desc1 = _TileDescriptorScript.new(Rect2(x0, y0, w * 0.5, h_rect), h1, base_bevel, tone1, 1, 0.0, world_offset, poly1)
			var desc2 = _TileDescriptorScript.new(Rect2(x0 + w * 0.5, y0, w * 0.5, h_rect), h2, base_bevel, tone2, 1, 0.0, world_offset, poly2)
			descriptors.append(desc1)
			descriptors.append(desc2)

		else:
			# Fractura radial en 3-4 esquirlas triangulares (piedra reventada en el centro)
			var center_pt := Vector2(
				lerpf(x0, x1, rng.randf_range(0.4, 0.6)),
				lerpf(y0, y1, rng.randf_range(0.4, 0.6))
			)

			var poly_nw: PackedVector2Array = [Vector2(x0, y0), Vector2(x1, y0), center_pt]
			var poly_ne: PackedVector2Array = [Vector2(x1, y0), Vector2(x1, y1), center_pt]
			var poly_se: PackedVector2Array = [Vector2(x1, y1), Vector2(x0, y1), center_pt]
			var poly_sw: PackedVector2Array = [Vector2(x0, y1), Vector2(x0, y0), center_pt]

			var polys = [poly_nw, poly_ne, poly_se, poly_sw]
			for p_idx in range(polys.size()):
				var poly: PackedVector2Array = polys[p_idx]
				var frag_h: float = base_h * rng.randf_range(0.65, 1.05)
				var frag_tone: float = base_tone + rng.randf_range(-0.12, 0.06)
				var d = _TileDescriptorScript.new(Rect2(x0, y0, w, h_rect), frag_h, base_bevel * 0.8, frag_tone, 1, 0.0, world_offset, poly)
				descriptors.append(d)
