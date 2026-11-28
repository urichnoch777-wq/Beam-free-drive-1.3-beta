extends Node3D
## Машина: мягкое тело (узлы+балки), 4 колеса с лучевой подвеской,
## двигатель с турбо, автоматическая КПП, кузов-«шкура» с деформацией.

const SoftBody = preload("res://scripts/soft_body.gd")
const ModelLoader = preload("res://scripts/model_loader.gd")


class Wheel:
    var mount := 0
    var front := false
    var side := 1.0
    var omega := 0.0
    var spin := 0.0
    var comp := 0.0
    var grounded := false
    var n := Vector3.UP
    var dist := 0.0
    var ray_len := 0.0
    var origin := Vector3.ZERO
    var fw := Vector3(0, 0, -1)
    var ax := Vector3.RIGHT
    var fz := 0.0
    var free := 0.5
    var other: Wheel
    var node: MeshInstance3D


# геометрия: 8 сечений вдоль машины, 2 яруса (пол/верх), nz колонн в ширину
const NX := 8
var WF := 0.88
var ST_Z := PackedFloat32Array([-2.20, -1.30, -0.45, 0.20, 1.10, 1.50, 1.95, 2.25])
var ST_TOP := PackedFloat32Array([0.64, 0.80, 0.90, 1.42, 1.42, 1.00, 0.97, 0.86])
var ST_FLOOR := PackedFloat32Array([0.40, 0.30, 0.30, 0.30, 0.30, 0.30, 0.30, 0.40])
var ST_WT := PackedFloat32Array([0.78, 0.84, 0.84, 0.70, 0.70, 0.78, 0.80, 0.78])
var ST_STR := PackedFloat32Array([0.30, 0.60, 1.00, 1.00, 1.00, 0.90, 0.55, 0.30])
var K_EDGE := 3.0e5
var Y_BASE := 26000.0
# подвеска и шины
const H_TOP := 0.45
var INSET := 0.08
var K_SPRING := 35000.0
var C_BUMP := 3000.0
var C_REB := 4500.0
const BUMP_START := 0.17
var K_BUMP := 250000.0
var K_ARB_F := 18000.0
var K_ARB_R := 9000.0
var R_TIRE := 0.33
var I_WHEEL := 1.6
const MU0 := 1.1
var MEFF := 100.0
# двигатель и трансмиссия
var GEARS := PackedFloat32Array([3.6, 2.2, 1.55, 1.2, 0.95, 0.78])
var RPMS := PackedFloat32Array([0, 800, 1500, 2500, 3500, 4500, 5500, 6500, 7000, 7300])
var TQS := PackedFloat32Array([0, 95, 190, 255, 280, 290, 280, 245, 190, 0])
const REV := 3.4
var FINAL := 3.9
var IDLE := 900.0
var REDLINE := 6800.0
const DT_MAX := 1.0 / 480.0
# кузов
const DARK := Color(0.12, 0.12, 0.13)
var COLORS := [Color(0.78, 0.10, 0.10), Color(0.35, 0.50, 0.60), DARK, Color(0.78, 0.10, 0.10)]

var sb: SoftBody
var world
var nz := 3
var wheels: Array[Wheel] = []
var total_mass := 0.0
var fwd := Vector3(0, 0, -1)
var right := Vector3.RIGHT
var up := Vector3.UP
# вход
var in_throttle := 0.0
var in_brake := 0.0
var in_steer := 0.0
var in_hand := 0.0
var tc := true
var sim_speed := 1.0
# состояние
var throttle := 0.0
var brake := 0.0
var brake_cmd := 0.0
var steer := 0.0
var gear := 1
var rpm := 900.0
var boost := 0.0
var shift_t := 0.0
var since_shift := 9.0
var speed := 0.0
var temp := 80.0
var coolant := 1.0
var radiator_dead := false
var engine_dead := false
var gear_text := "D1"
var turbo := 0.35
var vmax := 90.0
var ms := 1.0
var has_model := false
var spec_data := {}
var body_mat: ShaderMaterial
var front_len0 := 1.0
var n_front := 0
var n_front2 := 0
# кузов-шкура
var skin: MeshInstance3D
var q_a := PackedInt32Array()
var q_b := PackedInt32Array()
var q_c := PackedInt32Array()
var q_d := PackedInt32Array()
var q_kind := PackedInt32Array()
var q_d0 := PackedFloat32Array()
var q_d1 := PackedFloat32Array()
var _va := PackedVector3Array()
var _na := PackedVector3Array()
var _ca := PackedColorArray()


