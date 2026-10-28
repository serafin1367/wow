extends PanelContainer
## WOW 0.15 — centrum produkcji: wejscia/wyjscia, kolejki, alarmy i flota.
signal close_requested
signal refresh_requested
signal pause_requested(kind: String)
signal queue_requested(kind: String, cycles: int)
signal priority_requested(kind: String, priority: int)
signal enqueue_requested(kind: String, cycles: int, priority: int)
signal focus_requested(kind: String)

const BG_COLOR: Color = Color(0.055, 0.11, 0.15, 0.98)
const FG_COLOR: Color = Color(0.90, 0.95, 0.97)
const HIGHLIGHT: Color = Color(0.23, 0.87, 0.90)
const ALARM_COLOR: Color = Color(1.0, 0.65, 0.25)

var summary_label: Label
var machines_container: VBoxContainer
var alerts_container: VBoxContainer


func _ready() -> void:
	name = "ProductionConsole"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = HIGHLIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	call_deferred("_fit_viewport")

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 14)
	margins.add_theme_constant_override("margin_right", 14)
	margins.add_theme_constant_override("margin_top", 12)
	margins.add_theme_constant_override("margin_bottom", 12)
	add_child(margins)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 7)
	margins.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _label("CENTRUM PRODUKCJI", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var refresh := Button.new()
	refresh.text = "ODSWIEZ"
	refresh.pressed.connect(func(): refresh_requested.emit())
	header.add_child(refresh)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)

	var scrolling := ScrollContainer.new()
	scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scrolling.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scrolling)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scrolling.add_child(content)
	summary_label = _label("", 12)
	content.add_child(summary_label)
	content.add_child(HSeparator.new())
	machines_container = VBoxContainer.new()
	machines_container.add_theme_constant_override("separation", 9)
	content.add_child(machines_container)
	content.add_child(HSeparator.new())
	content.add_child(_label("ALARMY I PRZESTOJE", 13, ALARM_COLOR))
	alerts_container = VBoxContainer.new()
	content.add_child(alerts_container)
	content.add_child(_label("Klawisz V: otworz/zamknij. -1 cykli = bez limitu.", 11))


func _fit_viewport() -> void:
	var bounds: Vector2 = get_viewport().get_visible_rect().size
	var width: float = minf(540.0, maxf(290.0, bounds.x - 30.0))
	offset_left = -width - 12.0
	offset_right = -12.0
	# Dokladne rozmiary paneli HUD moga przekraczac nominalne kotwice
	# po zmianie rozdzielczosci lub czcionek. Bierzemy ich rzeczywiste
	# krawedzie, zeby nie zaslaniac gornego i dolnego paska.
	var top_edge: float = 102.0
	var bottom_edge: float = bounds.y - 278.0
	var parent = get_parent()
	if parent != null:
		var status = parent.get_node_or_null("TopStatusBar") as Control
		var commands = parent.get_node_or_null("CommandBar") as Control
		if status != null:
			top_edge = maxf(top_edge, status.position.y + status.size.y + 8.0)
		if commands != null:
			bottom_edge = minf(bottom_edge, commands.position.y - 8.0)
	offset_top = top_edge
	offset_bottom = maxf(top_edge + 180.0, bottom_edge)


func _label(value: String, size: int, color: Color = FG_COLOR) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_color_override("font_color", color)
	item.add_theme_font_size_override("font_size", size)
	return item


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func show_snapshot(data: Dictionary) -> void:
	var stocks: Dictionary = data.get("resources", {})
	summary_label.text = "Ruda +%.1f/min | Metal +%.1f/min | Ruda -%.1f/min\nMagazyn: drewno %d | kamien %d | zloto %d | metal %d\nRoboty: %d zajetych, %d laduje, %d wolnych, zlecenia %d" % [
		float(data.get("ore_per_min", 0.0)), float(data.get("metal_per_min", 0.0)),
		float(data.get("ore_consumed_per_min", 0.0)),
		int(stocks.get("wood", 0)), int(stocks.get("stone", 0)),
		int(stocks.get("gold", 0)), int(stocks.get("metal", 0)),
		int(data.get("busy_robots", 0)), int(data.get("charging_robots", 0)),
		int(data.get("idle_robots", 0)), int(data.get("job_count", 0))]
	_clear_children(machines_container)
	for machine in data.get("machines", []):
		_add_machine(machine)
	_clear_children(alerts_container)
	var alarms: Array = data.get("alarms", [])
	if alarms.is_empty():
		alerts_container.add_child(_label("Brak problemow produkcyjnych.", 12))
	for alarm in alarms:
		var row := HBoxContainer.new()
		alerts_container.add_child(row)
		var text_label := _label(str(alarm.get("message", "")), 11, ALARM_COLOR)
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_label)
		var locate := Button.new()
		locate.text = "POKAZ"
		locate.pressed.connect(_send_focus.bind(str(alarm.get("kind", ""))))
		row.add_child(locate)


