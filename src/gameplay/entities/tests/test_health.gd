extends SceneTree

func _init() -> void:
	test_dano_normal()
	test_dano_cero()
	test_dano_negativo_se_clampa()
	test_dano_superior_a_hp()
	test_curacion_normal()
	test_curacion_superior_a_max()
	test_curacion_negativa_se_clampa()
	test_limites_exactos()
	print("test_health: OK")
	quit()

func test_dano_normal() -> void:
	var h := Health.new(100.0)
	assert(h.apply_damage(30.0) == 30.0)
	assert(h.current_hp == 70.0)

func test_dano_cero() -> void:
	var h := Health.new(100.0)
	assert(h.apply_damage(0.0) == 0.0)
	assert(h.current_hp == 100.0)

func test_dano_negativo_se_clampa() -> void:
	var h := Health.new(100.0)
	assert(h.apply_damage(-20.0) == 0.0)
	assert(h.current_hp == 100.0)

func test_dano_superior_a_hp() -> void:
	var h := Health.new(50.0)
	assert(h.apply_damage(999.0) == 50.0)
	assert(h.current_hp == 0.0)
	assert(h.is_dead())

func test_curacion_normal() -> void:
	var h := Health.new(100.0)
	h.apply_damage(40.0)
	assert(h.heal(15.0) == 15.0)
	assert(h.current_hp == 75.0)

func test_curacion_superior_a_max() -> void:
	var h := Health.new(100.0)
	h.apply_damage(10.0)
	assert(h.heal(999.0) == 10.0)
	assert(h.current_hp == 100.0)

func test_curacion_negativa_se_clampa() -> void:
	var h := Health.new(100.0)
	h.apply_damage(20.0)
	assert(h.heal(-5.0) == 0.0)
	assert(h.current_hp == 80.0)

func test_limites_exactos() -> void:
	var h := Health.new(1.0)
	assert(h.current_hp == 1.0)
	h.apply_damage(1.0)
	assert(h.current_hp == 0.0)
	assert(h.is_dead())
