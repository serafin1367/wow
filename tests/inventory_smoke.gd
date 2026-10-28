extends SceneTree
## WOW 0.14: bufor dla tasmy i robota, pelny odbiorca i save/load rezerwacji.
const INVENTORY = preload("res://scripts/inventory.gd")


func _initialize() -> void:
	call_deferred("_test")


func _fail(message: String) -> void:
	push_error("INVENTORY TEST: " + message)
	quit(1)


func _test() -> void:
	var mine = INVENTORY.new("mine:out")
	mine.configure("iron_ore", 20, 10)
	var smelter = INVENTORY.new("smelter:in")
	smelter.configure("iron_ore", 6, 2)
	var moved: int = mine.transfer_to(smelter, "iron_ore", 8, "belt:packet:1")
	if moved != 4 or mine.quantity("iron_ore") != 6 or smelter.quantity("iron_ore") != 6:
		_fail("Przekroczono pojemnosc huty lub zgubiono material")
		return
	if mine.transfer_to(smelter, "iron_ore", 6, "robot:job:2") != 0:
		_fail("Transport po napelnieniu bufora musi sie zatrzymac")
		return
	if not mine.reserve_output("robot:r2", "iron_ore", 4):
		_fail("Robot nie moze zarezerwowac rudy")
		return
	if mine.reserve_output("belt:r3", "iron_ore", 3):
		_fail("Robot i tasma zarezerwowaly ten sam ladunek")
		return
	mine.cancel_output("robot:r2")
	if not mine.reserve_output("belt:r3", "iron_ore", 3):
		_fail("Anulowanie zlecenia nie zwolnilo rezerwacji")
		return
	# Wlasnosc 3 jednostek przechodzi teraz na tasme.
	var cargo: int = mine.commit_output("belt:r3")
	if cargo != 3 or mine.quantity("iron_ore") != 3:
		_fail("Niepoprawne przeniesienie ladunku z kopalni na tasme")
		return

	# Huta moze zwolnic tylko 2 miejsca: paczka czeka na wolny bufor.
	smelter.stock["iron_ore"] = 4
	if smelter.reserve_input("robot:r4", "iron_ore", 3):
		_fail("Rezerwacja przekroczyla wolna pojemnosc")
		return
	if not smelter.reserve_input("belt:packet:waiting", "iron_ore", 2):
		_fail("Nie przydzielono miejsca na oczekujaca paczke")
		return
	if smelter.reserve_input("robot:r5", "iron_ore", 1):
		_fail("Robot nadpisal rezerwacje tasmy")
		return

	var original_total: int = mine.quantity("iron_ore") + smelter.quantity("iron_ore") + cargo
	var json: String = JSON.stringify({"mine": mine.to_dict(), "smelter": smelter.to_dict(), "cargo": cargo})
	var loaded: Dictionary = JSON.parse_string(json)
	var mine_loaded = INVENTORY.new()
	var smelter_loaded = INVENTORY.new()
	mine_loaded.from_dict(loaded["mine"])
	smelter_loaded.from_dict(loaded["smelter"])
	if mine_loaded.quantity("iron_ore") != 3 or smelter_loaded.available_input("iron_ore") != 0:
		_fail("Odczyt zgubil stan bufora lub rezerwacje")
		return
	if smelter_loaded.commit_input("belt:packet:waiting") != 2:
		_fail("Po wczytaniu ladunek tasmy nie moze zostac przyjety")
		return
	cargo -= 2
	if mine_loaded.quantity("iron_ore") + smelter_loaded.quantity("iron_ore") + cargo != original_total:
		_fail("Po odczycie skopiowano lub zgubiono material")
		return

	print("INVENTORY SMOKE OK: shared buffer, reservations, save/load and mass conservation")
	quit(0)
