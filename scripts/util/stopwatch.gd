class_name Stopwatch


var watches := []
var times := []

var _i = 0


func _init() -> void:
	clear()


func start(lap_name: String = "") -> void:
	if lap_name == null or lap_name.length() < 1:
		lap_name = "Lap %d" % _i
	
	watches.append([lap_name, Time.get_ticks_usec()])
	_i += 1


func stop() -> void:
	var w = watches.pop_back()
	w[1] = Time.get_ticks_usec() - w[1]
	times.append(w)


func clear() -> void:
	times.clear()


func print_times() -> void:
	if times.size() < 1:
		print("No times recorded")
		return
	
	for t in times:
		print("%s: %.06f s (%d us)" % [t[0], t[1] / 1e6, t[1]])


func print_average() -> void:
	if times.size() < 1:
		print("No times recorded")
		return
	
	var average: float = 0
	
	for t in times:
		average += t[1]
	
	average /= float(times.size())
	
	print("Average times: %.06f s (%.02f us)" % [average / 1e6, average])
