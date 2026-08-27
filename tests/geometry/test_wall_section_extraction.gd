extends SceneTree

const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallSectionExtractorScript = preload("res://src/geometry_generator/extraction/wall_section_extractor.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_section_extraction ---")
	print("==================================================================")

	var comp := _WallComponentScript.new(1)
	# Rectángulo 10x4 celdas
	var loop: Array[Vector2i] = []
	for x in range(0, 11):
		loop.append(Vector2i(x, 0))
	for y in range(1, 5):
		loop.append(Vector2i(10, y))
	for x in range(9, -1, -1):
		loop.append(Vector2i(x, 4))
	for y in range(3, -1, -1):
		loop.append(Vector2i(0, y))
	comp.add_loop(loop)

	var extractor := _WallSectionExtractorScript.new()
	var sections = extractor.extract_sections(comp, 2, 6, 5)

	assert(sections.size() > 4, "FAIL: A 10x4 room should extract into more than 4 sections with max_length=6 (got %d)" % sections.size())

	for sec in sections:
		assert(sec.component_id == 1, "FAIL: component_id")
		assert(sec.room_id == 5, "FAIL: room_id")
		assert(sec.points.size() >= 2, "FAIL: points size")
		assert(sec.length <= 6.0, "FAIL: section length should be <= max_length (got %f)" % sec.length)

	print("  [OK] WallSectionExtractor extracts corner-split and length-subdivided sections.")
	print("==================================================================")
	print("[PASS] test_wall_section_extraction passed successfully!")
	print("==================================================================")
	quit(0)
