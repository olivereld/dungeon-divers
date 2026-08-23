class_name FloorTilePattern
extends RefCounted

## Generador estocástico de patrones y descriptores de losas/piedras de suelo (Fases V1 y V2).
## Integra: StoneLayoutCatalog (64 variantes combinatorias) + FloorNoiseField (modulación espacial continua).

const _TileDescriptorScript = preload("res://src/floor_tile_generator/data/tile_descriptor.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _StoneLayoutCatalogScript = preload("res://src/floor_tile_generator/patterns/stone_layout_catalog.gd")
const _FloorNoiseFieldScript = preload("res://src/floor_tile_generator/patterns/floor_noise_field.gd")

var _default_noise_field: RefCounted = null

## Genera la lista de TileDescriptor para una celda espacial individual
func generate_descriptors_for_cell(
	cell_pos: Vector2i,
	config = null,
	seed_val: int = 1337,
	noise_field = null
) -> Array:
	var descriptors: Array = []
	if config == null:
		config = _FloorTileConfigScript.new()

	var tile_size: float = config.tile_size
	var world_offset := Vector2(float(cell_pos.x) * tile_size, float(cell_pos.y) * tile_size)

	# Inicializar FloorNoiseField si no se proporcionó
	if noise_field == null:
		if _default_noise_field == null or _default_noise_field.seed_val != seed_val:
			_default_noise_field = _FloorNoiseFieldScript.new(seed_val, config.noise_frequency)
		noise_field = _default_noise_field

	# Hash determinista de celda
	var cell_hash: int = (seed_val ^ (cell_pos.x * 73856093) ^ (cell_pos.y * 19349663)) & 0x7FFFFFFF
	var rng := RandomNumberGenerator.new()
	rng.seed = cell_hash

	match config.pattern:
		_FloorTileConfigScript.PatternType.COBBLESTONE:
			_generate_cobblestone_pattern(descriptors, world_offset, config, rng, noise_field)
		_FloorTileConfigScript.PatternType.BRICK:
			_generate_brick_pattern(descriptors, world_offset, config, rng, noise_field)
		_FloorTileConfigScript.PatternType.SMOOTH_SLABS:
			_generate_smooth_slabs_pattern(descriptors, world_offset, config, rng, noise_field)
		_FloorTileConfigScript.PatternType.RUINED_TILES:
			_generate_ruined_tiles_pattern(descriptors, world_offset, config, rng, noise_field, cell_hash)
		_FloorTileConfigScript.PatternType.CATACOMB_DIRT:
			_generate_catacomb_dirt_pattern(descriptors, world_offset, config, rng, noise_field, cell_hash)
		_:
			_generate_stochastic_stone_pattern(descriptors, world_offset, config, rng, noise_field, cell_hash)

	return descriptors

## Patrón 1: Losas Estilizadas Estocásticas (V1: 64 variantes combinatorias + V2: modulación por ruido)
func _generate_stochastic_stone_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator,
	noise_field,
	cell_hash: int
) -> void:
	var tile_size: float = config.tile_size
	var margin: float = config.margin
	var jitter_max: float = config.jitter_strength

	# 1. Muestreo de ruido espacial para sesgo de tamaño
	var size_bias: int = noise_field.get_preferred_size_bias(world_offset.x, world_offset.y) if config.use_noise_modulation else 1
	var layout_idx: int = 0

	match size_bias:
		2: # Zona de losas grandes / megalitos
			var large_candidates = [0, 3, 4]
			layout_idx = large_candidates[(cell_hash >> 2) % large_candidates.size()]
		0: # Zona de losas pequeñas / densas
			var small_candidates = [1, 5, 7]
			layout_idx = small_candidates[(cell_hash >> 2) % small_candidates.size()]
		_: # Zona equilibrada (todos los layouts)
			layout_idx = (cell_hash >> 2) % _StoneLayoutCatalogScript.get_layout_count()

	# 2. Rotación ortogonal determinista (0°, 90°, 180°, 270°) y Reflejos H/V
	var rot_steps: int = (cell_hash >> 5) % 4
	var flip_x: bool = ((cell_hash >> 7) & 1) == 1
	var flip_y: bool = ((cell_hash >> 8) & 1) == 1

	var layout: Array = _StoneLayoutCatalogScript.get_transformed_layout(layout_idx, rot_steps, flip_x, flip_y)

	# 3. Modulación de tono continuo macro
	var macro_tone: float = noise_field.get_tone_offset(world_offset.x, world_offset.y) if config.use_noise_modulation else 0.0

	# 4. Generar descriptores escalados al tamaño de la celda
	for item in layout:
		var norm_r: Rect2 = item["rect"]
		var item_tone: float = item.get("tone", 0.0)
		var size_class: int = item.get("size_class", 1)

		# Escalar a dimensiones de mundo respetando el margen de mortero
		var x0: float = norm_r.position.x * tile_size + (margin * 0.5)
		var y0: float = norm_r.position.y * tile_size + (margin * 0.5)
		var w: float = maxf(0.04, norm_r.size.x * tile_size - margin)
		var h_rect: float = maxf(0.04, norm_r.size.y * tile_size - margin)

		# Jitter controlado seguro (sin salirse de la celda ni invadir mortero)
		var jx: float = rng.randf_range(-jitter_max, jitter_max)
		var jy: float = rng.randf_range(-jitter_max, jitter_max)
		x0 = clampf(x0 + jx, margin * 0.5, tile_size - w - (margin * 0.5))
		y0 = clampf(y0 + jy, margin * 0.5, tile_size - h_rect - (margin * 0.5))

		var scaled_rect := Rect2(x0, y0, w, h_rect)
		var h: float = rng.randf_range(config.height_min, config.height_max)
		var bevel: float = rng.randf_range(config.bevel_min, config.bevel_max)
		var tone: float = item_tone + macro_tone + rng.randf_range(-config.tone_variation, config.tone_variation)

		var desc = _TileDescriptorScript.new(
			scaled_rect, h, bevel, tone, 0, 0.0, world_offset,
			PackedVector2Array(), Vector2.ZERO, size_class as TileDescriptor.SizeClass
		)
		descriptors.append(desc)

