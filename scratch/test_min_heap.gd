@tool
extends SceneTree

# MinHeap test for Priority Flood
class PriorityQueue:
	var _data: Array[Dictionary] = []

	func push(pos: Vector2i, height: float) -> void:
		_data.append({ "pos": pos, "height": height })
		var idx := _data.size() - 1
		while idx > 0:
			var parent := (idx - 1) >> 1
			if _data[idx]["height"] < _data[parent]["height"]:
				var tmp = _data[idx]
				_data[idx] = _data[parent]
				_data[parent] = tmp
				idx = parent
			else:
				break

	func pop() -> Dictionary:
		var root: Dictionary = _data[0]
		var last: Dictionary = _data.pop_back()
		if not _data.is_empty():
			_data[0] = last
			var idx := 0
			var count := _data.size()
			while true:
				var left := (idx << 1) + 1
				var right := left + 1
				var smallest := idx
				if left < count and _data[left]["height"] < _data[smallest]["height"]:
					smallest = left
				if right < count and _data[right]["height"] < _data[smallest]["height"]:
					smallest = right
				if smallest != idx:
					var tmp = _data[idx]
					_data[idx] = _data[smallest]
					_data[smallest] = tmp
					idx = smallest
				else:
					break
		return root

	func is_empty() -> bool:
		return _data.is_empty()

	func size() -> int:
		return _data.size()

func _init() -> void:
	print("--- Testing MinHeap Priority Queue ---")
	var pq := PriorityQueue.new()
	pq.push(Vector2i(0, 0), 10.5)
	pq.push(Vector2i(1, 1), 3.2)
	pq.push(Vector2i(2, 2), 7.8)
	pq.push(Vector2i(3, 3), 1.1)
	pq.push(Vector2i(4, 4), 15.0)

	var prev := -INF
	while not pq.is_empty():
		var item := pq.pop()
		print("  Popped: ", item["pos"], " height: ", item["height"])
		assert(item["height"] >= prev, "Must be sorted ascending")
		prev = item["height"]

	print("MinHeap PASS OK!")
	quit(0)
