extends Node3D
## SoftBeam Drive 3D: сцена целиком собирается кодом.

const WorldScript := preload("res://scripts/world.gd")
const CarScript := preload("res://scripts/soft_car.gd")
const HudScript := preload("res://scripts/hud.gd")

var world: WorldScript
var car: CarScript
var hud: HudScript
var cam: Camera3D


func _ready() -> void:
    var env := Environment.new()
    var sky := Sky.new()
    sky.sky_material = ProceduralSkyMaterial.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.fog_enabled = true
    env.fog_light_color = Color(0.66, 0.8, 0.95)
    env.fog_density = 0.004
    env.fog_sky_affect = 0.0
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
    sun.light_energy = 1.3
    add_child(sun)
    world = WorldScript.new()
    add_child(world)
    car = CarScript.new()
    car.world = world
    add_child(car)
    cam = Camera3D.new()
    cam.fov = 70.0
    cam.far = 500.0
    add_child(cam)
    cam.make_current()
    cam.global_position = car.center + Vector3(0.0, 4.0, 9.0)
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = HudScript.new()
    layer.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.fix_pressed.connect(func(): car.build(car.center.x, car.center.z))
    hud.start_pressed.connect(func(): car.build(0.0, 0.0))
    hud.beams_pressed.connect(func(): car.set_beams(not car.show_beams))


func _process(delta: float) -> void:
    car.throttle = hud.throttle
    car.steer_in = hud.steer
    hud.speed_kmh = car.speed * 3.6
    hud.damage = car.damage_percent()
    hud.dist = maxi(0, roundi(-car.center.z))
    var f := Vector3(car.fwd.x, 0.0, car.fwd.z)
    f = f.normalized() if f.length() > 0.01 else Vector3(0.0, 0.0, -1.0)
    var target := car.center - f * 9.0 + Vector3(0.0, 3.6, 0.0)
    var p := cam.global_position.lerp(target, 1.0 - exp(-delta * 3.0))
    p.y = maxf(p.y, world.sample(p.x, p.z).w + 1.0)
    cam.global_position = p
    cam.look_at(car.center + f * 3.0 + Vector3(0.0, 1.0, 0.0), Vector3.UP)
