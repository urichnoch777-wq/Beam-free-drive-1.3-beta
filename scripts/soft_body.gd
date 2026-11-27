extends RefCounted
## Мягкое тело: узлы и балки с упругостью, пластической деформацией и разрывом.

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var ext := PackedVector3Array()       # внешние силы на ближайший шаг
var mass := PackedFloat32Array()
var inv_mass := PackedFloat32Array()
var ba := PackedInt32Array()
var bb := PackedInt32Array()
var k := PackedFloat32Array()
var c := PackedFloat32Array()
var len0 := PackedFloat32Array()      # длина покоя (меняется при деформации)
var len_init := PackedFloat32Array()
var y_t := PackedFloat32Array()       # предел текучести при растяжении, Н
var y_c := PackedFloat32Array()       # при сжатии
var brk := PackedFloat32Array()       # во сколько раз можно растянуть до разрыва
var alive := PackedByteArray()
var node_radius := 0.06


func add_node(p: Vector3, m: float) -> int:
    pos.append(p)
    vel.append(Vector3.ZERO)
    ext.append(Vector3.ZERO)
    mass.append(m)
    inv_mass.append(1.0 / m)
    return pos.size() - 1


func add_beam(a: int, b: int, stiff: float, yield_n: float, brk_ratio: float) -> void:
    var l: float = pos[a].distance_to(pos[b])
    ba.append(a)
    bb.append(b)
    k.append(stiff)
    len0.append(l)
    len_init.append(l)
    y_t.append(yield_n)
    y_c.append(yield_n * 0.7)
    brk.append(brk_ratio)
    alive.append(1)
    c.append(0.16 * sqrt(stiff * minf(mass[a], mass[b])))


func step(dt: float, world) -> void:
    var n: int = pos.size()
    var fn := PackedVector3Array()
    fn.resize(n)
    for i in range(ba.size()):
        if alive[i] == 0:
            continue
        var a: int = ba[i]
        var b: int = bb[i]
        var d: Vector3 = pos[b] - pos[a]
        var l: float = d.length()
        if l < 0.0001:
            continue
        var dir: Vector3 = d / l
        var kk: float = k[i]
        var fs: float = kk * (l - len0[i])
        if fs > y_t[i]:
            len0[i] = l - y_t[i] / kk
            fs = y_t[i]
        elif fs < -y_c[i]:
            len0[i] = l + y_c[i] / kk
            fs = -y_c[i]
        if l > len_init[i] * brk[i]:
            alive[i] = 0
            continue
        var lmin: float = 0.45 * len_init[i]
        if l < lmin:
            fs += 5.0 * kk * (l - lmin)
        var f: Vector3 = dir * (fs + c[i] * (vel[b] - vel[a]).dot(dir))
        fn[a] = fn[a] + f
        fn[b] = fn[b] - f
    for i in range(n):
        var v: Vector3 = vel[i] + ((fn[i] + ext[i]) * inv_mass[i] + Vector3(0, -9.81, 0)) * dt
        var p: Vector3 = pos[i] + v * dt
        ext[i] = Vector3.ZERO
        world.collide(p, v, node_radius, 0.55)
        pos[i] = world.out_p
        vel[i] = world.out_v
