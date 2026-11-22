extends Node3D
## Мягкая 3D-машина: решётка 6x3x2 узлов, балки = пружины с пластической деформацией
## (beamDeform) и разрывом (beamStrength). Решатель PBD. Колёса: рейкаст-подвеска.

const WorldScript := preload("res://scripts/world.gd")

const DT := 1.0 / 300.0   # 5 подшагов на тик физики 60 Гц
const IT := 4             # итераций решателя на подшаг
const G := 9.81
const L0 := 0.39          # длина подвески от узла до низа колеса
const WR := 0.34          # радиус колеса
const KS := 550.0         # жёсткость пружины подвески
const CD := 55.0          # демпфирование подвески
const AD := 26.0          # тяга
const VMAX := 28.0        # макс. скорость, м/с
const GRIP := 0.06
const GCAP := 49.0 * DT
const RN := 0.12          # радиус узла
const MU := 0.5           # трение узлов
const NN := 36
const COLX := [0.0, 0.9, 1.5, 2.5, 3.1, 4.0]
const TOPY := [0.62, 0.66, 1.2, 1.2, 0.8, 0.7]

var world: WorldScript
var throttle := 0.0
var steer_in := 0.0
var steer := 0.0
var spin := 0.0
var show_beams := true
var fwd := Vector3(0.0, 0.0, -1.0)
var up := Vector3.UP
var right := Vector3.RIGHT
var center := Vector3.ZERO
var vel := Vector3.ZERO
var speed := 0.0
var kb := 1.0 - pow(0.1, 1.0 / IT)

var pos := PackedVector3Array()
var prv := PackedVector3Array()
var w := PackedFloat32Array()
var ni := PackedInt32Array()
var nj := PackedInt32Array()
var nk := PackedInt32Array()
var ba := PackedInt32Array()
var bb := PackedInt32Array()
var bl := PackedFloat32Array()
var bl0 := PackedFloat32Array()
var bdf := PackedFloat32Array()
var bdf0 := PackedFloat32Array()
var bbr := PackedFloat32Array()
var dead := PackedByteArray()
var nbeams := 0

var wa := PackedInt32Array([6, 7, 24, 25])
var wb := PackedInt32Array([8, 9, 26, 27])
var wf := PackedInt32Array([0, 0, 1, 1])
var ws := PackedFloat32Array([-1.0, 1.0, -1.0, 1.0])
var wd := PackedFloat32Array([L0, L0, L0, L0])

var body_tris := PackedInt32Array()
var glass_tris := PackedInt32Array()
var im_body := ImmediateMesh.new()
var im_lines := ImmediateMesh.new()
var mat_body := StandardMaterial3D.new()
var mat_glass := StandardMaterial3D.new()
var mat_lines := StandardMaterial3D.new()
var wheels: Array[MeshInstance3D] = []


func _id(i: int, j: int, k: int) -> int:
    return (i * 3 + j) * 2 + k


func _ready() -> void:
    pos.resize(NN)
    prv.resize(NN)
    w.resize(NN)
    ni.resize(NN)
    nj.resize(NN)
    nk.resize(NN)
    for i in 6:
        for j in 3:
            for k in 2:
                var n := _id(i, j, k)
                ni[n] = i
                nj[n] = j
                nk[n] = k
                w[n] = 0.5 if i > 3 else 1.0
    build(0.0, 0.0)
    _make_beams()
    _build_faces()
    _make_visuals()
    set_beams(true)


## Поставить новую целую машину в точку (ox, oz).
func build(ox: float, oz: float) -> void:
    ox = clampf(ox, WorldScript.X0 + 4.0, WorldScript.X1 - 4.0)
    oz = clampf(oz, WorldScript.Z0 + 6.0, WorldScript.Z1 - 6.0)
    var oy: float = world.sample(ox, oz).w + 0.9
    for i in 6:
        for j in 3:
            for k in 2:
                var n := _id(i, j, k)
                var ly := 0.0
                if j == 1:
                    ly = 0.42
                elif j == 2:
                    ly = TOPY[i]
                var lx: float = COLX[i] - 2.0
                var lz := 0.8 if k == 1 else -0.8
                var p := Vector3(ox + lz, oy + ly, oz - lx)
                pos[n] = p
                prv[n] = p
    for q in nbeams:
        bl[q] = bl0[q]
        bdf[q] = bdf0[q]
        dead[q] = 0
    steer = 0.0
    update_axes()


