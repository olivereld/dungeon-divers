class_name CompositionStrategy
extends RefCounted

## Estrategia de Composición Espacial Global (Global Composition-Guided Room Placement).
## Consume la composición espacial global (SpatialComposition) derivada de MissionGraph + SpatialIntent
## para guiar la colocación física de habitaciones mediante evaluación multivariada no mutante.
##
## Principios Arquitectónicos:
## - Guiado global: Utiliza SpatialComposition.get_anchor_target(room_id) como target espacial primario.
## - Sin cálculos locales duplicados: Elimina offsets rígidos locales y proyecciones independientes.
## - Restricciones duras: Límites de bounds, separación mínima entre salas, min_mission_edge_distance y separación START/BOSS.
## - max_mission_edge_distance NO es hard constraint (se maneja por puntuación suave).
## - No muta RoomData, MissionGraph ni CellGrid.
## - Produce un RoomPlacementPlan inmutable y sellado.

const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")
const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const SpatialIntentBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
const SpatialComposition = preload("res://src/dungeon_generator/core/data/spatial_composition.gd")
const SpatialCompositionBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_composition_builder.gd")

const REGION_START: StringName = &"region_start"
const REGION_EARLY: StringName = &"region_early"
const REGION_MID: StringName = &"region_mid"
const REGION_LATE: StringName = &"region_late"
const REGION_BOSS: StringName = &"region_boss"
const REGION_BRANCH: StringName = &"region_branch"
const REGION_OPTIONAL: StringName = &"region_optional"
const REGION_MAIN_PATH: StringName = &"region_main_path"

const _DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)
]

var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator = null) -> void:
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()