func setup(w, origin: Vector3, spec: Dictionary = {}) -> void:
    world = w
    _apply_spec(spec)
    _build(origin)
    _make_visuals()


func _apply_spec(sp: Dictionary) -> void:
    spec_data = sp
    if sp.has("st_z"):
        ST_Z = PackedFloat32Array(sp["st_z"])
        ST_TOP = PackedFloat32Array(sp["st_top"])
        ST_FLOOR = PackedFloat32Array(sp["st_floor"])
        ST_WT = PackedFloat32Array(sp["st_wt"])
    WF = sp.get("wf", WF)
    INSET = sp.get("inset", INSET)
    R_TIRE = sp.get("r_tire", R_TIRE)
    I_WHEEL = sp.get("i_wheel", I_WHEEL)
    ms = float(sp.get("mass", 1230.0)) / 1230.0
    K_EDGE *= ms
    Y_BASE *= ms
    K_SPRING *= ms
    C_BUMP *= ms
    C_REB *= ms
    K_BUMP *= ms
    K_ARB_F *= ms
    K_ARB_R *= ms
    MEFF *= ms
    if sp.has("tqs"):
        RPMS = PackedFloat32Array(sp["rpms"])
        TQS = PackedFloat32Array(sp["tqs"])
    if sp.has("gears"):
        GEARS = PackedFloat32Array(sp["gears"])
    FINAL = sp.get("final", FINAL)
    REDLINE = sp.get("redline", REDLINE)
    IDLE = sp.get("idle", IDLE)
    turbo = sp.get("turbo", turbo)
    vmax = sp.get("vmax", vmax)
    rpm = IDLE
    has_model = sp.has("model")


func _idx(i: int, j: int, k: int) -> int:
    return (i * 2 + j) * nz + k


func _ids(sts: Array, ys: Array) -> Array:
    var r: Array = []
    for i in sts:
        for j in ys:
            for k in range(nz):
                r.append(_idx(i, j, k))
    return r


func _addm(ids: Array, total: float) -> void:
    for q in ids:
        sb.mass[q] = sb.mass[q] + total / ids.size()
        sb.inv_mass[q] = 1.0 / sb.mass[q]


func _pair(pairs: Dictionary, a: int, b: int, kind: int) -> void:
    var key := Vector2i(mini(a, b), maxi(a, b))
    if not pairs.has(key):
        pairs[key] = kind


func _c(i: int, j: int, k: int, dx: int, dy: int, dz: int) -> int:
    return _idx(i + dx, j + dy, k + dz)


func _add_quad(a: int, b: int, c: int, d: int, kind: int) -> void:
    q_a.append(a)
    q_b.append(b)
    q_c.append(c)
    q_d.append(d)
    q_kind.append(kind)
    q_d0.append(sb.pos[a].distance_to(sb.pos[c]))
    q_d1.append(sb.pos[b].distance_to(sb.pos[d]))


