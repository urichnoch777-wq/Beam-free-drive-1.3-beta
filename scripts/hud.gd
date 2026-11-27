extends Control
## Приборы и сенсорное управление (мультитач): стрелки / руль / наклон + вращение камеры пальцем.

const LABEL := {"gas": "GAS", "brake": "BRAKE", "hand": "HB", "reset": "RESET", "slow": "SLOW",
    "menu": "MENU", "left": "<", "right": ">", "cal": "CAL"}
const WHEEL_LOCK := 2.6

var car
var mode := 0
var gas := 0.0
var brake := 0.0
var steer := 0.0
var hand := 0.0
var want_reset := false
var want_slow := false
var want_menu := false
var cam_dx := 0.0
var cam_dy := 0.0
var cam_active := false
var _touch := {}
var _wheel := 0.0
var _wheel_prev := 0.0
var _neutral := 0.0
var _has_neutral := false
var _tilt := 0.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mode = GameSettings.control_mode


func _names() -> Array:
    var r: Array = ["gas", "brake", "hand", "reset", "slow", "menu"]
    if mode == 0:
        r.append("left")
        r.append("right")
    elif mode == 2:
        r.append("cal")
    return r


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
        "menu":
            return Rect2(w - 310.0, 20.0, 90.0, 60.0)
        "left":
            return Rect2(30.0, h - 190.0, 150.0, 150.0)
        "right":
            return Rect2(200.0, h - 190.0, 150.0, 150.0)
        "cal":
            return Rect2(30.0, h - 130.0, 130.0, 100.0)
    return Rect2()


func _wheel_c() -> Vector2:
    return Vector2(size.x * 0.17, size.y * 0.72)


func _hit(p: Vector2) -> String:
    for nm in _names():
        if _rect(nm).has_point(p):
            return nm
    if mode == 1 and p.distance_to(_wheel_c()) < 130.0:
        return "wheel"
    return "cam"


func _input(e: InputEvent) -> void:
    if e is InputEventScreenTouch:
        if e.pressed:
            var hit: String = _hit(e.position)
            _touch[e.index] = hit
            match hit:
                "reset":
                    want_reset = true
                "slow":
                    want_slow = true
                "menu":
                    want_menu = true
                "cal":
                    _has_neutral = false
                "wheel":
                    _wheel_prev = (e.position - _wheel_c()).angle()
        else:
            _touch.erase(e.index)
        _refresh()
    elif e is InputEventScreenDrag:
        var t: String = _touch.get(e.index, "")
        if t == "cam":
            cam_dx += e.relative.x
            cam_dy += e.relative.y
        elif t == "wheel":
            var a: float = (e.position - _wheel_c()).angle()
            _wheel = clampf(_wheel + angle_difference(_wheel_prev, a), -WHEEL_LOCK, WHEEL_LOCK)
            _wheel_prev = a


func _refresh() -> void:
    var v: Array = _touch.values()
    gas = 1.0 if v.has("gas") else 0.0
    brake = 1.0 if v.has("brake") else 0.0
    hand = 1.0 if v.has("hand") else 0.0
    cam_active = v.has("cam")
    if mode == 0:
        steer = (1.0 if v.has("right") else 0.0) - (1.0 if v.has("left") else 0.0)


func _process(delta: float) -> void:
    if mode == 1:
        if not _touch.values().has("wheel"):
            _wheel = move_toward(_wheel, 0.0, 5.0 * delta)
        steer = _wheel / WHEEL_LOCK
    elif mode == 2:
        var a: Vector3 = Input.get_accelerometer()
        if a.length() > 0.5:
            var ang: float = atan2(a.x, a.y)
            if not _has_neutral:
                _neutral = ang
                _has_neutral = true
            var s: float = angle_difference(_neutral, ang) / deg_to_rad(30.0 / GameSettings.tilt_sens)
            if GameSettings.tilt_invert:
                s = -s
            if absf(s) < 0.06:
                s = 0.0
            _tilt = lerpf(_tilt, clampf(s, -1.0, 1.0), 1.0 - exp(-12.0 * delta))
        steer = _tilt
    queue_redraw()


func _draw() -> void:
    var f := ThemeDB.fallback_font
    var held: Array = _touch.values()
    for nm in _names():
        var r: Rect2 = _rect(nm)
        draw_rect(r, Color(1, 1, 1, 0.32 if held.has(nm) else 0.12), true)
        draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
        draw_string(f, r.position + Vector2(10, r.size.y * 0.5 + 8), LABEL[nm], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 22, Color.WHITE)
    if mode == 1:
        var c: Vector2 = _wheel_c()
        draw_arc(c, 100.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 6.0)
        draw_line(c + Vector2(-100, 0).rotated(_wheel), c + Vector2(100, 0).rotated(_wheel), Color(1, 1, 1, 0.7), 6.0)
        draw_line(c, c + Vector2(0, 100).rotated(_wheel), Color(1, 1, 1, 0.7), 6.0)
    elif mode == 2:
        var bc := Vector2(size.x * 0.17, size.y * 0.55)
        draw_rect(Rect2(bc.x - 120.0, bc.y, 240.0, 12.0), Color(1, 1, 1, 0.2), true)
        draw_rect(Rect2(bc.x + steer * 120.0 - 8.0, bc.y - 6.0, 16.0, 24.0), Color(0.3, 0.9, 0.4), true)
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
        warn = "ENGINE DEAD (RESET)"
    elif car.radiator_dead:
        warn = "RADIATOR LEAK"
    if warn != "":
        draw_string(f, Vector2(30, 196), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.3, 0.2))
    if car.sim_speed < 1.0:
        draw_string(f, Vector2(30, 228), "slow-mo x%.2f" % car.sim_speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.8, 1))
