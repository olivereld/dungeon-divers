class_name StoneLayoutCatalog
extends RefCounted

## Catálogo de 8 familias de layouts modulares de baldosas y transformaciones ortogonales (Fase V1).
## Permite generar 64 variantes combinatorias con 100% de cobertura espacial garantizada en [0.0, 1.0] x [0.0, 1.0].

const _TileDescriptorScript = preload("res://src/floor_tile_generator/data/tile_descriptor.gd")

## Retorna el número total de familias de layouts base
static func get_layout_count() -> int:
	return 8

## Retorna la lista de rectángulos normalizados para un layout base específico (0..7)
static func get_base_layout(layout_idx: int) -> Array[Dictionary]:
	var idx: int = posmod(layout_idx, 8)
	match idx:
		0: return _layout_0_megalith_center()
		1: return _layout_1_herringbone_masonry()
		2: return _layout_2_asymmetric_3_row()
		3: return _layout_3_quad_grid()
		4: return _layout_4_split_corner()
		5: return _layout_5_cross_weave()
		6: return _layout_6_stepped_flags()
		_: return _layout_7_dense_pavers()

## Rota un layout normalizado 90° en sentido horario tantas veces como indique 'steps' (0..3)
static func rotate_layout_90(layout: Array, steps: int) -> Array:
	var s: int = posmod(steps, 4)
	if s == 0:
		return layout.duplicate(true)

	var result: Array = []
	for item in layout:
		var r: Rect2 = item["rect"]
		var tone: float = item.get("tone", 0.0)
		var size_class: int = item.get("size_class", 1)

		var new_r: Rect2
		match s:
			1: # 90° CW: (x, y, w, h) -> (1.0 - y - h, x, h, w)
				new_r = Rect2(1.0 - r.position.y - r.size.y, r.position.x, r.size.y, r.size.x)
			2: # 180°: (x, y, w, h) -> (1.0 - x - w, 1.0 - y - h, w, h)
				new_r = Rect2(1.0 - r.position.x - r.size.x, 1.0 - r.position.y - r.size.y, r.size.x, r.size.y)
			3: # 270° CW: (x, y, w, h) -> (y, 1.0 - x - w, h, w)
				new_r = Rect2(r.position.y, 1.0 - r.position.x - r.size.x, r.size.y, r.size.x)

		# Asegurar que las coordenadas permanezcan en [0, 1]
		new_r.position.x = clampf(new_r.position.x, 0.0, 1.0)
		new_r.position.y = clampf(new_r.position.y, 0.0, 1.0)

		result.append({
			"rect": new_r,
			"tone": tone,
			"size_class": size_class
		})

	return result

## Refleja horizontal y/o verticalmente un layout normalizado
static func flip_layout(layout: Array, flip_x: bool, flip_y: bool) -> Array:
	if not flip_x and not flip_y:
		return layout.duplicate(true)

	var result: Array = []
	for item in layout:
		var r: Rect2 = item["rect"]
		var tone: float = item.get("tone", 0.0)
		var size_class: int = item.get("size_class", 1)

		var nx: float = (1.0 - r.position.x - r.size.x) if flip_x else r.position.x
		var ny: float = (1.0 - r.position.y - r.size.y) if flip_y else r.position.y

		result.append({
			"rect": Rect2(clampf(nx, 0.0, 1.0), clampf(ny, 0.0, 1.0), r.size.x, r.size.y),
			"tone": tone,
			"size_class": size_class
		})

	return result

## Retorna un layout transformado combinando índice base (0..7), rotación (0..3) y reflejo
static func get_transformed_layout(
	layout_idx: int,
	rotation_steps: int = 0,
	flip_x: bool = false,
	flip_y: bool = false
) -> Array:
	var base = get_base_layout(layout_idx)
	var rotated = rotate_layout_90(base, rotation_steps)
	return flip_layout(rotated, flip_x, flip_y)

# ==============================================================================
# DEFINICIÓN DE LAS 8 FAMILIAS DE LAYOUTS BASE NORMALIZADOS [0.0, 1.0]
# ==============================================================================

