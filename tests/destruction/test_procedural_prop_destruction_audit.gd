extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const _FixtureSpawnerScript = preload("res://src/presentation/fixtures/fixture_spawner.gd")
const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionDebugInteractorScript = preload("res://src/destruction/debug/destruction_debug_interactor.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")

func _init() -> void:
	print("==================================================================")
	print("--- AUDITORÍA INTEGRAL: Pipeline Procedural -> Destrucción ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var d_reg := _DestructionRegistryScript.new()
	var p_reg := _PropAssetRegistryScript.new()
	var p_provider := _PropAssetProviderScript.new()
	var d_service := _DestructionServiceScript.new()
	var d_binder := _DestructionBinderScript.new(d_reg, d_service)
	var prop_spawner := _PropSpawnerScript.new(p_provider, d_binder)
	var fixture_spawner := _FixtureSpawnerScript.new(d_binder)
	var interactor := _DestructionDebugInteractorScript.new(d_service)

	var destructibles = d_reg.get_all_definitions()
	print("1. Definiciones cargadas en DestructionRegistry: %d" % destructibles.size())
	assert(destructibles.size() > 0, "FAIL: destruction.json must have definitions")

	var audited_count := 0

	for def in destructibles:
		var asset_id: StringName = def.id
		var is_fixture: bool = (def.destruction_mode == _DestructionModeScript.Mode.EXTINGUISH or asset_id == &"candle_cluster" or asset_id == &"candle_holder")

		print("\n--- Auditando Elemento: %s (Tipo: %s, Modo: %s, Durabilidad: %.1f) ---" % [
			asset_id,
			"FIXTURE" if is_fixture else "PROP",
			_DestructionModeScript.to_name(def.destruction_mode),
			def.durability
		])

		var parent := Node3D.new()
		var node: Node3D = null

		if is_fixture:
			var fix_style = _FixtureStyleScript.new(
				asset_id,
				_FixtureStyleScript.Type.CANDLE_CLUSTER if asset_id == &"candle_cluster" else _FixtureStyleScript.Type.CANDLE_HOLDER,
				_FixturePlacementModeScript.Mode.FLOOR,
				1.0, Vector3.ZERO, false, 0, true, Color(1, 0.8, 0.5), 1.0, 4.0
			)
			var placement = _FixturePlacementScript.new(
				_FixturePlacementModeScript.Mode.FLOOR, Vector2i(5, 5), -1, Vector3(10.0, 0.0, 10.0), 0.0, Vector3.UP
			)
			var fix_dir = _FixtureDirectiveScript.new(
				asset_id, 1, fix_style, placement, 1.0
			)
			var fix_dict = fixture_spawner.spawn_fixtures([fix_dir], parent, null, 2.0)
			var fixtures_cont = parent.get_node_or_null("Fixtures")
			if fixtures_cont != null and fixtures_cont.get_child_count() > 0:
				node = fixtures_cont.get_child(0) as Node3D
		else:
			assert(p_reg.has_definition(asset_id), "FAIL: prop %s must exist in props.json" % asset_id)
			var style = _PropStyleScript.new(
				asset_id, _PropStyleScript.Type.RUBBLE,
				_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
				_PropFootprintScript.new(Vector2i(1, 1)), asset_id, {},
				_DecorationRoleScript.Role.SUPPORT, []
			)
			var directive = _PropDirectiveScript.new(
				asset_id, 1, style, Vector3(10.0, 0.0, 10.0), 0.0, [Vector2i(5, 5)]
			)
			node = prop_spawner.spawn_prop(directive, parent)

		assert(node != null, "FAIL: %s must materialize into Node3D" % asset_id)

		# C. Verificar vinculación automática de DestructionComponent sin hardcoding
		var comp: _DestructionCompScript = null
		for child in node.get_children():
			if child is _DestructionCompScript:
				comp = child
				break
		assert(comp != null, "FAIL: DestructionBinder must attach DestructionComponent to %s" % asset_id)
		assert(comp.current_durability == def.durability, "FAIL: initial durability must match JSON")

		# D. Verificar colisionadores físicos y resolución del raycast
		var colliders: Array[CollisionObject3D] = []
		_collect_colliders(node, colliders)
		print("   Colliders físicos encontrados: %d" % colliders.size())
		if def.destruction_mode != _DestructionModeScript.Mode.EXTINGUISH:
			assert(not colliders.is_empty(), "FAIL: physical destructible %s must have CollisionObject3D" % asset_id)

		for col in colliders:
			var resolved = interactor.resolve_destructible_from_collider(col)
			assert(resolved == comp, "FAIL: Interactor must resolve component from child collider on %s" % asset_id)

		# E. Simular Impactos de Mouse (1. Lógica, 2. Visual, 3. Física, 4. Persistencia)
		# 1. Daño progresivo
		var half_hit = _DestructionHitScript.new(def.durability * 0.5, &"physical")
		var hit_res = interactor.apply_hit_to_target(node, half_hit.damage, half_hit.damage_type, false)
		assert(hit_res.success, "FAIL: hit must succeed on %s" % asset_id)
		assert(comp.current_durability == def.durability * 0.5, "FAIL: durability after half damage on %s" % asset_id)
		assert(comp.current_state == _DestructionStateScript.State.DAMAGED or comp.current_state == _DestructionStateScript.State.CRITICAL, "FAIL: state must be damaged on %s" % asset_id)

		# 2. Daño fatal (Destrucción total)
		var fatal_hit = _DestructionHitScript.new(def.durability * 0.6, &"physical")
		var fatal_res = interactor.apply_hit_to_target(node, fatal_hit.damage, fatal_hit.damage_type, false)
		assert(fatal_res.success, "FAIL: fatal hit must succeed on %s" % asset_id)
		assert(comp.is_destroyed(), "FAIL: %s must be in DESTROYED state" % asset_id)

		# 3. Verificación de representación visual y física post-destrucción
		match def.destruction_mode:
			_DestructionModeScript.Mode.BREAK, _DestructionModeScript.Mode.COLLAPSE:
				assert(not node.visible, "FAIL: BREAK/COLLAPSE must hide root node for %s" % asset_id)
				for col in colliders:
					for sub in col.get_children():
						if sub is CollisionShape3D:
							assert(sub.disabled, "FAIL: collision shape must be disabled after destruction on %s" % asset_id)
				print("   [OK] Lógica + Visual + Física validadas correctamente para %s." % asset_id)

			_DestructionModeScript.Mode.EXTINGUISH:
				assert(node.visible, "FAIL: EXTINGUISH must keep base mesh visible for %s" % asset_id)
				print("   [OK] Lógica + Extinción validadas correctamente para %s." % asset_id)

		parent.free()
		audited_count += 1

	print("\n==================================================================")
	print("[PASS] Auditoría Integral superada al 100%%. Total elementos auditados: %d" % audited_count)
	print("==================================================================")
	quit(0)

func _collect_colliders(n: Node, list: Array[CollisionObject3D]) -> void:
	if n is CollisionObject3D:
		list.append(n as CollisionObject3D)
	for c in n.get_children():
		_collect_colliders(c, list)
