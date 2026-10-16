class_name PoiGroundDecorationSpawner
extends RefCounted

## Spawner determinista y modular de decoración exterior de terreno para POIs.
## Utiliza MultiMeshInstance3D y especificaciones de colocación por anillos concéntricos
## (clearance, zona funeraria, corrupción y transición) con validación de pendiente y agua.

const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

class DecorationSpec extends RefCounted:
	var id: String = "prop"
	var mesh: Mesh = null
	var material: Material = null
	var density: float = 0.10
	var min_distance: float = 2.0
	var scale_min: float = 0.8
	var scale_max: float = 1.2
	var radius_min: float = 5.0
	var radius_max: float = 25.0
	var forbidden_radius: float = 4.5
	var max_slope: float = 25.0
	var allow_frontal_corridor: bool = false
	var align_to_terrain: bool = false
	var tilt_max_deg: float = 12.0
	var ground_embed_m: float = 0.05
	var cluster_anchor_points: Array = []
	var cluster_bias: float = 0.0

static func scatter_decorations(
	poi: RefCounted,
	profile: RefCounted,
	world_query: Object,
	specs: Array
) -> Node3D:
	var container := Node3D.new()
	container.name = "GroundDecorations"

	var seed_val: int = poi.identity.dungeon_seed if (poi != null and "identity" in poi and poi.identity != null and "dungeon_seed" in poi.identity) else 12345
	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var ori_deg: float = poi.orientation_deg if (poi != null and "orientation_deg" in poi) else 0.0

	var global_placed_points: Array[Vector2] = []

	for spec_obj in specs:
		var spec: DecorationSpec = spec_obj as DecorationSpec
		if spec == null or spec.mesh == null or spec.density <= 0.0:
			continue

		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val ^ (spec.id.hash() & 0x7FFFFFFF)

		# Cantidad objetivo proporcional al área anular y la densidad
		var inner_r: float = maxf(spec.radius_min, spec.forbidden_radius)
		var outer_r: float = spec.radius_max
		var ring_area: float = PI * (outer_r * outer_r - inner_r * inner_r)
		var target_count: int = clampi(int(round(ring_area * spec.density * 0.035)), 1, 60)

		var transforms: Array[Transform3D] = []
		var placed_for_spec: Array[Vector2] = []
		var max_attempts: int = target_count * 14

		for attempt in range(max_attempts):
			if transforms.size() >= target_count:
				break

			var sample_pos_2d: Vector2
			if not spec.cluster_anchor_points.is_empty() and rng.randf() < spec.cluster_bias:
				var anchor: Vector2 = spec.cluster_anchor_points[rng.randi() % spec.cluster_anchor_points.size()]
				var offset_ang: float = rng.randf() * TAU
				var offset_dist: float = rng.randf_range(0.8, 3.2)
				sample_pos_2d = anchor + Vector2(cos(offset_ang), sin(offset_ang)) * offset_dist
			else:
				var ang: float = rng.randf() * TAU
				var dist: float = sqrt(rng.randf_range(inner_r * inner_r, outer_r * outer_r))
				sample_pos_2d = Vector2(poi_pos.x + cos(ang) * dist, poi_pos.z + sin(ang) * dist)

			var d_poi: float = (sample_pos_2d - Vector2(poi_pos.x, poi_pos.z)).length()
			if d_poi < spec.forbidden_radius:
				continue

			if not spec.allow_frontal_corridor:
				if _EvaluatorScript.is_in_frontal_corridor(sample_pos_2d, Vector2(poi_pos.x, poi_pos.z), ori_deg, 8.5, 3.5):
					continue

			# Espaciado mínimo
			var too_close := false
			for pt in placed_for_spec:
				if (pt - sample_pos_2d).length() < spec.min_distance:
					too_close = true
					break
			if too_close:
				continue

			var wx: int = int(round(sample_pos_2d.x))
			var wz: int = int(round(sample_pos_2d.y))

			# Hidrología y pendiente
			if world_query != null and world_query.has_method("is_water") and world_query.is_water(wx, wz):
				continue
			if world_query != null and world_query.has_method("get_slope") and world_query.get_slope(wx, wz) > spec.max_slope:
				continue

			var wy: float = poi_pos.y
			var ground_normal := Vector3.UP
			if world_query != null and world_query.has_method("get_elevation"):
				wy = world_query.get_elevation(wx, wz)
				var h_e: float = world_query.get_elevation(wx + 1, wz)
				var h_s: float = world_query.get_elevation(wx, wz + 1)
				ground_normal = Vector3(wy - h_e, 1.0, wy - h_s).normalized()

			var s: float = rng.randf_range(spec.scale_min, spec.scale_max)
			var rot_y: float = rng.randf() * TAU

			var t := Transform3D()
			t = t.scaled(Vector3.ONE * s)
			t = t.rotated(Vector3.UP, rot_y)

			if spec.align_to_terrain and ground_normal.dot(Vector3.UP) < 0.999:
				var align_axis: Vector3 = Vector3.UP.cross(ground_normal).normalized()
				var align_angle: float = minf(acos(clampf(Vector3.UP.dot(ground_normal), -1.0, 1.0)), deg_to_rad(spec.tilt_max_deg))
				if align_axis.length_squared() > 0.001:
					t.basis = Basis(align_axis, align_angle) * t.basis

			if spec.tilt_max_deg > 0.0 and not spec.align_to_terrain:
				var pitch: float = deg_to_rad(rng.randf_range(-spec.tilt_max_deg, spec.tilt_max_deg))
				var roll: float = deg_to_rad(rng.randf_range(-spec.tilt_max_deg, spec.tilt_max_deg))
				t = t.rotated_local(Vector3.RIGHT, pitch)
				t = t.rotated_local(Vector3.FORWARD, roll)

			t.origin = Vector3(sample_pos_2d.x - poi_pos.x, wy - poi_pos.y - spec.ground_embed_m, sample_pos_2d.y - poi_pos.z)

			transforms.append(t)
			placed_for_spec.append(sample_pos_2d)
			global_placed_points.append(sample_pos_2d)

		if not transforms.is_empty():
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "MultiMesh_" + spec.id
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = spec.mesh
			mm.instance_count = transforms.size()

			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])

			mmi.multimesh = mm
			if spec.material != null:
				mmi.material_override = spec.material
			mmi.set_meta("placed_transforms", transforms)
			container.add_child(mmi)

	return container
