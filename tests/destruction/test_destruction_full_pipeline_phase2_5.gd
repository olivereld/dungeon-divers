extends SceneTree

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")

func _init() -> void:
	print("==================================================================")
	print("--- AUDITORÍA INTEGRAL: FASES 2.3, 2.4 & 2.5 (E2E PIPELINE) ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var d_reg := _DestructionRegistryScript.new()
	loader.populate_destruction_registry(d_reg)

	var d_service := _DestructionServiceScript.new()
	var provider := _PropAssetProviderScript.new()
	var staging := Node3D.new()

	var response_service := _DestructionResponseServiceScript.new(provider, 4242, staging)
	d_service.set_response_service(response_service)

	var binder := _DestructionBinderScript.new(d_reg, d_service)
	var spawner := _PropSpawnerScript.new(provider, binder)

	# --------------------------------------------------------------------------
	# BENCHMARK 1: URNA (BREAK -> Replacement + Debris + Effects)
	# --------------------------------------------------------------------------
	print("\n1. Probando Urna (BREAK)...")
	var style_urn = _PropStyleScript.new(
		&"crypt_urn_banded_floor", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"crypt_urn_banded_floor", {}, 0, []
	)
	var dir_urn = _PropDirectiveScript.new(
		&"crypt_urn_banded_floor", 1, style_urn, Vector3(2.0, 0.0, 3.0), 0.0, [Vector2i(1, 1)]
	)
	var urn_node = spawner.spawn_prop(dir_urn, staging)
	assert(urn_node != null, "FAIL: Urn must spawn")
	var urn_comp: _DestructionCompScript = urn_node.get_node("DestructionComponent")

	# Daño letal
	urn_comp.apply_hit(_DestructionHitScript.new(30.0, &"physical"))
	assert(urn_comp.is_destroyed(), "FAIL: Urn must be destroyed")
	assert(not urn_node.visible, "FAIL: Original urn must be hidden")

	# Verificar que staging contiene escombros y partículas
	var shards_found := 0
	var fx_found := 0
	for child in staging.get_children():
		if child.name.begins_with("Debris_ceramic_small"):
			shards_found += 1
		elif child.name.begins_with("FX_"):
			fx_found += 1

	print("   [OK] Escombros cerámicos generados: %d" % shards_found)
	print("   [OK] Emisores de partículas VFX generados: %d" % fx_found)
	assert(shards_found >= 3, "FAIL: Urn must generate at least 3 ceramic shards")
	assert(fx_found >= 1, "FAIL: Urn must trigger VFX particles")

	# --------------------------------------------------------------------------
	# BENCHMARK 2: PILA DE CALAVERAS (COLLAPSE -> Bone Debris + Bone Scatter FX)
	# --------------------------------------------------------------------------
	print("\n2. Probando Pila de Calaveras (COLLAPSE)...")
	var style_sk = _PropStyleScript.new(
		&"skull_pile", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"skull_pile", {}, 0, []
	)
	var dir_sk = _PropDirectiveScript.new(
		&"skull_pile", 1, style_sk, Vector3(6.0, 0.0, 3.0), 0.0, [Vector2i(3, 1)]
	)
	var sk_node = spawner.spawn_prop(dir_sk, staging)
	assert(sk_node != null, "FAIL: Skull pile must spawn")
	var sk_comp: _DestructionCompScript = sk_node.get_node("DestructionComponent")

	sk_comp.apply_hit(_DestructionHitScript.new(20.0, &"physical"))
	assert(sk_comp.is_destroyed(), "FAIL: Skull pile must be destroyed")
	assert(not sk_node.visible, "FAIL: Original skull pile must be hidden")

	var bone_shards := 0
	for child in staging.get_children():
		if child.name.begins_with("Debris_bones_small"):
			bone_shards += 1
	print("   [OK] Fragmentos de huesos generados: %d" % bone_shards)
	assert(bone_shards >= 4, "FAIL: Skull pile must generate at least 4 bone fragments")

	# --------------------------------------------------------------------------
	# BENCHMARK 3: COFRE / CAJA (BREAK -> Wood Splinters Debris)
	# --------------------------------------------------------------------------
	print("\n3. Probando Caja de Minas (BREAK)...")
	var style_crate = _PropStyleScript.new(
		&"mine_crate_corner", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"mine_crate_corner", {}, 0, []
	)
	var dir_crate = _PropDirectiveScript.new(
		&"mine_crate_corner", 1, style_crate, Vector3(10.0, 0.0, 3.0), 0.0, [Vector2i(5, 1)]
	)
	var crate_node = spawner.spawn_prop(dir_crate, staging)
	assert(crate_node != null, "FAIL: Crate must spawn")
	var crate_comp: _DestructionCompScript = crate_node.get_node("DestructionComponent")

	crate_comp.apply_hit(_DestructionHitScript.new(25.0, &"physical"))
	assert(crate_comp.is_destroyed(), "FAIL: Crate must be destroyed")

	var wood_shards := 0
	for child in staging.get_children():
		if child.name.begins_with("Debris_wood_splinters"):
			wood_shards += 1
	print("   [OK] Astillas de madera generadas: %d" % wood_shards)
	assert(wood_shards >= 3, "FAIL: Crate must generate wood splinters")

	staging.free()
	print("\n==================================================================")
	print("[PASS] Fases 2.3, 2.4 y 2.5 (Pipeline Completo E2E) superadas al 100%!")
	print("==================================================================")
	quit(0)
