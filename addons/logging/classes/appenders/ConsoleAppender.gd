extends BaseAppender
class_name ConsoleAppender

# %c -> loggername
# %r -> log event timestamp in milliseconds
# %p -> log level
# %m -> application specified message
# %n -> newline seperator
var fmt_str = "[%p] %c - %m"

func append_event(event):
	var log_str = fmt_str
	log_str = log_str.replace("%c",event.loggername)
	log_str = log_str.replace("%r",event.timestamp)
	log_str = log_str.replace("%p",event.level)
	log_str = log_str.replace("%m",event.message)
	log_str = log_str.replace("%n","\n")
	print(log_str)