## Genera un plan de colocación espacial sellado (RoomPlacementPlan) guiado por SpatialComposition.
## Acepta SpatialComposition directamente, o lo construye desde MissionGraph / SpatialIntent si no se provee.
func create_placement_plan(
	rooms: Array[RoomData],
	mission_graph_or_composition = null,
	bounds: Rect2i = Rect2i(),
	config: SpaceGrammarConfig = null,
	spatial_intent_or_composition = null,
	spatial_composition: SpatialComposition = null
) -> RoomPlacementPlan:
	var plan := RoomPlacementPlan.new()
	if rooms.is_empty():
		plan.seal()
		return plan

	# 1. Resolver MissionGraph y SpatialComposition desde los argumentos polimórficos
	var mission_graph: DungeonGraph = null
	var comp: SpatialComposition = null

	if mission_graph_or_composition is SpatialComposition:
		comp = mission_graph_or_composition
	elif mission_graph_or_composition is DungeonGraph:
		mission_graph = mission_graph_or_composition

	if spatial_composition != null:
		comp = spatial_composition
	elif comp == null and spatial_intent_or_composition is SpatialComposition:
		comp = spatial_intent_or_composition

	# Si aún no tenemos SpatialComposition, construirla canónicamente
	if comp == null:
		var comp_builder := SpatialCompositionBuilder.new(_rng)
		comp = comp_builder.build(mission_graph, spatial_intent_or_composition, config, bounds)

	# 2. Extraer parámetros de configuración
	var preferred_distance: float = config.mission_aware_preferred_distance if config != null else 12.0
	var candidate_count: int = config.mission_aware_candidate_count if config != null else 15
	var distance_jitter: float = config.mission_aware_distance_jitter if config != null else 4.0
	var min_separation: int = config.min_room_separation if config != null else 2
	var min_edge_dist: float = config.min_mission_edge_distance if config != null else 6.0
	var progression_strength: float = config.progression_strength if config != null else 1.0
	var density_strength: float = config.density_strength if config != null else 0.5

	# 3. Indexar salas por ID y por mission_node_id
	var room_by_id: Dictionary = {}
	var room_by_node_id: Dictionary = {}
	for r in rooms:
		if r != null:
			room_by_id[r.id] = r
			if r.mission_node_id >= 0:
				room_by_node_id[r.mission_node_id] = r

	# 4. Orden de procesamiento guiado por SpatialComposition (Main Path primero, luego Branches)
	var ordered_rooms: Array[RoomData] = []
	var visited_rooms: Dictionary = {}

	# 4a. Main Path en orden estricto de progresión
	var main_path_ids: Array[int] = comp.main_path_node_ids
	for nid in main_path_ids:
		var r: RoomData = null
		if room_by_node_id.has(nid):
			r = room_by_node_id[nid]
		elif room_by_id.has(nid):
			r = room_by_id[nid]
		if r != null and not visited_rooms.has(r.id):
			visited_rooms[r.id] = true
			ordered_rooms.append(r)

	# 4b. Ramas secundarias (Side branches) ordenadas por dependencia topológica
	var all_comp_nodes: Array[int] = comp.get_all_node_ids()
	for nid in all_comp_nodes:
		if comp.is_main_path(nid):
			continue
		var r: RoomData = null
		if room_by_node_id.has(nid):
			r = room_by_node_id[nid]
		elif room_by_id.has(nid):
			r = room_by_id[nid]
		if r != null and not visited_rooms.has(r.id):
			visited_rooms[r.id] = true
			ordered_rooms.append(r)

	# 4c. Salas restantes no mapeadas
	for r in rooms:
		if r != null and not visited_rooms.has(r.id):
			visited_rooms[r.id] = true
			ordered_rooms.append(r)

	# 5. Colocación de Salas
	var placed_rects: Dictionary = {} # room_id -> Rect2i
	var start_center := Vector2.ZERO
	var prev_main_center := Vector2.ZERO

	for room in ordered_rooms:
		var size: Vector2i = room.rect.size
		var node_id: int = _resolve_node_id(comp, room)
		var is_main: bool = comp.is_main_path(node_id)
		var region: StringName = comp.get_region(node_id)
		var priority: int = _determine_priority(room, region)

		var global_target: Vector2 = _get_room_target(comp, room)
		var best_pos: Vector2i = Vector2i.MIN

		var is_start_room: bool = (
			room.room_type == RoomData.RoomType.START
			or room.room_type == &"start"
			or region == REGION_START
			or (placed_rects.is_empty() and is_main)
		)

		if is_start_room:
			best_pos = _place_start_room(size, bounds, global_target, comp.progression_direction)
			if best_pos != Vector2i.MIN:
				start_center = Vector2(best_pos) + Vector2(size) / 2.0
				prev_main_center = start_center
		else:
			best_pos = _find_best_position(
				room,
				size,
				node_id,
				comp,
				mission_graph,
				bounds,
				placed_rects,
				room_by_id,
				room_by_node_id,
				start_center,
				prev_main_center,
				preferred_distance,
				candidate_count,
				distance_jitter,
				min_separation,
				min_edge_dist,
				progression_strength,
				density_strength
			)
			if best_pos != Vector2i.MIN and is_main:
				prev_main_center = Vector2(best_pos) + Vector2(size) / 2.0

		if best_pos != Vector2i.MIN:
			placed_rects[room.id] = Rect2i(best_pos, size)
			plan.add_entry(room.id, best_pos, region, priority)
		else:
			push_warning("[CompositionStrategy] Failed to find valid placement for room %d (type=%s, node=%d). Refusing invalid placement." % [
				room.id, str(room.room_type), node_id
			])

	plan.seal()
	return plan

## Coloca la sala START en torno a su target global dentro de los límites estrictos.
func _place_start_room(size: Vector2i, bounds: Rect2i, target_pos: Vector2, progression_dir: Vector2) -> Vector2i:
	if size.x > bounds.size.x or size.y > bounds.size.y:
		return Vector2i.MIN

	var max_x: int = bounds.end.x - size.x
	var max_y: int = bounds.end.y - size.y
	if max_x < bounds.position.x or max_y < bounds.position.y:
		return Vector2i.MIN

	var base_center := target_pos
	if base_center == Vector2.ZERO:
		base_center = Vector2(bounds.position + bounds.size / 2) - progression_dir * 8.0

	for attempt in range(16):
		var ox: int = 0
		var oy: int = 0
		if attempt > 0:
			var damp: float = 1.0 - float(attempt) / 16.0
			ox = _rng.randi_range(-4, 4) + int(progression_dir.x * -2.0 * damp)
			oy = _rng.randi_range(-4, 4) + int(progression_dir.y * -2.0 * damp)

		var cand := Vector2i(int(base_center.x - size.x / 2.0) + ox, int(base_center.y - size.y / 2.0) + oy)
		if bounds.encloses(Rect2i(cand, size)):
			return cand

	var fallback_center := Vector2i(int(base_center.x - size.x / 2.0), int(base_center.y - size.y / 2.0))
	fallback_center.x = clampi(fallback_center.x, bounds.position.x, bounds.end.x - size.x)
	fallback_center.y = clampi(fallback_center.y, bounds.position.y, bounds.end.y - size.y)
	if bounds.encloses(Rect2i(fallback_center, size)):
		return fallback_center

	return Vector2i.MIN

