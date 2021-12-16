extends Node

class StopwatchFactoryEntry:
	extends Reference
	var name : String = ''
	var sw : Stopwatch = null
	
	func _init(sw_name, max_intervals, wrap):
		name = sw_name
		sw = Stopwatch.new(max_intervals, wrap)

var _stopwatches = []

func create(name, max_intervals, wrap = false) -> Stopwatch:
	var new_entry := StopwatchFactoryEntry.new(name,max_intervals,wrap)
	_stopwatches.append(new_entry)
	return new_entry.sw
