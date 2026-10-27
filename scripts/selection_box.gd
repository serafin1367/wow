extends Control
## Rysuje prostokat zaznaczenia we wspolrzednych ekranu.

var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO
var is_dragging: bool = false


func show_selection(start: Vector2, end: Vector2) -> void:
	drag_start = start
	drag_end = end
	is_dragging = true
	queue_redraw()


func hide_selection() -> void:
	is_dragging = false
	queue_redraw()


func _draw() -> void:
	if not is_dragging:
		return
	var rect := Rect2(drag_start, drag_end - drag_start).abs()
	draw_rect(rect, Color(0.25, 0.75, 1.0, 0.16), true)
	draw_rect(rect, Color(0.30, 0.85, 1.0, 0.95), false, 2.0)
