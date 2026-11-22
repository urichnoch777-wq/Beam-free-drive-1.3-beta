extends Control
## Мультитач-управление и HUD (рисуется кодом).

signal fix_pressed
signal start_pressed
signal beams_pressed

var throttle := 0.0
var steer := 0.0
var speed_kmh := 0.0
var damage := 0
var dist := 0
var hint := true
var touches := {}
var sb := StyleBoxFlat.new()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    sb.set_corner_radius_all(18)


func _rects() -> Dictionary:
    var s := size
    return {
        "L": Rect2(24, s.y - 174, 150, 150),
        "R": Rect2(198, s.y - 174, 150, 150),
        "B": Rect2(s.x - 348, s.y - 174, 150, 150),
        "G": Rect2(s.x - 174, s.y - 174, 150, 150),
        "fix": Rect2(s.x - 480, 16, 150, 54),
        "start": Rect2(s.x - 320, 16, 150, 54),
        "beam": Rect2(s.x - 160, 16, 150, 54),
    }


func _hit(p: Vector2) -> String:
    var r := _rects()
    for k in r:
        if r[k].has_point(p):
            return k
    return ""


func _press(idx: int, p: Vector2) -> void:
    var k := _hit(p)
    if k == "fix":
        fix_pressed.emit()
    elif k == "start":
        start_pressed.emit()
    elif k == "beam":
        beams_pressed.emit()
    elif k != "":
        touches[idx] = k


func _move(idx: int, p: Vector2) -> void:
    if touches.has(idx):
        var k := _hit(p)
        if k in ["L", "R", "G", "B"]:
            touches[idx] = k
        else:
            touches.erase(idx)


func _input(e: InputEvent) -> void:
    if e is InputEventScreenTouch:
        if e.pressed:
            _press(e.index, e.position)
        else:
            touches.erase(e.index)
    elif e is InputEventScreenDrag:
        _move(e.index, e.position)
    elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        if e.pressed:
            _press(-1, e.position)
        else:
            touches.erase(-1)
    elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
        _move(-1, e.position)


func _key(k: String) -> bool:
    match k:
        "L":
            return Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
        "R":
            return Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
        "G":
            return Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
        "B":
            return Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
    return false


func _on(k: String) -> bool:
    return touches.values().has(k) or _key(k)


func _process(_d: float) -> void:
    steer = (1.0 if _on("R") else 0.0) - (1.0 if _on("L") else 0.0)
    throttle = (1.0 if _on("G") else 0.0) - (1.0 if _on("B") else 0.0)
    if steer != 0.0 or throttle != 0.0:
        hint = false
    queue_redraw()


func _draw() -> void:
    var font := get_theme_default_font()
    var ink := Color(0.07, 0.12, 0.18, 0.9)
    var s := size
    var r := _rects()
    for k in r:
        var rc: Rect2 = r[k]
        sb.bg_color = Color(1, 1, 1, 0.9 if _on(k) else 0.55)
        draw_style_box(sb, rc)
        var c := rc.get_center()
        var pts := PackedVector2Array()
        match k:
            "L":
                pts = PackedVector2Array([c + Vector2(-40, 0), c + Vector2(28, -40), c + Vector2(28, 40)])
            "R":
                pts = PackedVector2Array([c + Vector2(40, 0), c + Vector2(-28, -40), c + Vector2(-28, 40)])
            "G":
                pts = PackedVector2Array([c + Vector2(0, -40), c + Vector2(-40, 28), c + Vector2(40, 28)])
            "B":
                pts = PackedVector2Array([c + Vector2(0, 40), c + Vector2(-40, -28), c + Vector2(40, -28)])
        if pts.size() > 0:
            draw_colored_polygon(pts, ink)
        var label: String = {"G": "ГАЗ", "B": "ТОРМОЗ", "fix": "Чинить", "start": "Старт", "beam": "Балки"}.get(k, "")
        if label != "":
            var y := rc.end.y - 16.0 if rc.size.y > 100.0 else rc.position.y + 36.0
            draw_string(font, Vector2(rc.position.x, y), label, HORIZONTAL_ALIGNMENT_CENTER, rc.size.x, 20, ink)
    sb.bg_color = Color(1, 1, 1, 0.8)
    draw_style_box(sb, Rect2(16, 16, 270, 100))
    draw_string(font, Vector2(34, 72), str(int(speed_kmh)), HORIZONTAL_ALIGNMENT_LEFT, -1, 46, ink)
    draw_string(font, Vector2(150, 72), "км/ч", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
    draw_string(font, Vector2(34, 102), "урон %d%%  ·  %d м" % [damage, dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
    if hint:
        sb.bg_color = Color(0, 0, 0, 0.5)
        draw_style_box(sb, Rect2(s.x * 0.5 - 360, s.y * 0.2, 720, 64))
        draw_string(font, Vector2(s.x * 0.5 - 360, s.y * 0.2 + 41), "Левая рука — руль, правая — газ и тормоз. Разбей машину!", HORIZONTAL_ALIGNMENT_CENTER, 720, 24, Color.WHITE)
