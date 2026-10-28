extends RefCounted
## WOW 0.15: metrics in data, not derived from changing buffer quantities.
## Throughput tracks cumulative mine/smelter counters even when robots take cargo.

const SAMPLE_SECONDS: float = 2.0
const MAX_SAMPLES: int = 30
var elapsed: float = 0.0
var last_ore: int = 0
var last_metal: int = 0
var samples: Array[Dictionary] = []


func capture(mine, smelter, delta: float) -> void:
	elapsed += maxf(0.0, delta)
	if elapsed < SAMPLE_SECONDS:
		return
	var ore: int = mine.total_extracted if is_instance_valid(mine) else 0
	var metal: int = smelter.total_smelted if is_instance_valid(smelter) else 0
	var new_ore: int = maxi(0, ore - last_ore)
	var new_metal: int = maxi(0, metal - last_metal)
	last_ore = ore
	last_metal = metal
	samples.append({"seconds": elapsed, "ore": new_ore, "metal": new_metal})
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()
	elapsed = 0.0


func report(mine, smelter) -> Dictionary:
	var seconds: float = 0.0
	var ore: int = 0
	var metal: int = 0
	for item in samples:
		seconds += float(item["seconds"])
		ore += int(item["ore"])
		metal += int(item["metal"])
	var ore_rate: float = 60.0 * float(ore) / seconds if seconds > 0.0 else 0.0
	var metal_rate: float = 60.0 * float(metal) / seconds if seconds > 0.0 else 0.0
	var mine_status: String = "NIE ZBUDOWANO"
	var smelter_status: String = "NIE ZBUDOWANO"
	var mine_progress: float = 0.0
	var smelter_progress: float = 0.0
	if is_instance_valid(mine):
		mine_progress = 100.0 * clampf(mine.accumulated / mine.CYCLE_SECONDS, 0.0, 1.0)
		if mine.production_paused:
			mine_status = "WSTRZYMANA"
		elif mine.cycles_remaining == 0:
			mine_status = "ZLECENIE WYKONANE"
		elif not mine.power_enabled:
			mine_status = "BRAK ENERGII"
		elif mine.stock >= mine.MAX_BUFFER:
			mine_status = "PELNY BUF RUDY"
		elif not mine.has_ore():
			mine_status = "BRAK ZLOZA"
		else:
			mine_status = "PRACUJE"
	if is_instance_valid(smelter):
		smelter_progress = 100.0 * clampf(smelter.accumulated / smelter.CYCLE_SECONDS, 0.0, 1.0)
		if smelter.production_paused:
			smelter_status = "WSTRZYMANA"
		elif smelter.cycles_remaining == 0:
			smelter_status = "ZLECENIE WYKONANE"
		elif not smelter.power_enabled:
			smelter_status = "BRAK ENERGII"
		elif smelter.metal_stock >= smelter.MAX_METAL:
			smelter_status = "PELNY BUF METALU"
		elif smelter.ore_stock < smelter.ORE_PER_METAL:
			smelter_status = "BRAK RUDY"
		else:
			smelter_status = "PRACUJE"
	return {"ore_per_min": ore_rate, "metal_per_min": metal_rate,
		"ore_consumed_per_min": metal_rate * 2.0,
		"mine_status": mine_status, "smelter_status": smelter_status,
		"mine_progress": mine_progress, "smelter_progress": smelter_progress,
		"ore_created": last_ore, "metal_created": last_metal}


func to_dict() -> Dictionary:
	return {"save_id": "production:monitor", "type_id": "service:production",
		"object_version": 1, "elapsed": elapsed, "last_ore": last_ore,
		"last_metal": last_metal, "samples": samples.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	elapsed = clampf(float(data.get("elapsed", 0.0)), 0.0, SAMPLE_SECONDS)
	last_ore = maxi(0, int(data.get("last_ore", 0)))
	last_metal = maxi(0, int(data.get("last_metal", 0)))
	samples.clear()
	for entry in data.get("samples", []):
		if entry is Dictionary and samples.size() < MAX_SAMPLES:
			var seconds: float = float(entry.get("seconds", 0.0))
			if seconds > 0.0:
				samples.append({"seconds": minf(seconds, 4.0),
					"ore": maxi(0, int(entry.get("ore", 0))),
					"metal": maxi(0, int(entry.get("metal", 0)))})
