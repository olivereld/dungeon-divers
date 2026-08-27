class_name GeneratedMesh
extends RefCounted

## Unidad geométrica 3D independiente producida por el generador de geometría.
## Encapsula la malla de renderizado, formas de colisión asociadas, bounds y metadatos.

var mesh: Mesh = null
var collision_shapes: Array[Shape3D] = []
var collision_transforms: Array[Transform3D] = []
var bounds: AABB = AABB()
var component_id: int = 0
var section_id: int = -1
var variant_id: StringName = &""
var room_id: int = -1
var material_slots: Dictionary = {} # slot_index: int -> Material

func add_collision_shape(shape: Shape3D, xform: Transform3D = Transform3D.IDENTITY) -> void:
	if shape != null:
		collision_shapes.append(shape)
		collision_transforms.append(xform)

func to_mesh_instance(name_prefix: String = "GeometryCluster") -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	if section_id >= 0:
		inst.name = "%s_%d_%d" % [name_prefix, component_id, section_id]
	else:
		inst.name = "%s_%d" % [name_prefix, component_id]
	inst.mesh = mesh
	for slot_idx in material_slots.keys():
		var mat = material_slots[slot_idx]
		if mat is Material:
			inst.set_surface_override_material(slot_idx, mat)
	return inst

func create_collision_body(static_body: StaticBody3D = null) -> StaticBody3D:
	var body: StaticBody3D = static_body if static_body != null else StaticBody3D.new()
	for i in range(collision_shapes.size()):
		var shape := collision_shapes[i]
		var xform: Transform3D = collision_transforms[i] if i < collision_transforms.size() else Transform3D.IDENTITY
		var col_node := CollisionShape3D.new()
		col_node.name = "CollisionShape_%d" % i
		col_node.shape = shape
		col_node.transform = xform
		body.add_child(col_node)
	return body