func _build(origin: Vector3) -> void:
    sb = SoftBody.new()
    var per_floor: float = 400.0 / (NX * nz)
    var per_top: float = 200.0 / (NX * nz)
    for i in range(NX):
        for j in range(2):
            for k in range(nz):
                var hw: float = WF if j == 0 else ST_WT[i]
                var x: float = -hw + 2.0 * hw * k / (nz - 1)
                var y: float = ST_FLOOR[i] if j == 0 else ST_TOP[i]
                sb.add_node(origin + Vector3(x, y, ST_Z[i]), per_floor if j == 0 else per_top)
    # распределение масс: двигатель, КПП, водитель, бак, мост, багажник
    _addm(_ids([1], [0, 1]), 120.0)
    _addm(_ids([0], [0]), 50.0)
    _addm(_ids([0], [1]), 30.0)
    _addm(_ids([2], [0]), 45.0)
    _addm(_ids([3], [0, 1]), 120.0)
    _addm(_ids([5], [0]), 45.0)
    _addm(_ids([6], [0]), 45.0)
    _addm(_ids([6, 7], [1]), 40.0)
    var defs := [[_idx(1, 0, 0), true, -1.0, 1], [_idx(1, 0, nz - 1), true, 1.0, 1],
        [_idx(5, 0, 0), false, -1.0, 5], [_idx(5, 0, nz - 1), false, 1.0, 5]]
    for d in defs:
        var w := Wheel.new()
        w.mount = d[0]
        w.front = d[1]
        w.side = d[2]
        w.free = ST_FLOOR[d[3]] + H_TOP + 0.09 - R_TIRE
        wheels.append(w)
        _addm([w.mount], 24.0)
    wheels[0].other = wheels[1]
    wheels[1].other = wheels[0]
    wheels[2].other = wheels[3]
    wheels[3].other = wheels[2]
    for q in range(sb.mass.size()):
        sb.mass[q] = sb.mass[q] * ms
        sb.inv_mass[q] = 1.0 / sb.mass[q]
    for m in sb.mass:
        total_mass += m
    # балки: рёбра, диагонали граней, диагонали ячеек
    var pairs := {}
    for i in range(NX):
        for j in range(2):
            for k in range(nz):
                if i + 1 < NX:
                    _pair(pairs, _idx(i, j, k), _idx(i + 1, j, k), 0)
                if j + 1 < 2:
                    _pair(pairs, _idx(i, j, k), _idx(i, j + 1, k), 0)
                if k + 1 < nz:
                    _pair(pairs, _idx(i, j, k), _idx(i, j, k + 1), 0)
    for i in range(NX - 1):
        for k in range(nz - 1):
            for dz in range(2):
                _pair(pairs, _c(i, 0, k, 0, 0, dz), _c(i, 0, k, 1, 1, dz), 1)
                _pair(pairs, _c(i, 0, k, 1, 0, dz), _c(i, 0, k, 0, 1, dz), 1)
            for dy in range(2):
                _pair(pairs, _c(i, 0, k, 0, dy, 0), _c(i, 0, k, 1, dy, 1), 1)
                _pair(pairs, _c(i, 0, k, 1, dy, 0), _c(i, 0, k, 0, dy, 1), 1)
            for dx in range(2):
                _pair(pairs, _c(i, 0, k, dx, 0, 0), _c(i, 0, k, dx, 1, 1), 1)
                _pair(pairs, _c(i, 0, k, dx, 1, 0), _c(i, 0, k, dx, 0, 1), 1)
            _pair(pairs, _c(i, 0, k, 0, 0, 0), _c(i, 0, k, 1, 1, 1), 2)
            _pair(pairs, _c(i, 0, k, 1, 0, 0), _c(i, 0, k, 0, 1, 1), 2)
            _pair(pairs, _c(i, 0, k, 0, 1, 0), _c(i, 0, k, 1, 0, 1), 2)
            _pair(pairs, _c(i, 0, k, 0, 0, 1), _c(i, 0, k, 1, 1, 0), 2)
    var kf := [1.0, 0.8, 0.6]
    for key in pairs:
        var a: int = key.x
        var b: int = key.y
        var kind: int = pairs[key]
        var st_a: int = floori(a / float(2 * nz))
        var st_b: int = floori(b / float(2 * nz))
        var f: float = (ST_STR[st_a] + ST_STR[st_b]) * 0.5
        sb.add_beam(a, b, K_EDGE * kf[kind] * (0.7 + 0.3 * f),
            Y_BASE * f * (1.0 if kind == 0 else 0.8), 1.5 if f < 0.7 else 2.0)
    # грани кузова: 0 кузов, 1 стекло, 2 тёмное, 3 борт с окном
    for i in range(NX - 1):
        for k in range(nz - 1):
            _add_quad(_idx(i, 1, k), _idx(i + 1, 1, k), _idx(i + 1, 1, k + 1), _idx(i, 1, k + 1),
                1 if (i == 2 or i == 4) else 0)
            _add_quad(_idx(i, 0, k), _idx(i + 1, 0, k), _idx(i + 1, 0, k + 1), _idx(i, 0, k + 1), 2)
        for k in [0, nz - 1]:
            _add_quad(_idx(i, 0, k), _idx(i + 1, 0, k), _idx(i + 1, 1, k), _idx(i, 1, k),
                3 if (i >= 2 and i <= 4) else 0)
    for k in range(nz - 1):
        _add_quad(_idx(0, 0, k), _idx(0, 0, k + 1), _idx(0, 1, k + 1), _idx(0, 1, k), 2)
        _add_quad(_idx(NX - 1, 0, k), _idx(NX - 1, 0, k + 1), _idx(NX - 1, 1, k + 1), _idx(NX - 1, 1, k), 0)
    var km: int = nz >> 1
    n_front = _idx(0, 0, km)
    n_front2 = _idx(2, 0, km)
    front_len0 = sb.pos[n_front].distance_to(sb.pos[n_front2])


