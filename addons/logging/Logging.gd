extends Node

enum LEVEL {
	TRACE,DEBUG,INFO,WARN,ERROR,FATAL
}

var global_threshold = LEVEL.INFO

var appenders = []

func _ready():
	pass

func init_basic_logging():
	appenders.append(ConsoleAppender.new())
	
func add_appender(appender):
	appender.open()
	appenders.append(appender)

# get a Logger instance
func get_logger(obj) -> Logger:
	return Logger.new(obj)

func log_event(event):
	for appender in appenders:
		appender.append_event(event)
