extends Reference

const MAX_INT : int = 2^63
const MIN_INT : int = -2^63

class Interval:
	extends Reference
	var start_time_us : int = 0
	var duration_us : int = 0





var enabled = false
var _intervals = []
var _idx = 0
var _allow_wrap = false
var _max_intervals = 0
var total_intervals : int = 0
var max_duration : int = MIN_INT
var min_duration : int = MAX_INT
var ellapsed_duration : int = 0

func _init(max_intervals, wrap = false):
	_max_intervals = max_intervals
	_allow_wrap = wrap
	for _i in range(_max_intervals):
		_intervals.append(Interval.new())

func reset():
	_idx = 0
	total_intervals = 0
	max_duration = MIN_INT
	min_duration = MAX_INT
	ellapsed_duration = 0
	
func mean():
	if total_intervals > 0:
		return ellapsed_duration / total_intervals
	else:
		return 0
	
func start():
	if ! enabled:
		return
	elif ! _allow_wrap and _idx >= _max_intervals:
		return
		
	_intervals[_idx].start_time_us = OS.get_ticks_usec()
	
func stop():
	if ! enabled:
		return
	elif ! _allow_wrap and _idx >= _max_intervals:
		return
		
	var dur = (OS.get_ticks_usec() - _intervals[_idx].start_time_us)
	_intervals[_idx].duration_us = dur
	if dur > max_duration:
		max_duration = dur
	if dur < min_duration:
		min_duration = dur
	ellapsed_duration += dur
	total_intervals += 1
	_idx += 1
	if _allow_wrap and _idx >= _max_intervals:
		_idx = 0
	
func print_stats():
	print('intervals = %d' % _idx)
	print('ellapsed_duration = %dus' % ellapsed_duration)
	print('min_duration = %dus' % min_duration)
	print('max_duration = %dus' % max_duration)
	print('mean_duration = %dus' % mean())