## Encuentra la mejor posición para una sala evaluando candidatos contra el target global de SpatialComposition.
func _find_best_position(
	room: RoomData,
	size: Vector2i,
	node_id: int,
	comp: SpatialComposition,
	mission_graph: DungeonGraph,
	bounds: Rect2i,
	placed_rects: Dictionary,
	room_by_id: Dictionary,
	room_by_node_id: Dictionary,
	start_center: Vector2,
	prev_main_center: Vector2,
	preferred_distance: float,
	candidate_count: int,
	distance_jitter: float,
	min_separation: int,
	min_edge_dist: float,
	progression_strength: float,
	density_strength: float
) -> Vector2i:
	var global_target: Vector2 = _get_room_target(comp, room)
	var is_main: bool = comp.is_main_path(node_id)
	var prog_dir: Vector2 = comp.progression_direction
	var perp_dir := Vector2(-prog_dir.y, prog_dir.x)

	# 1. Recopilar vecinos de misión ya colocados
	var neighbor_rects: Array[Rect2i] = []
	if mission_graph != null and node_id >= 0:
		var neighbor_ids: Array[int] = mission_graph.get_neighbors(node_id)
		for other_id in placed_rects:
			var other_room: RoomData = room_by_id.get(other_id)
			if other_room != null:
				var other_node: int = _resolve_node_id(comp, other_room)
				if other_node in neighbor_ids:
					neighbor_rects.append(placed_rects[other_id])

	# 2. Determinar ancla espacial para generación de candidatos
	var anchor: Vector2
	var main_anchor_center := Vector2.ZERO
	if not is_main:
		var branch_anchor_nid: int = comp.get_branch_anchor(node_id)
		if branch_anchor_nid >= 0:
			var anchor_room: RoomData = null
			if room_by_node_id.has(branch_anchor_nid):
				anchor_room = room_by_node_id[branch_anchor_nid]
			elif room_by_id.has(branch_anchor_nid):
				anchor_room = room_by_id[branch_anchor_nid]
			if anchor_room != null and placed_rects.has(anchor_room.id):
				var ar: Rect2i = placed_rects[anchor_room.id]
				main_anchor_center = Vector2(ar.position) + Vector2(ar.size) / 2.0

	if not neighbor_rects.is_empty():
		var sum := Vector2.ZERO
		for nr in neighbor_rects:
			sum += Vector2(nr.position) + Vector2(nr.size) / 2.0
		anchor = sum / float(neighbor_rects.size())
	elif not is_main and main_anchor_center != Vector2.ZERO:
		anchor = main_anchor_center
	elif is_main and prev_main_center != Vector2.ZERO:
		anchor = prev_main_center
	elif global_target != Vector2.ZERO:
		anchor = global_target
	else:
		var sum := Vector2.ZERO
		for pr in placed_rects.values():
			sum += Vector2((pr as Rect2i).position) + Vector2((pr as Rect2i).size) / 2.0
		anchor = sum / float(maxi(1, placed_rects.size()))

	# Dirección orientada hacia el target global
	var to_global: Vector2 = (global_target - anchor).normalized() if global_target != Vector2.ZERO else prog_dir
	if to_global.is_zero_approx():
		to_global = prog_dir if not prog_dir.is_zero_approx() else Vector2(1, 0)

	var best_pos: Vector2i = Vector2i.MIN
	var best_score: float = -INF

	# 3. Búsqueda primaria de candidatos
	var attempts: int = candidate_count * 2
	for i in range(attempts):
		var target_center: Vector2

		if global_target != Vector2.ZERO and (i % 2 == 0 or i < 4):
			# Candidato explorando directamente las proximidades de SpatialComposition.get_anchor_target
			var jitter_radius: float = _rng.randf_range(0.0, maxf(distance_jitter, 3.0))
			var jitter_angle: float = _rng.randf() * TAU
			target_center = global_target + Vector2(cos(jitter_angle), sin(jitter_angle)) * jitter_radius
		else:
			var dir: Vector2
			var roll: float = _rng.randf()

			if not is_main and roll < 0.5:
				# Para ramas secundarias: sesgo lateral para ramificarse perpendicularmente del camino principal
				var lat_sign: float = -1.0 if _rng.randf() < 0.5 else 1.0
				var lat_jitter: float = _rng.randf_range(-0.4, 0.4)
				dir = (perp_dir * lat_sign + prog_dir * 0.3).rotated(lat_jitter).normalized()
			elif roll < 0.45:
				# Sesgo hacia el target global de progresión
				var angle_jitter: float = _rng.randf_range(-0.5, 0.5)
				dir = to_global.rotated(angle_jitter).normalized()
			else:
				# Exploración omnidireccional
				var dir_idx: int = _rng.randi_range(0, _DIRECTIONS.size() - 1)
				var angle_jitter: float = _rng.randf_range(-0.3, 0.3)
				dir = _DIRECTIONS[dir_idx].rotated(angle_jitter).normalized()

			var dist: float = preferred_distance + _rng.randf_range(-distance_jitter, distance_jitter)
			target_center = anchor + dir * dist

		var cand_pos := Vector2i(int(target_center.x - size.x / 2.0), int(target_center.y - size.y / 2.0))

		# RESTRICCIÓN DURA: Descarte inmediato si no satisface todas las condiciones
		if not _passes_hard_constraints(cand_pos, size, bounds, placed_rects, neighbor_rects, min_separation, min_edge_dist, start_center, room.room_type, comp, node_id):
			continue

		# SOFT SCORING: Puntuación guiada por SpatialComposition
		var score: float = _score_candidate(
			cand_pos,
			size,
			bounds,
			room,
			node_id,
			is_main,
			comp,
			global_target,
			anchor,
			main_anchor_center,
			start_center,
			prev_main_center,
			neighbor_rects,
			placed_rects,
			room_by_id,
			room_by_node_id,
			preferred_distance,
			progression_strength,
			density_strength
		)

		if score > best_score:
			best_score = score
			best_pos = cand_pos

	if best_pos != Vector2i.MIN:
		return best_pos

	# 4. Búsqueda expandida determinista (filtrada estrictamente por restricciones duras)
	return _expanded_valid_candidate_search(
		room,
		size,
		node_id,
		is_main,
		comp,
		global_target,
		anchor,
		main_anchor_center,
		bounds,
		placed_rects,
		neighbor_rects,
		room_by_id,
		room_by_node_id,
		min_separation,
		min_edge_dist,
		start_center,
		prev_main_center,
		preferred_distance,
		progression_strength,
		density_strength
	)

