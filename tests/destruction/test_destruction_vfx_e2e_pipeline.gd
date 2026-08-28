extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_vfx_e2e_pipeline (Task 6 - E2E) ---")
	print("==================================================================")
	var loader := _ProfileLoaderScript.new()
	var d_reg := _DestructionRegistryScript.new()
	loader.populate_destruction_registry(d_reg)

	var d_service := _DestructionServiceScript.new()
	var provider := _PropAssetProviderScript.new()
	var staging := Node3D.new()
	var resp_service := _DestructionResponseServiceScript.new(provider, 1337, staging)
	d_service.set_response_service(resp_service)

	var binder := _DestructionBinderScript.new(d_reg, d_service)
	var spawner := _PropSpawnerScript.new(provider, binder)

	# 1. Probar Urna Cripta -> stone_break + small_dust
	print("1. Probando Urna Cripta...")
	var style_urn = _PropStyleScript.new(
		&"crypt_urn_banded_floor", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"crypt_urn_banded_floor", {}, 0, []
	)
	var dir_urn = _PropDirectiveScript.new(
		&"crypt_urn_banded_floor", 1, style_urn, Vector3(5.0, 0.0, 5.0), 0.0, [Vector2i(1, 1)]
	)
	var urn = spawner.spawn_prop(dir_urn, staging)
	var urn_comp = urn.get_node("DestructionComponent")
	urn_comp.apply_hit(_DestructionHitScript.new(50.0, &"physical"))

	var vfx_urn_count := 0
	for child in staging.get_children():
		if child.name.begins_with("VFX_"):
			vfx_urn_count += 1
			assert(child is _VFXInstanceScript, "FAIL: spawned VFX must be instance of VFXInstance")

	print("   [OK] Instancias VFX generadas para Urna: %d" % vfx_urn_count)
	assert(vfx_urn_count >= 1, "FAIL: Urna must trigger VFX (small_dust)")

	# 2. Probar Caja de Minas -> wood_break + small_dust
	print("2. Probando Caja de Madera...")
	var style_crate = _PropStyleScript.new(
		&"mine_crate_corner", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"mine_crate_corner", {}, 0, []
	)
	var dir_crate = _PropDirectiveScript.new(
		&"mine_crate_corner", 1, style_crate, Vector3(10.0, 0.0, 5.0), 0.0, [Vector2i(3, 1)]
	)
	var crate = spawner.spawn_prop(dir_crate, staging)
	var crate_comp = crate.get_node("DestructionComponent")
	crate_comp.apply_hit(_DestructionHitScript.new(50.0, &"physical"))

	var vfx_crate_found := false
	for child in staging.get_children():
		if child.name == "VFX_WoodBreak":
			vfx_crate_found = true

	assert(vfx_crate_found, "FAIL: VFX_WoodBreak must be spawned for crate")
	print("   [OK] VFX_WoodBreak instanciado correctamente para Caja de Madera.")

	staging.free()
	print("\n==================================================================")
	print("[PASS] test_destruction_vfx_e2e_pipeline passed 100%!")
	print("==================================================================")
	quit(0)
