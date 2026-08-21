class_name GeneratedAsset
extends RefCounted

## Contenedor semántico para un elemento arquitectónico ensamblado (ej. Portal = Arco + Hoja de Puerta).
## Permite composición limpia de múltiples GeneratedMesh con metadatos, colisiones y transforms.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")

var asset_id: StringName = &""
var meshes: Dictionary = {} # slot_name (StringName) -> GeneratedMesh
var transforms: Dictionary = {} # slot_name (StringName) -> Transform3D
var metadata: Dictionary = {}
var bounds: AABB = AABB()

func add_mesh(slot: StringName, g_mesh, xform: Transform3D = Transform3D.IDENTITY) -> void:
	if g_mesh != null:
		meshes[slot] = g_mesh
		transforms[slot] = xform
		var xformed_aabb: AABB = xform * g_mesh.bounds if g_mesh.bounds.size != Vector3.ZERO else AABB()
		if bounds.size == Vector3.ZERO:
			bounds = xformed_aabb
		elif xformed_aabb.size != Vector3.ZERO:
			bounds = bounds.merge(xformed_aabb)

func get_mesh(slot: StringName):
	return meshes.get(slot, null)

func get_mesh_transform(slot: StringName) -> Transform3D:
	return transforms.get(slot, Transform3D.IDENTITY)

func has_slot(slot: StringName) -> bool:
	return meshes.has(slot)

func to_node3d(prefix: String = "Asset") -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [prefix, String(asset_id)]

	for slot in meshes.keys():
		var gm = meshes[slot]
		if gm != null and gm.mesh != null:
			var mi: MeshInstance3D = gm.to_mesh_instance(String(slot))
			var xform: Transform3D = transforms.get(slot, Transform3D.IDENTITY)
			mi.transform = xform
			root.add_child(mi)

			if not gm.collision_shapes.is_empty():
				var body: StaticBody3D = gm.create_collision_body()
				body.transform = xform
				root.add_child(body)

	return root