func _make_visuals() -> void:
    skin = MeshInstance3D.new()
    var wm: Array = []
    if has_model:
        var bm: Array = ModelLoader.load_meshes(spec_data["model"])
        wm = ModelLoader.load_meshes(spec_data["wheels"])
        if bm.size() == 0 or wm.size() < 4:
            has_model = false
        else:
            skin.mesh = bm[0]
            body_mat = ShaderMaterial.new()
            body_mat.shader = load("res://shaders/car_body.gdshader")
            body_mat.set_shader_parameter("st_z", ST_Z)
            body_mat.set_shader_parameter("st_top", ST_TOP)
            body_mat.set_shader_parameter("st_floor", ST_FLOOR)
            body_mat.set_shader_parameter("st_wt", ST_WT)
            body_mat.set_shader_parameter("wf", WF)
            body_mat.set_shader_parameter("nodes", sb.pos)
            body_mat.set_shader_parameter("car_basis", Basis.IDENTITY)
            skin.material_override = body_mat
            skin.custom_aabb = AABB(Vector3(-10000, -1000, -10000), Vector3(20000, 2000, 20000))
    if not has_model:
        skin.mesh = ArrayMesh.new()
        var mat := StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo = true
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mat.roughness = 0.5
        skin.material_override = mat
    add_child(skin)
    for wi in range(wheels.size()):
        var w: Wheel = wheels[wi]
        var m := MeshInstance3D.new()
        if has_model:
            m.mesh = wm[wi]
            var wmat := StandardMaterial3D.new()
            wmat.vertex_color_use_as_albedo = true
            wmat.roughness = 0.5
            m.material_override = wmat
        else:
            var cyl := CylinderMesh.new()
            cyl.top_radius = R_TIRE
            cyl.bottom_radius = R_TIRE
            cyl.height = 0.22
            cyl.radial_segments = 16
            cyl.rings = 1
            m.mesh = cyl
            var tm := StandardMaterial3D.new()
            tm.albedo_color = Color(0.07, 0.07, 0.08)
            m.material_override = tm
            var st := MeshInstance3D.new()
            var bx := BoxMesh.new()
            bx.size = Vector3(0.52, 0.24, 0.07)
            st.mesh = bx
            var sm := StandardMaterial3D.new()
            sm.albedo_color = Color(0.75, 0.75, 0.78)
            st.material_override = sm
            m.add_child(st)
        add_child(m)
        w.node = m


func center() -> Vector3:
    var s := Vector3.ZERO
    for w in wheels:
        s += sb.pos[w.mount]
    return s * 0.25


func _frame() -> void:
    var fl: Vector3 = sb.pos[wheels[0].mount]
    var fr: Vector3 = sb.pos[wheels[1].mount]
    var rl: Vector3 = sb.pos[wheels[2].mount]
    var rr: Vector3 = sb.pos[wheels[3].mount]
    fwd = ((fl + fr) * 0.5 - (rl + rr) * 0.5).normalized()
    var r: Vector3 = (fr + rr) * 0.5 - (fl + rl) * 0.5
    up = r.cross(fwd).normalized()
    right = fwd.cross(up).normalized()


func _vcg() -> Vector3:
    var s := Vector3.ZERO
    for i in range(sb.vel.size()):
        s += sb.vel[i] * sb.mass[i]
    return s / total_mass


func _tq(r: float) -> float:
    for i in range(1, RPMS.size()):
        if r <= RPMS[i]:
            return lerpf(TQS[i - 1], TQS[i], (r - RPMS[i - 1]) / (RPMS[i] - RPMS[i - 1]))
    return 0.0


func _tire(fz: float, mu: float, sx_v: float, sy_v: float, rx: float, ry: float) -> Vector2:
    var sx: float = sx_v / rx
    var sy: float = sy_v / ry
    var s: float = sqrt(sx * sx + sy * sy)
    if s < 0.000001:
        return Vector2.ZERO
    var cv: float = 1.0 - 0.18 * minf(1.0, (s - 1.0) / 3.0)
    if s < 1.0:
        cv = 2.0 * s - s * s
    var f: float = mu * fz * cv
    return Vector2(f * sx / s, -f * sy / s)


