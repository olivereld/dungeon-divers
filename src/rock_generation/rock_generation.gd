class_name RockGeneration
extends RefCounted

const RockSizeProfile = preload("res://src/rock_generation/rock_size_profile.gd")
const RockMeshBuilder = preload("res://src/rock_generation/rock_mesh_builder.gd")
const RockMaterial = preload("res://src/rock_generation/rock_material.gd")
const RockInstance = preload("res://src/rock_generation/rock_instance.gd")
const RockDistribution = preload("res://src/rock_generation/rock_distribution.gd")

## Fachada y orquestador del sistema de generación procedural de rocas estilizadas.
## Módulo 100% autónomo e independiente.
## Gestiona perfiles, mallas pregeneradas en caché, material y generación de MultiMeshes.

var profiles: Dictionary = {} # int (Category) -> RockSizeProfile
var mesh_variants: Dictionary = {} # int (Category) -> Array[ArrayMesh]
var shared_material: ShaderMaterial = null
var base_seed: int = 1337

func _init(p_base_seed: int = 1337, custom_profiles: Dictionary = {}) -> void:
	base_seed = p_base_seed
	if custom_profiles.is_empty():
		profiles = RockSizeProfile.get_all_profiles()
	else:
		profiles = custom_profiles

	shared_material = RockMaterial.create_rock_material()
	_pregenerate_mesh_variants()

## Pre-genera variantes de malla facetadas para cada categoría
func _pregenerate_mesh_variants() -> void:
	mesh_variants.clear()
	for cat in profiles.keys():
		var prof: RockSizeProfile = profiles[cat]
		var variants: Array[ArrayMesh] = []
		var count: int = max(1, prof.num_variants)
		for v in range(count):
			var variant_seed: int = (base_seed * 49979687) ^ (cat * 73856093) ^ (v * 19349663)
			var m: ArrayMesh = RockMeshBuilder.build_rock_mesh(prof, variant_seed)
			if shared_material != null:
				m.surface_set_material(0, shared_material)
			variants.append(m)
		mesh_variants[cat] = variants

## Obtiene una variante de malla pregenerada
func get_mesh(category: int, variant_index: int = 0) -> ArrayMesh:
	if mesh_variants.has(category):
		var variants: Array = mesh_variants[category]
		if not variants.is_empty():
			return variants[variant_index % variants.size()]
	return null

## Obtiene el material compartido de las rocas
func get_material() -> ShaderMaterial:
	return shared_material

## Genera la lista de instancias calculadas para un área específica
func generate_instances(
	bounds: Rect2,
	world_seed: int,
	terrain_query_fn: Callable = Callable()
) -> Array[RockInstance]:
	return RockDistribution.generate_area_rocks(bounds, world_seed, profiles, terrain_query_fn)

## Empaqueta una lista de RockInstance en nodos MultiMeshInstance3D listos para renderizar
## Retorna un Array[MultiMeshInstance3D] ordenados por categoría y variante
func create_multimesh_nodes(instances: Array[RockInstance]) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []

	# Agrupar instancias por (category, variant_index)
	# key: "cat_variant"
	var grouped: Dictionary = {}
	for inst in instances:
		var key: String = "%d_%d" % [inst.category, inst.variant_index]
		if not grouped.has(key):
			grouped[key] = {
				"category": inst.category,
				"variant": inst.variant_index,
				"instances": []
			}
		grouped[key]["instances"].append(inst)

	for key in grouped.keys():
		var group: Dictionary = grouped[key]
		var cat: int = group["category"]
		var var_idx: int = group["variant"]
		var inst_list: Array = group["instances"]
		var count: int = inst_list.size()

		if count == 0:
			continue

		var mesh: ArrayMesh = get_mesh(cat, var_idx)
		if mesh == null:
			continue

		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "RockMultiMesh_Cat%d_Var%d" % [cat, var_idx]

		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true # Usado para enviar variación de material al shader
		mm.mesh = mesh
		mm.instance_count = count

		for i in range(count):
			var r_inst: RockInstance = inst_list[i]
			mm.set_instance_transform(i, r_inst.transform)
			mm.set_instance_custom_data(i, r_inst.custom_data)

		mmi.multimesh = mm
		if shared_material != null:
			mmi.material_override = shared_material

		result.append(mmi)

	return result
