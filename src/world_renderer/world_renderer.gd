class_name WorldRenderer
extends Node3D

const _TerrainMaterialScript = preload("res://src/world_generator/presentation/terrain_material.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _ProceduralRockGeneratorScript = preload("res://src/world_renderer/procedural_rock_generator.gd")

func render_world(
		result: WorldResult,
		profile_or_cell_size: Variant = 1.0,
		show_water_wireframe: bool = false,
		show_terrain_wireframe: bool = false
	) -> Node3D:
	var profile: WorldProfile = null
	var cell_size: float = 1.0

	if profile_or_cell_size is WorldProfile:
		profile = profile_or_cell_size as WorldProfile
		cell_size = profile.cell_size
	elif profile_or_cell_size is float or profile_or_cell_size is int:
		cell_size = float(profile_or_cell_size)

	var root := Node3D.new()
	root.name = "RenderedWorld"

	# 1. Terrain Mesh & Collision
	var mesh := TerrainMeshBuilder.build_mesh(result, cell_size, profile)
	var terrain_mi := MeshInstance3D.new()
	terrain_mi.name = "TerrainMesh"
	terrain_mi.mesh = mesh
	terrain_mi.set_surface_override_material(0, _TerrainMaterialScript.create_material(profile))
	root.add_child(terrain_mi)

	# Overlay de depuracion wireframe para terreno
	var terrain_wire = TerrainMeshBuilder.build_wireframe_node(mesh)
	if terrain_wire != null:
		terrain_wire.visible = show_terrain_wireframe
		root.add_child(terrain_wire)

	# Static collision
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	root.add_child(static_body)

	# 2. Water Surface Mesh (Unified Rivers & Lakes Presentation)
	if result.hydrology != null:
		var water_node: Node3D = _WaterRendererScript.build_water_node(result, profile, show_water_wireframe)
		if water_node != null:
			root.add_child(water_node)

	# 3. Vegetation MultiMeshes
	_spawn_vegetation_multimeshes(root, result, profile)

	return root

const PINO_GLB_PATH: String = "res://assets/models/props/nature/pino.glb"
const BUSH_GLB_PATH: String = "res://models/nature/bush/bush_1.glb"
const PINO_SHADER_PATH: String = "res://src/world_renderer/shaders/pino_foliage.gdshader"
static var _cached_conifer_mesh: Mesh = null
static var _cached_shrub_mesh: Mesh = null

func _spawn_vegetation_multimeshes(parent: Node3D, result: WorldResult, p_profile: WorldProfile = null) -> void:
	spawn_vegetation(parent, result.vegetation, Vector3.ZERO, p_profile)

static func spawn_vegetation(parent: Node3D, items: Array, origin_3d: Vector3 = Vector3.ZERO, profile: WorldProfile = null) -> void:
	if items.is_empty():
		return

	var conifers: Array[WorldVegetationItem] = []
	var shrubs: Array[WorldVegetationItem] = []
	var rocks: Array[WorldVegetationItem] = []

	for it in items:
		var item := it as WorldVegetationItem
		if item == null:
			continue
		match item.type:
			WorldVegetationItem.Type.CONIFER: conifers.append(item)
			WorldVegetationItem.Type.SHRUB: shrubs.append(item)
			WorldVegetationItem.Type.ROCK: rocks.append(item)

	var conifer_mesh := _create_conifer_mesh()
	var conifer_offset := 0.0 if not (conifer_mesh is CylinderMesh) else 1.95
	var foliage_variants: Array = profile.foliage_tint_variants if (profile != null and not profile.foliage_tint_variants.is_empty()) else []
	_create_multimesh(parent, "Conifers", conifer_mesh, conifers, conifer_offset, origin_3d, foliage_variants)
	var shrub_mesh := _create_shrub_mesh(not foliage_variants.is_empty())
	var shrub_offset := 0.0 if not (shrub_mesh is SphereMesh) else 0.30
	_create_multimesh(parent, "Shrubs", shrub_mesh, shrubs, shrub_offset, origin_3d, foliage_variants)
	_spawn_rock_multimeshes(parent, rocks, origin_3d)

static func _create_multimesh(parent: Node3D, name_id: String, base_mesh: Mesh, items: Array, base_y_offset: float = 0.0, origin_3d: Vector3 = Vector3.ZERO, color_variants: Array = []) -> void:
	if items.is_empty() or base_mesh == null:
		return

	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_id
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var has_colors: bool = not color_variants.is_empty()
	if has_colors:
		mm.use_colors = true
	mm.mesh = base_mesh
	mm.instance_count = items.size()

	for i in range(items.size()):
		var item: WorldVegetationItem = items[i] as WorldVegetationItem
		var t := Transform3D()
		t = t.scaled(Vector3.ONE * item.scale)
		t = t.rotated(Vector3.UP, item.rotation_y)
		var local_pos: Vector3 = item.position - origin_3d
		t.origin = local_pos + Vector3(0.0, base_y_offset * item.scale, 0.0)
		mm.set_instance_transform(i, t)
		if has_colors:
			var h: int = (int(absf(item.position.x * 19.0)) ^ int(absf(item.position.z * 37.0))) % color_variants.size()
			mm.set_instance_color(i, color_variants[h])

	mmi.multimesh = mm
	parent.add_child(mmi)

static func _create_conifer_mesh() -> Mesh:
	if _cached_conifer_mesh != null:
		return _cached_conifer_mesh

	if ResourceLoader.exists(PINO_GLB_PATH):
		var glb: PackedScene = load(PINO_GLB_PATH)
		if glb != null:
			var inst: Node = glb.instantiate()
			var mi: MeshInstance3D = null
			for child in inst.get_children():
				if child is MeshInstance3D and child.mesh != null:
					mi = child
					break
			if mi != null:
				var baked := _bake_pino_mesh(mi.mesh, mi.transform, mi.get_surface_override_material(0) if mi.get_surface_override_material(0) else mi.mesh.surface_get_material(0))
				inst.queue_free()
				if baked != null:
					_cached_conifer_mesh = baked
					return _cached_conifer_mesh
			inst.queue_free()

	# Fallback a cono primitivo si el recurso GLB no estuviera disponible
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.2
	mesh.height = 4.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.28, 0.15)
	mat.roughness = 0.9
	mesh.material = mat
	_cached_conifer_mesh = mesh
	return _cached_conifer_mesh