## Evaluación de Restricciones Duras (Hard Constraints).
## Rechazo inmediato si viola contención en bounds, separación mínima, min_mission_edge_distance o distancia START/BOSS.
## max_mission_edge_distance NO es hard constraint.
func _passes_hard_constraints(
	pos: Vector2i,
	size: Vector2i,
	bounds: Rect2i,
	placed_rects: Dictionary,
	neighbor_rects: Array[Rect2i],
	min_separation: int,
	min_edge_dist: float,
	start_center: Vector2,
	room_type: Variant,
	comp: SpatialComposition,
	node_id: int
) -> bool:
	var cand_rect := Rect2i(pos, size)
	var cand_center := Vector2(pos) + Vector2(size) / 2.0

	# 1. Contención estricta dentro de los límites
	if not bounds.encloses(cand_rect):
		return false

	# 2. Separación mínima contra TODAS las salas colocadas (sin colisiones con margen)
	for pr in placed_rects.values():
		var target_rect: Rect2i = (pr as Rect2i).grow(min_separation) if min_separation > 0 else (pr as Rect2i)
		if cand_rect.intersects(target_rect):
			return false

	# 3. Restricción dura de distancia mínima para vecinos de misión obligatorios
	if not neighbor_rects.is_empty():
		for nr in neighbor_rects:
			var n_center := Vector2(nr.position) + Vector2(nr.size) / 2.0
			var d: float = cand_center.distance_to(n_center)
			if d < min_edge_dist:
				return false

	# 4. Regla de progresión para el BOSS: debe estar separado del START
	var is_boss: bool = (
		room_type == RoomData.RoomType.BOSS
		or room_type == &"boss"
		or room_type == RoomData.RoomType.GOAL
		or room_type == &"goal"
		or comp.get_region(node_id) == SpatialComposition.REGION_BOSS
	)
	if is_boss and start_center != Vector2.ZERO:
		if cand_center.distance_to(start_center) < (min_edge_dist * 1.8):
			return false

	return true