# Layout 0: Megalito Central dominante rodeado de losas perimetrales (8 losas)
static func _layout_0_megalith_center() -> Array[Dictionary]:
	return [
		# Megalito central amplio (LARGE)
		{"rect": Rect2(0.24, 0.24, 0.52, 0.52), "tone": 0.05, "size_class": 2},
		# Borde Norte
		{"rect": Rect2(0.0, 0.0, 0.48, 0.22), "tone": -0.04, "size_class": 1},
		{"rect": Rect2(0.50, 0.0, 0.50, 0.22), "tone": 0.08, "size_class": 1},
		# Borde Este
		{"rect": Rect2(0.78, 0.24, 0.22, 0.52), "tone": -0.06, "size_class": 1},
		# Borde Sur
		{"rect": Rect2(0.0, 0.78, 0.54, 0.22), "tone": 0.06, "size_class": 1},
		{"rect": Rect2(0.56, 0.78, 0.44, 0.22), "tone": -0.03, "size_class": 1},
		# Borde Oeste
		{"rect": Rect2(0.0, 0.24, 0.22, 0.26), "tone": 0.02, "size_class": 0},
		{"rect": Rect2(0.0, 0.52, 0.22, 0.24), "tone": -0.08, "size_class": 0},
	]

# Layout 1: Aparejo de Espiga / Ladrillado Modular Alternado (10 losas)
static func _layout_1_herringbone_masonry() -> Array[Dictionary]:
	return [
		{"rect": Rect2(0.0, 0.0, 0.60, 0.28), "tone": 0.04, "size_class": 1},
		{"rect": Rect2(0.62, 0.0, 0.38, 0.48), "tone": -0.05, "size_class": 1},
		{"rect": Rect2(0.0, 0.30, 0.32, 0.42), "tone": 0.07, "size_class": 0},
		{"rect": Rect2(0.34, 0.30, 0.26, 0.42), "tone": -0.02, "size_class": 0},
		{"rect": Rect2(0.62, 0.50, 0.38, 0.24), "tone": 0.09, "size_class": 0},
		{"rect": Rect2(0.0, 0.74, 0.46, 0.26), "tone": -0.06, "size_class": 1},
		{"rect": Rect2(0.48, 0.76, 0.52, 0.24), "tone": 0.03, "size_class": 1},
		{"rect": Rect2(0.62, 0.76, 0.38, 0.24), "tone": -0.07, "size_class": 0},
		{"rect": Rect2(0.34, 0.50, 0.26, 0.22), "tone": 0.01, "size_class": 0},
		{"rect": Rect2(0.0, 0.52, 0.32, 0.20), "tone": -0.04, "size_class": 0},
	]

# Layout 2: Asimétrico de 3 Filas con Desfase Escalonado (11 losas)
static func _layout_2_asymmetric_3_row() -> Array[Dictionary]:
	return [
		# Fila 1 (Norte)
		{"rect": Rect2(0.0, 0.0, 0.38, 0.32), "tone": 0.06, "size_class": 1},
		{"rect": Rect2(0.40, 0.0, 0.32, 0.32), "tone": -0.04, "size_class": 0},
		{"rect": Rect2(0.74, 0.0, 0.26, 0.32), "tone": 0.08, "size_class": 0},
		# Fila 2 (Centro)
		{"rect": Rect2(0.0, 0.34, 0.28, 0.34), "tone": -0.08, "size_class": 0},
		{"rect": Rect2(0.30, 0.34, 0.44, 0.34), "tone": 0.05, "size_class": 1},
		{"rect": Rect2(0.76, 0.34, 0.24, 0.34), "tone": -0.02, "size_class": 0},
		# Fila 3 (Sur)
		{"rect": Rect2(0.0, 0.70, 0.46, 0.30), "tone": 0.03, "size_class": 1},
		{"rect": Rect2(0.48, 0.70, 0.24, 0.30), "tone": -0.06, "size_class": 0},
		{"rect": Rect2(0.74, 0.70, 0.26, 0.30), "tone": 0.09, "size_class": 0},
		# Cuñas de transición
		{"rect": Rect2(0.0, 0.16, 0.18, 0.16), "tone": -0.03, "size_class": 0},
		{"rect": Rect2(0.82, 0.16, 0.18, 0.16), "tone": 0.04, "size_class": 0},
	]

