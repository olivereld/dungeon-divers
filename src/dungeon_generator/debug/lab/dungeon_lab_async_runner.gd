class_name DungeonLabAsyncRunner
extends RefCounted

signal progress(completed: int, total: int)
signal batch_completed(results: Array)
signal batch_cancelled

var _is_running: bool = false
var _should_cancel: bool = false
var _thread: Thread = null

func is_running() -> bool:
	return _is_running

func cancel() -> void:
	if _is_running:
		_should_cancel = true
		_is_running = false
		batch_cancelled.emit()

func run_batch_sync(items: Array, work_fn: Callable) -> Array:
	_is_running = true
	_should_cancel = false
	var results: Array = []
	var total: int = items.size()

	for i in range(total):
		if _should_cancel:
			break
		var res = work_fn.call(items[i])
		results.append(res)
		progress.emit(i + 1, total)

	_is_running = false
	if not _should_cancel:
		batch_completed.emit(results)
	return results

func run_batch_threaded(items: Array, work_fn: Callable) -> void:
	if _is_running:
		cancel()
	_is_running = true
	_should_cancel = false
	_thread = Thread.new()
	_thread.start(_thread_worker.bind(items, work_fn))

func _thread_worker(items: Array, work_fn: Callable) -> void:
	var results: Array = []
	var total: int = items.size()

	for i in range(total):
		if _should_cancel:
			break
		var res = work_fn.call(items[i])
		results.append(res)
		progress.emit.call_deferred(i + 1, total)

	_is_running = false
	if not _should_cancel:
		batch_completed.emit.call_deferred(results)