## Момент на ведущую ось (задний привод) + положение КПП.
func _drive(dt: float, vlong: float) -> float:
    var thr: float = throttle
    var brk: float = brake
    var dir := 1
    if throttle > 0.05 and brake < 0.05:
        if vlong < -1.0:
            brk = throttle
            thr = 0.0
    elif brake > 0.05 and throttle < 0.05:
        if vlong > 1.0:
            thr = 0.0
        else:
            dir = -1
            thr = brake
            brk = 0.0
    brake_cmd = brk
    var om: float = (wheels[2].omega + wheels[3].omega) * 0.5
    var gr: float = (-REV if dir < 0 else GEARS[gear - 1]) * FINAL
    var rpm_lock: float = absf(om * gr) * 9.549297
    shift_t = maxf(0.0, shift_t - dt)
    since_shift += dt
    if dir > 0 and shift_t <= 0.0 and since_shift > 0.6:
        var rg: float = absf(vlong) / R_TIRE * absf(gr) * 9.549297
        if rg > REDLINE * (0.52 + 0.43 * thr) and gear < 6:
            gear += 1
            shift_t = 0.22
            since_shift = 0.0
        elif rg < REDLINE * (0.19 + 0.19 * thr) and gear > 1:
            gear -= 1
            shift_t = 0.18
            since_shift = 0.0
    gear_text = "R" if dir < 0 else "D%d" % gear
    var cl: float = minf(1.0, rpm_lock / 1600.0)
    cl = cl * cl * (3.0 - 2.0 * cl)
    var rpm_slip: float = IDLE + thr * (2800.0 - IDLE)
    var rpm_t: float = maxf(maxf(rpm_lock, rpm_slip * (1.0 - cl) + rpm_lock * cl), IDLE)
    rpm += (rpm_t - rpm) * (1.0 - exp(-30.0 * dt))
    var tgt: float = clampf((rpm - 1800.0) / 1600.0, 0.0, 1.0) * thr
    boost += (tgt - boost) * (1.0 - exp(-(3.0 if tgt > boost else 6.0) * dt))
    var t: float = _tq(rpm) * thr * (1.0 + turbo * boost) - (10.0 + 0.008 * rpm) * (1.0 - thr)
    if rpm > REDLINE + 200.0:
        t = minf(t, 0.0)
    t *= clampf((vmax + 3.0 - speed) / 3.0, 0.0, 1.0)
    if engine_dead:
        t = 0.0
    var cap: float = 0.55 + 0.45 * cl
    if t < 0.0:
        cap = cl
    var tw: float = t * gr * 0.92 * cap
    if shift_t > 0.0:
        tw = 0.0
    return tw