func _make_beams() -> void:
    for a in NN:
        for b in range(a + 1, NN):
            var di := absi(ni[a] - ni[b])
            var dj := absi(nj[a] - nj[b])
            var dk := absi(nk[a] - nk[b])
            if di > 1 or dj > 1 or dk > 1 or di + dj + dk == 3:
                continue
            var l := (pos[a] - pos[b]).length()
            var m: float = (COLX[ni[a]] + COLX[ni[b]]) * 0.5
            var crumple: bool = m < 1.0 or m > 3.0
            var df := 0.03 if crumple else 0.06
            ba.append(a)
            bb.append(b)
            bl.append(l)
            bl0.append(l)
            bdf.append(df)
            bdf0.append(df)
            bbr.append(0.3 if crumple else 0.4)
            dead.append(0)
    nbeams = ba.size()


func _quad(gl: bool, a: int, b: int, c: int, d: int) -> void:
    if gl:
        glass_tris.append_array(PackedInt32Array([a, b, c, a, c, d]))
    else:
        body_tris.append_array(PackedInt32Array([a, b, c, a, c, d]))


func _build_faces() -> void:
    for i in 5:
        for j in 2:
            var gl: bool = j == 1 and i > 0 and i < 4
            _quad(gl, _id(i, j, 1), _id(i + 1, j, 1), _id(i + 1, j + 1, 1), _id(i, j + 1, 1))
            _quad(gl, _id(i, j, 0), _id(i, j + 1, 0), _id(i + 1, j + 1, 0), _id(i + 1, j, 0))
        var gt: bool = i == 1 or i == 3
        _quad(gt, _id(i, 2, 0), _id(i, 2, 1), _id(i + 1, 2, 1), _id(i + 1, 2, 0))
        _quad(false, _id(i, 0, 0), _id(i + 1, 0, 0), _id(i + 1, 0, 1), _id(i, 0, 1))
    for j in 2:
        _quad(false, _id(5, j, 0), _id(5, j + 1, 0), _id(5, j + 1, 1), _id(5, j, 1))
        _quad(false, _id(0, j, 0), _id(0, j, 1), _id(0, j + 1, 1), _id(0, j + 1, 0))


func _make_visuals() -> void:
    mat_body.albedo_color = Color(0.85, 0.27, 0.23)
    mat_body.roughness = 0.6
    mat_body.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat_glass.albedo_color = Color(0.62, 0.82, 1.0, 0.7)
    mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat_lines.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_lines.vertex_color_use_as_albedo = true
    var mb := MeshInstance3D.new()
    mb.mesh = im_body
    add_child(mb)
    var ml := MeshInstance3D.new()
    ml.mesh = im_lines
    add_child(ml)
    var tire_mat := StandardMaterial3D.new()
    tire_mat.albedo_color = Color(0.1, 0.1, 0.12)
    var rim_mat := StandardMaterial3D.new()
    rim_mat.albedo_color = Color(0.8, 0.82, 0.85)
    var cyl := CylinderMesh.new()
    cyl.top_radius = WR
    cyl.bottom_radius = WR
    cyl.height = 0.26
    cyl.radial_segments = 20
    cyl.rings = 1
    var spoke := BoxMesh.new()
    spoke.size = Vector3(0.6, 0.28, 0.07)
    for q in 4:
        var m := MeshInstance3D.new()
        m.mesh = cyl
        m.material_override = tire_mat
        add_child(m)
        for r in 2:
            var s := MeshInstance3D.new()
            s.mesh = spoke
            s.material_override = rim_mat
            s.rotation.y = r * PI / 2.0
            m.add_child(s)
        wheels.append(m)


func set_beams(v: bool) -> void:
    show_beams = v
    mat_body.albedo_color.a = 0.4 if v else 1.0
    mat_body.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if v else BaseMaterial3D.TRANSPARENCY_DISABLED


