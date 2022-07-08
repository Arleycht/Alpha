class_name EnvironmentManager
extends WorldEnvironment


@export var angle := 70.0
@export var time := 7.0
@export_node_path(WorldEnvironment) var environment_path

var _sun: DirectionalLight3D


func _ready() -> void:
	_sun = get_node("Sun") as DirectionalLight3D


func _physics_process(_delta: float) -> void:
	time = wrapf(time, 0, 24)
	
	var t := time * PI / 12
	_sun.transform.basis = Basis.from_euler(Vector3(deg2rad(angle), t, 0), Basis.EULER_ORDER_XYZ)
	_sun.light_energy = clampf(_sun.transform.basis.z.y, 0, 1)