## Patrón 2: Adoquines pequeños (Cobblestone 4x4 con jitter)
func _generate_cobblestone_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator,
	noise_field
) -> void:
	var tile_size: float = config.tile_size
	var grid_n: int = 4
	var step: float = tile_size / float(grid_n)
	var margin: float = config.margin * 0.8
	var macro_tone: float = noise_field.get_tone_offset(world_offset.x, world_offset.y) if config.use_noise_modulation else 0.0

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
			var tone: float = macro_tone + rng.randf_range(-config.tone_variation * 1.5, config.tone_variation * 1.5)

			var desc = _TileDescriptorScript.new(r, h, bevel, tone, 0, 0.0, world_offset, PackedVector2Array(), Vector2.ZERO, _TileDescriptorScript.SizeClass.SMALL)
			descriptors.append(desc)

## Patrón 3: Ladrillos rectangulares entrelazados (Brick Pattern)
func _generate_brick_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator,
	noise_field
) -> void:
	var tile_size: float = config.tile_size
	var rows: int = 4
	var row_h: float = tile_size / float(rows)
	var brick_w: float = tile_size / 2.0
	var margin: float = config.margin
	var macro_tone: float = noise_field.get_tone_offset(world_offset.x, world_offset.y) if config.use_noise_modulation else 0.0

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
			var tone: float = macro_tone + rng.randf_range(-config.tone_variation, config.tone_variation)

			var desc = _TileDescriptorScript.new(r_rect, h, bevel, tone, 0, 0.0, world_offset, PackedVector2Array(), Vector2.ZERO, _TileDescriptorScript.SizeClass.MEDIUM)
			descriptors.append(desc)

## Patrón 4: 4 Losas amplias y limpias (Smooth Slabs 2x2)
func _generate_smooth_slabs_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator,
	noise_field
) -> void:
	var tile_size: float = config.tile_size
	var half: float = tile_size * 0.5
	var margin: float = config.margin * 1.2
	var macro_tone: float = noise_field.get_tone_offset(world_offset.x, world_offset.y) if config.use_noise_modulation else 0.0

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
			var tone: float = macro_tone + rng.randf_range(-config.tone_variation * 0.8, config.tone_variation * 0.8)

			var desc = _TileDescriptorScript.new(r, h, bevel, tone, 0, 0.0, world_offset, PackedVector2Array(), Vector2.ZERO, _TileDescriptorScript.SizeClass.LARGE)
			descriptors.append(desc)

