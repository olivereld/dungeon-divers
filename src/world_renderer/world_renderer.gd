class_name WorldRenderer
extends Node3D

const _TerrainMaterialScript = preload("res://src/world_generator/presentation/terrain_material.gd")
const _HydrologyRendererScript = preload("res://src/world_renderer/hydrology_renderer.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")

func render_world(result: WorldResult, profile_or_cell_size: Variant = 1.0) -> Node3D:
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
	terrain_mi.set_surface_override_material(0, _TerrainMaterialScript.create_material())
	root.add_child(terrain_mi)

	# Static collision
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	root.add_child(static_body)

	# 2. Water Surface Mesh (Unified Rivers & Lakes Presentation)
	if result.hydrology != null:
		var water_node: Node3D = _WaterRendererScript.build_water_node(result, profile)
		if water_node != null:
			root.add_child(water_node)

	# 3. Vegetation MultiMeshes
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

	# base_y_offset lifts primitive mesh center so its base is firmly grounded:
	# - Conifers (CylinderMesh H=4.5): half-height is 2.25m. Lift by 1.95m so the bottom is 0.30m
	#   embedded in the soil, showing 4.2m of pine above ground with no gap on slopes.
	# - Shrubs (SphereMesh H=0.8): half-height is 0.40m. Lift by 0.30m to sit 10cm in the soil.
	# - Rocks (BoxMesh H=0.8): half-height is 0.40m. Lift by 0.20m to keep ~25% buried naturally.
	_create_multimesh(parent, "Conifers", _create_conifer_mesh(), conifers, 1.95)
	_create_multimesh(parent, "Shrubs", _create_shrub_mesh(), shrubs, 0.30)
	_create_multimesh(parent, "Rocks", _create_rock_mesh(), rocks, 0.20)

func _create_multimesh(parent: Node3D, name_id: String, base_mesh: Mesh, items: Array[WorldVegetationItem], base_y_offset: float = 0.0) -> void:
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
		t.origin = item.position + Vector3(0.0, base_y_offset * item.scale, 0.0)
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
