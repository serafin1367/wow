extends PanelContainer
## WOW 0.14 — panel konfiguracji buforow i zlecen (dane bez referencji Node).

signal close_requested
signal refresh_requested
signal stock_limits_requested(depot_id: String, resource_type: String, minimum: int, maximum: int)
signal priority_requested(job_id: String, value: int)
signal cancel_requested(job_id: String)

const RESOURCE_TYPES: Array[String] = ["iron_ore", "metal", "wood", "stone", "gold"]
const RESOURCE_LABELS: Array[String] = ["Ruda", "Metal", "Drewno", "Kamien", "Zloto"]
const UI_FG: Color = Color(0.88, 0.96, 0.96)
const ACCENT: Color = Color(0.24, 0.89, 0.89)

var depot_picker: OptionButton
var resource_picker: OptionButton
var minimum_editor: SpinBox
var maximum_editor: SpinBox
var current_label: Label
var job_container: VBoxContainer
var depot_records: Array[Dictionary] = []
var selected_depot_id: String = ""
var updating: bool = false


func _ready() -> void:
	name = "LogisticsConsole"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(510, 480)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -540
	offset_right = -18
	offset_top = 65
	offset_bottom = 595
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.11, 0.15, 0.98)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 13)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var label := _label("CENTRUM LOGISTYKI", 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var refresh := Button.new()
	refresh.text = "ODSWIEZ"
	refresh.pressed.connect(func(): refresh_requested.emit())
	heading.add_child(refresh)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(func(): close_requested.emit())
	heading.add_child(close)

	layout.add_child(_label("MAGAZYN POSREDNI / ZAPASY", 12))
	depot_picker = OptionButton.new()
	depot_picker.item_selected.connect(func(_id: int): _select_depot())
	layout.add_child(depot_picker)
	resource_picker = OptionButton.new()
	for i in range(RESOURCE_TYPES.size()):
		resource_picker.add_item(RESOURCE_LABELS[i], i)
	resource_picker.item_selected.connect(func(_id: int): _show_limits())
	layout.add_child(resource_picker)
	current_label = _label("Brak magazynow", 12)
	layout.add_child(current_label)
	var limits := HBoxContainer.new()
	limits.add_child(_label("MIN:", 12))
	minimum_editor = _spin(0, 120)
	limits.add_child(minimum_editor)
	limits.add_child(_label("MAX:", 12))
	maximum_editor = _spin(0, 120)
	limits.add_child(maximum_editor)
	var apply := Button.new()
	apply.text = "ZASTOSUJ"
	apply.pressed.connect(_apply_limits)
	limits.add_child(apply)
	layout.add_child(limits)

	layout.add_child(HSeparator.new())
	layout.add_child(_label("ZLECENIA / PRIORYTET 0–200", 12))
	var list := ScrollContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(list)
	job_container = VBoxContainer.new()
	job_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_container.add_theme_constant_override("separation", 6)
	list.add_child(job_container)
	layout.add_child(_label("Anulowanie dostepne tylko przed odbiorem ladunku.", 11))


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UI_FG)
	label.add_theme_font_size_override("font_size", size)
	return label


func _spin(lower: int, upper: int) -> SpinBox:
	var value := SpinBox.new()
	value.min_value = lower
	value.max_value = upper
	value.step = 1
	value.custom_minimum_size.x = 73
	return value


func show_state(depots: Array[Dictionary], jobs: Array[Dictionary]) -> void:
	depot_records = depots.duplicate(true)
	updating = true
	depot_picker.clear()
	var selection: int = 0
	for i in range(depot_records.size()):
		var row: Dictionary = depot_records[i]
		depot_picker.add_item(str(row.get("label", "DEPOT %d" % (i + 1))), i)
		if str(row.get("save_id", "")) == selected_depot_id:
			selection = i
	if not depot_records.is_empty():
		depot_picker.select(selection)
		selected_depot_id = str(depot_records[selection].get("save_id", ""))
	else:
		selected_depot_id = ""
	updating = false
	_show_limits()
	for old in job_container.get_children():
		job_container.remove_child(old)
		old.queue_free()
	if jobs.is_empty():
		job_container.add_child(_label("Brak zlecen. Zbuduj kopalnie, hute i depot.", 12))
		return
	for job in jobs:
		var id: String = str(job.get("id", ""))
		var row := HBoxContainer.new()
		job_container.add_child(row)
		var details := _label("%s | %s x%d | %s" % [
			id, str(job.get("resource_type", "")), int(job.get("amount", 0)),
			str(job.get("status", ""))], 11)
		details.custom_minimum_size.x = 265
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.tooltip_text = "%s → %s" % [
			str(job.get("source_id", "")), str(job.get("destination_id", ""))]
		row.add_child(details)
		var priority := _spin(0, 200)
		priority.value = int(job.get("priority", 50))
		row.add_child(priority)
		var set_button := Button.new()
		set_button.text = "OK"
		set_button.pressed.connect(_request_priority.bind(id, priority))
		row.add_child(set_button)
		var cancel := Button.new()
		cancel.text = "ANULUJ"
		cancel.disabled = str(job.get("status", "")) == "picked"
		cancel.pressed.connect(_request_cancel.bind(id))
		row.add_child(cancel)


func _request_priority(id: String, editor: SpinBox) -> void:
	priority_requested.emit(id, int(editor.value))


func _request_cancel(id: String) -> void:
	cancel_requested.emit(id)


func _select_depot() -> void:
	if updating:
		return
	var index: int = depot_picker.selected
	if index >= 0 and index < depot_records.size():
		selected_depot_id = str(depot_records[index]["save_id"])
	_show_limits()


func _show_limits() -> void:
	if updating:
		return
	if depot_records.is_empty():
		current_label.text = "Nie ma jeszcze magazynu posredniego"
		return
	var index: int = depot_picker.selected
	if index < 0 or index >= depot_records.size():
		return
	var row: Dictionary = depot_records[index]
	var material: String = RESOURCE_TYPES[resource_picker.selected]
	var qty: int = int(row.get("stock", {}).get(material, 0))
	current_label.text = "Zapas: %d / 120 | Port: %s" % [qty, str(row.get("save_id", ""))]
	minimum_editor.value = int(row.get("minimum_stock", {}).get(material, 0))
	maximum_editor.value = int(row.get("maximum_stock", {}).get(material, 120))


func _apply_limits() -> void:
	if selected_depot_id.is_empty():
		return
	var minimum: int = int(minimum_editor.value)
	var maximum: int = int(maximum_editor.value)
	if minimum > maximum:
		current_label.text = "BLAD: MIN nie moze byc wyzsze od MAX"
		return
	stock_limits_requested.emit(selected_depot_id,
		RESOURCE_TYPES[resource_picker.selected], minimum, maximum)
