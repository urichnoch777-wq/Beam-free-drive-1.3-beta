extends RefCounted
## Мир: плоскость земли (y=0) и ящики (стены, трамплины). Столкновения и лучи колёс.

var boxes: Array = []
var out_p := Vector3.ZERO
var out_v := Vector3.ZERO
var hit_dist := 0.0
var hit_n := Vector3.UP


func add_box(xf: Transform3D, size: Vector3) -> void:
    var h: Vector3 = size * 0.5
    boxes.append({"xf": xf, "inv": xf.affine_inverse(), "h": h, "c": xf.origin, "r2": h.length_squared() + 1.0})


func _resolve(v: Vector3, n: Vector3, mu: float) -> Vector3:
    var vn: float = v.dot(n)
    if vn >= 0.0:
        return v
    v -= n * vn
    var sp: float = v.length()
    if sp > 0.00001:
        v *= maxf(0.0, sp + mu * vn) / sp
    return v


func collide(p: Vector3, v: Vector3, r: float, mu: float) -> void:
    if p.y < r:
        p.y = r
        v = _resolve(v, Vector3.UP, mu)
    for bx in boxes:
        if p.distance_squared_to(bx["c"]) > bx["r2"]:
            continue
        var xf: Transform3D = bx["xf"]
        var h: Vector3 = bx["h"]
        var lp: Vector3 = (bx["inv"] as Transform3D) * p
        var pen := Vector3(h.x + r - absf(lp.x), h.y + r - absf(lp.y), h.z + r - absf(lp.z))
        if pen.x > 0.0 and pen.y > 0.0 and pen.z > 0.0:
            var nl := Vector3.ZERO
            var depth: float
            if pen.x <= pen.y and pen.x <= pen.z:
                nl.x = 1.0 if lp.x >= 0.0 else -1.0
                depth = pen.x
            elif pen.y <= pen.z:
                nl.y = 1.0 if lp.y >= 0.0 else -1.0
                depth = pen.y
            else:
                nl.z = 1.0 if lp.z >= 0.0 else -1.0
                depth = pen.z
            var n: Vector3 = xf.basis * nl
            p += n * depth
            v = _resolve(v, n, mu)
    out_p = p
    out_v = v


## Луч из o по направлению d. Результат: hit_dist, hit_n.
func raycast(o: Vector3, d: Vector3, max_len: float) -> bool:
    var best: float = max_len + 1.0
    var found := false
    if d.y < -0.00001:
        var t0: float = -o.y / d.y
        if t0 >= 0.0 and t0 <= max_len:
            best = t0
            hit_n = Vector3.UP
            found = true
    for bx in boxes:
        var inv: Transform3D = bx["inv"]
        var h: Vector3 = bx["h"]
        var lo: Vector3 = inv * o
        var ld: Vector3 = inv.basis * d
        var tmin := -1.0e9
        var tmax := 1.0e9
        var ax := -1
        var sg := 0.0
        var ok := true
        for i in range(3):
            if absf(ld[i]) < 0.000001:
                if absf(lo[i]) > h[i]:
                    ok = false
                    break
            else:
                var t1: float = (-h[i] - lo[i]) / ld[i]
                var t2: float = (h[i] - lo[i]) / ld[i]
                if t1 > t2:
                    var tmp: float = t1
                    t1 = t2
                    t2 = tmp
                if t1 > tmin:
                    tmin = t1
                    ax = i
                    sg = -signf(ld[i])
                tmax = minf(tmax, t2)
        if ok and ax >= 0 and tmin <= tmax and tmin >= 0.0 and tmin < best and tmin <= max_len:
            var nl := Vector3.ZERO
            nl[ax] = sg
            best = tmin
            hit_n = (bx["xf"] as Transform3D).basis * nl
            found = true
    hit_dist = best
    return found
