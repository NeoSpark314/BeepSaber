extends Reference
class_name Logger

# this logger's logger name
var logger_name = "UnknownLogger"

# logging threshold for this logger instance
var threshold = Logging.global_threshold

# Initializes the logger with an object that wants to log
# obj can be a Node, or a String defining the log4j-style loggername to be
# used for this logger instance
func _init(obj):
	if obj is Node:
		var path = obj.get_path()
		logger_name = str(path)
		if path.is_absolute():
			if logger_name.find("/root",0) == 0:
				logger_name = logger_name.substr(6)
			elif logger_name.find("/global",0) == 0:
				logger_name = logger_name.substr(8)
		logger_name = logger_name.replace("/",".")
	elif obj is String:
		logger_name = obj

func trace(msg_fmt,sub_strs = []):
	_log(Logging.LEVEL.TRACE,msg_fmt,sub_strs)
	
func debug(msg_fmt,sub_strs = []):
	_log(Logging.LEVEL.DEBUG,msg_fmt,sub_strs)

func info(msg_fmt,sub_strs = []):
	_log(Logging.LEVEL.INFO,msg_fmt,sub_strs)

func warn(msg_fmt,sub_strs = []):
	_log(Logging.LEVEL.WARN,msg_fmt,sub_strs)

func error(msg_fmt,sub_strs = []):
	_log(Logging.LEVEL.ERROR,msg_fmt,sub_strs)

func fatal(msg_fmt,sub_strs = []):
	_log(Logging.LEVEL.FATAL,msg_fmt,sub_strs)

func _log(level,msg_fmt,sub_strs):
	if level < Logging.global_threshold || level < threshold:
		return
	
	var timestamp_ms = OS.get_system_time_msecs()
	
	# build user log message
	var msg = msg_fmt
	if len(sub_strs) > 0:
		msg = msg_fmt % sub_strs
	
	# build and log the event
	var event = {
		"loggername" : logger_name,
		"level" : Logging.LEVEL.keys()[level],
		"timestamp" : str(timestamp_ms),
		"message" : msg
	}
	Logging.log_event(event)