## Evaluación de Puntuación Suave (Soft Scoring).
## Evalúa calidad espacial guiada por SpatialComposition para candidatos que superaron todas las restricciones duras.
func _score_candidate(
	cand_pos: Vector2i,
	size: Vector2i,
	bounds: Rect2i,
	room: RoomData,
	node_id: int,
	is_main: bool,
	comp: SpatialComposition,
	global_target: Vector2,
	anchor: Vector2,
	main_anchor_center: Vector2,
	start_center: Vector2,
	prev_main_center: Vector2,
	neighbor_rects: Array[Rect2i],
	placed_rects: Dictionary,
	room_by_id: Dictionary,
	room_by_node_id: Dictionary,
	preferred_distance: float,
	progression_strength: float,
	density_strength: float
) -> float:
	var cand_center := Vector2(cand_pos) + Vector2(size) / 2.0
	var prog_dir: Vector2 = comp.progression_direction
	var perp_dir := Vector2(-prog_dir.y, prog_dir.x)
	var node_density: float = comp.get_density(node_id)

	# --------------------------------------------------------------------------
	# A. Vecinos de Misión y Conectividad
	# --------------------------------------------------------------------------
	var neighbor_score: float = 0.0
	var excessive_edge_penalty: float = 0.0
	if not neighbor_rects.is_empty():
		for nr in neighbor_rects:
			var n_center := Vector2(nr.position) + Vector2(nr.size) / 2.0
			var d: float = cand_center.distance_to(n_center)
			neighbor_score -= abs(d - preferred_distance)
			if d > preferred_distance * 1.8:
				excessive_edge_penalty += (d - preferred_distance * 1.8) * 1.2
	elif anchor != Vector2.ZERO and global_target == Vector2.ZERO:
		var d: float = cand_center.distance_to(anchor)
		neighbor_score -= abs(d - preferred_distance) * 0.5

	# --------------------------------------------------------------------------
	# B. Target Espacial Global (SpatialComposition.get_anchor_target)
	# --------------------------------------------------------------------------
	var target_score: float = 0.0
	if global_target != Vector2.ZERO:
		var target_dist: float = cand_center.distance_to(global_target)
		target_score = -target_dist * 1.5

	# --------------------------------------------------------------------------
	# C. Puntuación Diferenciada: Main Path vs Branches
	# --------------------------------------------------------------------------
	var role_score: float = 0.0

	if is_main:
		# 1. Alineación con la dirección de progresión global
		var from_start: Vector2 = cand_center - start_center if start_center != Vector2.ZERO else Vector2.ZERO
		if not from_start.is_zero_approx() and not prog_dir.is_zero_approx():
			var factor: float = comp.get_main_path_factor(node_id)
			role_score += from_start.normalized().dot(prog_dir) * 4.0 * maxf(factor, 0.1)

		# 2. Monotonía a lo largo del camino principal
		if prev_main_center != Vector2.ZERO and not prog_dir.is_zero_approx():
			var cand_proj: float = (cand_center - start_center).dot(prog_dir)
			var prev_proj: float = (prev_main_center - start_center).dot(prog_dir)
			if cand_proj < prev_proj:
				# Penalizar severamente retroceso espacial en el camino principal
				role_score -= (prev_proj - cand_proj) * 3.0
			else:
				# Premiar avance monótono ordenado
				role_score += minf(cand_proj - prev_proj, preferred_distance) * 0.6

		# 3. Continuidad con la sala anterior del camino principal
		if prev_main_center != Vector2.ZERO:
			var d_prev: float = cand_center.distance_to(prev_main_center)
			role_score -= abs(d_prev - preferred_distance) * 0.75

	else:
		# --- Branches (Ramas Secundarias) ---
		# 1. Proximidad y coherencia con su ancla principal heredada
		if main_anchor_center != Vector2.ZERO:
			var d_anchor: float = cand_center.distance_to(main_anchor_center)
			role_score -= abs(d_anchor - preferred_distance) * 0.9

			# 2. Desplazamiento lateral (Lateral Offset): premiar alejamiento perpendicular
			var lateral_dist: float = abs((cand_center - main_anchor_center).dot(perp_dir))
			role_score += minf(lateral_dist, preferred_distance) * 0.7

			# 3. Coherencia de progresión: no adelantarse ni atrasarse excesivamente respecto a su ancla
			var anchor_proj: float = (main_anchor_center - start_center).dot(prog_dir)
			var cand_proj: float = (cand_center - start_center).dot(prog_dir)
			role_score -= abs(cand_proj - anchor_proj) * 0.35

		# 4. Separación de otros nodos del Main Path (evitar apiñarse en la espina principal)
		var main_crowding_penalty: float = 0.0
		var branch_anchor_nid: int = comp.get_branch_anchor(node_id)
		for mp_nid in comp.main_path_node_ids:
			if mp_nid == branch_anchor_nid:
				continue
			var mp_room: RoomData = room_by_node_id.get(mp_nid, room_by_id.get(mp_nid, null))
			if mp_room != null and placed_rects.has(mp_room.id):
				var mp_c: Vector2 = Vector2(placed_rects[mp_room.id].position) + Vector2(placed_rects[mp_room.id].size) / 2.0
				var d_mp: float = cand_center.distance_to(mp_c)
				if d_mp < preferred_distance * 0.85:
					main_crowding_penalty += (preferred_distance * 0.85 - d_mp) * 2.0

		role_score -= main_crowding_penalty

		# 5. Evitar colocarse exactamente "entre anclas" consecutivas del main path
		if main_anchor_center != Vector2.ZERO and prev_main_center != Vector2.ZERO and main_anchor_center != prev_main_center:
			var seg_dir := (prev_main_center - main_anchor_center).normalized()
			var to_cand := cand_center - main_anchor_center
			var proj_len: float = to_cand.dot(seg_dir)
			var seg_len: float = main_anchor_center.distance_to(prev_main_center)
			if proj_len > 2.0 and proj_len < seg_len - 2.0:
				var dist_to_segment: float = (to_cand - seg_dir * proj_len).length()
				if dist_to_segment < preferred_distance * 0.6:
					role_score -= (preferred_distance * 0.6 - dist_to_segment) * 3.0

		# 6. Evitar atracción no intencional hacia START o BOSS
		if start_center != Vector2.ZERO and branch_anchor_nid != comp.main_path_node_ids[0]:
			var d_start: float = cand_center.distance_to(start_center)
			if d_start < preferred_distance * 0.9:
				role_score -= (preferred_distance * 0.9 - d_start) * 2.5

		# 7. Evitar dominancia de rama (alejamiento desmedido del dungeon)
		if main_anchor_center != Vector2.ZERO:
			var d_anchor_total: float = cand_center.distance_to(main_anchor_center)
			if d_anchor_total > preferred_distance * 2.2:
				role_score -= (d_anchor_total - preferred_distance * 2.2) * 1.8

	# --------------------------------------------------------------------------
	# D. Densidad por Región y Separación (Breathing Space)
	# --------------------------------------------------------------------------
	var min_dist_to_any: float = INF
	var close_rooms_count: int = 0
	var clustering_metric: float = 0.0

	for pr in placed_rects.values():
		var p_center := Vector2((pr as Rect2i).position) + Vector2((pr as Rect2i).size) / 2.0
		var d: float = cand_center.distance_to(p_center)
		min_dist_to_any = minf(min_dist_to_any, d)
		if d < 18.0:
			close_rooms_count += 1
		clustering_metric += 1.0 / maxf(d, 1.0)

	var separation_score: float = 0.0
	if min_dist_to_any != INF:
		separation_score = min_dist_to_any * 0.35

	# Modulación de clustering por node_density
	var effective_density: float = node_density * density_strength
	var excessive_clustering_penalty: float = 0.0
	if close_rooms_count > 2:
		excessive_clustering_penalty = float(close_rooms_count - 2) * 5.0 * effective_density
	excessive_clustering_penalty += clustering_metric * 2.5 * effective_density

	var excessive_distance_penalty: float = 0.0
	var max_allowed_dist: float = preferred_distance * 2.2
	if global_target != Vector2.ZERO:
		max_allowed_dist = maxf(max_allowed_dist, preferred_distance * 3.5)
	if min_dist_to_any > max_allowed_dist:
		excessive_distance_penalty = (min_dist_to_any - max_allowed_dist) * 1.5

	# --------------------------------------------------------------------------
	# E. Forma Global y Desempate Determinista
	# --------------------------------------------------------------------------
	var bounds_center := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	var global_shape_score: float = -cand_center.distance_to(bounds_center) * 0.05
	var jitter: float = _rng.randf() * 0.05

	const W_NEIGHBOR := 1.0
	const W_TARGET := 1.2
	const W_ROLE := 1.0
	const W_SEPARATION := 0.3

	var total_score: float = (
		(W_NEIGHBOR * neighbor_score)
		+ (W_TARGET * target_score)
		+ (progression_strength * W_ROLE * role_score)
		+ (W_SEPARATION * separation_score)
		+ global_shape_score
		- excessive_edge_penalty
		- excessive_clustering_penalty
		- excessive_distance_penalty
		+ jitter
	)

	return total_score