## Patrón 5: Suelo Agrietado y Ruinas Procedurales (Fracturas Poligonales Moduladas por Ruido)
func _generate_ruined_tiles_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator,
	noise_field,
	cell_hash: int
) -> void:
	var tile_size: float = config.tile_size
	var margin: float = config.margin * 0.9

	# Seleccionar layout base con rotaciones y reflejos
	var layout_idx: int = (cell_hash >> 2) % _StoneLayoutCatalogScript.get_layout_count()
	var rot_steps: int = (cell_hash >> 5) % 4
	var flip_x: bool = ((cell_hash >> 7) & 1) == 1
	var flip_y: bool = ((cell_hash >> 8) & 1) == 1

	var layout: Array = _StoneLayoutCatalogScript.get_transformed_layout(layout_idx, rot_steps, flip_x, flip_y)
	var wear_zone: float = noise_field.get_wear_factor(world_offset.x, world_offset.y) if config.use_noise_modulation else 0.5
	var macro_tone: float = noise_field.get_tone_offset(world_offset.x, world_offset.y) if config.use_noise_modulation else 0.0

	for item in layout:
		var norm_r: Rect2 = item["rect"]
		var item_tone: float = item.get("tone", 0.0)

		var x0: float = norm_r.position.x * tile_size + (margin * 0.5)
		var y0: float = norm_r.position.y * tile_size + (margin * 0.5)
		var w: float = maxf(0.04, norm_r.size.x * tile_size - margin)
		var h_rect: float = maxf(0.04, norm_r.size.y * tile_size - margin)
		var x1: float = x0 + w
		var y1: float = y0 + h_rect

		var base_h: float = rng.randf_range(config.height_min, config.height_max)
		var base_bevel: float = rng.randf_range(config.bevel_min, config.bevel_max * 1.3)
		var base_tone: float = item_tone + macro_tone + rng.randf_range(-config.tone_variation * 1.2, config.tone_variation * 1.2)

		var crack_chance: float = (wear_zone * 0.6) + (rng.randf() * 0.4)

		if crack_chance < 0.40:
			# Losa intacta con cota rugosa
			var desc_rect := Rect2(x0, y0, w, h_rect)
			var desc = _TileDescriptorScript.new(desc_rect, base_h, base_bevel, base_tone, 0, 0.0, world_offset, PackedVector2Array(), Vector2.ZERO, _TileDescriptorScript.SizeClass.MEDIUM)
			descriptors.append(desc)

		elif crack_chance < 0.75:
			# Fractura diagonal en 2 fragmentos poligonales
			var split_t: float = rng.randf_range(0.35, 0.65)
			var p_mid_top := Vector2(lerpf(x0, x1, split_t), y0)
			var p_mid_bot := Vector2(lerpf(x0, x1, 1.0 - split_t), y1)

			var poly1: PackedVector2Array = [Vector2(x0, y0), p_mid_top, p_mid_bot, Vector2(x0, y1)]
			var poly2: PackedVector2Array = [p_mid_top, Vector2(x1, y0), Vector2(x1, y1), p_mid_bot]

			var h1: float = base_h + rng.randf_range(-0.012, 0.012)
			var h2: float = base_h + rng.randf_range(-0.012, 0.012)
			var tone1: float = base_tone + rng.randf_range(-0.06, 0.04)
			var tone2: float = base_tone + rng.randf_range(-0.08, 0.02)

			var desc1 = _TileDescriptorScript.new(Rect2(x0, y0, w * 0.5, h_rect), h1, base_bevel, tone1, 1, 0.0, world_offset, poly1, Vector2.ZERO, _TileDescriptorScript.SizeClass.SHARD)
			var desc2 = _TileDescriptorScript.new(Rect2(x0 + w * 0.5, y0, w * 0.5, h_rect), h2, base_bevel, tone2, 1, 0.0, world_offset, poly2, Vector2.ZERO, _TileDescriptorScript.SizeClass.SHARD)
			descriptors.append(desc1)
			descriptors.append(desc2)

		else:
			# Fractura radial en esquirlas triangulares
			var center_pt := Vector2(
				lerpf(x0, x1, rng.randf_range(0.4, 0.6)),
				lerpf(y0, y1, rng.randf_range(0.4, 0.6))
			)
			var polys = [
				[Vector2(x0, y0), Vector2(x1, y0), center_pt] as PackedVector2Array,
				[Vector2(x1, y0), Vector2(x1, y1), center_pt] as PackedVector2Array,
				[Vector2(x1, y1), Vector2(x0, y1), center_pt] as PackedVector2Array,
				[Vector2(x0, y1), Vector2(x0, y0), center_pt] as PackedVector2Array
			]
			for p_idx in range(polys.size()):
				var poly: PackedVector2Array = polys[p_idx]
				var frag_h: float = base_h * rng.randf_range(0.7, 1.05)
				var frag_tone: float = base_tone + rng.randf_range(-0.10, 0.05)
				var d = _TileDescriptorScript.new(Rect2(x0, y0, w, h_rect), frag_h, base_bevel * 0.8, frag_tone, 1, 0.0, world_offset, poly, Vector2.ZERO, _TileDescriptorScript.SizeClass.SHARD)
				descriptors.append(d)

