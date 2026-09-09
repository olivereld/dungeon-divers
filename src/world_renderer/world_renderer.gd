class_name WorldRenderer
extends Node3D

func render_world(result: WorldResult, cell_size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "RenderedWorld"

	# 1. Terrain Mesh & Collision
	var mesh := TerrainMeshBuilder.build_mesh(result, cell_size)
	var terrain_mi := MeshInstance3D.new()
	terrain_mi.name = "TerrainMesh"
	terrain_mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	terrain_mi.set_surface_override_material(0, mat)
	root.add_child(terrain_mi)

	# Static collision
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	root.add_child(static_body)

	# 2. Vegetation MultiMeshes
	_spawn_vegetation_multimeshes(root, result)

	return root

func _spawn_vegetation_multimeshes(parent: Node3D, result: WorldResult) -> void:
	var conifers: Array[WorldVegetationItem] = []
	var shrubs: Array[WorldVegetationItem] = []
	var rocks: Array[WorldVegetationItem] = []

	for item in result.vegetation:
		match item.type:
			WorldVegetationItem.Type.CONIFER: conifers.append(item)
			WorldVegetationItem.Type.SHRUB: shrubs.append(item)
			WorldVegetationItem.Type.ROCK: rocks.append(item)

	_create_multimesh(parent, "Conifers", _create_conifer_mesh(), conifers)
	_create_multimesh(parent, "Shrubs", _create_shrub_mesh(), shrubs)
	_create_multimesh(parent, "Rocks", _create_rock_mesh(), rocks)

func _create_multimesh(parent: Node3D, name_id: String, base_mesh: Mesh, items: Array[WorldVegetationItem]) -> void:
	if items.is_empty():
		return

	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_id
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = base_mesh
	mm.instance_count = items.size()

	for i in range(items.size()):
		var item := items[i]
		var t := Transform3D()
		t = t.scaled(Vector3.ONE * item.scale)
		t = t.rotated(Vector3.UP, item.rotation_y)
		t.origin = item.position
		mm.set_instance_transform(i, t)

	mmi.multimesh = mm
	parent.add_child(mmi)

func _create_conifer_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.2
	mesh.height = 4.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.28, 0.15)
	mat.roughness = 0.9
	mesh.material = mat
	return mesh

func _create_shrub_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.45, 0.20)
	mesh.material = mat
	return mesh

func _create_rock_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.8, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.42, 0.45)
	mesh.material = mat
	return mesh
