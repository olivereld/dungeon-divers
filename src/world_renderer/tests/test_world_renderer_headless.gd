extends SceneTree

func _init() -> void:
	var result := WorldPipeline.generate(123, TaigaWorldProfile.new())
	var renderer := WorldRenderer.new()
	var node := renderer.render_world(result)
	assert(node != null)
	assert(node.has_node("TerrainMesh"))
	assert(node.has_node("TerrainCollision"))
	node.free()
	renderer.free()
	print("test_world_renderer_headless: OK")
	quit()
