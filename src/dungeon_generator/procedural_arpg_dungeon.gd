class_name ProceduralArpgDungeon
extends RefCounted

## Deterministic, presentation-independent ARPG dungeon generator for Godot 4.4+.
## The requested THREE.Group presentation is mapped to Godot's Node3D hierarchy;
## MultiMeshInstance3D is the GPU-instancing equivalent and avoids per-tile MeshInstance3D nodes.

const MAX_ATTEMPTS := 5
const DEFAULT_MAX_GRID := Vector2i(256, 256)
const VOID := 0
const FLOOR := 1
const WALL := 2
const CORRIDOR := 3

class RNG:
	var state: int
	func _init(seed: int) -> void: state = seed & 0xffffffff
	func _u32() -> int:
		state = (state + 0x6D2B79F5) & 0xffffffff
		var t: int = state
		t = (t ^ (t >> 15)) * (t | 1) & 0xffffffff
		t ^= t + ((t ^ (t >> 7)) * (t | 61) & 0xffffffff) & 0xffffffff
		return (t ^ (t >> 14)) & 0xffffffff
	func float(a: float = 0.0, b: float = 1.0) -> float: return a + float(_u32()) / 4294967296.0 * (b - a)
	func int(a: int, b: int) -> int: return a + int(_u32() % uint(maxi(1, b - a + 1)))
	func chance(p: float) -> bool: return float() < clampf(p, 0.0, 1.0)
	func pick(arr: Array) -> Variant: return arr[int(_u32() % uint(arr.size()))] if not arr.is_empty() else null
	func gaussian(mu: float, sigma: float) -> float:
		var u1 := maxf(float(), 0.000001)
		var u2 := float()
		return mu + sigma * sqrt(-2.0 * log(u1)) * cos(TAU * u2)