# Layout 3: Cuadrantes Subdivididos (12 losas)
static func _layout_3_quad_grid() -> Array[Dictionary]:
	return [
		# Cuadrante NW (Dividido en 2)
		{"rect": Rect2(0.0, 0.0, 0.48, 0.23), "tone": 0.04, "size_class": 0},
		{"rect": Rect2(0.0, 0.25, 0.48, 0.23), "tone": -0.05, "size_class": 0},
		# Cuadrante NE (Losa sólida grande)
		{"rect": Rect2(0.50, 0.0, 0.50, 0.48), "tone": 0.07, "size_class": 2},
		# Cuadrante SW (Losa sólida grande)
		{"rect": Rect2(0.0, 0.50, 0.48, 0.50), "tone": -0.03, "size_class": 2},
		# Cuadrante SE (Dividido en 4 pequeñas)
		{"rect": Rect2(0.50, 0.50, 0.24, 0.24), "tone": 0.08, "size_class": 0},
		{"rect": Rect2(0.76, 0.50, 0.24, 0.24), "tone": -0.06, "size_class": 0},
		{"rect": Rect2(0.50, 0.76, 0.24, 0.24), "tone": -0.02, "size_class": 0},
		{"rect": Rect2(0.76, 0.76, 0.24, 0.24), "tone": 0.05, "size_class": 0},
		# Losas de ajuste
		{"rect": Rect2(0.24, 0.0, 0.24, 0.23), "tone": -0.07, "size_class": 0},
		{"rect": Rect2(0.0, 0.25, 0.24, 0.23), "tone": 0.02, "size_class": 0},
		{"rect": Rect2(0.24, 0.50, 0.24, 0.24), "tone": 0.06, "size_class": 0},
		{"rect": Rect2(0.50, 0.25, 0.24, 0.23), "tone": -0.04, "size_class": 0},
	]

# Layout 4: Esquina Partida con Losas L (9 losas)
static func _layout_4_split_corner() -> Array[Dictionary]:
	return [
		{"rect": Rect2(0.0, 0.0, 0.68, 0.48), "tone": 0.05, "size_class": 2},
		{"rect": Rect2(0.70, 0.0, 0.30, 0.48), "tone": -0.06, "size_class": 1},
		{"rect": Rect2(0.0, 0.50, 0.32, 0.50), "tone": 0.08, "size_class": 1},
		{"rect": Rect2(0.34, 0.50, 0.34, 0.24), "tone": -0.04, "size_class": 0},
		{"rect": Rect2(0.70, 0.50, 0.30, 0.24), "tone": 0.03, "size_class": 0},
		{"rect": Rect2(0.34, 0.76, 0.34, 0.24), "tone": 0.07, "size_class": 0},
		{"rect": Rect2(0.70, 0.76, 0.30, 0.24), "tone": -0.08, "size_class": 0},
		{"rect": Rect2(0.0, 0.0, 0.32, 0.24), "tone": -0.02, "size_class": 0},
		{"rect": Rect2(0.34, 0.0, 0.34, 0.24), "tone": 0.06, "size_class": 0},
	]

