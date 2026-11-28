extends RefCounted
## Список машин. Новые модели добавляются сюда.


static func list() -> Array:
    return [
        {
            "id": "mustang",
            "name": "Ford Mustang 2025",
            "info": "V8 5.0 · 1750 кг · задний привод",
            "model": "res://models/mustang_body.bin",
            "wheels": "res://models/mustang_wheels.bin",
            "mass": 1750.0,
            "st_z": [-2.311, -1.401, -0.85, 0.10, 0.90, 1.435, 1.95, 2.517],
            "st_top": [0.90, 1.06, 1.10, 1.46, 1.46, 1.31, 1.17, 1.17],
            "st_floor": [0.30, 0.22, 0.22, 0.22, 0.22, 0.22, 0.24, 0.34],
            "st_wt": [0.80, 1.04, 1.05, 0.79, 0.78, 0.88, 0.97, 0.80],
            "wf": 1.08,
            "inset": 0.137,
            "r_tire": 0.386,
            "i_wheel": 2.2,
            "rpms": [0, 800, 1500, 2500, 3500, 4500, 5500, 6500, 7000, 7500],
            "tqs": [0, 300, 420, 500, 540, 565, 560, 520, 420, 0],
            "gears": [3.5, 2.2, 1.55, 1.2, 0.95, 0.78],
            "final": 3.3,
            "redline": 7000.0,
            "idle": 800.0,
            "vmax": 69.0,
            "turbo": 0.0,
        },
        {
            "id": "sedan",
            "name": "Седан (базовый)",
            "info": "Турбо 2.0 · 1230 кг · задний привод",
        },
    ]


static func get_spec(i: int) -> Dictionary:
    var l: Array = list()
    return l[clampi(i, 0, l.size() - 1)]