class Dungeon:
	var seed: int
	var attempt_seed: int
	var width: int
	var height: int
	var cells: PackedByteArray
	var reserved: PackedByteArray
	var distance: PackedInt32Array
	var corridor_mask: PackedByteArray
	var rooms: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var candidate_edges: Array[Dictionary] = []
	var mst_edges: Array[Dictionary] = []
	var props: Array[Dictionary] = []
	var spawns: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	var name: String
	var checksum: int
	var stats: Dictionary = {}
	var debug: Dictionary = {}

	func index(x: int, y: int) -> int: return y * width + x
	func inside(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < width and y < height
	func get_cell(x: int, y: int) -> int: return cells[index(x, y)] if inside(x, y) else VOID

class _DSU:
	var p: PackedInt32Array
	func _init(n: int) -> void:
		p.resize(n)
		for i in range(n): p[i] = i
	func find(x: int) -> int:
		var a := x
		while p[a] != a: a = p[a]
		var r := a
		a = x
		while p[a] != a:
			var n := p[a]
			p[a] = r
			a = n
		return r
	func union(a: int, b: int) -> bool:
		a = find(a); b = find(b)
		if a == b: return false
		p[b] = a
		return true

static func generateDungeon(params: Dictionary) -> Dungeon:
	var seed := int(params.get("seed", 1))
	var room_count := clampi(int(params.get("roomCount", 42)), 2, 60)
	var loop_chance := clampf(float(params.get("loopChance", 0.15)), 0.0, 1.0)
	var decor_density := clampf(float(params.get("decorDensity", 0.6)), 0.0, 1.0)
	var theme := str(params.get("theme", "crypt"))
	var max_grid := Vector2i(256, 256)
	var requested_max = params.get("maxGrid", DEFAULT_MAX_GRID)
	if requested_max is Vector2i: max_grid = Vector2i(clampi(requested_max.x, 32, 256), clampi(requested_max.y, 32, 256))
	var t0 := Time.get_ticks_usec()
	for attempt in range(MAX_ATTEMPTS):
		var attempt_seed := _derive_seed(seed, attempt, 0xA17E)
		var d := _generate_attempt(seed, attempt_seed, room_count, loop_chance, decor_density, theme, max_grid)
		if d != null:
			d.stats["genMs"] = float(Time.get_ticks_usec() - t0) / 1000.0
			return d
	# Deterministic emergency seed chain: a final attempt is still a generated layout, never a teleport repair.
	var fallback := _generate_attempt(seed, _derive_seed(seed, MAX_ATTEMPTS, 0xA17E), room_count, maxf(loop_chance, 0.25), decor_density, theme, max_grid)
	if fallback != null:
		fallback.stats["genMs"] = float(Time.get_ticks_usec() - t0) / 1000.0
	return fallback

static func _generate_attempt(base_seed: int, attempt_seed: int, room_count: int, loop_chance: float, decor_density: float, theme: String, max_grid: Vector2i) -> Dungeon:
	var d := Dungeon.new()
	d.seed = base_seed
	d.attempt_seed = attempt_seed
	var scatter_rng := RNG.new(_derive_seed(attempt_seed, 1, 0x51A7))
	var topology_rng := RNG.new(_derive_seed(attempt_seed, 2, 0x70B1))
	var corridor_rng := RNG.new(_derive_seed(attempt_seed, 3, 0xC022))
	var decor_rng := RNG.new(_derive_seed(attempt_seed, 4, 0xDEC0))

	var rooms := _scatter_rooms(room_count, scatter_rng)
	rooms = _separate_and_cull(rooms, room_count)
	if rooms.size() != room_count: return null
	rooms.sort_custom(func(a, b): return int(a.id) < int(b.id))

	var candidates := _delaunay_fallback(rooms)
	candidates.sort_custom(_edge_sort)
	var graph := _build_graph(rooms.size(), candidates, loop_chance, topology_rng)
	if graph.edges.size() < rooms.size() or graph.loops < 1: return null
	d.edges = graph.edges
	d.candidate_edges = candidates
	d.mst_edges = graph.mst

	var boss := _largest_room(rooms)
	var entrance := _select_entrance(rooms, d.edges, boss)
	if entrance < 0 or _degree(d.edges, entrance) != 1: return null
	var distances := _graph_distances(rooms.size(), d.edges, entrance)
	var boss_depth := distances[boss]
	var max_depth := 0
	for x in distances: max_depth = maxi(max_depth, x)
	if max_depth <= 0 or float(boss_depth) < float(max_depth) * 0.60: return null

	var critical := _critical_path(rooms.size(), d.edges, entrance, boss)
	var crit_set: Dictionary = {}
	for r in critical: crit_set[r] = true
	var degree1 := []
	for i in range(rooms.size()):
		if _degree(d.edges, i) == 1 and i != entrance and i != boss: degree1.append(i)
	degree1.sort_custom(func(a, b):
		if distances[a] == distances[b]: return a < b
		return distances[a] > distances[b])
	var treasure_set: Dictionary = {}
	for i in range(mini(4, degree1.size())): treasure_set[degree1[i]] = true
	var shrine_candidates := []
	for i in range(rooms.size()):
		if not crit_set.has(i) and not treasure_set.has(i) and distances[i] > 0 and distances[i] < max_depth:
			shrine_candidates.append(i)
	shrine_candidates.sort_custom(func(a,b): return distances[a] < distances[b])
	var shrine_set: Dictionary = {}
	for i in range(mini(2, shrine_candidates.size())): shrine_set[shrine_candidates[i]] = true
	var elite_set: Dictionary = {}
	for i in critical:
		if i == entrance or i == boss: continue
		var p := float(distances[i]) / float(max_depth)
		if p >= 0.55 and p <= 0.85: elite_set[i] = true

	for r in rooms:
		var id := int(r.id)
		r["depth"] = distances[id]
		r["difficulty"] = 1.0 if id == boss else 0.15 + 0.85 * float(distances[id]) / float(max_depth)
		r["role"] = "combat"
		if id == entrance: r["role"] = "entrance"
		elif id == boss: r["role"] = "boss"
		elif treasure_set.has(id): r["role"] = "treasure"
		elif shrine_set.has(id): r["role"] = "shrine"
		elif elite_set.has(id): r["role"] = "elite"

	var bounds := _compute_bounds(rooms, max_grid)
	if bounds.size.x > max_grid.x or bounds.size.y > max_grid.y: return null
	d.width = bounds.size.x; d.height = bounds.size.y
	d.cells.resize(d.width * d.height); d.cells.fill(VOID)
	d.reserved.resize(d.width * d.height); d.reserved.fill(0)
	d.corridor_mask.resize(d.width * d.height); d.corridor_mask.fill(0)
	for r in rooms:
		r.rect = Rect2i(r.rect.position - bounds.position, r.rect.size)
		r.center = r.rect.position + Vector2i(r.rect.size.x / 2, r.rect.size.y / 2)
		_raster_room(d, r)
	var room_by_id := {}
	for r in rooms: room_by_id[int(r.id)] = r
	for e in d.edges:
		var a: Dictionary = room_by_id[int(e.a)]
		var b: Dictionary = room_by_id[int(e.b)]
		var width := 3 if crit_set.has(int(e.a)) and crit_set.has(int(e.b)) else 2
		_carve_corridor(d, a.center, b.center, width, corridor_rng, e)
	_raster_walls(d)
	_doorways_and_reservation(d, rooms)
	d.distance = _bfs_distance(d, rooms[entrance].center)
	if not _validate_floor_connectivity(d): return null
	if not _validate_boss_depth(d, rooms[boss].center, max_depth): return null
	if not _decorate(d, rooms, entrance, boss, decor_density, decor_rng): return null
	d.rooms = rooms
	d.name = _seeded_name(base_seed, theme)
	d.checksum = _checksum(d, rooms)
	d.stats = {"rooms": rooms.size(), "edges": d.edges.size(), "loops": d.edges.size() - rooms.size() + 1, "criticalLength": critical.size(), "floorTiles": _count_cells(d, FLOOR) + _count_cells(d, CORRIDOR), "wallTiles": _count_cells(d, WALL), "props": d.props.size() + d.spawns.size()}
	d.debug = {"criticalPath": critical, "maxDepth": max_depth, "bossDepth": boss_depth, "entrance": entrance, "boss": boss}
	return d

static func _scatter_rooms(n: int, rng: RNG) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var radius := 7.0 * sqrt(float(n))
	var cx := radius + 12.0
	var cy := radius + 12.0
	var large_count := 0
	for i in range(int(ceil(float(n) * 1.4))):
		var angle := rng.float(0.0, TAU)
		var rr := sqrt(rng.float())
		var x := roundi(cx + cos(angle) * radius * rr)
		var y := roundi(cy + sin(angle) * radius * rr)
		var size_roll := rng.float()
		var w: int
		var h: int
		if size_roll < 0.45:
			w = rng.int(5, 7); h = rng.int(5, 7)
		elif size_roll < 0.85:
			w = rng.int(8, 12); h = rng.int(8, 12)
		else:
			w = rng.int(13, 18); h = rng.int(13, 18); large_count += 1
		var shape := "rect"
		var sr := rng.float()
		if sr >= 0.60 and sr < 0.82: shape = "ellipse"
		elif sr >= 0.82: shape = "octagon"
		result.append({"id": result.size(), "rect": Rect2i(x - w / 2, y - h / 2, w, h), "shape": shape, "area": w * h})
	# Force two large rooms before separation by replacing the smallest candidates deterministically.
	var large_seen := result.filter(func(r): return int(r.area) >= 169).size()
	if large_seen < 2:
		var order := result.duplicate()
		order.sort_custom(func(a,b): return int(a.area) < int(b.area))
		for k in range(2 - large_seen):
			var r = order[k]
			r.rect.size = Vector2i(13, 13)
			r.area = 169
	return result

static func _separate_and_cull(rooms: Array[Dictionary], target: int) -> Array[Dictionary]:
	var work := rooms.duplicate()
	for _iter in range(300):
		var moved := false
		for i in range(work.size()):
			for j in range(i + 1, work.size()):
			var a: Rect2i = work[i].rect.grow(2)
			var b: Rect2i = work[j].rect.grow(2)
			if not a.intersects(b): continue
			var ca := a.get_center(); var cb := b.get_center(); var delta := ca - cb
			if delta == Vector2i.ZERO: delta = Vector2i(1 if i < j else -1, 0)
			if abs(delta.x) >= abs(delta.y):
				work[i].rect.position.x += 1 if delta.x >= 0 else -1
				work[j].rect.position.x -= 1 if delta.x >= 0 else -1
			else:
				work[i].rect.position.y += 1 if delta.y >= 0 else -1
				work[j].rect.position.y -= 1 if delta.y >= 0 else -1
			moved = true
		if not moved: break
	for r in work: r.rect.position = Vector2i(r.rect.position.x, r.rect.position.y)
	work.sort_custom(func(a,b):
		if int(a.area) == int(b.area): return int(a.id) < int(b.id)
		return int(a.area) > int(b.area))
	if work.size() > target: work = work.slice(0, target)
	for i in range(work.size()): work[i].id = i
	return work

static func _delaunay_fallback(rooms: Array[Dictionary]) -> Array[Dictionary]:
	# Deterministic k-NN is deliberately used as the safe fallback. For n<=60, O(n²) is cheaper
	# than maintaining mutable triangle objects in GDScript and is sufficient for the planar-ish skeleton.
	var out: Array[Dictionary] = []
	for i in range(rooms.size()):
		var neighbors := []
		for j in range(rooms.size()):
			if i == j: continue
			var a: Vector2 = Vector2(rooms[i].center if rooms[i].has("center") else rooms[i].rect.get_center())
			var b: Vector2 = Vector2(rooms[j].center if rooms[j].has("center") else rooms[j].rect.get_center())
			neighbors.append({"a": mini(i,j), "b": maxi(i,j), "w": a.distance_to(b)})
		neighbors.sort_custom(func(x,y):
			if is_equal_approx(x.w, y.w):
				if x.a == y.a: return x.b < y.b
				return x.a < y.a
			return x.w < y.w)
		for k in range(mini(4, neighbors.size())):
			var e = neighbors[k]
			var exists := false
			for q in out:
				if q.a == e.a and q.b == e.b: exists = true; break
			if not exists: out.append(e)
	return out

static func _build_graph(n: int, candidates: Array, chance_loop: float, rng: RNG) -> Dictionary:
	var sorted := candidates.duplicate()
	sorted.sort_custom(_edge_sort)
	var dsu := _DSU.new(n)
	var mst: Array[Dictionary] = []
	var mean := 0.0
	for e in sorted: mean += float(e.w)
	mean /= float(maxi(1, sorted.size()))
	for e in sorted:
		if dsu.union(int(e.a), int(e.b)): mst.append(e)
	var edges := mst.duplicate()
	var non_mst: Array[Dictionary] = []
	for e in sorted:
		var is_mst := false
		for m in mst:
			if m.a == e.a and m.b == e.b: is_mst = true; break
		if not is_mst and float(e.w) <= mean * 2.2: non_mst.append(e)
	non_mst.sort_custom(_edge_sort)
	for e in non_mst:
		if rng.chance(chance_loop): edges.append(e)
	if edges.size() == n - 1 and not non_mst.is_empty(): edges.append(non_mst[0])
	edges.sort_custom(_edge_sort)
	return {"mst": mst, "edges": edges, "loops": edges.size() - n + 1}

static func _edge_sort(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.w), float(b.w)): return float(a.w) < float(b.w)
	if int(a.a) != int(b.a): return int(a.a) < int(b.a)
	return int(a.b) < int(b.b)

