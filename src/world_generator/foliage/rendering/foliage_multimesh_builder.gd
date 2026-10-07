class_name FoliageMultiMeshBuilder
extends RefCounted

## Construye MultiMeshInstance3D optimizados a partir de datos de foliage.

const _FoliageMeshFactoryScript = preload("res://src/world_generator/foliage/rendering/foliage_mesh_factory.gd")
const _FoliageMaterialScript = preload("res://src/world_generator/foliage/rendering/foliage_material.gd")

static func build_multimesh(
	species: Resource,
	instances: Array,
	colors: PackedColorArray = PackedColorArray(),
	origin_offset: Vector3 = Vector3.ZERO,
	wind_strength: float = 0.35,
	wind_speed: float = 2.0
) -> MultiMeshInstance3D:
	if species == null or instances.is_empty():
		return null

	var cross_count: int = species.quad_cross_count if "quad_cross_count" in species else 2
	var mesh: ArrayMesh = _FoliageMeshFactoryScript.get_or_create_mesh(cross_count, 1.0, 1.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = instances.size()

	var has_colors := not colors.is_empty()

	for i in range(instances.size()):
		var tr: Transform3D = instances[i]
		if origin_offset != Vector3.ZERO:
			tr.origin = tr.origin - origin_offset
		mm.set_instance_transform(i, tr)
		if has_colors and i < colors.size():
			mm.set_instance_color(i, colors[i])
		else:
			mm.set_instance_color(i, Color.WHITE)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Foliage_" + String(species.id if "id" in species else &"unknown")
	mmi.multimesh = mm
	mmi.material_override = _FoliageMaterialScript.get_or_create_material(species, wind_strength, wind_speed)

	return mmi
