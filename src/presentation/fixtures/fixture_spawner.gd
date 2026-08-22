class_name FixtureSpawner
extends RefCounted

## Spawner y materializador físico de fixtures arquitectónicos en Staging.
## Instancia escenas personalizadas o genera mallas procedurales de alta fidelidad (TorchGeometryBuilder),
## configurando colisiones, mallas PBR y fuentes de iluminación local (OmniLight3D).

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")
const _TorchGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/torch_geometry_builder.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

var _torch_builder = _TorchGeometryBuilderScript.new()

## Spawnea todos los fixtures correspondientes a las directivas provistas dentro de staging_root.
func spawn_fixtures(
	directives: Array, # Array[FixtureDirective]
	staging_root: Node3D,
	biome: BiomeProfile,
	tile_size: float = 2.0
) -> Dictionary:
	var result := {
		"spawned_fixtures": [],
		"diagnostics": []
	}

	if directives.is_empty() or staging_root == null:
		return result

	var fixtures_container := Node3D.new()
	fixtures_container.name = "Fixtures"
	staging_root.add_child(fixtures_container)

	for directive in directives:
		if directive == null or not (directive is _FixtureDirectiveScript):
			continue

		var fixture_node: Node3D = null

		if directive.style != null and directive.style.custom_scene != null:
			fixture_node = directive.style.custom_scene.instantiate() as Node3D
		elif directive.style != null and directive.style.fixture_type == _FixtureStyleScript.Type.TORCH:
			fixture_node = _materialize_procedural_torch(directive)

		if fixture_node != null:
			fixture_node.name = "Fixture_%s_%d" % [str(directive.fixture_id), directive.room_id]
			fixture_node.position = directive.world_position
			fixture_node.rotation = Vector3(0.0, directive.rotation_y, 0.0)
			fixture_node.scale = Vector3.ONE * directive.scale

			fixture_node.set_meta("fixture_directive", directive)
			fixture_node.set_meta("room_id", directive.room_id)
			fixture_node.set_meta("fixture_id", directive.fixture_id)

			fixtures_container.add_child(fixture_node)
			result["spawned_fixtures"].append(fixture_node)

	return result

func _materialize_procedural_torch(directive: _FixtureDirectiveScript) -> Node3D:
	var root_node := Node3D.new()

	# Construir asset procedural de alta fidelidad (soporte de hierro + llama)
	var scale_mult: float = directive.scale
	var generated_asset = _torch_builder.build_torch_fixture(scale_mult, scale_mult)
	if generated_asset == null:
		return root_node

	var bracket_gm = generated_asset.get_mesh(&"bracket")
	var flame_gm = generated_asset.get_mesh(&"flame")

	# 1. Instanciar soporte de hierro forjado
	if bracket_gm != null and bracket_gm.mesh != null:
		var bracket_inst := MeshInstance3D.new()
		bracket_inst.name = "IronBracket"
		bracket_inst.mesh = bracket_gm.mesh
		bracket_inst.transform = generated_asset.get_mesh_transform(&"bracket")

		for slot in bracket_gm.material_slots.keys():
			bracket_inst.set_surface_override_material(slot, bracket_gm.material_slots[slot])

		if directive.style.collision_mode == _FixtureCollisionModeScript.Mode.STATIC_BODY:
			bracket_inst.create_trimesh_collision()

		root_node.add_child(bracket_inst)

	# 2. Instanciar llama estilizada
	if flame_gm != null and flame_gm.mesh != null:
		var flame_inst := MeshInstance3D.new()
		flame_inst.name = "StylizedFlame"
		flame_inst.mesh = flame_gm.mesh
		flame_inst.transform = generated_asset.get_mesh_transform(&"flame")

		for slot in flame_gm.material_slots.keys():
			flame_inst.set_surface_override_material(slot, flame_gm.material_slots[slot])

		root_node.add_child(flame_inst)

	# 3. Luz local OmniLight3D
	if directive.style.has_light:
		var light := OmniLight3D.new()
		light.name = "TorchLight"
		light.position = Vector3(0.0, 0.22 * scale_mult, 0.12 * scale_mult)
		light.light_color = directive.style.light_color
		light.light_energy = directive.style.light_energy
		light.omni_range = directive.style.light_range
		light.shadow_enabled = true
		root_node.add_child(light)

	return root_node
