extends Node3D
## Точка входа: мир, камера, ввод, спавн машины.

const World = preload("res://scripts/world.gd")
const Car = preload("res://scripts/car.gd")
const Hud = preload("res://scripts/hud.gd")
const SLOW := [1.0, 0.25, 0.05, 0.01]

var world
var car
var hud
var cam: Camera3D
var cam_dir := Vector3(0, 0, -1)
var slow_i := 0
var orbit_yaw := 0.0
var orbit_pitch := 0.0
var idle_t := 0.0


func _ready() -> void:
    _setup_input()
    world = World.new()
    _build_scene()
    cam = Camera3D.new()
    cam.far = 1500.0
    add_child(cam)
    cam.current = true
    hud = Hud.new()
    var layer := CanvasLayer.new()
    add_child(layer)
    layer.add_child(hud)
    _spawn()


func _key(action: String, code: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var e := InputEventKey.new()
    e.physical_keycode = code
    InputMap.action_add_event(action, e)


func _setup_input() -> void:
    if InputMap.has_action("throttle"):
        return
    _key("throttle", KEY_W)
    _key("throttle", KEY_UP)
    _key("brake", KEY_S)
    _key("brake", KEY_DOWN)
    _key("steer_left", KEY_A)
    _key("steer_left", KEY_LEFT)
    _key("steer_right", KEY_D)
    _key("steer_right", KEY_RIGHT)
    _key("handbrake", KEY_SPACE)
    _key("reset", KEY_R)
    _key("slowmo", KEY_T)
    _key("tc", KEY_Y)
    _key("menu", KEY_ESCAPE)


func _box(center: Vector3, size: Vector3, rot_x_deg: float, col: Color) -> void:
    var xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(rot_x_deg)), center)
    world.add_box(xf, size)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.transform = xf
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mi.material_override = mat
    add_child(mi)


func _build_scene() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    sky.sky_material = ProceduralSkyMaterial.new()
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.shadow_enabled = not OS.has_feature("mobile")
    add_child(sun)
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(4000, 4000)
    ground.mesh = pm
    var sm := ShaderMaterial.new()
    sm.shader = load("res://shaders/ground.gdshader")
    ground.material_override = sm
    add_child(ground)
    # полигон: бетонная стена (краш-тест), трамплин, коробки
    _box(Vector3(0, 1.5, -60), Vector3(30, 3, 1), 0.0, Color(0.7, 0.7, 0.72))
    _box(Vector3(0, -0.26, -110), Vector3(8, 3, 14), 10.0, Color(0.85, 0.6, 0.15))
    for i in range(6):
        _box(Vector3(-8 + i * 3.2, 0.5, -30 - (i % 2) * 6), Vector3(1, 1, 1), 0.0, Color(0.25, 0.5, 0.8))


func _spawn() -> void:
    if car != null:
        car.queue_free()
    car = Car.new()
    add_child(car)
    car.setup(world, Vector3(0, 0.1, 0), 3)
    car.sim_speed = SLOW[slow_i]
    hud.car = car


func _cycle_slow() -> void:
    slow_i = (slow_i + 1) % SLOW.size()
    car.sim_speed = SLOW[slow_i]


func _unhandled_input(e: InputEvent) -> void:
    if e.is_action_pressed("reset"):
        _spawn()
    elif e.is_action_pressed("slowmo"):
        _cycle_slow()
    elif e.is_action_pressed("tc"):
        car.tc = not car.tc
    elif e.is_action_pressed("menu"):
        _to_menu()


func _process(delta: float) -> void:
    if car == null:
        return
    if hud.want_reset:
        hud.want_reset = false
        _spawn()
    if hud.want_slow:
        hud.want_slow = false
        _cycle_slow()
    if hud.want_menu:
        hud.want_menu = false
        _to_menu()
        return
    car.in_throttle = maxf(Input.get_action_strength("throttle"), hud.gas)
    car.in_brake = maxf(Input.get_action_strength("brake"), hud.brake)
    car.in_hand = maxf(Input.get_action_strength("handbrake"), hud.hand)
    var st: float = Input.get_axis("steer_left", "steer_right")
    if absf(hud.steer) > 0.01:
        st = hud.steer
    car.in_steer = st
    var f := Vector3(car.fwd.x, 0.0, car.fwd.z)
    if f.length() > 0.1:
        cam_dir = cam_dir.lerp(f.normalized(), 1.0 - exp(-4.0 * delta)).normalized()
    if hud.cam_dx != 0.0 or hud.cam_dy != 0.0:
        orbit_yaw -= hud.cam_dx * 0.006
        orbit_pitch = clampf(orbit_pitch + hud.cam_dy * 0.004, -0.25, 1.0)
        hud.cam_dx = 0.0
        hud.cam_dy = 0.0
        idle_t = 0.0
    elif hud.cam_active:
        idle_t = 0.0
    else:
        idle_t += delta
        if idle_t > 2.5:
            orbit_yaw = lerp_angle(orbit_yaw, 0.0, 1.0 - exp(-2.0 * delta))
            orbit_pitch = lerpf(orbit_pitch, 0.0, 1.0 - exp(-2.0 * delta))
    var d: Vector3 = cam_dir.rotated(Vector3.UP, orbit_yaw)
    var elev: float = clampf(0.33 + orbit_pitch, 0.05, 1.35)
    var target: Vector3 = car.center() + Vector3(0, 0.8, 0)
    cam.global_position = target - d * (8.0 * cos(elev)) + Vector3(0, 8.0 * sin(elev), 0)
    cam.look_at(target, Vector3.UP)


func _to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _to_menu()