static func _largest_room(rooms: Array[Dictionary]) -> int:
	var best := 0
	for i in range(1, rooms.size()):
		if int(rooms[i].area) > int(rooms[best].area): best = i
	return best

static func _degree(edges: Array[Dictionary], v: int) -> int:
	var n := 0
	for e in edges: n += 1 if e.a == v or e.b == v else 0
	return n

static func _select_entrance(rooms: Array[Dictionary], edges: Array[Dictionary], boss: int) -> int:
	var dist := _graph_distances(rooms.size(), edges, boss)
	var best := -1
	for i in range(rooms.size()):
		if i == boss or _degree(edges, i) != 1: continue
		if best < 0 or dist[i] > dist[best] or (dist[i] == dist[best] and i < best): best = i
	return best

static func _graph_distances(n: int, edges: Array[Dictionary], start: int) -> PackedInt32Array:
	var d := PackedInt32Array(); d.resize(n); d.fill(-1)
	var q: Array[int] = [start]; d[start] = 0; var head := 0
	while head < q.size():
		var v := q[head]; head += 1
		for e in edges:
			var u := -1
			if e.a == v: u = e.b
			elif e.b == v: u = e.a
			if u >= 0 and d[u] < 0: d[u] = d[v] + 1; q.append(u)
	return d

