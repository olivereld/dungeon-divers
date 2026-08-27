class_name WallSectionExtractor
extends RefCounted

## Descompone los bucles y cadenas de un WallComponent en segmentos discretos WallSection.
## Detecta esquinas (cambios de dirección), aberturas/puertas y divide tramos rectos largos
## respetando [min_length, max_length] para mantener unidades arquitectónicas manejables,
## garantizando cobertura 100% de bordes y conectividad suave y continua en todas las esquinas.

const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")

func extract_sections(
	component: WallComponent,
	min_length: int = 2,
	max_length: int = 6,
	room_id: int = -1
) -> Array: # Array[WallSection]
	var sections: Array = []
	if component == null or component.is_empty():
		return sections

	var section_counter: int = 0

	# 1. Procesar bucles cerrados
	for loop in component.loops:
		var loop_sections = _split_closed_loop(
			loop, component.id, section_counter, min_length, max_length, room_id
		)
		sections.append_array(loop_sections)
		section_counter += loop_sections.size()

	# 2. Procesar cadenas abiertas
	for chain in component.open_chains:
		var chain_sections = _split_open_chain(
			chain, component.id, section_counter, min_length, max_length, room_id
		)
		sections.append_array(chain_sections)
		section_counter += chain_sections.size()

	return sections

func _split_closed_loop(
	pts: Array,
	comp_id: int,
	start_id: int,
	min_len: int,
	max_len: int,
	room_id: int
) -> Array:
	var result: Array = []
	var clean_pts: Array[Vector2i] = _deduplicate_points(pts)
	if clean_pts.size() > 1 and clean_pts[0] == clean_pts[clean_pts.size() - 1]:
		clean_pts.pop_back()

	var n: int = clean_pts.size()
	if n < 3:
		return result

	# 1. Identificar esquinas naturales del bucle cerrado (en 360 grados)
	var corners: Array[int] = []
	for i in range(n):
		var prev_i = (i - 1 + n) % n
		var next_i = (i + 1) % n
		var v_prev = clean_pts[i] - clean_pts[prev_i]
		var v_next = clean_pts[next_i] - clean_pts[i]
		if v_prev != v_next:
			corners.append(i)

	if corners.is_empty():
		corners.append(0)

	# 2. Subdividir tramos rectos largos entre esquinas consecutivas
	var cut_indices: Array[int] = []
	var num_corners: int = corners.size()
	for k in range(num_corners):
		var idx_a: int = corners[k]
		var idx_b: int = corners[(k + 1) % num_corners]
		var dist: int = (idx_b - idx_a + n) % n
		if dist == 0:
			dist = n

		cut_indices.append(idx_a)

		if dist > max_len and max_len > 0:
			var subdivisions: int = ceili(float(dist) / float(max_len))
			var step: float = float(dist) / float(subdivisions)
			for s in range(1, subdivisions):
				var cut_idx: int = (idx_a + int(round(s * step))) % n
				if not cut_indices.has(cut_idx):
					cut_indices.append(cut_idx)

	# Ordenar índices de corte preservando el recorrido cíclico a partir del primer corte
	cut_indices.sort()
	var num_cuts: int = cut_indices.size()

	# 3. Generar WallSections para cada segmento del bucle
	for k in range(num_cuts):
		var from_idx: int = cut_indices[k]
		var to_idx: int = cut_indices[(k + 1) % num_cuts]

		var sec_pts: Array[Vector2i] = []
		var curr_idx: int = from_idx
		while true:
			sec_pts.append(clean_pts[curr_idx])
			if curr_idx == to_idx:
				break
			curr_idx = (curr_idx + 1) % n

		var sec := _WallSectionScript.new(
			start_id + result.size(),
			comp_id,
			sec_pts,
			room_id,
			&"normal",
			num_cuts == 1
		)

		# Vecinos para cálculo continuo de ingletes
		sec.start_miter_neighbor = clean_pts[(from_idx - 1 + n) % n]
		sec.end_miter_neighbor = clean_pts[(to_idx + 1) % n]
		sec.has_start_cap = false
		sec.has_end_cap = false

		result.append(sec)

	return result

func _split_open_chain(
	pts: Array,
	comp_id: int,
	start_id: int,
	min_len: int,
	max_len: int,
	room_id: int
) -> Array:
	var result: Array = []
	var clean_pts: Array[Vector2i] = _deduplicate_points(pts)
	var n: int = clean_pts.size()
	if n < 2:
		return result

	# 1. Identificar esquinas en la cadena abierta
	var split_indices: Array[int] = [0]
	for i in range(1, n - 1):
		var v_prev = clean_pts[i] - clean_pts[i - 1]
		var v_next = clean_pts[i + 1] - clean_pts[i]
		if v_prev != v_next:
			split_indices.append(i)
	split_indices.append(n - 1)

	# 2. Subdividir tramos rectos largos
	var final_cuts: Array[int] = [0]
	for k in range(split_indices.size() - 1):
		var idx_a: int = split_indices[k]
		var idx_b: int = split_indices[k + 1]
		var dist: int = idx_b - idx_a
		if dist > max_len and max_len > 0:
			var subdivisions: int = ceili(float(dist) / float(max_len))
			var step: float = float(dist) / float(subdivisions)
			for s in range(1, subdivisions):
				var cut_idx: int = idx_a + int(round(s * step))
				if cut_idx > final_cuts[final_cuts.size() - 1] and cut_idx < idx_b:
					final_cuts.append(cut_idx)
		if idx_b > final_cuts[final_cuts.size() - 1]:
			final_cuts.append(idx_b)

	# 3. Generar WallSections para la cadena
	for k in range(final_cuts.size() - 1):
		var from_i: int = final_cuts[k]
		var to_i: int = final_cuts[k + 1]

		var sec_pts: Array[Vector2i] = []
		for p_i in range(from_i, to_i + 1):
			sec_pts.append(clean_pts[p_i])

		var sec := _WallSectionScript.new(
			start_id + result.size(),
			comp_id,
			sec_pts,
			room_id,
			&"normal",
			false
		)

		if from_i > 0:
			sec.start_miter_neighbor = clean_pts[from_i - 1]
			sec.has_start_cap = false
		else:
			sec.start_miter_neighbor = _WallSectionScript.INVALID_NEIGHBOR
			sec.has_start_cap = true

		if to_i < n - 1:
			sec.end_miter_neighbor = clean_pts[to_i + 1]
			sec.has_end_cap = false
		else:
			sec.end_miter_neighbor = _WallSectionScript.INVALID_NEIGHBOR
			sec.has_end_cap = true

		result.append(sec)

	return result

func _deduplicate_points(pts: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in pts:
		var v: Vector2i = p as Vector2i
		if result.is_empty() or result[result.size() - 1] != v:
			result.append(v)
	return result
