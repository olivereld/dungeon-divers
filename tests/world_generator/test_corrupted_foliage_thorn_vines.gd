extends SceneTree

const _FoliageRendererScript = preload("res://src/world_generator/foliage/rendering/foliage_renderer.gd")
const _FoliageMaterialScript = preload("res://src/world_generator/foliage/rendering/foliage_material.gd")
const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _FoliageChunkDataScript = preload("res://src/world_generator/foliage/foliage_chunk_data.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _NecropolisProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" Testing Corrupted Foliage & Thorn Vines")
	print("==================================================")

	# 1. Validar las 4 especies de thorn vines y sus texturas
	for i in range(1, 5):
		var sp = _FoliageRendererScript.create_thorn_vines_species(i)
		assert(sp != null, "Thorn vines species must instantiate")
		assert(ResourceLoader.exists(sp.texture_path), "Texture must exist: %s" % sp.texture_path)
		assert(ResourceLoader.exists(sp.bark_texture_path), "Bark texture must exist: %s" % sp.bark_texture_path)
		assert(sp.tint_with_grass_color == false, "Thorn vines must not be tinted green with grass color")
		assert(sp.quad_cross_count == 3, "Thorn vines should have 3 crossed quads for volumetric density")
		assert(sp.color_top.r > sp.color_top.b * 1.8, "Thorn vines must have warm brown hue (not black or dark gray)")
		assert(sp.color_top.r >= 0.60, "Thorn vines must have sufficient brightness to contrast with dark ground")

		# Validar generación del ShaderMaterial con textura de ramas/corteza
		var mat = _FoliageMaterialScript.get_or_create_material(sp)
		assert(mat != null, "Material must instantiate")
		assert(mat is ShaderMaterial, "Material must be ShaderMaterial")
		var sm := mat as ShaderMaterial
		assert(sm.get_shader_parameter("use_bark_detail") == true, "Must enable use_bark_detail")
		assert(sm.get_shader_parameter("bark_detail_texture") != null, "Must assign bark_detail_texture")
		print(" [PASS] 1.%d Thorn vines 0%d species & material validated with bark texture" % [i, i])

	# 2. Validar filtrado de follaje en zona corrupta (reemplazo de hierba por thorn vines)
	var chunk_world = _ChunkWorldScript.new()
	var identity = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 12345)
	var poi = _DungeonPOIScript.new(identity, Vector3(0.0, 2.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var nec_profile = _NecropolisProfileScript.new()

	var fol_data = _FoliageChunkDataScript.new(Vector2i.ZERO)
	# Instancia 1: En núcleo ceremonial (distancia 2m) -> debe ser purgada completamente
	fol_data.add_instance(&"grass_common", Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -2.0)), Color.WHITE)
	# Instancias 2 a 20: En zona de corrupción (distancia 14m a 18m)
	for k in range(25):
		var ang := float(k) * 0.25
		var pos := Vector3(cos(ang) * 15.0, 2.0, sin(ang) * 15.0)
		fol_data.add_instance(&"grass_common", Transform3D(Basis.IDENTITY, pos), Color.WHITE)

	var filtered = chunk_world._filter_chunk_foliage_for_pois(fol_data, [poi], Vector3.ZERO, nec_profile)
	assert(filtered != null, "Filtered foliage data must exist")

	var thorn_vines_count := 0
	var grass_count := 0
	for sp_id in filtered.instances_by_species:
		var count: int = filtered.instances_by_species[sp_id].size()
		if String(sp_id).begins_with("thorn_vines"):
			thorn_vines_count += count
		elif String(sp_id).begins_with("grass"):
			grass_count += count

	print(" [INFO] En zona de corrupción: grass=%d, thorn_vines=%d" % [grass_count, thorn_vines_count])
	assert(grass_count <= 4, "Grass in corruption zone must be drastically reduced (got %d)" % grass_count)
	assert(thorn_vines_count >= 10, "Thorn vines must populate the corrupted zone (got %d)" % thorn_vines_count)

	# Validar que FoliageRenderer ensambla el nodo con las especies de thorn vines
	var foliage_node = _FoliageRendererScript.build_chunk_foliage_node(filtered, [], Vector3.ZERO)
	assert(foliage_node != null, "Foliage node must be built")
	var found_vine_node := false
	for child in foliage_node.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("Foliage_thorn_vines"):
			found_vine_node = true
			assert(child.multimesh != null and child.multimesh.instance_count > 0)
	assert(found_vine_node, "Foliage node must contain Foliage_thorn_vines MultiMeshInstance3D")

	print(" [PASS] 2. Foliage filtering & thorn vines MultiMesh generation verified")
	foliage_node.free()
	chunk_world.free()

	# 3. Validar filtrado con chunk offset NO nulo (e.g. Chunk (2, 4) con origin_3d = (32, 0, 64))
	var cw2 = _ChunkWorldScript.new()
	var poi_pos_offset := Vector3(37.0, 5.0, 73.0)
	var poi2 = _DungeonPOIScript.new(identity, poi_pos_offset, Transform3D.IDENTITY, &"necropolis", 1)
	var chunk_origin := Vector3(32.0, 0.0, 64.0)
	var fol_data_offset = _FoliageChunkDataScript.new(Vector2i(2, 4))
	for k in range(30):
		var ang := float(k) * 0.22
		var p_world := poi_pos_offset + Vector3(cos(ang) * 14.0, 0.0, sin(ang) * 14.0)
		fol_data_offset.add_instance(&"grass_common", Transform3D(Basis.IDENTITY, p_world), Color.WHITE)

	var filtered_offset = cw2._filter_chunk_foliage_for_pois(fol_data_offset, [poi2], chunk_origin, nec_profile)
	var offset_vines := 0
	var offset_grass := 0
	for sp_id in filtered_offset.instances_by_species:
		var count: int = filtered_offset.instances_by_species[sp_id].size()
		if String(sp_id).begins_with("thorn_vines"):
			offset_vines += count
		elif String(sp_id).begins_with("grass"):
			offset_grass += count

	print(" [INFO] Con chunk offset (32, 0, 64): grass=%d, thorn_vines=%d" % [offset_grass, offset_vines])
	assert(offset_grass <= 3, "Grass must be culled even with chunk origin offset")
	assert(offset_vines >= 15, "Thorn vines must spawn even with chunk origin offset")
	cw2.free()
	print(" [PASS] 3. Non-zero chunk offset foliage filtering verified")

	# 4. Validar NecropolisThornVinesSpawner y presencia en DungeonEntrancePOIView
	var _ThornVinesSpawnerScript = load("res://src/world_generator/poi/necropolis_thorn_vines_spawner.gd")
	var tv_node: Node3D = _ThornVinesSpawnerScript.generate_thorn_vines(poi2, nec_profile, null)
	assert(tv_node != null, "Thorn vines node must be generated")
	assert(tv_node.get_child_count() > 0, "Thorn vines node must have MultiMesh children")
	var total_tv_instances := 0
	for child in tv_node.get_children():
		if child is MultiMeshInstance3D and child.multimesh != null:
			total_tv_instances += child.multimesh.instance_count
	print(" [INFO] NecropolisThornVinesSpawner generó %d instancias totales de zarzas" % total_tv_instances)
	assert(total_tv_instances >= 20, "Should generate dense clusters of vines around entrance")
	tv_node.free()

	# Validar que DungeonEntrancePOIView incorpora ThornVines
	var _DungeonEntrancePOIViewScript = load("res://src/world_generator/presentation/dungeon_entrance_poi_view.gd")
	var entrance_view = _DungeonEntrancePOIViewScript.new(poi2, null)
	entrance_view._ready()
	var found_poi_tv = entrance_view.find_child("ThornVines", true, false)
	assert(found_poi_tv != null, "DungeonEntrancePOIView must contain ThornVines node")
	assert(found_poi_tv.get_child_count() > 0, "ThornVines node in POI view must have children")
	print(" [PASS] 4. DungeonEntrancePOIView has ThornVines with MultiMeshes")
	entrance_view.free()

	print("==================================================")
	print(" ALL CORRUPTED FOLIAGE TESTS PASSED!")
	print("==================================================")
	quit(0)
