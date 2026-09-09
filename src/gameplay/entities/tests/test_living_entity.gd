extends SceneTree

func _init() -> void:
	test_creacion_y_vida()
	test_alive_dead()
	test_integracion_con_derived_stats()
	print("test_living_entity: OK")
	quit()

func _make_derived_stats() -> DerivedStats:
	var base := AttributeSet.new(12, 14, 13, 10, 10, 8)
	return StatCalculator.calculate_derived_stats(5, base, {})

func test_creacion_y_vida() -> void:
	var identity := EntityIdentity.new("player_001", EntityKind.Type.PLAYER, "Hero")
	var derived := _make_derived_stats()
	var health := Health.new(derived.max_hp)
	var player := LivingEntity.new(identity, health, derived)
	assert(player.health.current_hp == derived.max_hp)
	assert(player.is_alive())

func test_alive_dead() -> void:
	var identity := EntityIdentity.new("goblin_002", EntityKind.Type.MONSTER)
	var derived := _make_derived_stats()
	var health := Health.new(10.0)
	var goblin := LivingEntity.new(identity, health, derived)
	assert(goblin.is_alive())
	health.apply_damage(10.0)
	assert(goblin.is_dead())
	assert(not goblin.is_alive())

func test_integracion_con_derived_stats() -> void:
	var identity := EntityIdentity.new("mage_001", EntityKind.Type.NPC)
	var derived := _make_derived_stats()
	var health := Health.new(derived.max_hp)
	var mage := LivingEntity.new(identity, health, derived)
	# DerivedStats NO se duplica: debe ser la MISMA referencia, no una copia.
	assert(mage.derived_stats == derived)
