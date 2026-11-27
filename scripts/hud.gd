extends Control
## Приборы и сенсорное управление (мультитач).

const LABELS := {"gas": "GAS", "brake": "BRAKE", "hand": "HB", "reset": "RESET", "slow": "SLOW"}

var car
var gas := 0.0
var brake := 0.0
var steer := 0.0
var hand := 0.0
var want_reset := false
var want_slow := false
var _touch := {}
var _steer_x0 := 0.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rect(nm: String) -> Rect2:
    var w: float = size.x
    var h: float = size.y
    match nm:
        "gas":
            return Rect2(w - 170.0, h - 330.0, 140.0, 300.0)
        "brake":
            return Rect2(w - 330.0, h - 230.0, 140.0, 200.0)
        "hand":
            return Rect2(w - 480.0, h - 130.0, 130.0, 100.0)
        "reset":
            return Rect2(w - 110.0, 20.0, 90.0, 60.0)
        "slow":
            return Rect2(w - 210.0, 20.0, 90.0, 60.0)
    return Rect2()


func _input(e: InputEvent) -> void:
    if e is InputEventScreenTouch:
        if e.pressed:
            var hit := "steer"
            for nm in LABELS:
                if _rect(nm).has_point(e.position):
                    hit = nm
            if hit == "steer" and e.position.x > size.x * 0.5:
                return
            _touch[e.index] = hit
            if hit == "steer":
                _steer_x0 = e.position.x
            elif hit == "reset":
                want_reset = true
            elif hit == "slow":
                want_slow = true
        else:
            _touch.erase(e.index)
        _refresh()
    elif e is InputEventScreenDrag:
        if _touch.get(e.index, "") == "steer":
            steer = clampf((e.position.x - _steer_x0) / 150.0, -1.0, 1.0)


func _refresh() -> void:
    var v: Array = _touch.values()
    gas = 1.0 if v.has("gas") else 0.0
    brake = 1.0 if v.has("brake") else 0.0
    hand = 1.0 if v.has("hand") else 0.0
    if not v.has("steer"):
        steer = 0.0


func _process(_d: float) -> void:
    queue_redraw()


func _draw() -> void:
    var f := ThemeDB.fallback_font
    var on: Array = _touch.values()
    for nm in LABELS:
        var r: Rect2 = _rect(nm)
        draw_rect(r, Color(1, 1, 1, 0.32 if on.has(nm) else 0.12), true)
        draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
        draw_string(f, r.position + Vector2(10, r.size.y * 0.5 + 8), LABELS[nm], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 22, Color.WHITE)
    # руль
    var c := Vector2(size.x * 0.17, size.y * 0.74)
    var a: float = steer * 1.4
    draw_arc(c, 90.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 5.0)
    draw_line(c + Vector2(-90, 0).rotated(a), c + Vector2(90, 0).rotated(a), Color(1, 1, 1, 0.7), 5.0)
    draw_line(c, c + Vector2(0, 90).rotated(a), Color(1, 1, 1, 0.7), 5.0)
    if car == null:
        return
    var kmh: int = int(car.speed * 3.6)
    draw_string(f, Vector2(30, 64), "%d km/h" % kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
    draw_string(f, Vector2(30, 104), car.gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.9, 0.3))
    var rr: float = clampf(car.rpm / 7000.0, 0.0, 1.0)
    draw_rect(Rect2(30, 118, 300, 14), Color(1, 1, 1, 0.2), true)
    draw_rect(Rect2(30, 118, 300 * rr, 14), Color(1, 0.3, 0.2) if rr > 0.9 else Color(0.3, 0.9, 0.4), true)
    var tcol := Color(1, 0.3, 0.2) if car.temp > 110.0 else Color.WHITE
    draw_string(f, Vector2(30, 162), "TEMP %d C" % int(car.temp), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, tcol)
    var warn := ""
    if car.engine_dead:
        warn = "ENGINE DEAD (R = respawn)"
    elif car.radiator_dead:
        warn = "RADIATOR LEAK"
    if warn != "":
        draw_string(f, Vector2(30, 196), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.3, 0.2))
    if car.sim_speed < 1.0:
        draw_string(f, Vector2(30, 228), "slow-mo x%.2f" % car.sim_speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.8, 1))
