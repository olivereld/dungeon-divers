class_name DecorationPlacementScorer
extends RefCounted

## Evaluador heurístico determinista para candidatos de colocación de props y fixtures.
## Aplica bonificaciones (centralidad focal, alineación, simetría) y penalizaciones (puertas, saturación).

const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")

func score_candidate(
	candidate,
	comp_role: int,
	occupancy,
	room_center_cell: Vector2i,
	door_cells: Array[Vector2i] = [],
	seed_val: int = 1337,
	primary_cells: Array[Vector2i] = []
) -> float:
	if candidate == null:
		return -1000.0

	var total_score: float = 100.0
	var cell: Vector2i = candidate.cell

	# 1. Idoneidad respecto al centro de la habitación y al PRIMARY spatial anchor
	var dist_to_center: float = Vector2(cell).distance_to(Vector2(room_center_cell))

	match comp_role:
		_CompositionRoleScript.Role.PRIMARY:
			# Bonificación por proximidad al centro (foco visual principal)
			total_score += maxf(0.0, 50.0 - dist_to_center * 12.0)

		_CompositionRoleScript.Role.SECONDARY, _CompositionRoleScript.Role.COMPANION:
			if not primary_cells.is_empty():
				# Subordinación al Primary: calcular distancia mínima al objeto principal
				var min_dist_primary: float = 999.0
				for p_cell in primary_cells:
					var d = Vector2(cell).distance_to(Vector2(p_cell))
					if d < min_dist_primary:
						min_dist_primary = d

				if min_dist_primary < 1.5:
					# Penalización severa por apelotonamiento sobre el objeto focal
					total_score -= 50.0
				elif min_dist_primary >= 1.8 and min_dist_primary <= 3.8:
					# Bonificación óptima por flanqueo y acompañamiento armónico
					total_score += 35.0 - absf(min_dist_primary - 2.5) * 6.0
				else:
					# Decaimiento progresivo si está demasiado disperso
					total_score += maxf(0.0, 15.0 - min_dist_primary * 2.0)
			else:
				# Fallback sin primary: preferencia por zonas intermedias
				total_score += maxf(0.0, 20.0 - absf(dist_to_center - 2.0) * 8.0)

		_CompositionRoleScript.Role.DETAIL:
			# Los detalles prefieren esquinas o zonas perimetrales no focales
			total_score += dist_to_center * 4.0
			if not primary_cells.is_empty():
				for p_cell in primary_cells:
					if Vector2(cell).distance_to(Vector2(p_cell)) < 2.0:
						total_score -= 20.0 # No ensuciar el foco con debris menor

	# 2. Penalización por proximidad a puertas (evitar congestión de paso)
	for d_cell in door_cells:
		var dist_door = absi(cell.x - d_cell.x) + absi(cell.y - d_cell.y) # Manhattan
		if dist_door <= 1:
			total_score -= 80.0
		elif dist_door == 2:
			total_score -= 30.0

	# 3. Penalización por despejes cercanos ocupados
	if occupancy != null and occupancy.has_clearance(cell):
		total_score -= 40.0

	# 4. Modulación pseudoaleatoria determinista para evitar patrones rígidos
	var hash_mod: float = float((cell.x * 73856093 ^ cell.y * 19349663 ^ seed_val) & 0xFF) / 255.0
	total_score += hash_mod * 8.0

	return total_score