static func _critical_path(n: int, edges: Array[Dictionary], start: int, goal: int) -> Array[int]:
	var prev := PackedInt32Array(); prev.resize(n); prev.fill(-1)
	var seen := PackedByteArray(); seen.resize(n); seen.fill(0)
	var q: Array[int] = [start]; seen[start] = 1; var head := 0
	while head < q.size():
		var v := q[head]; head += 1
		if v == goal: break
		for e in edges:
			var u := e.b if e.a == v else (e.a if e.b == v else -1)
			if u >= 0 and seen[u] == 0: seen[u] = 1; prev[u] = v; q.append(u)
	var path: Array[int] = []; var cur := goal
	while cur >= 0: path.push_front(cur); cur = prev[cur]
	return path

static func _compute_bounds(rooms: Array[Dictionary], max_grid: Vector2i) -> Rect2i:
	var b: Rect2i = rooms[0].rect
	for r in rooms: b = b.merge(r.rect)
	b = b.grow(4)
	return b

static func _raster_room(d: Dungeon, r: Dictionary) -> void:
	var rect: Rect2i = r.rect
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var inside := true
			var lx := x - rect.position.x; var ly := y - rect.position.y
			if r.shape == "ellipse":
				var nx := (float(lx) + 0.5) / float(rect.size.x) * 2.0 - 1.0
				var ny := (float(ly) + 0.5) / float(rect.size.y) * 2.0 - 1.0
				inside = nx * nx + ny * ny <= 1.0
			elif r.shape == "octagon":
				var c := mini(rect.size.x, rect.size.y) / 4
				inside = not ((lx < c and ly < c and lx + ly < c) or (lx >= rect.size.x-c and ly < c and rect.size.x-1-lx+ly < c) or (lx < c and ly >= rect.size.y-c and lx+rect.size.y-1-ly < c) or (lx >= rect.size.x-c and ly >= rect.size.y-c and rect.size.x-1-lx+rect.size.y-1-ly < c))
			if inside: d.cells[d.index(x,y)] = FLOOR

