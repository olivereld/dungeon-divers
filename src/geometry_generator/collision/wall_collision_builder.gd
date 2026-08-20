class_name WallCollisionBuilder
extends RefCounted

## Constructor de formas de colisión física desacopladas para muros (Fase M3 & Hardening).
## Genera colisiones según CollisionConfig: NONE, PER_SEGMENT_BOX, COMPOUND_BOX o CONCAVE_TRIMESH.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")

func build_collision_for_component(
	component: WallComponent,
	config: WallGeometryConfig,
	col_config: CollisionConfig,
	g_mesh: GeneratedMesh
) -> void:
	if component == null or col_config == null or g_mesh == null:
		return

	if col_config.mode == _CollisionConfigScript.CollisionMode.NONE:
		return

	if config == null:
		config = _WallGeometryConfigScript.new()

	var total_h: float = config.get_total_height()
	var tile_size: float = config.cube_size
	var thickness: float = config.wall_thickness + (config.trim_overhang * 2.0) + col_config.extra_thickness

	# 1. Modo CONCAVE_TRIMESH
	if col_config.mode == _CollisionConfigScript.CollisionMode.CONCAVE_TRIMESH:
		if g_mesh.mesh != null and g_mesh.mesh.get_surface_count() > 0:
			var trimesh: ConcavePolygonShape3D = g_mesh.mesh.create_trimesh_shape()
			if trimesh != null:
				g_mesh.add_collision_shape(trimesh, Transform3D.IDENTITY)
		return

	# 2. Modos BOX y COMPOUND_BOX
	for loop_pts in component.loops:
		var n: int = loop_pts.size()
		if n < 3:
			continue

		var segments: Array[Dictionary] = [] # Array de { "p0": Vector3, "p1": Vector3 }

		if col_config.mode == _CollisionConfigScript.CollisionMode.COMPOUND_BOX:
			# Fusión de tramos colineales continuos
			var merged_pts: Array[Vector3] = []
			for pt_raw in loop_pts:
				var pt_v: Vector2i = pt_raw as Vector2i
				merged_pts.append(Vector3(float(pt_v.x) * tile_size, 0.0, float(pt_v.y) * tile_size))

			var m_count: int = merged_pts.size()
			for i in range(m_count):
				var p0: Vector3 = merged_pts[i]
				var p1: Vector3 = merged_pts[(i + 1) % m_count]
				segments.append({"p0": p0, "p1": p1})
		else:
			# Modo PER_SEGMENT_BOX: Generar tramo por cada segmento directo
			for i in range(n):
				var pt0: Vector2i = loop_pts[i] as Vector2i
				var pt1: Vector2i = loop_pts[(i + 1) % n] as Vector2i
				var p0 := Vector3(float(pt0.x) * tile_size, 0.0, float(pt0.y) * tile_size)
				var p1 := Vector3(float(pt1.x) * tile_size, 0.0, float(pt1.y) * tile_size)
				segments.append({"p0": p0, "p1": p1})

		for seg in segments:
			var p0: Vector3 = seg["p0"]
			var p1: Vector3 = seg["p1"]
			var diff: Vector3 = p1 - p0
			var length: float = diff.length()
			if length < 0.001:
				continue

			var tangent: Vector3 = diff.normalized()
			# Normal hacia el interior de la masa sólida del muro
			var normal := Vector3(tangent.z, 0.0, -tangent.x)

			var box := BoxShape3D.new()
			box.size = Vector3(thickness, total_h, length)

			var center: Vector3 = (p0 + p1) * 0.5
			center.y = total_h * 0.5
			center += normal * (thickness * 0.5)

			var basis := Basis(normal, Vector3.UP, tangent)
			var xform := Transform3D(basis, center)

			g_mesh.add_collision_shape(box, xform)