## Búsqueda expandida determinista cuando la búsqueda primaria no encontró candidatos válidos.
func _expanded_valid_candidate_search(
	room: RoomData,
	size: Vector2i,
	node_id: int,
	is_main: bool,
	comp: SpatialComposition,
	global_target: Vector2,
	anchor: Vector2,
	main_anchor_center: Vector2,
	bounds: Rect2i,
	placed_rects: Dictionary,
	neighbor_rects: Array[Rect2i],
	room_by_id: Dictionary,
	room_by_node_id: Dictionary,
	min_separation: int,
	min_edge_dist: float,
	start_center: Vector2,
	prev_main_center: Vector2,
	preferred_distance: float,
	progression_strength: float,
	density_strength: float
) -> Vector2i:
	var best_pos: Vector2i = Vector2i.MIN
	var best_score: float = -INF

	var search_origins: Array[Vector2] = [anchor]
	if global_target != Vector2.ZERO and global_target != anchor:
		search_origins.append(global_target)

	for origin in search_origins:
		var max_search_radius: int = maxi(int(preferred_distance * 2.8), 40)
		for radius in range(int(min_edge_dist), max_search_radius, 2):
			var steps: int = clampi(int(TAU * radius / 3.0), 8, 36)
			for s in range(steps):
				var angle: float = (float(s) / float(steps)) * TAU
				var cand_pos := Vector2i(
					int(origin.x + cos(angle) * radius - size.x / 2.0),
					int(origin.y + sin(angle) * radius - size.y / 2.0)
				)

				if not _passes_hard_constraints(cand_pos, size, bounds, placed_rects, neighbor_rects, min_separation, min_edge_dist, start_center, room.room_type, comp, node_id):
					continue

				var score: float = _score_candidate(
					cand_pos,
					size,
					bounds,
					room,
					node_id,
					is_main,
					comp,
					global_target,
					origin,
					main_anchor_center,
					start_center,
					prev_main_center,
					neighbor_rects,
					placed_rects,
					room_by_id,
					room_by_node_id,
					preferred_distance,
					progression_strength,
					density_strength
				)

				if score > best_score:
					best_score = score
					best_pos = cand_pos

			if best_pos != Vector2i.MIN:
				return best_pos

	return Vector2i.MIN

func _get_room_target(comp: SpatialComposition, room: RoomData) -> Vector2:
	if comp == null:
		return Vector2.ZERO
	# 1. Consultar por room.id directamente
	var target: Vector2 = comp.get_anchor_target(room.id)
	if target != Vector2.ZERO:
		return target
	# 2. Consultar por mission_node_id si está asociado
	if room.mission_node_id >= 0:
		target = comp.get_anchor_target(room.mission_node_id)
		if target != Vector2.ZERO:
			return target
	return Vector2.ZERO

func _resolve_node_id(comp: SpatialComposition, room: RoomData) -> int:
	if comp != null:
		if comp.has_node(room.id):
			return room.id
		if room.mission_node_id >= 0 and comp.has_node(room.mission_node_id):
			return room.mission_node_id
	return room.mission_node_id if room.mission_node_id >= 0 else room.id

func _determine_priority(room: RoomData, region: StringName) -> int:
	match region:
		REGION_START:
			return 100
		REGION_BOSS:
			return 90
		REGION_LATE:
			return 60
		REGION_MID:
			return 50
		REGION_EARLY:
			return 40
		REGION_BRANCH, REGION_OPTIONAL:
			return 20
		_:
			return 10