## Patrón 5: Suelo de Tierra de Catacumba / Cripta con Relieve y Baldosas Incrustadas
func _generate_catacomb_dirt_pattern(
	descriptors: Array,
	world_offset: Vector2,
	config,
	rng: RandomNumberGenerator,
	noise_field,
	cell_hash: int
) -> void:
	var tile_size: float = config.tile_size
	var macro_tone: float = noise_field.get_tone_offset(world_offset.x, world_offset.y) if config.use_noise_modulation else 0.0

	# 1. Baldosas/Losas rotas incrustadas esparcidas (0 a 3 losas desgastadas)
	var slab_count: int = rng.randi_range(0, 2)
	if (cell_hash % 3) == 0:
		slab_count = rng.randi_range(1, 3)

	for s_i in range(slab_count):
		var w: float = rng.randf_range(0.35, 0.65)
		var h_rect: float = rng.randf_range(0.30, 0.60)
		var x0: float = rng.randf_range(0.1, tile_size - w - 0.1)
		var y0: float = rng.randf_range(0.1, tile_size - h_rect - 0.1)
		var x1: float = x0 + w
		var y1: float = y0 + h_rect

		var slab_h: float = rng.randf_range(0.025, 0.042) # Losa semi-enterrada
		var slab_bevel: float = rng.randf_range(0.02, 0.035)
		var slab_tone: float = macro_tone + rng.randf_range(-0.06, 0.06)

		var is_broken: bool = rng.randf() < 0.65
		if is_broken:
			# Losa astillada en polígono trapezoidal/irregular
			var corner_cut: float = rng.randf_range(0.05, 0.15)
			var poly: PackedVector2Array = [
				Vector2(x0 + corner_cut, y0),
				Vector2(x1, y0 + corner_cut * 0.5),
				Vector2(x1 - corner_cut * 0.5, y1),
				Vector2(x0, y1 - corner_cut)
			]
			var desc = _TileDescriptorScript.new(
				Rect2(x0, y0, w, h_rect), slab_h, slab_bevel, slab_tone, 1, 0.0,
				world_offset, poly, Vector2.ZERO, _TileDescriptorScript.SizeClass.SHARD
			)
			descriptors.append(desc)
		else:
			var desc_rect := Rect2(x0, y0, w, h_rect)
			var desc = _TileDescriptorScript.new(
				desc_rect, slab_h, slab_bevel, slab_tone, 0, 0.0,
				world_offset, PackedVector2Array(), Vector2.ZERO, _TileDescriptorScript.SizeClass.SMALL
			)
			descriptors.append(desc)

	# 2. Guijarros y esquirlas de piedra sueltas en la tierra (2 a 6 piedrecitas)
	var pebble_count: int = rng.randi_range(2, 6)
	for p_i in range(pebble_count):
		var p_cx: float = rng.randf_range(0.15, tile_size - 0.15)
		var p_cy: float = rng.randf_range(0.15, tile_size - 0.15)
		var rad: float = rng.randf_range(0.04, 0.09)
		var p_h: float = rng.randf_range(0.020, 0.038)
		var p_tone: float = macro_tone + rng.randf_range(-0.12, 0.08)

		# Pequeño rombo/hexágono procedural
		var pebble_poly: PackedVector2Array = [
			Vector2(p_cx - rad, p_cy),
			Vector2(p_cx - rad * 0.3, p_cy - rad * 0.8),
			Vector2(p_cx + rad * 0.7, p_cy - rad * 0.4),
			Vector2(p_cx + rad, p_cy + rad * 0.2),
			Vector2(p_cx + rad * 0.2, p_cy + rad * 0.9),
			Vector2(p_cx - rad * 0.6, p_cy + rad * 0.5)
		]
		var p_desc = _TileDescriptorScript.new(
			Rect2(p_cx - rad, p_cy - rad, rad * 2.0, rad * 2.0),
			p_h, rad * 0.4, p_tone, 1, 0.0, world_offset, pebble_poly,
			Vector2.ZERO, _TileDescriptorScript.SizeClass.SHARD
		)
		descriptors.append(p_desc)
