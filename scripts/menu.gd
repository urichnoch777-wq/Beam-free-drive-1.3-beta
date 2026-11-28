extends Control
## Главное меню и настройки.

const CarSpecs = preload("res://scripts/car_specs.gd")
const DESCR := ["Кнопки-стрелки слева на экране", "Крути руль пальцем", "Наклоняй телефон как руль (кнопка CAL — калибровка)"]

var main_box: VBoxContainer
var set_box: VBoxContainer
var desc: Label
var car_box: VBoxContainer
var car_name: Label
var car_info: Label


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.07, 0.07, 0.08)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    main_box = _vbox(center)
    set_box = _vbox(center)
    car_box = _vbox(center)
    _label(main_box, "BEAM FREE DRIVE", 60)
    _button(main_box, "НАЧАТЬ ЗАЕЗД", _show_cars)
    _button(main_box, "НАСТРОЙКИ", _show_settings)
    _label(set_box, "НАСТРОЙКИ", 48)
    _label(set_box, "Управление", 30)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    set_box.add_child(row)
    var grp := ButtonGroup.new()
    var names := ["Стрелки", "Руль", "Наклон"]
    for i in range(3):
        var b := Button.new()
        b.text = names[i]
        b.toggle_mode = true
        b.button_group = grp
        b.button_pressed = (GameSettings.control_mode == i)
        b.custom_minimum_size = Vector2(150, 80)
        b.add_theme_font_size_override("font_size", 28)
        b.pressed.connect(_set_mode.bind(i))
        row.add_child(b)
    desc = _label(set_box, DESCR[GameSettings.control_mode], 24)
    _label(set_box, "Чувствительность наклона", 24)
    var sl := HSlider.new()
    sl.min_value = 0.5
    sl.max_value = 2.0
    sl.step = 0.1
    sl.value = GameSettings.tilt_sens
    sl.custom_minimum_size = Vector2(460, 50)
    sl.value_changed.connect(_set_sens)
    set_box.add_child(sl)
    var inv := CheckButton.new()
    inv.text = "Инвертировать наклон"
    inv.button_pressed = GameSettings.tilt_invert
    inv.add_theme_font_size_override("font_size", 26)
    inv.toggled.connect(_set_invert)
    set_box.add_child(inv)
    _button(set_box, "НАЗАД", _show_main)
    set_box.visible = false
    _label(car_box, "ВЫБОР МАШИНЫ", 48)
    var crow := HBoxContainer.new()
    crow.alignment = BoxContainer.ALIGNMENT_CENTER
    crow.add_theme_constant_override("separation", 16)
    car_box.add_child(crow)
    _small_btn(crow, "<", _cycle.bind(-1))
    car_name = Label.new()
    car_name.custom_minimum_size = Vector2(520, 90)
    car_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    car_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    car_name.add_theme_font_size_override("font_size", 38)
    crow.add_child(car_name)
    _small_btn(crow, ">", _cycle.bind(1))
    car_info = _label(car_box, "", 26)
    _button(car_box, "ИГРАТЬ", _play)
    _button(car_box, "НАЗАД", _show_main)
    car_box.visible = false
    _refresh_car()


func _small_btn(parent: Node, text: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(90, 90)
    b.add_theme_font_size_override("font_size", 40)
    b.pressed.connect(cb)
    parent.add_child(b)


func _cycle(d: int) -> void:
    var n: int = CarSpecs.list().size()
    GameSettings.car_id = (GameSettings.car_id + d + n) % n
    GameSettings.save()
    _refresh_car()


func _refresh_car() -> void:
    var sp: Dictionary = CarSpecs.get_spec(GameSettings.car_id)
    car_name.text = sp["name"]
    car_info.text = sp["info"]


func _show_cars() -> void:
    main_box.visible = false
    car_box.visible = true


func _vbox(parent: Node) -> VBoxContainer:
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 18)
    parent.add_child(v)
    return v


func _label(parent: Node, text: String, font_size: int) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", font_size)
    parent.add_child(l)
    return l


func _button(parent: Node, text: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(460, 88)
    b.add_theme_font_size_override("font_size", 34)
    b.pressed.connect(cb)
    parent.add_child(b)


func _play() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_settings() -> void:
    main_box.visible = false
    set_box.visible = true


func _show_main() -> void:
    set_box.visible = false
    car_box.visible = false
    main_box.visible = true


func _set_mode(i: int) -> void:
    GameSettings.control_mode = i
    GameSettings.save()
    desc.text = DESCR[i]


func _set_sens(v: float) -> void:
    GameSettings.tilt_sens = v
    GameSettings.save()


func _set_invert(on: bool) -> void:
    GameSettings.tilt_invert = on
    GameSettings.save()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if (set_box != null and set_box.visible) or (car_box != null and car_box.visible):
            _show_main()
        else:
            get_tree().quit()
