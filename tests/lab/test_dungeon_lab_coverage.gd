extends SceneTree

const _ShowcaseScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_template_showcase.gd")
const _CoverageScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_coverage.gd")
const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_coverage ---")
	var pipeline = _PipelineScript.new()
	var val_res = pipeline.load_profiles("necropolis")
	assert(val_res.is_valid, "FAIL: necropolis bundle must be valid")

	var bundle = pipeline.get_profile_bundle()

	# 1. Test Showcase
	var showcase = _ShowcaseScript.new()
	var crypt_items = showcase.showcase_profile(&"crypt", bundle.template_registry)
	assert(crypt_items.size() >= 4, "FAIL: crypt showcase should find at least 4 crypt templates")
	assert(crypt_items[0].has("id") and crypt_items[0].has("cells"), "FAIL: showcase items must have id and cells")

	# 2. Test Coverage
	var coverage = _CoverageScript.new()
	var report = coverage.run_coverage(pipeline, &"necropolis", 100001, 10) # 10 seeds for fast unit test
	assert(report != null, "FAIL: coverage must produce a report")
	assert(report["seed_count"] == 10, "FAIL: seed_count mismatch")
	assert(report["total_rooms"] > 0, "FAIL: total_rooms must be > 0")
	assert(report.has("profile_distribution"), "FAIL: report must contain profile_distribution")
	assert(report.has("template_selection_counts"), "FAIL: report must contain template_selection_counts")
	assert(report.has("coverage_percentage"), "FAIL: report must contain coverage_percentage")

	# 3. Test Export Report
	var export_path := "user://test_coverage_report.json"
	var exported = coverage.export_report(report, export_path)
	assert(exported, "FAIL: export_report should succeed")
	assert(FileAccess.file_exists(export_path), "FAIL: exported report file must exist")

	print("PASS: test_dungeon_lab_coverage passed!")
	quit(0)
