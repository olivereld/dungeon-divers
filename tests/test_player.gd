class_name TestPlayerMovement
extends SceneTree

const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _DungeonLevelControllerScript = preload("res://scenes/dungeon/dungeon_level_controller.gd")

func _init() -> void:
	print("--- Running test_player ---")

	# Test 1: Instanciación e inicialización de nodos internos
	var player = _PlayerTestScript.new()
	root.add_child(player)
	player._ready()

	assert(player.get_node_or_null("CollisionShape3D") != null, "Player must have a CollisionShape3D")
	assert(player.get_node_or_null("Visuals") != null, "Player must have a Visuals node")
	assert(player.get_node("Visuals").get_node_or_null("BodyMesh") != null, "Player must have a BodyMesh")
	assert(player.get_node("Visuals").get_node_or_null("VisorMesh") != null, "Player must have a VisorMesh")
	print("  [OK] Test 1: Player capsule and visuals properly configured")

	# Test 2: Simulación de física / gravedad
	player.position = Vector3(0, 5, 0)
	player._physics_process(0.1)
	assert(player.velocity.y < 0.0, "Player should fall under gravity when not on floor")
	print("  [OK] Test 2: Player physics and gravity verified")

	player.queue_free()

	# Test 3: Spawn en DungeonLevelController
	var controller = _DungeonLevelControllerScript.new()
	var cfg: DungeonConfig = preload("res://resources/configs/cave_dungeon.tres").duplicate()
	cfg.seed = 12345
	cfg.use_fixed_seed = true
	controller.config = cfg
	root.add_child(controller)
	controller.regenerate(false)

	assert(controller._player != null, "PlayerTest must be automatically spawned by DungeonLevelController")
	assert(controller.has_node("PlayerTest"), "PlayerTest must be a child of DungeonLevelController")
	print("  [OK] Test 3: PlayerTest successfully spawned and placed in generated dungeon")

	controller.queue_free()

	print("[PASS] test_player completed successfully with 100% assertions passing!")
	quit(0)