func _substep(dt: float) -> void:
    _frame()
    var vcg: Vector3 = _vcg()
    speed = vcg.length()
    var vlong: float = vcg.dot(fwd)
    steer += clampf(in_steer - steer, -4.0 * dt, 4.0 * dt)
    throttle += clampf(in_throttle - throttle, -8.0 * dt, 6.0 * dt)
    brake += clampf(in_brake - brake, -8.0 * dt, 8.0 * dt)
    var lock: float = 0.55 / (1.0 + pow(absf(vlong) / 22.0, 2.0))
    var ds: float = steer * lock
    var per: float = _drive(dt, vlong) * 0.5
    # проход 1: лучи подвески
    for w in wheels:
        w.origin = sb.pos[w.mount] + up * H_TOP - right * (w.side * INSET)
        w.ray_len = w.free + R_TIRE
        if world.raycast(w.origin, -up, w.ray_len):
            w.dist = world.hit_dist
            w.n = world.hit_n
            w.comp = w.ray_len - w.dist
            w.grounded = w.comp > 0.0
        else:
            w.grounded = false
            w.comp = 0.0
    # проход 2: силы подвески и шин
    for w in wheels:
        if w.front:
            w.fw = fwd * cos(ds) + right * sin(ds)
            w.ax = right * cos(ds) - fwd * sin(ds)
        else:
            w.fw = fwd
            w.ax = right
        var drive_t: float = 0.0 if w.front else per
        var bt: float = brake_cmd * (1500.0 if w.front else 900.0)
        if not w.front:
            bt = maxf(bt, in_hand * 1800.0)
        if not w.grounded:
            w.fz = 0.0
            w.omega += drive_t / I_WHEEL * dt
            w.omega = signf(w.omega) * maxf(0.0, absf(w.omega) - bt * dt / I_WHEEL)
            w.spin += w.omega * dt
            continue
        if tc:
            var lim: float = 0.9 * MU0 * w.fz * R_TIRE
            drive_t = clampf(drive_t, -lim, lim)
        var m: int = w.mount
        var vm: Vector3 = sb.vel[m]
        var cv: float = vm.dot(-up)
        var fz: float = K_SPRING * w.comp + (C_BUMP if cv > 0.0 else C_REB) * cv
        if w.comp > BUMP_START:
            fz += K_BUMP * (w.comp - BUMP_START)
        if w.other.grounded:
            fz += (K_ARB_F if w.front else K_ARB_R) * (w.comp - w.other.comp)
        fz = maxf(fz, 0.0)
        w.fz = fz
        var n: Vector3 = w.n
        var fwd_g: Vector3 = (w.fw - n * w.fw.dot(n)).normalized()
        var right_g: Vector3 = fwd_g.cross(n).normalized()
        var vl: float = vm.dot(fwd_g)
        var vt: float = vm.dot(right_g)
        var ref_x: float = maxf(0.4, 0.10 * absf(vl))
        var ref_y: float = maxf(0.5, 0.12 * absf(vl))
        var slip: float = w.omega * R_TIRE - vl
        var f0: Vector2 = _tire(fz, MU0, slip, vt, ref_x, ref_y)
        var f1: Vector2 = _tire(fz, MU0, slip + 0.1, vt, ref_x, ref_y)
        var kk: float = maxf(0.0, (f1.x - f0.x) / 0.1)
        w.omega += (drive_t - R_TIRE * f0.x) / (I_WHEEL / dt + R_TIRE * R_TIRE * kk)
        w.omega = signf(w.omega) * maxf(0.0, absf(w.omega) - bt * dt / I_WHEEL)
        w.spin += w.omega * dt
        var fx: float = f0.x
        var fy: float = f0.y
        if fx * vl < 0.0:
            fx = signf(fx) * minf(absf(fx), 0.8 * MEFF * absf(vl) / dt)
        fy = signf(fy) * minf(absf(fy), 0.8 * MEFF * absf(vt) / dt)
        fx -= signf(vl) * minf(0.012 * fz, 0.8 * MEFF * absf(vl) / dt)
        sb.ext[m] = sb.ext[m] + n * fz + fwd_g * fx + right_g * fy
    # аэродинамическое сопротивление
    var fd: Vector3 = vcg * (-0.42 * speed)
    for i in range(sb.pos.size()):
        sb.ext[i] = sb.ext[i] + fd * (sb.mass[i] / total_mass)
    sb.step(dt, world)


func _update_status(dt: float) -> void:
    var crush: float = front_len0 - sb.pos[n_front].distance_to(sb.pos[n_front2])
    if crush > 0.30:
        radiator_dead = true
    if radiator_dead:
        coolant = maxf(0.0, coolant - 0.03 * dt)
    var power: float = throttle * rpm / REDLINE
    var heat: float = 0.5 + 3.5 * power
    var cool: float = (temp - 20.0) * (0.012 + 0.0004 * speed) * coolant * (1.0 + maxf(0.0, temp - 85.0) * 0.08)
    temp += (heat - cool) * dt
    if temp > 135.0:
        engine_dead = true


func _tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, col: Color) -> void:
    var g: Vector3 = (c - a).cross(b - a)
    if g.dot(out) < 0.0:
        var t: Vector3 = b
        b = c
        c = t
        g = -g
    var n: Vector3 = g.normalized()
    _va.append(a)
    _va.append(b)
    _va.append(c)
    for _i in range(3):
        _na.append(n)
        _ca.append(col)


func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, out: Vector3, col: Color) -> void:
    _tri(p0, p1, p2, out, col)
    _tri(p0, p2, p3, out, col)


func _update_visuals() -> void:
    for w in wheels:
        var drop: float = w.free
        if w.grounded:
            drop = w.dist - R_TIRE
        var hub: Vector3 = w.origin - up * drop
        var b0 := Basis(w.fw, w.ax, w.