func _add_machine(machine: Dictionary) -> void:
	var kind: String = str(machine.get("kind", ""))
	var block := VBoxContainer.new()
	machines_container.add_child(block)
	var header := HBoxContainer.new()
	block.add_child(header)
	var name_label := _label(str(machine.get("name", "")) + " | " + str(machine.get("status", "")), 12, HIGHLIGHT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var focus := Button.new()
	focus.text = "POKAZ"
	focus.pressed.connect(_send_focus.bind(kind))
	header.add_child(focus)
	block.add_child(_label(str(machine.get("recipe", "")), 11))
	block.add_child(_label(str(machine.get("buffers", "")), 11))
	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = float(machine.get("progress", 0.0))
	progress.show_percentage = true
	progress.custom_minimum_size.y = 16
	block.add_child(progress)
	var controls := HBoxContainer.new()
	block.add_child(controls)
	var pause := Button.new()
	pause.text = "WZNOW" if bool(machine.get("paused", false)) else "PAUZA"
	pause.pressed.connect(_send_pause.bind(kind))
	controls.add_child(pause)
	var label := _label("Cykle:", 11)
	controls.add_child(label)
	var remaining := SpinBox.new()
	remaining.min_value = -1
	remaining.max_value = 1000
	remaining.step = 1
	remaining.value = int(machine.get("cycles_remaining", -1))
	remaining.custom_minimum_size.x = 84
	remaining.tooltip_text = "-1: bez limitu, 0: zakoncz, 1-1000: okresl liczbe cykli"
	controls.add_child(remaining)
	var apply := Button.new()
	apply.text = "USTAW"
	apply.pressed.connect(_send_queue.bind(kind, remaining))
	controls.add_child(apply)
	var add_batch := Button.new()
	add_batch.text = "DODAJ"
	add_batch.tooltip_text = "Dodaj kolejna partie do kolejki"
	add_batch.pressed.connect(_send_enqueue.bind(kind, remaining, machine))
	controls.add_child(add_batch)
	var queue: Array = machine.get("queue", [])
	if not queue.is_empty():
		var parts: Array[String] = []
		for item in queue:
			parts.append("%d cykli (P%d)" % [int(item.get("cycles", 0)), int(item.get("priority", 100))])
		block.add_child(_label("Kolejka: " + ", ".join(parts), 11))
	var priority_row := HBoxContainer.new()
	block.add_child(priority_row)
	priority_row.add_child(_label("Priorytet zasilania:", 11))
	var priority := SpinBox.new()
	priority.min_value = 0
	priority.max_value = 200
	priority.step = 1
	priority.value = int(machine.get("priority", 100))
	priority.custom_minimum_size.x = 84
	priority_row.add_child(priority)
	var priority_button := Button.new()
	priority_button.text = "USTAW"
	priority_button.pressed.connect(_send_priority.bind(kind, priority))
	priority_row.add_child(priority_button)


func _send_enqueue(kind: String, editor: SpinBox, machine: Dictionary) -> void:
	enqueue_requested.emit(kind, int(editor.value), int(machine.get("priority", 100)))


func _send_priority(kind: String, editor: SpinBox) -> void:
	priority_requested.emit(kind, int(editor.value))


func _send_pause(kind: String) -> void:
	pause_requested.emit(kind)


func _send_queue(kind: String, spinner: SpinBox) -> void:
	queue_requested.emit(kind, int(spinner.value))


func _send_focus(kind: String) -> void:
	focus_requested.emit(kind)
