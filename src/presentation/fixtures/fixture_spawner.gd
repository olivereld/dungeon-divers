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
const _TorchLightControllerScript = preload("res://src/dungeon_lighting/presentation/torch_light_controller.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")

var _torch_builder = _TorchGeometryBuilderScript.new()
var _lantern_builder = _LanternGeometryBuilderScript.new()
var _brazier_builder = _BrazierGeometryBuilderScript.new()
var _candle_holder_builder = _CandleHolderGeometryBuilderScript.new()
var _candle_cluster_builder = _CandleClusterGeometryBuilderScript.new()
var _destruction_binder: _DestructionBinderScript = null

func _init(binder: _DestructionBinderScript = null) -> void:
	_destruction_binder = binder if binder != null else _DestructionBinderScript.new()

func get_destruction_binder() -> _DestructionBinderScript:
	return _destruction_binder

func set_destruction_binder(binder: _DestructionBinderScript) -> void:
	if binder != null:
		_destruction_binder = binder

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
	var forward_mount_offset: float = 0.0
	var light_offset := Vector3(0.0, 0.22 * scale_mult, 0.12 * scale_mult)

	var eff_color: Color = directive.get_effective_color()
	var eff_energy: float = directive.get_effective_energy()
	var eff_range: float = directive.get_effective_range()

	match style.fixture_type:
		_FixtureStyleScript.Type.TORCH:
			generated_asset = _torch_builder.build_torch_fixture(scale_mult, scale_mult)
			forward_mount_offset = 0.22 * scale_mult
			light_offset = Vector3(0.0, 0.35 * scale_mult, forward_mount_offset)

		_FixtureStyleScript.Type.LANTERN:
			var l_cfg = _LanternGeometryConfigScript.new()
			l_cfg.scale_mult = scale_mult
			l_cfg.is_wall_mounted = style.is_wall_mounted
			if style.has_light:
				l_cfg.glass_color = eff_color
			generated_asset = _lantern_builder.build_lantern_fixture(l_cfg)
			if style.is_wall_mounted:
				forward_mount_offset = 0.42 * scale_mult
			light_offset = Vector3(0.0, -0.05 * scale_mult, forward_mount_offset)

		_FixtureStyleScript.Type.BRAZIER:
			var b_cfg = _BrazierGeometryConfigScript.new()
			b_cfg.scale_mult = scale_mult
			generated_asset = _brazier_builder.build_brazier_fixture(b_cfg)
			# Posicionar la fuente de luz justo sobre la cama de brasas/cáliz (Y=1.25m) para libre propagación
			light_offset = Vector3(0.0, 1.25 * scale_mult, 0.0)

		_FixtureStyleScript.Type.CANDLE_HOLDER:
			var ch_cfg = _CandleHolderGeometryConfigScript.new()
			ch_cfg.scale_mult = scale_mult
			if style.has_light:
				ch_cfg.flame_color = eff_color
			generated_asset = _candle_holder_builder.build_candle_holder_fixture(ch_cfg)
			light_offset = Vector3(0.0, 0.78 * scale_mult, 0.0)

		_FixtureStyleScript.Type.CANDLE_CLUSTER:
			var cc_cfg = _CandleClusterGeometryConfigScript.new()
			cc_cfg.scale_mult = scale_mult
			if style.has_light:
				cc_cfg.flame_color = eff_color
			generated_asset = _candle_cluster_builder.build_candle_cluster_fixture(cc_cfg)
			light_offset = Vector3(0.0, 0.38 * scale_mult, 0.0)

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
			if forward_mount_offset > 0.0:
				m_inst.position.z += forward_mount_offset

			for mat_slot in gm.material_slots.keys():
				m_inst.set_surface_override_material(mat_slot, gm.material_slots[mat_slot])

			# Evitar que la propia malla de la luminaria (cáliz, brasas, llamas o vidrios) atrape u ocluya su emisión lumínica
			var is_ember_or_glass: bool = (slot == &"lantern_glass" or slot == &"glass" or slot == &"flame" or slot == &"flames" or slot == &"firebed" or slot == &"glowing_firebed" or slot == &"coals")
			var is_brazier_mesh: bool = (style.fixture_type == _FixtureStyleScript.Type.BRAZIER)
			if is_ember_or_glass or is_brazier_mesh:
				m_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			if style.collision_mode == _FixtureCollisionModeScript.Mode.STATIC_BODY and not is_ember_or_glass:
				m_inst.create_trimesh_collision()

			root_node.add_child(m_inst)

	# Luz local OmniLight3D y controlador de parpadeo realista
	if style.has_light:
		var light := OmniLight3D.new()
		light.name = "FixtureLight"
		light.position = light_offset
		light.light_color = eff_color
		light.light_energy = eff_energy
		light.omni_range = eff_range
		light.omni_attenuation = 1.0
		light.shadow_enabled = true
		light.shadow_bias = 0.08
		root_node.add_child(light)

		# Controlador de parpadeo orgánico e intermitencia de velas
		var flicker := _TorchLightControllerScript.new()
		flicker.name = "FixtureFlicker"
		flicker.target_light = light
		flicker.base_energy = eff_energy

		match style.fixture_type:
			_FixtureStyleScript.Type.CANDLE_HOLDER:
				flicker.flicker_amplitude = 0.35 # Intermitencia notable y viva
				flicker.flicker_speed = 8.5      # Aleteo rápido característico de vela
			_FixtureStyleScript.Type.CANDLE_CLUSTER:
				flicker.flicker_amplitude = 0.30 # Oscilación colectiva de cúmulo
				flicker.flicker_speed = 7.5
			_FixtureStyleScript.Type.BRAZIER, _FixtureStyleScript.Type.TORCH:
				flicker.flicker_amplitude = 0.22
				flicker.flicker_speed = 6.0
			_FixtureStyleScript.Type.LANTERN:
				flicker.flicker_amplitude = 0.12
				flicker.flicker_speed = 4.5
			_:
				flicker.flicker_amplitude = 0.25
				flicker.flicker_speed = 6.5

		# Desfasar el tiempo según la posición espacial para evitar parpadeo sincronizado
		flicker.time_offset = float(directive.cell.x * 43.17 + directive.cell.y * 79.23 + directive.room_id * 17.5)
		light.add_child(flicker)

	if _destruction_binder != null and directive.fixture_id != &"":
		_destruction_binder.bind_prop(root_node, directive.fixture_id)

	return root_node
