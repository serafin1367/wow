extends CanvasLayer
## WOW 0.3: czytelny, responsywny HUD strategii ekonomicznej.
## Oddziela interfejs od skryptu glownej sceny.

signal build_center_requested
signal build_forester_requested
signal train_robot_requested
signal charge_requested

const BG = Color(0.065, 0.105, 0.145, 0.94)
const BG_SUBTLE = Color(0.105, 0.16, 0.20, 0.96)
const BORDER = Color(0.23, 0.34, 0.39, 1.0)
const TEXT = Color(0.91, 0.96, 0.96)
const MUTED = Color(0.62, 0.72, 0.76)
const TURQUOISE = Color(0.25, 0.88, 0.90)
const ORANGE = Color(1.0, 0.61, 0.22)

var root: Control
var resource_label: Label
var energy_label: Label
var title_label: Label
var detail_label: Label
var battery_bar: ProgressBar
var battery_caption: Label
var event_label: Label
var build_button: Button
var forester_button: Button
var train_button: Button
var charge_button: Button


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "HUDRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_make_top_bar()
	_make_bottom_bar()
	set_resources(0, 0, 0, 3, 30)
	set_power(0.0, false)
	set_no_selection()


func add_selection_overlay(overlay: Control) -> void:
	root.add_child(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# SelectionBox ma rysowac sie nad plansza i ponizej widzetow HUD.
	root.move_child(overlay, 0)


func _make_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopStatusBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = 12
	bar.offset_bottom = 92

	var margin := _margins(18, 11, 18, 11)
	bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var branding := VBoxContainer.new()
	branding.custom_minimum_size.x = 150
	row.add_child(branding)
	branding.add_child(_label("WOW  /  COLONY", 20, ORANGE, true))
	branding.add_child(_label("ROBOTIC FRONTIER  •  v0.3", 11, MUTED))
	row.add_child(VSeparator.new())

	resource_label = _label("", 18, TEXT, true)
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(resource_label)

	row.add_child(VSeparator.new())
	var power_block := VBoxContainer.new()
	power_block.custom_minimum_size.x = 207
	power_block.add_child(_label("ENERGIA KOLONII", 11, MUTED, true))
	energy_label = _label("", 16, TURQUOISE, true)
	power_block.add_child(energy_label)
	row.add_child(power_block)


func _make_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "CommandBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = -188
	bar.offset_bottom = -14

	var margin := _margins(16, 12, 16, 10)
	bar.add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 15)
	margin.add_child(layout)

	# Lewy panel: jednostka / budynek / poziom baterii.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 264
	left.add_theme_constant_override("separation", 5)
	layout.add_child(left)
	left.add_child(_label("WYBRANY OBIEKT", 11, TURQUOISE, true))
	title_label = _label("BRAK ZAZNACZENIA", 17, TEXT, true)
	left.add_child(title_label)
	detail_label = _label("", 13, MUTED)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.y = 38
	left.add_child(detail_label)
	battery_bar = ProgressBar.new()
	battery_bar.name = "BatteryProgress"
	battery_bar.show_percentage = false
	battery_bar.max_value = 100.0
	battery_bar.custom_minimum_size.y = 11
	battery_bar.add_theme_stylebox_override("background", _solid_style(Color(0.17, 0.24, 0.28), 5))
	battery_bar.add_theme_stylebox_override("fill", _solid_style(TURQUOISE, 5))
	left.add_child(battery_bar)
	battery_caption = _label("AKUMULATOR", 11, MUTED)
	left.add_child(battery_caption)
	layout.add_child(VSeparator.new())

	# Srodek: rozkazy i budowanie, stale na dole.
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	layout.add_child(center)
	center.add_child(_label("CENTRUM OPERACYJNE  /  BUDOWANIE", 11, TURQUOISE, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	center.add_child(actions)
	build_button = _action_button("B   CENTRUM", "40 drewna · 20 kamienia", ORANGE)
	build_button.pressed.connect(func(): build_center_requested.emit())
	actions.add_child(build_button)
	train_button = _action_button("T   GORNIK", "10 drewna · 20 zlota", TURQUOISE)
	train_button.pressed.connect(func(): train_robot_requested.emit())
	actions.add_child(train_button)
	forester_button = _action_button("L   REKULTYWACJA", "30 drewna · 10 kamienia", TURQUOISE)
	forester_button.pressed.connect(func(): build_forester_requested.emit())
	actions.add_child(forester_button)
	charge_button = _action_button("C   LADUJ", "Wybrane roboty", TURQUOISE)
	charge_button.pressed.connect(func(): charge_requested.emit())
	actions.add_child(charge_button)

	event_label = _label("Gotowosc systemow kolonii.", 13, TEXT)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.clip_text = true
	center.add_child(event_label)

	layout.add_child(VSeparator.new())
	var help := VBoxContainer.new()
	help.custom_minimum_size.x = 185
	help.add_theme_constant_override("separation", 7)
	layout.add_child(help)
	help.add_child(_label("STEROWANIE", 11, TURQUOISE, true))
	help.add_child(_label("LPM   Wybierz / grupa", 13, TEXT))
	help.add_child(_label("PPM   Ruch / zadanie", 13, TEXT))
	help.add_child(_label("WASD   Kamera", 13, TEXT))
	help.add_child(_label("ESC   Anuluj budowe", 13, TEXT))


func set_resources(wood: int, gold: int, stone: int, population: int, cap: int) -> void:
	if resource_label != null:
		resource_label.text = "DREWNO   %d       ZLOTO   %d       KAMIEN   %d       ROBOTY   %d/%d" % [
			wood, gold, stone, population, cap
		]


func set_power(power_kw: float, active: bool) -> void:
	if energy_label != null:
		energy_label.text = "%.1f kW  /  %s" % [power_kw, "LADOWANIE OK" if active else "BRAK ZASILANIA"]


func set_status(message: String) -> void:
	if event_label != null:
		event_label.text = message


func set_no_selection() -> void:
	_set_object("BRAK ZAZNACZENIA", "Wybierz jednostke lub budynek na mapie.", -1.0, "")


func set_robot(role: String, state: String, energy: float, cargo: int) -> void:
	_set_object(role, "%s   •   Ladunek: %d" % [state, cargo], energy, "AKUMULATOR   %d%%" % roundi(energy))


func set_robot_group(count: int) -> void:
	_set_object("%d ROBOTY" % count, "Zaznaczona grupa jednostek.", -1.0, "")


func set_structure(title: String, details: String, condition: float = -1.0) -> void:
	_set_object(title, details, condition, "SPRAWNOSC   %d%%" % roundi(condition))


func _set_object(title: String, details: String, progress: float, bar_caption: String) -> void:
	if title_label == null:
		return
	title_label.text = title
	detail_label.text = details
	battery_bar.visible = progress >= 0.0
	battery_caption.visible = progress >= 0.0
	if progress >= 0.0:
		battery_bar.value = clampf(progress, 0.0, 100.0)
		battery_caption.text = bar_caption


func set_action_availability(center_exists: bool, population_full: bool, training: bool, forester_limit: bool, has_selection: bool) -> void:
	if build_button != null:
		build_button.disabled = center_exists
	if train_button != null:
		train_button.disabled = population_full or training
	if forester_button != null:
		forester_button.disabled = forester_limit
	if charge_button != null:
		charge_button.disabled = not has_selection


func _action_button(text: String, tooltip: String, tint: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(108, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.54, 0.57))
	button.add_theme_stylebox_override("normal", _button_style(BG_SUBTLE, BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.15, 0.25, 0.29), tint))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.32, 0.34), tint))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.10, 0.13, 0.15), Color(0.13, 0.20, 0.23)))
	return button


func _label(value: String, size: int, color: Color, strong: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if strong:
		label.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.03, 0.55))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _margins(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return margin


func _panel_style() -> StyleBoxFlat:
	var style := _solid_style(BG, 10)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = BORDER
	return style


func _solid_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


func _button_style(background: Color, border_color: Color) -> StyleBoxFlat:
	var style := _solid_style(background, 6)
	style.set_border_width_all(1)
	style.border_color = border_color
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
