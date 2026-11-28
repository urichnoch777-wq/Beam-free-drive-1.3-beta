extends Node
## Настройки игры (сохраняются в user://settings.cfg)

const PATH := "user://settings.cfg"
var control_mode := 0       # 0 стрелки, 1 руль, 2 наклон
var tilt_sens := 1.0
var tilt_invert := false
var car_id := 0


func _ready() -> void:
    var cf := ConfigFile.new()
    if cf.load(PATH) == OK:
        control_mode = int(cf.get_value("controls", "mode", 0))
        tilt_sens = float(cf.get_value("controls", "tilt_sens", 1.0))
        tilt_invert = bool(cf.get_value("controls", "tilt_invert", false))
        car_id = int(cf.get_value("game", "car_id", 0))


func save() -> void:
    var cf := ConfigFile.new()
    cf.set_value("controls", "mode", control_mode)
    cf.set_value("controls", "tilt_sens", tilt_sens)
    cf.set_value("controls", "tilt_invert", tilt_invert)
    cf.set_value("game", "car_id", car_id)
    cf.save(PATH)
