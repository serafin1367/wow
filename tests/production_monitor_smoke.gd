extends SceneTree
## WOW 0.15: miernik produkcji korzysta z licznikow, nie z zawartosci buforow.
const MONITOR = preload("res://scripts/production_monitor.gd")
const MINE = preload("res://scripts/automated_mine.gd")
const SMELTER = preload("res://scripts/automated_smelter.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PRODUCTION TEST: " + message)
	quit(1)


func _run() -> void:
	var mine = MINE.new()
	var smelter = SMELTER.new()
	root.add_child(mine)
	root.add_child(smelter)
	mine.power_enabled = true
	smelter.power_enabled = true
	mine.stock = 30
	smelter.ore_stock = 15
	mine.total_extracted = 12
	smelter.total_smelted = 4
	mine.accumulated = 0.75
	smelter.accumulated = 1.5
	var monitor = MONITOR.new()
	monitor.capture(mine, smelter, 2.0)
	var rates: Dictionary = monitor.report(mine, smelter)
	if absf(float(rates["ore_per_min"]) - 360.0) > 0.001 or absf(float(rates["metal_per_min"]) - 120.0) > 0.001:
		_fail("Bledne tempo produkcji z licznikow absolutnych")
		return
	if absf(float(rates["mine_progress"]) - 50.0) > 0.1 or absf(float(rates["smelter_progress"]) - 50.0) > 0.1:
		_fail("Postep cyklu wydobycia lub przetopienia jest niepoprawny")
		return
	# Wyniesienie materialu przez robota nie moze cofac licznika produkcji.
	mine.stock = 0
	smelter.metal_stock = 0
	monitor.capture(mine, smelter, 2.0)
	var unchanged: Dictionary = monitor.report(mine, smelter)
	if float(unchanged["ore_per_min"]) <= 0.0 or float(unchanged["metal_per_min"]) <= 0.0:
		_fail("Transport resetuje statystyki produkcji")
		return
	mine.power_enabled = false
	smelter.power_enabled = false
	if monitor.report(mine, smelter)["mine_status"] != "BRAK ENERGII":
		_fail("Brak diagnozy zaniku zasilania kopalni")
		return
	mine.power_enabled = true
	mine.stock = mine.MAX_BUFFER
	smelter.power_enabled = true
	smelter.metal_stock = smelter.MAX_METAL
	if monitor.report(mine, smelter)["mine_status"] != "PELNY BUF RUDY":
		_fail("Brak ostrzezenia o zablokowanej kopalni")
		return
	if monitor.report(mine, smelter)["smelter_status"] != "PELNY BUF METALU":
		_fail("Brak ostrzezenia o pelnej hucie")
		return
	var restored = MONITOR.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(monitor.to_dict())))
	var last: Dictionary = restored.report(mine, smelter)
	if absf(float(last["ore_per_min"]) - float(unchanged["ore_per_min"])) > 0.001:
		_fail("Odczyt gry wyzerowal statystyki")
		return
	print("PRODUCTION MONITOR SMOKE OK: rates, progress, power failures, full buffers, saved telemetry")
	mine.queue_free()
	smelter.queue_free()
	await process_frame
	quit(0)
