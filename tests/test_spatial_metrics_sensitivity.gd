extends SceneTree

const _DungeonDiagnosticsScript = preload("res://src/dungeon_generator/diagnostics/dungeon_diagnostics.gd")

func _init() -> void:
    print("--- Running test_spatial_metrics_sensitivity ---")
    test_overlap_count_sensitivity()
    test_pairwise_spacing_sensitivity()
    test_nearest_neighbor_sensitivity()
    test_bounding_box_sensitivity()
    print("[PASS] test_spatial_metrics_sensitivity completed successfully!")
    quit(0)

func _make_rooms() -> Array[RoomData]:
    return [
        RoomData.new(1, Rect2i(0, 0, 5, 5), &"explore"),
        RoomData.new(2, Rect2i(10, 10, 5, 5), &"explore"),
        RoomData.new(3, Rect2i(20, 20, 5, 5), &"explore"),
    ]

func test_overlap_count_sensitivity() -> void:
    print("  -> Testing overlap_count sensitivity...")
    var diag = _DungeonDiagnosticsScript.new()
    var config = _DungeonDiagnosticsScript.build_config(42)

    var snap = diag.compute_spatial_metrics_from_rooms(_make_rooms(), config)
    var no_overlap = snap.overlap_count

    var overlapping_rooms := [
        RoomData.new(1, Rect2i(0, 0, 10, 10), &"explore"),
        RoomData.new(2, Rect2i(5, 5, 10, 10), &"explore"),
        RoomData.new(3, Rect2i(20, 20, 5, 5), &"explore"),
    ]
    var snap2 = diag.compute_spatial_metrics_from_rooms(overlapping_rooms, config)

    assert(snap2.overlap_count > no_overlap, "Overlapping rooms should increase overlap_count: %d vs %d" % [no_overlap, snap2.overlap_count])
    print("    [OK] overlap_count: %d -> %d" % [no_overlap, snap2.overlap_count])

func test_pairwise_spacing_sensitivity() -> void:
    print("  -> Testing pairwise_spacing sensitivity...")
    var diag = _DungeonDiagnosticsScript.new()
    var config = _DungeonDiagnosticsScript.build_config(42)

    var tight_rooms := [
        RoomData.new(1, Rect2i(0, 0, 5, 5), &"explore"),
        RoomData.new(2, Rect2i(6, 0, 5, 5), &"explore"),
    ]
    var snap_tight = diag.compute_spatial_metrics_from_rooms(tight_rooms, config)

    var wide_rooms := [
        RoomData.new(1, Rect2i(0, 0, 5, 5), &"explore"),
        RoomData.new(2, Rect2i(100, 100, 5, 5), &"explore"),
    ]
    var snap_wide = diag.compute_spatial_metrics_from_rooms(wide_rooms, config)

    assert(snap_tight.pairwise_spacing_mean < snap_wide.pairwise_spacing_mean, "Tighter rooms should have lower pairwise_spacing_mean")
    assert(snap_tight.pairwise_spacing_min < snap_wide.pairwise_spacing_min, "Tighter rooms should have lower pairwise_spacing_min")
    print("    [OK] pairwise_spacing: tight mean=%.2f vs wide mean=%.2f" % [snap_tight.pairwise_spacing_mean, snap_wide.pairwise_spacing_mean])

func test_nearest_neighbor_sensitivity() -> void:
    print("  -> Testing nearest_neighbor sensitivity...")
    var diag = _DungeonDiagnosticsScript.new()
    var config = _DungeonDiagnosticsScript.build_config(42)

    var close_rooms := [
        RoomData.new(1, Rect2i(0, 0, 5, 5), &"explore"),
        RoomData.new(2, Rect2i(6, 0, 5, 5), &"explore"),
        RoomData.new(3, Rect2i(7, 0, 5, 5), &"explore"),
    ]
    var snap_close = diag.compute_spatial_metrics_from_rooms(close_rooms, config)

    var far_rooms := [
        RoomData.new(1, Rect2i(0, 0, 5, 5), &"explore"),
        RoomData.new(2, Rect2i(100, 0, 5, 5), &"explore"),
        RoomData.new(3, Rect2i(200, 0, 5, 5), &"explore"),
    ]
    var snap_far = diag.compute_spatial_metrics_from_rooms(far_rooms, config)

    assert(snap_close.nearest_neighbor_mean < snap_far.nearest_neighbor_mean, "Closer rooms should have lower nearest_neighbor_mean")
    assert(snap_close.nearest_neighbor_min < snap_far.nearest_neighbor_min, "Closer rooms should have lower nearest_neighbor_min")
    print("    [OK] nearest_neighbor: close mean=%.2f vs far mean=%.2f" % [snap_close.nearest_neighbor_mean, snap_far.nearest_neighbor_mean])

func test_bounding_box_sensitivity() -> void:
    print("  -> Testing bounding box sensitivity...")
    var diag = _DungeonDiagnosticsScript.new()
    var config = _DungeonDiagnosticsScript.build_config(42)

    var compact_rooms := [
        RoomData.new(1, Rect2i(0, 0, 5, 5), &"explore"),
        RoomData.new(2, Rect2i(5, 5, 5, 5), &"explore"),
    ]
    var snap_compact = diag.compute_spatial_metrics_from_rooms(compact_rooms, config)

    var spread_rooms := [
        RoomData.new(1, Rect2i(0, 0, 5, 5), &"explore"),
        RoomData.new(2, Rect2i(100, 100, 5, 5), &"explore"),
    ]
    var snap_spread = diag.compute_spatial_metrics_from_rooms(spread_rooms, config)

    assert(snap_compact.spatial_bbox_area < snap_spread.spatial_bbox_area, "Compact rooms should have smaller bbox area")
    print("    [OK] bbox_area: compact=%d vs spread=%d" % [snap_compact.spatial_bbox_area, snap_spread.spatial_bbox_area])
