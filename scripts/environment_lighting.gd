extends Node3D


@export var angle := 70.0
@export var time := 7.0
@export var time_scale := 1.0 / 60.0
@export_node_path(WorldEnvironment) var environment_path
@export_node_path(DirectionalLight3D) var sun_path

var _environment: WorldEnvironment
var _sun: DirectionalLight3D


func _ready() -> void:
	_environment = get_node(environment_path) as WorldEnvironment
	_sun = get_node(sun_path) as DirectionalLight3D


func _physics_process(delta: float) -> void:
	var t := time * PI / 12
	
	_sun.transform.basis = Basis.from_euler(Vector3(deg2rad(angle), t, 0), Basis.EULER_ORDER_XYZ)
	_sun.light_energy = clampf(_sun.transform.basis.z.y, 0, 1)
	
	time = wrapf(time + delta * time_scale, 0, 24)