# Layout 5: Tejido Cruzado (10 losas)
static func _layout_5_cross_weave() -> Array[Dictionary]:
	return [
		{"rect": Rect2(0.32, 0.0, 0.36, 0.48), "tone": 0.06, "size_class": 1},
		{"rect": Rect2(0.32, 0.52, 0.36, 0.48), "tone": -0.04, "size_class": 1},
		{"rect": Rect2(0.0, 0.32, 0.30, 0.36), "tone": 0.09, "size_class": 0},
		{"rect": Rect2(0.70, 0.32, 0.30, 0.36), "tone": -0.07, "size_class": 0},
		{"rect": Rect2(0.0, 0.0, 0.30, 0.30), "tone": -0.05, "size_class": 0},
		{"rect": Rect2(0.70, 0.0, 0.30, 0.30), "tone": 0.04, "size_class": 0},
		{"rect": Rect2(0.0, 0.70, 0.30, 0.30), "tone": 0.02, "size_class": 0},
		{"rect": Rect2(0.70, 0.70, 0.30, 0.30), "tone": -0.03, "size_class": 0},
		{"rect": Rect2(0.0, 0.32, 0.14, 0.36), "tone": 0.05, "size_class": 0},
		{"rect": Rect2(0.86, 0.32, 0.14, 0.36), "tone": -0.06, "size_class": 0},
	]

# Layout 6: Losas Escalonadas con Aspecto Alargado (11 losas)
static func _layout_6_stepped_flags() -> Array[Dictionary]:
	return [
		{"rect": Rect2(0.0, 0.0, 0.52, 0.36), "tone": 0.05, "size_class": 1},
		{"rect": Rect2(0.54, 0.0, 0.46, 0.22), "tone": -0.08, "size_class": 0},
		{"rect": Rect2(0.54, 0.24, 0.46, 0.24), "tone": 0.06, "size_class": 0},
		{"rect": Rect2(0.0, 0.38, 0.32, 0.34), "tone": -0.03, "size_class": 0},
		{"rect": Rect2(0.34, 0.38, 0.32, 0.34), "tone": 0.08, "size_class": 0},
		{"rect": Rect2(0.68, 0.50, 0.32, 0.50), "tone": -0.05, "size_class": 1},
		{"rect": Rect2(0.0, 0.74, 0.32, 0.26), "tone": 0.02, "size_class": 0},
		{"rect": Rect2(0.34, 0.74, 0.32, 0.26), "tone": -0.06, "size_class": 0},
		{"rect": Rect2(0.0, 0.0, 0.24, 0.36), "tone": 0.07, "size_class": 0},
		{"rect": Rect2(0.26, 0.0, 0.26, 0.36), "tone": -0.04, "size_class": 0},
		{"rect": Rect2(0.68, 0.50, 0.32, 0.24), "tone": 0.04, "size_class": 0},
	]

# Layout 7: Adoquines Densos Estilizados (14 losas)
static func _layout_7_dense_pavers() -> Array[Dictionary]:
	return [
		{"rect": Rect2(0.0, 0.0, 0.32, 0.24), "tone": 0.06, "size_class": 0},
		{"rect": Rect2(0.34, 0.0, 0.32, 0.24), "tone": -0.05, "size_class": 0},
		{"rect": Rect2(0.68, 0.0, 0.32, 0.24), "tone": 0.08, "size_class": 0},
		{"rect": Rect2(0.0, 0.26, 0.22, 0.34), "tone": -0.07, "size_class": 0},
		{"rect": Rect2(0.24, 0.26, 0.44, 0.34), "tone": 0.04, "size_class": 1},
		{"rect": Rect2(0.70, 0.26, 0.30, 0.34), "tone": -0.03, "size_class": 0},
		{"rect": Rect2(0.0, 0.62, 0.40, 0.38), "tone": 0.07, "size_class": 1},
		{"rect": Rect2(0.42, 0.62, 0.28, 0.18), "tone": -0.06, "size_class": 0},
		{"rect": Rect2(0.72, 0.62, 0.28, 0.18), "tone": 0.02, "size_class": 0},
		{"rect": Rect2(0.42, 0.82, 0.28, 0.18), "tone": 0.05, "size_class": 0},
		{"rect": Rect2(0.72, 0.82, 0.28, 0.18), "tone": -0.08, "size_class": 0},
		{"rect": Rect2(0.0, 0.62, 0.20, 0.38), "tone": -0.02, "size_class": 0},
		{"rect": Rect2(0.22, 0.62, 0.18, 0.38), "tone": 0.08, "size_class": 0},
		{"rect": Rect2(0.24, 0.26, 0.22, 0.34), "tone": -0.04, "size_class": 0},
	]
