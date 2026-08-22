class_name FixtureSpawner
extends RefCounted

## Spawner y materializador físico de fixtures arquitectónicos en Staging.
## Instancia escenas personalizadas o genera mallas procedurales de alta fidelidad:
## - Antorchas de pared (TorchGeometryBuilder)
## - Faroles de pared y colgantes (LanternGeometryBuilder)
## - Braseros góticos de pie (BrazierGeometryBuilder)
## - Candelabros (CandleHolderGeometryBuilder)
## - Cúmulos de velas (CandleClusterGeometryBuilder)

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")

const _TorchGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/torch_geometry_builder.gd")
const _LanternGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/lantern_geometry_builder.gd")
const _LanternGeometryConfigScript = preload("res://src/geometry_generator/config/lantern_geometry_config.gd")
const _BrazierGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/brazier_geometry_builder.gd")
const _BrazierGeometryConfigScript = preload("res://src/geometry_generator/config/brazier_geometry_config.gd")
const _CandleHolderGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/candle_holder_geometry_builder.gd")
const _CandleHolderGeometryConfigScript = preload("res://src/geometry_generator/config/candle_holder_geometry_config.gd")
const _CandleClusterGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/candle_cluster_geometry_builder.gd")
const _CandleClusterGeometryConfigScript = preload("res://src/geometry_generator/config/candle_cluster_geometry_config.gd")

var _torch_builder = _TorchGeometryBuilderScript.new()
var _lantern_builder = _LanternGeometryBuilderScript.new()
var _brazier_builder = _BrazierGeometryBuilderScript.new()
var _candle_holder_builder = _CandleHolderGeometryBuilderScript.new()
var _candle_cluster_builder = _CandleClusterGeometryBuilderScript.new()

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
		elif directive.style != null:
			fixture_node = _materialize_procedural_fixture(directive)

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

func _materialize_procedural_fixture(directive: _FixtureDirectiveScript) -> Node3D:
	var root_node := Node3D.new()
	var style: _FixtureStyleScript = directive.style
	var scale_mult: float = directive.scale
	var generated_asset = null
	var light_offset := Vector3(0.0, 0.22 * scale_mult, 0.12 * scale_mult)

	match style.fixture_type:
		_FixtureStyleScript.Type.TORCH:
			generated_asset = _torch_builder.build_torch_fixture(scale_mult, scale_mult)
			light_offset = Vector3(0.0, 0.20 * scale_mult, 0.11 * scale_mult)

		_FixtureStyleScript.Type.LANTERN:
			var l_cfg = _LanternGeometryConfigScript.new()
			l_cfg.scale_mult = scale_mult
			l_cfg.is_wall_mounted = style.is_wall_mounted
			generated_asset = _lantern_builder.build_lantern_fixture(l_cfg)
			light_offset = Vector3(0.0, 0.05 * scale_mult, 0.0 if not style.is_wall_mounted else 0.12 * scale_mult)

		_FixtureStyleScript.Type.BRAZIER:
			var b_cfg = _BrazierGeometryConfigScript.new()
			b_cfg.scale_mult = scale_mult
			generated_asset = _brazier_builder.build_brazier_fixture(b_cfg)
			light_offset = Vector3(0.0, 0.70 * scale_mult, 0.0)

		_FixtureStyleScript.Type.CANDLE_HOLDER:
			var ch_cfg = _CandleHolderGeometryConfigScript.new()
			ch_cfg.scale_mult = scale_mult
			generated_asset = _candle_holder_builder.build_candle_holder_fixture(ch_cfg)
			light_offset = Vector3(0.0, 0.40 * scale_mult, 0.0)

		_FixtureStyleScript.Type.CANDLE_CLUSTER:
			var cc_cfg = _CandleClusterGeometryConfigScript.new()
			cc_cfg.scale_mult = scale_mult
			generated_asset = _candle_cluster_builder.build_candle_cluster_fixture(cc_cfg)
			light_offset = Vector3(0.0, 0.25 * scale_mult, 0.0)

	if generated_asset == null:
		return root_node

	# Montar todas las mallas del GeneratedAsset
	for slot in generated_asset.meshes.keys():
		var gm = generated_asset.get_mesh(slot)
		if gm != null and gm.mesh != null:
			var m_inst := MeshInstance3D.new()
			m_inst.name = String(slot).capitalize().replace(" ", "")
			m_inst.mesh = gm.mesh
			m_inst.transform = generated_asset.get_mesh_transform(slot)

			for mat_slot in gm.material_slots.keys():
				m_inst.set_surface_override_material(mat_slot, gm.material_slots[mat_slot])

			if style.collision_mode == _FixtureCollisionModeScript.Mode.STATIC_BODY and slot != &"flame" and slot != &"flames":
				m_inst.create_trimesh_collision()

			root_node.add_child(m_inst)

	# Luz local OmniLight3D
	if style.has_light:
		var light := OmniLight3D.new()
		light.name = "FixtureLight"
		light.position = light_offset
		light.light_color = style.light_color
		light.light_energy = style.light_energy
		light.omni_range = style.light_range
		light.shadow_enabled = true
		root_node.add_child(light)

	return root_node