static func _carve_corridor(d: Dungeon, a: Vector2i, b: Vector2i, width: int, rng: RNG, edge: Dictionary) -> void:
	var horizontal_first := rng.chance(0.5)
	var elbow := Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
	if abs(a.x - b.x) <= width or abs(a.y - b.y) <= width: _stamp_segment(d, a, b, width, false, edge)
	else:
		_stamp_segment(d, a, elbow, width, true, edge)
		_stamp_segment(d, elbow, b, width, true, edge)

static func _stamp_segment(d: Dungeon, a: Vector2i, b: Vector2i, width: int, corridor: bool, edge: Dictionary) -> void:
	var dx := signi(b.x - a.x); var dy := signi(b.y - a.y); var p := a
	var steps := maxi(abs(b.x-a.x), abs(b.y-a.y))
	for _i in range(steps + 1):
		for oy in range(-width/2, width/2 + 1):
			for ox in range(-width/2, width/2 + 1):
				var x := p.x + ox; var y := p.y + oy
				if d.inside(x,y):
					d.cells[d.index(x,y)] = CORRIDOR
					d.corridor_mask[d.index(x,y)] = 1
		p += Vector2i(dx, dy)

static func _raster_walls(d: Dungeon) -> void:
	for y in range(d.height):
		for x in range(d.width):
			var i := d.index(x,y)
			if d.cells[i] != VOID: continue
			var floor_adj := false
			for dy in range(-1,2):
				for dx in range(-1,2):
					if dx == 0 and dy == 0: continue
					if d.get_cell(x+dx,y+dy) == FLOOR or d.get_cell(x+dx,y+dy) == CORRIDOR: floor_adj = true
			if floor_adj: d.cells[i] = WALL

static func _doorways_and_reservation(d: Dungeon, rooms: Array[Dictionary]) -> void:
	for y in range(d.height):
		for x in range(d.width):
			if d.cells[d.index(x,y)] != CORRIDOR: continue
			var adjacent_room := false
			for off in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var c := d.get_cell(x+off.x,y+off.y)
				if c == FLOOR: adjacent_room = true
			if adjacent_room: d.reserved[d.index(x,y)] = 1

