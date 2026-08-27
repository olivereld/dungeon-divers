class_name PropFixtureRelationshipResolver
extends RefCounted

## Resolutor espacial determinista de relaciones semánticas Prop -> Fixture.
## 100% puro: no instancia nodos 3D, no muta CellGrid y solo genera FixtureDirective.

const _PropFixtureRelationScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation.gd")
const _PropFixtureRelationPlacementScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_placement.gd")
const _PropFixtureRelationTypeScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_type.gd")
const _PropFixtureRelationshipCandidateScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_candidate.gd")
const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")

const _PropFixtureRelationshipResultScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_result.gd")

func resolve_relationships(
	placed_props: Array,
	relation_profile, # PropFixtureRelationshipProfile
	fixture_palette, # FixturePalette
	room_geom, # PresentationRoomGeometry
	occupancy, # DecorationOccupancyMap
	seed_val: int,
	tile_size: float = 2.0
) -> Array[_FixtureDirectiveScript]:
	var result_obj = resolve_relationships_with_diagnostics(
		placed_props,
		relation_profile,
		fixture_palette,
		room_geom,
		occupancy,
		seed_val,
		tile_size
	)
	return result_obj.directives

func resolve_relationships_with_diagnostics(
	placed_props: Array,
	relation_profile, # PropFixtureRelationshipProfile
	fixture_palette, # FixturePalette
	room_geom, # PresentationRoomGeometry
	occupancy, # DecorationOccupancyMap
	seed_val: int,
	tile_size: float = 2.0
) -> _PropFixtureRelationshipResultScript:
	var result: Array[_FixtureDirectiveScript] = []
	var diagnostics: Array[Dictionary] = []

	if placed_props.is_empty() or relation_profile == null or fixture_palette == null or room_geom == null:
		return _PropFixtureRelationshipResultScript.new(result, diagnostics)

	var room_id: int = room_geom.room_id if "room_id" in room_geom else 0

	var floor_cells_map: Dictionary = {}
	if "floor_cells" in room_geom and room_geom.floor_cells != null:
		for fc in room_geom.floor_cells:
			floor_cells_map[fc] = true

	var door_map: Dictionary = {}
	var door_positions: Array = room_geom.door_positions if "door_positions" in room_geom else []
	for dp in door_positions:
		door_map[dp] = true
		for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			door_map[dp + off] = true

	var occupied_cells_map: Dictionary = {}

	var prop_idx: int = 0
	for prop_dir in placed_props:
		if prop_dir == null:
			continue

		var style_id: StringName = &""
		if "style" in prop_dir and prop_dir.style != null and "id" in prop_dir.style:
			style_id = prop_dir.style.id
		elif "style_id" in prop_dir:
			style_id = prop_dir.style_id
		elif "prop_id" in prop_dir:
			style_id = prop_dir.prop_id

		var relations: Array = relation_profile.get_relations_for_prop(style_id)
		if relations.is_empty():
			continue

		var prop_rot_y: float = 0.0
		if "rotation_degrees_y" in prop_dir:
			prop_rot_y = prop_dir.rotation_degrees_y * PI / 180.0
		elif "placement" in prop_dir and prop_dir.placement != null and "rotation_y" in prop_dir.placement:
			prop_rot_y = prop_dir.placement.rotation_y

		var prop_foot_cells: Array[Vector2i] = []
		if "occupied_cells" in prop_dir and not prop_dir.occupied_cells.is_empty():
			prop_foot_cells = prop_dir.occupied_cells
		elif "placement" in prop_dir and prop_dir.placement != null and "cell" in prop_dir.placement:
			var prop_cell: Vector2i = prop_dir.placement.cell
			if "style" in prop_dir and prop_dir.style != null and "footprint" in prop_dir.style and prop_dir.style.footprint != null:
				var deg_y: float = prop_rot_y * 180.0 / PI
				prop_foot_cells = prop_dir.style.footprint.get_occupied_cells(prop_cell, deg_y)
			else:
				prop_foot_cells = [prop_cell]

		for rel in relations:
			var matching_entries = _filter_entries(fixture_palette, rel)
			if matching_entries.is_empty():
				diagnostics.append({
					"relation_id": rel.relation_id,
					"source_prop": style_id,
					"requested_min": rel.min_count,
					"requested_max": rel.max_count,
					"actual_count": 0,
					"satisfied": rel.min_count == 0,
					"failure_reason": &"NO_MATCHING_STYLES" if rel.min_count > 0 else &"OK",
					"candidates_evaluated": 0
				})
				continue

			var candidates: Array[_PropFixtureRelationshipCandidateScript] = _generate_candidates(
				style_id,
				prop_foot_cells,
				prop_rot_y,
				rel,
				matching_entries,
				floor_cells_map,
				door_map,
				occupancy,
				occupied_cells_map,
				tile_size,
				seed_val + prop_idx
			)

			if candidates.is_empty():
				diagnostics.append({
					"relation_id": rel.relation_id,
					"source_prop": style_id,
					"requested_min": rel.min_count,
					"requested_max": rel.max_count,
					"actual_count": 0,
					"satisfied": rel.min_count == 0,
					"failure_reason": &"NO_VALID_ANCHORS" if rel.min_count > 0 else &"OK",
					"candidates_evaluated": 0
				})
				continue

			# Ordenar por puntuación total descendente
			candidates.sort_custom(func(a, b): return a.total_score > b.total_score)

			var placed_count: int = 0
			var evaluated_count: int = candidates.size()

			for cand in candidates:
				if placed_count >= rel.max_count:
					break

				var foot_cells: Array[Vector2i] = []
				if cand.fixture_style != null and "footprint" in cand.fixture_style and cand.fixture_style.footprint != null:
					var deg: float = cand.rotation_y * 180.0 / PI
					foot_cells = cand.fixture_style.footprint.get_occupied_cells(cand.fixture_cell, deg)
				else:
					foot_cells = [cand.fixture_cell]

				var valid_foot: bool = true
				if cand.placement_mode != _FixturePlacementModeScript.Mode.HANGING:
					for c in foot_cells:
						if not floor_cells_map.has(c) or door_map.has(c) or occupied_cells_map.has(c) or (occupancy != null and occupancy.is_cell_occupied(c)):
							valid_foot = false
							break
				else:
					if occupied_cells_map.has(cand.fixture_cell):
						valid_foot = false

				if not valid_foot:
					continue

				var pl := _FixturePlacementScript.new(
					cand.placement_mode,
					cand.fixture_cell,
					-1,
					cand.world_position,
					cand.rotation_y,
					cand.normal
				)

				var f_dir := _FixtureDirectiveScript.new(
					cand.fixture_style.id,
					room_id,
					cand.fixture_style,
					pl,
					cand.fixture_style.scale,
					_FixtureDirectiveScript.SourceType.PROP_RELATION,
					style_id,
					rel.relation_id,
					rel.relation_type
				)

				result.append(f_dir)
				if occupancy != null and cand.placement_mode != _FixturePlacementModeScript.Mode.HANGING:
					occupancy.add_footprint(foot_cells, cand.fixture_style.id, 0)
				for c in foot_cells:
					occupied_cells_map[c] = true
				placed_count += 1

			var is_sat: bool = placed_count >= rel.min_count
			diagnostics.append({
				"relation_id": rel.relation_id,
				"source_prop": style_id,
				"requested_min": rel.min_count,
				"requested_max": rel.max_count,
				"actual_count": placed_count,
				"satisfied": is_sat,
				"failure_reason": &"OK" if is_sat else &"INSUFFICIENT_VALID_ANCHORS",
				"candidates_evaluated": evaluated_count
			})

		prop_idx += 1

	return _PropFixtureRelationshipResultScript.new(result, diagnostics)

