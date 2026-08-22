extends SceneTree

## Test suite para validar la construcción de geometría procedural de Urnas (UrnGeometryBuilder).

const UrnGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/urn_geometry_builder.gd")
const UrnGeometryConfigScript = preload("res://src/geometry_generator/config/urn_geometry_config.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_urn_geometry_builder ---")
	print("==================================================================")

	var builder = UrnGeometryBuilderScript.new()

	# 1. Test Estilo 0: BANDED_STONE_URN
	var cfg_banded = UrnGeometryConfigScript.new(
		UrnGeometryConfigScript.Style.BANDED_STONE_URN,
		1.0, true, 12, 0, 1337
	)
	var asset_banded = builder.build_urn_fixture(cfg_banded)
	assert(asset_banded != null, "FAIL: Asset banded is null")
	assert(asset_banded.has_mesh(&"urn_body"), "FAIL: Banded urn has body mesh")
	assert(asset_banded.has_mesh(&"urn_trim"), "FAIL: Banded urn has trim mesh")
	var node_banded: Node3D = asset_banded.to_node3d("BandedUrn")
	assert(node_banded != null, "FAIL: Banded urn converted to Node3D")
	assert(node_banded.get_child_count() > 0, "FAIL: Banded urn has mesh child instances")
	node_banded.free()
	print("  [OK] Estilo 0: BANDED_STONE_URN validado correctamente.")

	# 2. Test Estilo 1: SKULL_RELIC_URN
	var cfg_skull = UrnGeometryConfigScript.new(
		UrnGeometryConfigScript.Style.SKULL_RELIC_URN,
		1.0, true, 12, 0, 1337
	)
	var asset_skull = builder.build_urn_fixture(cfg_skull)
	assert(asset_skull != null, "FAIL: Asset skull is null")
	assert(asset_skull.has_mesh(&"urn_body"), "FAIL: Skull urn has body mesh")
	assert(asset_skull.has_mesh(&"urn_trim"), "FAIL: Skull urn has trim mesh")
	var node_skull: Node3D = asset_skull.to_node3d("SkullUrn")
	assert(node_skull != null, "FAIL: Skull urn converted to Node3D")
	node_skull.free()
	print("  [OK] Estilo 1: SKULL_RELIC_URN validado correctamente.")

	# 3. Test Estilo 2: CEREMONIAL_PEDESTAL
	var cfg_pedestal = UrnGeometryConfigScript.new(
		UrnGeometryConfigScript.Style.CEREMONIAL_PEDESTAL,
		1.0, true, 12, 0, 1337
	)
	var asset_pedestal = builder.build_urn_fixture(cfg_pedestal)
	assert(asset_pedestal != null, "FAIL: Asset pedestal is null")
	assert(asset_pedestal.has_mesh(&"urn_body"), "FAIL: Pedestal urn has body mesh")
	assert(asset_pedestal.has_mesh(&"urn_trim"), "FAIL: Pedestal urn has trim mesh")
	var node_pedestal: Node3D = asset_pedestal.to_node3d("PedestalUrn")
	assert(node_pedestal != null, "FAIL: Pedestal urn converted to Node3D")
	node_pedestal.free()
	print("  [OK] Estilo 2: CEREMONIAL_PEDESTAL validado correctamente.")

	# 4. Test Estilo 3: CANOPIC_JAR (Superficie / Mesa)
	var cfg_canopic = UrnGeometryConfigScript.new(
		UrnGeometryConfigScript.Style.CANOPIC_JAR,
		0.65, true, 12, 0, 1337
	)
	var asset_canopic = builder.build_urn_fixture(cfg_canopic)
	assert(asset_canopic != null, "FAIL: Asset canopic is null")
	assert(asset_canopic.has_mesh(&"urn_body"), "FAIL: Canopic jar has body mesh")
	assert(asset_canopic.has_mesh(&"urn_trim"), "FAIL: Canopic jar has trim mesh")
	var node_canopic: Node3D = asset_canopic.to_node3d("CanopicJar")
	assert(node_canopic != null, "FAIL: Canopic jar converted to Node3D")
	node_canopic.free()
	print("  [OK] Estilo 3: CANOPIC_JAR (Surface) validado correctamente.")

	print("==================================================================")
	print("[PASS] test_urn_geometry_builder completado con 100% éxito!")
	print("==================================================================")
	quit(0)