func update_axes() -> void:
    var fa := Vector3.ZERO
    var ra := Vector3.ZERO
    var ta := Vector3.ZERO
    var bt := Vector3.ZERO
    var c := Vector3.ZERO
    var v := Vector3.ZERO
    var nf := 0.0
    var nr := 0.0
    var nt := 0.0
    var nb := 0.0
    for n in NN:
        var p: Vector3 = pos[n]
        c += p
        v += p - prv[n]
        if ni[n] > 3:
            fa += p
            nf += 1.0
        if ni[n] < 2:
            ra += p
            nr += 1.0
        if nj[n] == 2:
            ta += p
            nt += 1.0
        if nj[n] == 0:
            bt += p
            nb += 1.0
    fwd = (fa / nf - ra / nr).normalized()
    var u := ta / nt - bt / nb
    up = (u - fwd * u.dot(fwd)).normalized()
    right = fwd.cross(up)
    center = c / float(NN)
    vel = v / float(NN) / DT
    speed = vel.length()


func damage_percent() -> int:
    var d := 0.0
    for q in nbeams:
        d += 1.0 if dead[q] == 1 else minf(1.0, absf(bl[q] / bl0[q] - 1.0) * 2.0)
    return mini(100, roundi(d / nbeams * 600.0))


func _physics_process(delta: float) -> void:
    steer += ((steer_in * 0.5 / (1.0 + speed / 12.0)) - steer) * minf(1.0, delta * 8.0)
    update_axes()
    for i in clampi(roundi(delta / DT), 1, 10):
        _step()
    update_axes()
    spin -= vel.dot(fwd) * delta / WR


func _step() -> void:
    var g := G * DT * DT
    for n in NN:
        var p: Vector3 = pos[n]
        var v: Vector3 = (p - prv[n]) * 0.9998
        prv[n] = p
        pos[n] = p + v + Vector3(0.0, -g, 0.0)
    _wheels()
    for it in IT:
        for q in nbeams:
            if dead[q] == 1:
                continue
            var a: int = ba[q]
            var b: int = bb[q]
            var pa: Vector3 = pos[a]
            var pb: Vector3 = pos[b]
            var d := pb - pa
            var dist := d.length()
            if dist < 0.000001:
                continue
            if it == 0:
                var s: float = (dist - bl[q]) / bl[q]
                var df: float = bdf[q]
                if s > df or s < -df:
                    if absf(s) > bbr[q]:
                        dead[q] = 1
                        continue
                    var e: float = s - df if s > 0.0 else s + df
                    var nl: float = maxf(bl0[q] * 0.4, bl[q] * (1.0 + e))
                    bl[q] = nl
                    bdf[q] = minf(bdf0[q] * 2.0, df * 1.02)
                    if absf(nl / bl0[q] - 1.0) > 0.5:
                        dead[q] = 1
                        continue
            var f: float = (dist - bl[q]) / dist * kb / (w[a] + w[b])
            var c := d * f
            pos[a] = pa + c * w[a]
            pos[b] = pb - c * w[b]
    for n in NN:
        _collide(n)


func _ground(p: Vector3) -> float:
    var h: float = world.sample(p.x, p.z).w
    var bx := world.bxs
    for q in world.nbox:
        var o := q * 6
        if p.x > bx[o] and p.x < bx[o + 1] and p.z > bx[o + 4] and p.z < bx[o + 5] and p.y > bx[o + 3] - 0.3 and bx[o + 3] > h:
            h = bx[o + 3]
    return h


## Подвеска + тяга + боковое сцепление колёс.
func _wheels() -> void:
    for wi in 4:
        var a: int = wa[wi]
        var b: int = wb[wi]
        var pa: Vector3 = pos[a]
        var d: float = (pa.y - _ground(pa)) / maxf(0.5, up.y)
        wd[wi] = d
        var x := L0 - d
        if x <= 0.0:
            continue
        var v: Vector3 = (pa - prv[a]) / DT
        var ld := minf(1.0, x / 0.1)
        var sp := minf(160.0, maxf(0.0, KS * x - CD * v.dot(up))) * DT * DT
        var co := cos(steer) if wf[wi] == 1 else 1.0
        var si := sin(steer) if wf[wi] == 1 else 0.0
        var f := fwd * co + right * si
        var l := right * co - fwd * si
        var vl := v.dot(f)
        var vt := v.dot(l)
        var dl := clampf(-vt * GRIP, -GCAP, GCAP) * ld * DT
        var dv := 0.0
        var ac := 0.0
        if throttle > 0.0:
            if vl < VMAX:
                ac = AD
        elif throttle < 0.0:
            if vl > 1.0:
                dv = -minf(vl, 40.0 * DT)
            elif vl > -9.0:
                ac = -AD * 0.6
        else:
            dv = -vl * 0.002
        var dpos := up * sp + f * (ac * ld * DT * DT)
        var dprv := l * dl + f * (dv * ld * DT)
        pos[a] += dpos
        pos[b] += dpos
        prv[a] -= dprv
        prv[b] -= dprv


