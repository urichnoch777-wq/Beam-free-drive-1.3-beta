extends RefCounted
## Загрузка подготовленных моделей (.bin): позиции, нормали, цвета, индексы.

static var _cache := {}


static func load_meshes(path: String) -> Array:
    if _cache.has(path):
        return _cache[path]
    var out: Array = []
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        push_warning("Model file not found: " + path)
        return out
    var count: int = f.get_32()
    for _m in range(count):
        var nv: int = f.get_32()
        var ni: int = f.get_32()
        var pf: PackedFloat32Array = f.get_buffer(nv * 12).to_float32_array()
        var nf: PackedFloat32Array = f.get_buffer(nv * 12).to_float32_array()
        var cf: PackedFloat32Array = f.get_buffer(nv * 16).to_float32_array()
        var idx: PackedInt32Array = f.get_buffer(ni * 4).to_int32_array()
        var pos := PackedVector3Array()
        var nrm := PackedVector3Array()
        var col := PackedColorArray()
        pos.resize(nv)
        nrm.resize(nv)
        col.resize(nv)
        for i in range(nv):
            pos[i] = Vector3(pf[i * 3], pf[i * 3 + 1], pf[i * 3 + 2])
            nrm[i] = Vector3(nf[i * 3], nf[i * 3 + 1], nf[i * 3 + 2])
            col[i] = Color(cf[i * 4], cf[i * 4 + 1], cf[i * 4 + 2], cf[i * 4 + 3])
        var arr := []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = pos
        arr[Mesh.ARRAY_NORMAL] = nrm
        arr[Mesh.ARRAY_COLOR] = col
        arr[Mesh.ARRAY_INDEX] = idx
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
        out.append(mesh)
    _cache[path] = out
    return out
