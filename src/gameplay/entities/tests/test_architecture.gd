# test_architecture.gd
# Tests de arquitectura: protegen reglas conceptuales, no solo números.
# Si alguno de estos falla, algo rompió la separación Living/Object que
# es el objetivo central de Entities v1.
#
# NOTA: Godot 4.6 rechaza `ObjectEntity is LivingEntity` como error de
# análisis estático (sabe que un ObjectEntity nunca puede ser LivingEntity).
# Para que los tests corran como checks de runtime, usamos variables sin tipo
# explícito (Variant) donde sea necesario.
extends SceneTree

func _init() -> void:
	test_object_entity_no_es_living()
	test_living_entity_si_es_living()
	test_targetable_no_implica_living()
	test_destructible_no_implica_living()
	test_faction_no_implica_living()
	print("test_architecture: OK")
	quit()

func test_object_entity_no_es_living() -> void:
	var barrel = ObjectEntity.new(EntityIdentity.new("barrel_003", EntityKind.Type.DESTRUCTIBLE_OBJECT))
	assert(not (barrel is LivingEntity))

func test_living_entity_si_es_living() -> void:
	var base := AttributeSet.new()
	var derived := StatCalculator.calculate_derived_stats(1, base, {})
	var player = LivingEntity.new(
		EntityIdentity.new("player_002", EntityKind.Type.PLAYER),
		Health.new(derived.max_hp),
		derived
	)
	assert(player is LivingEntity)

func test_targetable_no_implica_living() -> void:
	var turret = ObjectEntity.new(EntityIdentity.new("turret_003", EntityKind.Type.TURRET))
	turret.add_capability("targetable", Targetable.new(true))
	assert(turret.has_capability("targetable"))
	assert(not (turret is LivingEntity))

func test_destructible_no_implica_living() -> void:
	var crate = ObjectEntity.new(EntityIdentity.new("crate_001", EntityKind.Type.DESTRUCTIBLE_OBJECT))
	crate.add_capability("destructible", Destructible.new(Integrity.new(20.0)))
	assert(not (crate is LivingEntity))

func test_faction_no_implica_living() -> void:
	var guard_turret = ObjectEntity.new(EntityIdentity.new("guard_turret_001", EntityKind.Type.TURRET))
	guard_turret.add_capability("faction", Faction.new(FactionId.Type.GUARDS))
	assert(not (guard_turret is LivingEntity))