## Контакт узла: вытолкнуть наружу + трение Кулона (по глубине проникновения).
func _push(n: int, nr: Vector3, d: float) -> void:
    var p: Vector3 = pos[n] + nr * d
    var v: Vector3 = p - prv[n]
    v -= nr * v.dot(nr)
    var t := v.length()
    var k := 0.0 if t < 0.000000001 else maxf(0.0, t - MU * d) / t
    pos[n] = p
    prv[n] = p - v * k


func _collide(n: int) -> void:
    var p: Vector3 = pos[n]
    var cp := Vector3(clampf(p.x, WorldScript.X0, WorldScript.X1), p.y, clampf(p.z, WorldScript.Z0, WorldScript.Z1))
    if cp != p:
        pos[n] = cp
        p = cp
    var s4: Vector4 = world.sample(p.x, p.z)
    var nr := Vector3(s4.x, s4.y, s4.z)
    var sd := (p.y - s4.w) * nr.y
    if sd < RN:
        _push(n, nr, RN - sd)
    var bx := world.bxs
    for q in world.nbox:
        var o := q * 6
        if p.x < bx[o] - RN or p.x > bx[o + 1] + RN or p.y < bx[o + 2] - RN or p.y > bx[o + 3] + RN or p.z < bx[o + 4] - RN or p.z > bx[o + 5] + RN:
            continue
        var pen := [p.x - bx[o] + RN, bx[o + 1] + RN - p.x, p.y - bx[o + 2] + RN, bx[o + 3] + RN - p.y, p.z - bx[o + 4] + RN, bx[o + 5] + RN - p.z]
        var m := 0
        for i in range(1, 6):
            if pen[i] < pen[m]:
                m = i
        var nb := Vector3.ZERO
        nb[m >> 1] = 1.0 if (m & 1) == 1 else -1.0
        _push(n, nb, pen[m])
        p = pos[n]


func _process(_delta: float) -> void:
    im_body.clear_surfaces()
    _emit(body_tris, mat_body)
    _emit(glass_tris, mat_glass)
    im_lines.clear_surfaces()
    if show_beams:
        im_lines.surface_begin(Mesh.PRIMITIVE_LINES, mat_lines)
        for q in nbeams:
            if dead[q] == 1:
                continue
            var r := clampf(absf(bl[q] / bl0[q] - 1.0) * 3.0, 0.0, 1.0)
            var c := Color.from_hsv((1.0 - r) * 0.36, 0.9, 1.0)
            im_lines.surface_set_color(c)
            im_lines.surface_add_vertex(pos[ba[q]])
            im_lines.surface_set_color(c)
            im_lines.surface_add_vertex(pos[bb[q]])
        im_lines.surface_end()
    for q in 4:
        var co := cos(steer) if wf[q] == 1 else 1.0
        var si := sin(steer) if wf[q] == 1 else 0.0
        var f := fwd * co + right * si
        var l := right * co - fwd * si
        var dd := minf(wd[q], L0) - WR
        var o: Vector3 = pos[wa[q]] - up * dd + right * (ws[q] * 0.14)
        var bs := Basis(f, l, -up) * Basis(Vector3.UP, spin)
        wheels[q].global_transform = Transform3D(bs, o)


## Кузов: плоские нормали, порядок вершин подбирается так, чтобы лицевая сторона смотрела наружу.
func _emit(tris: PackedInt32Array, mat: Material) -> void:
    im_body.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
    for t in range(0, tris.size(), 3):
        var pa: Vector3 = pos[tris[t]]
        var pb: Vector3 = pos[tris[t + 1]]
        var pc: Vector3 = pos[tris[t + 2]]
        var n := (pb - pa).cross(pc - pa)
        if n.dot((pa + pb + pc) / 3.0 - center) > 0.0:
            var tmp := pb
            pb = pc
            pc = tmp
        else:
            n = -n
        n = n.normalized()
        im_body.surface_set_normal(n)
        im_body.surface_add_vertex(pa)
        im_body.surface_set_normal(n)
        im_body.surface_add_vertex(pb)
        im_body.surface_set_normal(n)
        im_body.surface_add_vertex(pc)
    im_body.surface_end()