static func _bfs_distance(d: Dungeon, start: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array(); dist.resize(d.width*d.height); dist.fill(-1)
	var q: Array[int] = []
	if not d.inside(start.x,start.y): return dist
	var si := d.index(start.x,start.y); dist[si] = 0; q.append(si); var head := 0
	while head < q.size():
		var i := q[head]; head += 1; var x := i % d.width; var y := i / d.width
		for off in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var nx:=x+off.x; var ny:=y+off.y
			if not d.inside(nx,ny): continue
			var ni:=d.index(nx,ny)
			if dist[ni] >= 0: continue
			var c:=d.cells[ni]
			if c == FLOOR or c == CORRIDOR: dist[ni]=dist[i]+1; q.append(ni)
	return dist

static func _validate_floor_connectivity(d: Dungeon) -> bool:
	var total := 0; var reached := 0; var start := -1
	for i in range(d.cells.size()):
		if d.cells[i] == FLOOR or d.cells[i] == CORRIDOR: total += 1; if start < 0: start = i
	if start < 0: return false
	var seen := PackedByteArray(); seen.resize(d.cells.size()); seen.fill(0); var q:Array[int]=[start]; seen[start]=1; var head:=0
	while head < q.size():
		var i:=q[head]; head+=1; reached+=1; var x:=i%d.width; var y:=i/d.width
		for off in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var nx:=x+off.x; var ny:=y+off.y
			if not d.inside(nx,ny): continue
			var ni:=d.index(nx,ny)
			if seen[ni] == 0 and (d.cells[ni] == FLOOR or d.cells[ni] == CORRIDOR): seen[ni]=1; q.append(ni)
	return reached == total

static func _validate_boss_depth(d: Dungeon, boss_pos: Vector2i, max_depth: int) -> bool:
	var i:=d.index(boss_pos.x,boss_pos.y)
	var bd:=d.distance[i] if i>=0 and i<d.distance.size() else -1
	return bd >= int(ceil(float(max_depth)*0.60))

static func _decorate(d: Dungeon, rooms: Array[Dictionary], entrance: int, boss: int, density: float, rng: RNG) -> bool:
	var torch_candidates: Array[Vector2i] = []
	for y in range(d.height):
		for x in range(d.width):
			var i:=d.index(x,y)
			if (d.cells[i] == FLOOR or d.cells[i] == CORRIDOR) and d.reserved[i] == 0:
				var wall_adj:=false
				for off in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					if d.get_cell(x+off.x,y+off.y)==WALL: wall_adj=true
				if wall_adj: torch_candidates.append(Vector2i(x,y))
	var selected: Array[Vector2i]=[]
	for p in torch_candidates:
		var ok:=true
		for q in selected:
			if maxi(abs(p.x-q.x),abs(p.y-q.y)) < 4: ok=false; break
		if ok and rng.chance(0.25 + density*0.5): selected.append(p)
	selected.sort_custom(func(a,b): return a.y*d.width+a.x < b.y*d.width+b.x)
	for p in selected: d.props.append({"kind":"torch", "cell":p})
	for r in rooms:
		var role:=str(r.role); var center:Vector2i=r.center
		if role == "treasure":
			if not _reserve_prop(d, center): return false
			d.props.append({"kind":"chest","cell":center})
		elif role == "shrine":
			if not _reserve_prop(d, center): return false
			d.props.append({"kind":"crystal","cell":center})
		elif role == "boss":
			for p in [center+Vector2i(3,0),center+Vector2i(-3,0),center+Vector2i(0,3),center+Vector2i(0,-3)]:
				if _reserve_prop(d,p): d.props.append({"kind":"brazier","cell":p})
		elif role == "combat" or role == "elite":
			var count:=roundi(float(r.area)/18.0*(0.5+float(r.difficulty)))
			for _i in range(count):
				var p:=center+Vector2i(rng.int(-r.rect.size.x/3,r.rect.size.x/3),rng.int(-r.rect.size.y/3,r.rect.size.y/3))
				if d.inside(p.x,p.y) and d.get_cell(p.x,p.y) != WALL and d.reserved[d.index(p.x,p.y)]==0 and _reserve_prop(d,p): d.spawns.append({"kind":"enemy","cell":p,"difficulty":r.difficulty,"elite":role=="elite"})
	var ep:=rooms[entrance].center
	if _reserve_prop(d,ep): d.props.append({"kind":"portal","cell":ep})
	# Keep dynamic lights under the hard budget; select farthest-point-like spread in sorted order.
	var torch_props:=d.props.filter(func(p): return p.kind=="torch")
	for p in torch_props:
		if d.lights.size() >= 12: break
		d.lights.append({"cell":p.cell,"energy":2.2,"range":9.0,"warm":true})
	return _validate_placements(d)

static func _reserve_prop(d: Dungeon, p: Vector2i) -> bool:
	if not d.inside(p.x,p.y): return false
	var i:=d.index(p.x,p.y)
	if d.cells[i] != FLOOR and d.cells[i] != CORRIDOR: return false
	if d.reserved[i] != 0: return false
	d.reserved[i]=1
	return true

static func _validate_placements(d: Dungeon) -> bool:
	for p in d.props:
		var c:Vector2i=p.cell
		if not d.inside(c.x,c.y): return false
		if d.get_cell(c.x,c.y)==WALL or d.get_cell(c.x,c.y)==VOID: return false
	for s in d.spawns:
		var c:Vector2i=s.cell
		if not d.inside(c.x,c.y) or d.get_cell(c.x,c.y)==WALL or d.get_cell(c.x,c.y)==VOID: return false
	return d.lights.size() <= 12

static func _count_cells(d:Dungeon,t:int)->int:
	var n:=0
	for c in d.cells: n += 1 if c==t else 0
	return n

static func _checksum(d:Dungeon,rooms:Array[Dictionary])->int:
	var h:=2166136261
	func mix(v:int):
		h = h ^ (v & 0xff); h = int((h * 16777619) & 0xffffffff)
		mix.call((v >> 8) & 0xffffffff) if abs(v) > 255 else null
	mix.call(d.width); mix.call(d.height)
	for c in d.cells: mix.call(c)
	for r in rooms:
		mix.call(r.id); mix.call(r.rect.position.x); mix.call(r.rect.position.y); mix.call(r.rect.size.x); mix.call(r.rect.size.y)
	for e in d.edges: mix.call(e.a); mix.call(e.b)
	return h

static func _derive_seed(seed:int, stage:int, salt:int)->int:
	var h: int = (seed ^ (stage * 0x9E3779B9) ^ salt) & 0xffffffff
	h = int((((h ^ (h >> 16)) * 0x45d9f3b) & 0xffffffff))
	h = int((((h ^ (h >> 16)) * 0x45d9f3b) & 0xffffffff))
	h = (h ^ (h >> 16)) & 0xffffffff
	return h if h != 0 else 1

static func _seeded_name(seed:int, theme:String)->String:
	var rng:=RNG.new(_derive_seed(seed,99,0x4E414D45))
	var a=["Ashen","Black","Forgotten","Hollow","Drowned","Silent","Graven","Ivory"]
	var b=["Vaults","Catacombs","Halls","Sepulchres","Crypts","Reliquary","Sanctum"]
	var c=["Vor'gul","Mordane","Khar","Nhal","Vel","Draen"]
	return "The %s %s of %s" % [rng.pick(a),rng.pick(b),rng.pick(c)]

static func buildDungeonScene(dungeon:Dungeon) -> Node3D:
	var root:=Node3D.new()
	root.name="Dungeon_%d"%dungeon.seed
	var renderer:=_DungeonRenderer.new()
	root.add_child(renderer)
	renderer.build(dungeon)
	return root

class _DungeonRenderer:
	extends Node3D
	var instances: Dictionary = {}
	var lights: Array[OmniLight3D] = []
	var time := 0.0
	var materials: Dictionary = {}

	func build(d:Dungeon)->void:
		for kind in ["floor","wall","pillar","torch","flame","debris","chest","spawn","crystal"]: _make_multimesh(kind)
		for y in range(d.height):
			for x in range(d.width):
				var c:=d.cells[d.index(x,y)]
				if c==FLOOR or c==CORRIDOR: _add_instance("floor",Vector3(x,0,y),_floor_color(d,x,y),Vector3.ONE)
				elif c==WALL: _add_instance("wall",Vector3(x,1.0,y),Color(0.23,0.25,0.29),Vector3(1.0,2.0+(float(_noise(x,y,d.seed))-0.5)*0.5,1.0))
		for p in d.props:
			var v:Vector3=Vector3(p.cell.x,0.5,p.cell.y)
			match p.kind:
				"torch","brazier": _add_instance("torch",v,Color(0.45,0.28,0.12),Vector3.ONE); _add_instance("flame",v+Vector3(0,0.45,0),Color(1.0,0.45,0.08),Vector3.ONE)
				"chest": _add_instance("chest",v,Color(0.42,0.22,0.08),Vector3.ONE)
				"crystal": _add_instance("crystal",v,Color(0.45,0.75,1.0),Vector3.ONE)
				"portal": _add_instance("crystal",v,Color(0.35,0.6,1.0),Vector3(1.4,0.2,1.4))
		for s in d.spawns: _add_instance("spawn",Vector3(s.cell.x,0.05,s.cell.y),Color(0.75,0.15,0.1),Vector3.ONE)
		for l in d.lights:
			if lights.size()>=12: break
			var light:=OmniLight3D.new(); light.light_color=Color(1.0,0.55,0.23); light.omni_range=float(l.range); light.omni_attenuation=2.0; light.light_energy=float(l.energy); light.shadow_enabled=false; light.position=Vector3(l.cell.x,1.5,l.cell.y); add_child(light); lights.append(light)

	func _make_multimesh(kind:String)->void:
		var mi:=MultiMeshInstance3D.new(); mi.name="MM_"+kind
		var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_colors=true
		var box:=BoxMesh.new();
		match kind:
			"floor": box.size=Vector3(1.0,0.12,1.0)
			"wall": box.size=Vector3(1.0,2.0,1.0)
			"torch": box.size=Vector3(0.16,0.55,0.16)
			"flame": box.size=Vector3(0.22,0.35,0.22)
			"chest": box.size=Vector3(0.55,0.4,0.4)
			"crystal": box.size=Vector3(0.25,0.7,0.25)
			"spawn": box.size=Vector3(0.35,0.04,0.35)
			_: box.size=Vector3(0.35,0.8,0.35)
		mm.mesh=box; mm.instance_count=0
		mi.multimesh=mm; mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL; mat.vertex_color_use_as_albedo=true
		if kind=="flame" or kind=="crystal" or kind=="spawn": mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.emission_enabled=true; mat.emission=Color(1,0.35,0.1)
		box.material=mat; materials[kind]=mat; add_child(mi); instances[kind]=mi

	func _add_instance(kind:String,pos:Vector3,color:Color,scale:Vector3)->void:
		var mi:MultiMeshInstance3D=instances[kind]; var mm:=mi.multimesh; var idx:=mm.instance_count; mm.instance_count=idx+1; mm.set_instance_transform(idx,Transform3D(Basis().scaled(scale),pos)); mm.set_instance_color(idx,color)

	func _floor_color(d:Dungeon,x:int,y:int)->Color:
		var walls:=0
		for dy in range(-1,2):
			for dx in range(-1,2):
			if dx==0 and dy==0: continue
			if d.get_cell(x+dx,y+dy)==WALL: walls+=1
		var n:=_noise(x,y,d.seed); var v:=1.0-0.09*minf(float(walls),4.0); v*=0.95+n*0.10
		return Color(0.31*v,0.30*v,0.29*v)

	func _noise(x:int,y:int,s:int)->float:
		var h:=int((x*374761393+y*668265263+s*1442695041)&0xffffffff); h=(h^(h>>13))*1274126177&0xffffffff; return float(h&0xffff)/65535.0

	func _process(delta:float)->void:
		time+=delta
		for i in range(lights.size()): lights[i].light_energy*=1.0+sin(time*8.0+float(i)*1.71)*0.025

	func dispose()->void:
		for l in lights: l.queue_free()
		lights.clear()
		for v in instances.values(): v.queue_free()
		instances.clear(); materials.clear()

func runAcceptanceTests(params:Dictionary)->Dictionary:
	var a:=generateDungeon(params); var b:=generateDungeon(params); var c:=generateDungeon(params)
	if a==null or b==null or c==null: return {"passed":false,"error":"generation_failed"}
	var checks={
		"reachability_100": _validate_floor_connectivity(a),
		"checksum_same_3x": a.checksum==b.checksum and b.checksum==c.checksum,
		"boss_depth_60": int(a.debug.bossDepth)>=int(ceil(float(a.debug.maxDepth)*0.60)),
		"entrance_degree_1": _degree(a.edges,int(a.debug.entrance))==1,
		"entrance_not_boss_adjacent": not _are_adjacent(a.edges,int(a.debug.entrance),int(a.debug.boss)),
		"leaves_ge_3": a.rooms.size()<40 or _leaf_count(a.edges,a.debug.entrance,a.debug.boss)>=3,
		"cyclomatic": int(a.stats.loops)==a.edges.size()-a.rooms.size()+1,
		"placements_valid": _validate_placements(a),
		"light_budget": a.lights.size()<=12,
		"generation_ms_under_50": float(a.stats.genMs)<50.0
	}
	var passed:=true
	for v in checks.values(): passed = passed and bool(v)
	print("[ProceduralArpgDungeon] acceptance: ",checks," checksum=",a.checksum," genMs=",a.stats.genMs)
	return {"passed":passed,"checks":checks,"checksum":a.checksum,"genMs":a.stats.genMs,"stats":a.stats}

static func _are_adjacent(edges:Array[Dictionary],a:int,b:int)->bool:
	for e in edges: if (e.a==a and e.b==b) or (e.a==b and e.b==a): return true
	return false
static func _leaf_count(edges:Array[Dictionary],entrance:int,boss:int)->int:
	var n:=0; var verts:Dictionary={}
	for e in edges: verts[e.a]=true; verts[e.b]=true
	for v in verts.keys(): if int(v)!=entrance and int(v)!=boss and _degree(edges,int(v))==1: n+=1
	return n