func _generate_candidates(
	prop_style_id: StringName,
	prop_foot_cells: Array[Vector2i],
	prop_rot_y: float,
	rel,
	matching_entries: Array,
	floor_cells_map: Dictionary,
	door_map: Dictionary,
	occupancy,
	occupied_cells_map: Dictionary,
	tile_size: float,
	seed_val: int
) -> Array[_PropFixtureRelationshipCandidateScript]:
	var candidates: Array[_PropFixtureRelationshipCandidateScript] = []

	# Calcular centroide del prop
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var prop_set: Dictionary = {}
	for c in prop_foot_cells:
		prop_set[c] = true
		sum_x += float(c.x)
		sum_y += float(c.y)
	var count_f: float = float(maxi(1, prop_foot_cells.size()))
	var center_x: float = (sum_x / count_f + 0.5) * tile_size
	var center_z: float = (sum_y / count_f + 0.5) * tile_size
	var center_cell := Vector2i(int(floor(sum_x / count_f)), int(floor(sum_y / count_f)))

	for entry in matching_entries:
		if entry == null or entry.style == null:
			continue
		var style: _FixtureStyleScript = entry.style
		var weight_bonus: float = log(maxf(0.1, entry.weight)) * 3.0

		match rel.placement:
			_PropFixtureRelationPlacementScript.Placement.ABOVE:
				var h_pos := Vector3(center_x, 2.4, center_z)
				var cand := _PropFixtureRelationshipCandidateScript.new(
					prop_style_id,
					center_cell,
					center_cell,
					style,
					_FixturePlacementModeScript.Mode.HANGING,
					h_pos,
					0.0,
					Vector3.DOWN
				)
				cand.total_score = 100.0 + weight_bonus
				candidates.append(cand)

			_PropFixtureRelationPlacementScript.Placement.SURFACE:
				for c in prop_foot_cells:
					var s_x: float = (float(c.x) + 0.5) * tile_size
					var s_z: float = (float(c.y) + 0.5) * tile_size
					var s_pos := Vector3(s_x, 0.85, s_z)
					var cand := _PropFixtureRelationshipCandidateScript.new(
						prop_style_id,
						c,
						c,
						style,
						_FixturePlacementModeScript.Mode.SURFACE,
						s_pos,
						prop_rot_y,
						Vector3.UP
					)
					cand.total_score = 100.0 + weight_bonus
					candidates.append(cand)

			_: # NEAR, LEFT, RIGHT, FRONT, BACK
				# Vectores locales de dirección relativos a la rotación del prop
				var forward_v := Vector2(sin(prop_rot_y), -cos(prop_rot_y))
				var right_v := Vector2(cos(prop_rot_y), sin(prop_rot_y))

				var search_radius: int = int(ceil(rel.max_distance))
				var tested_cells: Dictionary = {}

				for base_c in prop_foot_cells:
					for dx in range(-search_radius, search_radius + 1):
						for dy in range(-search_radius, search_radius + 1):
							var n_cell := base_c + Vector2i(dx, dy)
							if tested_cells.has(n_cell) or prop_set.has(n_cell):
								continue
							tested_cells[n_cell] = true

							if not floor_cells_map.has(n_cell) or door_map.has(n_cell):
								continue
							if occupied_cells_map.has(n_cell) or (occupancy != null and occupancy.is_cell_occupied(n_cell)):
								continue

							var cand_world_x: float = (float(n_cell.x) + 0.5) * tile_size
							var cand_world_z: float = (float(n_cell.y) + 0.5) * tile_size
							var dist_to_center: float = Vector2(cand_world_x - center_x, cand_world_z - center_z).length() / tile_size

							if dist_to_center > rel.max_distance:
								continue

							# Puntuación espacial multidimensional
							var score_dist: float = maxf(0.0, 100.0 - absf(dist_to_center - rel.preferred_distance) * 35.0)

							var delta_vec := Vector2(float(n_cell.x) - (sum_x / count_f), float(n_cell.y) - (sum_y / count_f)).normalized()
							var score_dir: float = 50.0

							match rel.placement:
								_PropFixtureRelationPlacementScript.Placement.LEFT:
									var dot_r: float = delta_vec.dot(right_v)
									score_dir = maxf(0.0, (-dot_r) * 100.0)
								_PropFixtureRelationPlacementScript.Placement.RIGHT:
									var dot_r: float = delta_vec.dot(right_v)
									score_dir = maxf(0.0, dot_r * 100.0)
								_PropFixtureRelationPlacementScript.Placement.FRONT:
									var dot_f: float = delta_vec.dot(forward_v)
									score_dir = maxf(0.0, dot_f * 100.0)
								_PropFixtureRelationPlacementScript.Placement.BACK:
									var dot_f: float = delta_vec.dot(forward_v)
									score_dir = maxf(0.0, (-dot_f) * 100.0)
								_: # NEAR
									score_dir = 80.0

							if score_dir <= 0.0 and rel.placement != _PropFixtureRelationPlacementScript.Placement.NEAR:
								continue

							var total: float = score_dist * 0.6 + score_dir * 0.4 + weight_bonus

							var cand := _PropFixtureRelationshipCandidateScript.new(
								prop_style_id,
								base_c,
								n_cell,
								style,
								_FixturePlacementModeScript.Mode.FLOOR,
								Vector3(cand_world_x, 0.0, cand_world_z),
								0.0,
								Vector3.UP
							)
							cand.distance_score = score_dist
							cand.direction_score = score_dir
							cand.total_score = total
							candidates.append(cand)

	return candidates

