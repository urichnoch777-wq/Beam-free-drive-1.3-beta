extends Node3D
## Рельеф (одна сетка высот для графики и коллизий) и статичные препятствия.

const X0 := -78.0
const X1 := 78.0
const Z0 := -282.0
const Z1 := 42.0
const CELL := 1.5
const NX := 104
const NZ := 216
## трамплины: x, z начала (едем к -Z), ширина, длина, высота
const RAMPS := [[-14.0, -40.0, 10.0, 34.0, 3.0], [16.0, -95.0, 10.0, 40.0, 4.5], [-10.0, -150.0, 12.0, 50.0, 6.0], [0.0, -215.0, 12.0, 60.0, 7.0]]

var hgrid := PackedFloat32Array()
var bxs := PackedFloat32Array()  # по 6 чисел на коробку: x0 x1 y0 y1 z0 z1
var nbox := 0


static func sm(a: float, b: float, x: float) -> float:
    var t := clampf((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


static func raw_height(x: float, z: float) -> float:
    var h := sm(20.0, 70.0, Vector2(x, z).length()) * (2.2 * sin(x * 0.03 + 1.0) * cos(z * 0.027) + 1.1 * sin(z * 0.08 + x * 0.05))
    for r in RAMPS:
        var u: float = (r[1] - z) / r[3]
        if u > 0.0 and u < 1.0:
            h += u * r[4] * sm(0.0, 1.5, r[2] * 0.5 - absf(x - r[0]))
    return h


## Возвращает Vector4: xyz = нормаль, w = высота.
func sample(x: float, z: float) -> Vector4:
    var fx := clampf((x - X0) / CELL, 0.0, NX - 0.001)
    var fz := clampf((z - Z0) / CELL, 0.0, NZ - 0.001)
    var ix := int(fx)
    var iz := int(fz)
    var tx := fx - ix
    var tz := fz - iz
    var i := iz * (NX + 1) + ix
    var h00 := hgrid[i]
    var h10 := hgrid[i + 1]
    var h01 := hgrid[i + NX + 1]
    var h11 := hgrid[i + NX + 2]
    var gx := lerpf(h10 - h00, h11 - h01, tz) / CELL
    var gz := lerpf(h01 - h00, h11 - h10, tx) / CELL
    var nl := sqrt(gx * gx + gz * gz + 1.0)
    return Vector4(-gx / nl, 1.0 / nl, -gz / nl, lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz))


func add_box(cx: float, cz: float, sx: float, sy: float, sz: float, col: Color, by: float = NAN) -> void:
    var emb := is_nan(by)
    var y0: float = sample(cx, cz).w - 2.0 if emb else by
    var y1: float = y0 + (2.0 + sy if emb else sy)
    bxs.append_array(PackedFloat32Array([cx - sx / 2.0, cx + sx / 2.0, y0, y1, cz - sz / 2.0, cz + sz / 2.0]))
    nbox += 1
    var bm := BoxMesh.new()
    bm.size = Vector3(sx, y1 - y0, sz)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    var mi := MeshInstance3D.new()
    mi.mesh = bm
    mi.material_override = mat
    mi.position = Vector3(cx, (y0 + y1) / 2.0, cz)
    add_child(mi)


func _ready() -> void:
    var cnt := (NX + 1) * (NZ + 1)
    hgrid.resize(cnt)
    for iz in NZ + 1:
        for ix in NX + 1:
            hgrid[iz * (NX + 1) + ix] = raw_height(X0 + ix * CELL, Z0 + iz * CELL)
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    verts.resize(cnt)
    norms.resize(cnt)
    cols.resize(cnt)
    for iz in NZ + 1:
        for ix in NX + 1:
            var x := X0 + ix * CELL
            var z := Z0 + iz * CELL
            var s := sample(x, z)
            var k := iz * (NX + 1) + ix
            verts[k] = Vector3(x, s.w, z)
            norms[k] = Vector3(s.x, s.y, s.z)
            var t := clampf((1.0 - s.y) * 7.0, 0.0, 1.0)
            var v := 0.85 + 0.15 * sin(x * 0.7) * cos(z * 0.6)
            cols[k] = Color((0.32 + 0.3 * t) * v, (0.58 - 0.1 * t) * v, (0.28 + 0.05 * t) * v)
    var idx := PackedInt32Array()
    for iz in NZ:
        for ix in NX:
            var a := iz * (NX + 1) + ix
            idx.append_array(PackedInt32Array([a, a + 1, a + NX + 1, a + 1, a + NX + 2, a + NX + 1]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 1.0
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    add_child(mi)
    # препятствия
    add_box(0.0, -70.0, 16.0, 3.0, 1.0, Color(0.6, 0.63, 0.65))
    add_box(10.0, -190.0, 14.0, 3.0, 1.0, Color(0.6, 0.63, 0.65))
    for i in 5:
        add_box(-14.0 + i * 7.0, -125.0, 3.0, 1.6, 3.0, Color(0.55, 0.57, 0.6))
    var g0 := sample(30.0, -100.0).w - 0.5
    for r in 4:
        for c in 4 - r:
            add_box(30.0 + (c - (3 - r) / 2.0) * 2.1, -100.0, 2.0, 2.0, 2.0, Color(0.72, 0.54, 0.3), g0 + r * 2.0)
