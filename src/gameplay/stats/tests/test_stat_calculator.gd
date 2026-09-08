# test_stat_calculator.gd
# Test de ejemplo, escrito sin depender de ningún framework para que puedas
# ejecutarlo tal cual con `godot --headless --script res://tests/.../test_stat_calculator.gd`
# o adaptarlo fácilmente a GUT si ya lo usan en el proyecto (basta con
# convertir cada test_* en un método de un GutTest y cambiar assert() por
# assert_eq / assert_almost_eq).
extends SceneTree

func _init() -> void:
	test_nivel_1_valores_base()
	test_nivel_30_tanque()
	test_mitigacion_no_supera_el_tope()
	test_mago_vs_clerigo_usan_atributo_distinto()
	print("Todos los tests de StatCalculator pasaron correctamente.")
	quit()

func test_nivel_1_valores_base() -> void:
	var base := AttributeSet.new(10, 10, 10, 10, 10, 10)
	var derived := StatCalculator.calculate_derived_stats(1, base, {})
	assert(derived.max_hp == 95.0, "HP nivel 1 esperado 95, obtenido %s" % derived.max_hp)
	assert(derived.max_mana == 60.0, "Mana nivel 1 esperado 60, obtenido %s" % derived.max_mana)
	assert(derived.max_movement == 3.0, "Movimiento nivel 1 esperado 3, obtenido %s" % derived.max_movement)

func test_nivel_30_tanque() -> void:
	var base := AttributeSet.new(20, 15, 50, 12, 14, 10)
	var derived := StatCalculator.calculate_derived_stats(30, base, {})
	assert(derived.max_hp == 850.0, "HP nivel 30 CON50 esperado 850, obtenido %s" % derived.max_hp)

func test_mitigacion_no_supera_el_tope() -> void:
	# Un AC absurdamente alto (ej: bug de itemización) no debe superar el cap.
	var base := AttributeSet.new(10, 200, 10, 10, 10, 10)
	var stat_mods := {
		StatType.Type.ARMOR_CLASS: [StatModifier.new(StatModifierType.Type.ADD, 5000.0)]
	}
	var derived := StatCalculator.calculate_derived_stats(1, base, stat_mods)
	assert(derived.damage_mitigation <= StatCalculator.MITIGATION_CAP,
		"La mitigación no debería superar el cap, obtenido %s" % derived.damage_mitigation)

func test_mago_vs_clerigo_usan_atributo_distinto() -> void:
	var base := AttributeSet.new(10, 10, 10, 20, 8, 10)  # INT alto, WIS bajo
	var mago := StatCalculator.calculate_derived_stats(1, base, {}, StatCalculator.CastingStat.INTELLIGENCE)
	var clerigo := StatCalculator.calculate_derived_stats(1, base, {}, StatCalculator.CastingStat.WISDOM)
	assert(mago.max_mana > clerigo.max_mana,
		"Con INT alto y WIS bajo, el mago debería tener más maná que el clérigo")
