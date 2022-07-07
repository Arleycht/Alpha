class_name EnvironmentManager
extends WorldEnvironment


signal time_changed

@export var angle := 70.0
@export var time := 7.0:
	set(value):
		time_changed.emit(value)
@export var time_scale := 1.0 / 60.0
@export_node_path(WorldEnvironment) var environment_path

var _sun: DirectionalLight3D


func _ready() -> void:
	_sun = get_node("Sun") as DirectionalLight3D
	time_changed.connect(_update)


func _update(delta: float) -> void:
	var t := time * PI / 12
	
	_sun.transform.basis = Basis.from_euler(Vector3(deg2rad(angle), t, 0), Basis.EULER_ORDER_XYZ)
	_sun.light_energy = clampf(_sun.transform.basis.z.y, 0, 1)
	
	time = wrapf(time + delta * time_scale, 0, 24)