static func _bake_pino_mesh(orig_mesh: Mesh, xform: Transform3D, mat: Material, scale_factor: float = 0.65) -> ArrayMesh:
	var new_mesh := ArrayMesh.new()
	var min_y: float = INF
	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			var tv: Vector3 = xform * v
			min_y = minf(min_y, tv.y)
	if not is_finite(min_y):
		min_y = 0.0

	var y_offset: float = -min_y - 0.15

	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var basis: Basis = xform.basis.orthonormalized()

		for i in range(verts.size()):
			var tv: Vector3 = xform * verts[i]
			tv.y += y_offset
			verts[i] = tv * scale_factor

		if not normals.is_empty():
			for i in range(normals.size()):
				var n_trans: Vector3 = (basis * normals[i]).normalized()
				var v: Vector3 = verts[i]
				var horiz := Vector2(v.x, v.z)
				var outward: Vector3
				if horiz.length_squared() > 0.0004:
					var h_dir := horiz.normalized()
					if v.y > 0.8 or horiz.length() > 0.25:
						# Foliage: radial outward normal with slight upward flare (0.28) for soft volumetric light
						outward = Vector3(h_dir.x, 0.28, h_dir.y).normalized()
					else:
						# Base trunk: radial cylinder normal
						outward = Vector3(h_dir.x, 0.0, h_dir.y)
				else:
					outward = Vector3.UP

				# 70% outward volume normal blend eliminates harsh polygonal facets and specular glare
				normals[i] = n_trans.lerp(outward, 0.70).normalized()

		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals

		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var surface_mat: Material = mat
		if surface_mat == null:
			surface_mat = orig_mesh.surface_get_material(s)

		var final_mat: Material = null
		if ResourceLoader.exists(PINO_SHADER_PATH):
			var shader: Shader = load(PINO_SHADER_PATH)
			if shader != null:
				var sm := ShaderMaterial.new()
				sm.shader = shader
				if surface_mat is BaseMaterial3D:
					var bm := surface_mat as BaseMaterial3D
					if bm.albedo_texture != null:
						sm.set_shader_parameter("texture_albedo", bm.albedo_texture)
					if bm.albedo_color != Color.WHITE:
						sm.set_shader_parameter("foliage_tint", bm.albedo_color)
				sm.set_shader_parameter("alpha_scissor_threshold", 0.5)
				final_mat = sm

		if final_mat == null and surface_mat != null:
			var bm := surface_mat.duplicate() as BaseMaterial3D
			if bm != null:
				bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				bm.alpha_scissor_threshold = 0.5
				bm.cull_mode = BaseMaterial3D.CULL_DISABLED
				bm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
				bm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				bm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				bm.roughness = 1.0
				bm.metallic = 0.0
				final_mat = bm

		new_mesh.surface_set_material(s, final_mat if final_mat != null else surface_mat)

	return new_mesh

