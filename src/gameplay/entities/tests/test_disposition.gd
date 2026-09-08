extends SceneTree

func _init() -> void:
	test_valores_limite()
	test_clamp_inferior()
	test_clamp_superior()
	test_valores_intermedios()
	test_thresholds()
	print("test_disposition: OK")
	quit()

func test_valores_limite() -> void:
	assert(Disposition.new(-100.0).value == -100.0)
	assert(Disposition.new(0.0).value == 0.0)
	assert(Disposition.new(100.0).value == 100.0)

func test_clamp_inferior() -> void:
	assert(Disposition.new(-500.0).value == -100.0)

func test_clamp_superior() -> void:
	assert(Disposition.new(500.0).value == 100.0)

func test_valores_intermedios() -> void:
	assert(Disposition.new(25.0).value == 25.0)

func test_thresholds() -> void:
	assert(Disposition.new(-80.0).is_hostile())
	assert(Disposition.new(0.0).is_neutral())
	assert(Disposition.new(75.0).is_friendly())
	assert(not Disposition.new(0.0).is_hostile())
	assert(not Disposition.new(0.0).is_friendly())
