extends SceneTree

func _init() -> void:
	test_targetable_por_defecto()
	test_no_targetable()
	test_transicion_de_estado()
	print("test_targetable: OK")
	quit()

func test_targetable_por_defecto() -> void:
	assert(Targetable.new().is_targetable())

func test_no_targetable() -> void:
	assert(not Targetable.new(false).is_targetable())

func test_transicion_de_estado() -> void:
	var t := Targetable.new(true)
	t.set_targetable(false)
	assert(not t.is_targetable())
	t.set_targetable(true)
	assert(t.is_targetable())