static func _create_shrub_mesh(has_instance_colors: bool = false) -> Mesh:
	if _cached_shrub_mesh != null:
		return _cached_shrub_mesh

	if ResourceLoader.exists(BUSH_GLB_PATH):
		var glb: PackedScene = load(BUSH_GLB_PATH)
		if glb != null:
			var inst: Node = glb.instantiate()
			var chain: Array[Node3D] = []
			_find_mesh_instance_chain(inst, chain)
			if not chain.is_empty() and chain.back() is MeshInstance3D:
				var mi: MeshInstance3D = chain.back() as MeshInstance3D
				var accumulated_xf := Transform3D.IDENTITY
				for node in chain:
					accumulated_xf = accumulated_xf * node.transform
				var mat: Material = mi.get_surface_override_material(0) if mi.get_surface_override_material(0) else mi.mesh.surface_get_material(0)
				var baked := _bake_bush_mesh(mi.mesh, accumulated_xf, mat)
				inst.queue_free()
				if baked != null:
					_cached_shrub_mesh = baked
					return _cached_shrub_mesh
			inst.queue_free()

	# Fallback a esfera primitiva si el recurso GLB no estuviera disponible
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9) if has_instance_colors else Color(0.25, 0.45, 0.20)
	if has_instance_colors:
		mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_cached_shrub_mesh = mesh
	return _cached_shrub_mesh

static func _find_mesh_instance_chain(curr: Node, current_chain: Array[Node3D]) -> bool:
	if curr is Node3D:
		current_chain.append(curr)
	if curr is MeshInstance3D and curr.mesh != null:
		return true
	for c in curr.get_children():
		if _find_mesh_instance_chain(c, current_chain):
			return true
	if curr is Node3D:
		current_chain.pop_back()
	return false

static func _bake_bush_mesh(orig_mesh: Mesh, xform: Transform3D, mat: Material, scale_factor: float = 1.0) -> ArrayMesh:
	var new_mesh := ArrayMesh.new()
	var min_y: float = INF
	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			var tv: Vector3 = xform * v
			min_y = minf(min_y, tv.y)
	if not is_finite(min_y):
		min_y = 0.0

	var y_offset: float = -min_y

	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var basis: Basis = xform.basis.orthonormalized()

		for i in range(verts.size()):
			var tv: Vector3 = xform * verts[i]
			tv.y += y_offset
			verts[i] = tv * scale_factor

		if not normals.is_empty():
			for i in range(normals.size()):
				var n_trans: Vector3 = (basis * normals[i]).normalized()
				var v: Vector3 = verts[i]
				var outward: Vector3 = (v - Vector3(0.0, 0.35 * scale_factor, 0.0)).normalized()
				normals[i] = n_trans.lerp(outward, 0.60).normalized()

		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals

		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

		var surface_mat: Material = mat
		if surface_mat == null:
			surface_mat = orig_mesh.surface_get_material(s)

		var final_mat: Material = null
		if ResourceLoader.exists(PINO_SHADER_PATH):
			var shader: Shader = load(PINO_SHADER_PATH)
			if shader != null:
				var sm := ShaderMaterial.new()
				sm.shader = shader
				if surface_mat is BaseMaterial3D:
					var bm := surface_mat as BaseMaterial3D
					if bm.albedo_texture != null:
						sm.set_shader_parameter("texture_albedo", bm.albedo_texture)
					if bm.albedo_color != Color.WHITE:
						sm.set_shader_parameter("foliage_tint", bm.albedo_color)
				sm.set_shader_parameter("alpha_scissor_threshold", 0.5)
				sm.set_shader_parameter("shadow_tint", Color(0.18, 0.32, 0.24, 1.0))
				sm.set_shader_parameter("shadow_wrap", 0.45)
				sm.set_shader_parameter("direct_light_strength", 0.85)
				final_mat = sm

		if final_mat == null and surface_mat != null:
			var bm := surface_mat.duplicate() as BaseMaterial3D
			if bm != null:
				bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				bm.alpha_scissor_threshold = 0.5
				bm.cull_mode = BaseMaterial3D.CULL_DISABLED
				bm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
				bm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				bm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				bm.roughness = 1.0
				bm.metallic = 0.0
				bm.vertex_color_use_as_albedo = true
				final_mat = bm

		new_mesh.surface_set_material(s, final_mat if final_mat != null else surface_mat)

	return new_mesh