func _filter_entries(palette, rel) -> Array:
	var result: Array = []
	if palette == null or palette.entries.is_empty():
		return result

	for entry in palette.entries:
		if entry == null or entry.style == null:
			continue
		var style: _FixtureStyleScript = entry.style

		# 1. Descartar si está prohibido explícitamente por tipo o por ID
		if rel.forbidden_fixture_types.has(style.fixture_type):
			continue
		var is_forbidden_id: bool = false
		for fid in rel.forbidden_fixture_ids:
			if style.id == fid or str(style.id).to_lower().contains(str(fid).to_lower()):
				is_forbidden_id = true
				break
		if is_forbidden_id:
			continue

		# 2. Validación estricta de placement_mode según el tipo de relación espacial
		match rel.placement:
			_PropFixtureRelationPlacementScript.Placement.ABOVE:
				if style.placement_mode != _FixturePlacementModeScript.Mode.HANGING:
					continue
			_PropFixtureRelationPlacementScript.Placement.SURFACE:
				if style.placement_mode != _FixturePlacementModeScript.Mode.SURFACE and style.placement_mode != _FixturePlacementModeScript.Mode.FLOOR:
					continue
			_: # NEAR, LEFT, RIGHT, FRONT, BACK
				if style.placement_mode == _FixturePlacementModeScript.Mode.HANGING:
					continue
				if style.placement_mode == _FixturePlacementModeScript.Mode.WALL:
					continue

		# 3. Filtrar por target_fixture_ids si fue especificado
		if not rel.target_fixture_ids.is_empty():
			var matched_id: bool = false
			for fid in rel.target_fixture_ids:
				if style.id == fid or str(style.id).to_lower().contains(str(fid).to_lower()):
					matched_id = true
					break
			if matched_id:
				result.append(entry)
			continue

		# 4. Filtrar por target_fixture_types
		if not rel.target_fixture_types.is_empty():
			if rel.target_fixture_types.has(style.fixture_type):
				result.append(entry)
			continue

		# 5. Sin restricciones específicas
		result.append(entry)

	return result