static func _create_rock_mesh() -> Mesh:
	var variants: Array[Mesh] = _ProceduralRockGeneratorScript.get_rock_variants()
	if not variants.is_empty():
		return variants[0]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.8, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.42, 0.45)
	mesh.material = mat
	return mesh

static func _spawn_rock_multimeshes(parent: Node3D, items: Array, origin_3d: Vector3 = Vector3.ZERO) -> void:
	if items.is_empty():
		return

	var variants: Array[Mesh] = _ProceduralRockGeneratorScript.get_rock_variants()
	if variants.is_empty():
		_create_multimesh(parent, "Rocks", _create_rock_mesh(), items, 0.20, origin_3d)
		return

	var num_variants: int = variants.size()
	var buckets: Array = []
	for i in range(num_variants):
		var b: Array[WorldVegetationItem] = []
		buckets.append(b)

	# Distribuir rocas en las variantes mediante hash espacial consistente
	for item in items:
		var h: int = int(abs(item.position.x * 73.0 + item.position.z * 179.0))
		var v_idx: int = h % num_variants
		buckets[v_idx].append(item)

	var rocks_container := Node3D.new()
	rocks_container.name = "Rocks"
	parent.add_child(rocks_container)

	for v in range(num_variants):
		var bucket_items: Array[WorldVegetationItem] = buckets[v]
		if bucket_items.is_empty():
			continue

		var mesh: Mesh = variants[v]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "RockVariant_%d" % v
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = bucket_items.size()

		for i in range(bucket_items.size()):
			var item := bucket_items[i]
			var seed_hash: int = int(abs(item.position.x * 311.0 + item.position.z * 617.0)) & 0x7FFFFFFF
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_hash

			# Variación individual no uniforme de escala (aspectos únicos: achatado, alargado o compacto)
			var sx: float = rng.randf_range(0.85, 1.20)
			var sy: float = rng.randf_range(0.75, 1.18)
			var sz: float = rng.randf_range(0.85, 1.20)
			var base_scale: float = item.scale

			var t := Transform3D()
			t = t.scaled(Vector3(base_scale * sx, base_scale * sy, base_scale * sz))

			# Rotación 3D natural completa: guiñada yaw 0-360° más leves inclinaciones pitch/roll (-12° a +12°)
			var pitch: float = rng.randf_range(-0.20, 0.20)
			var roll: float = rng.randf_range(-0.20, 0.20)
			t = t.rotated(Vector3.RIGHT, pitch)
			t = t.rotated(Vector3.FORWARD, roll)
			t = t.rotated(Vector3.UP, item.rotation_y)

			# Arraigo: base descansando firmemente sobre el terreno
			var base_y_offset: float = 0.12
			var local_pos := item.position - origin_3d
			t.origin = local_pos + Vector3(0.0, base_y_offset * base_scale, 0.0)
			mm.set_instance_transform(i, t)

		mmi.multimesh = mm
		rocks_container.add_child(mmi)
