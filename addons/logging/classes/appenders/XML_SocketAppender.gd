extends BaseAppender
class_name XML_SocketAppender

# The maximum number of logs to buffer while host connection is down
const MAX_BUFFERED_EVENTS = 1024

var connection : StreamPeerTCP = null

# the hostname to log events to
var host = "localhost"

# the TCP port to log events to
var port = 4448

# set to true when connection to host is valid, false if connection dropped
var _connection_valid = false

# Logs that are being temporarily buffered until the connection to the logger
# host is restored. If this list ever reached the MAX_buffered_logs, then the
# oldest entry will be dropped.
var _buffered_logs = LinkedList.new()

# Number of logs that were dropped since the last time the Logger had a valid
# connection with the host
var _dropped_logs_since_last_connection = 0

func _init():
	connection = StreamPeerTCP.new()
	
func open():
	if not _connection_valid:
		var err = connection.connect_to_host(host,port)
		if err == OK:
			_connection_valid = true

func close():
	if connection:
		connection.disconnect_from_host()
	
func append_event(event):
	var logxml = "<log4j:event logger=\"" + event.loggername + "\""
	logxml += " timestamp=\"" + event.timestamp + "\""
	logxml += " level=\"" + event.level + "\""
	logxml += " thread=\"0\">"
	logxml += "<log4j:message><![CDATA[" + event.message + "]]></log4j:message>"
	logxml += "</log4j:event>"
	
	var logdata = logxml.to_utf8()
	
	var okay = _connection_valid
	if okay:
		var err = connection.put_data(logdata)
		if err != OK:
			_connection_valid = false
			okay = false
	
	if not okay:
		_buffer_log(logdata)

func _buffer_log(logdata):
	_buffered_logs.push_back(logdata)
	if _buffered_logs.size() > MAX_BUFFERED_EVENTS:
		_dropped_logs_since_last_connection += 1
		_buffered_logs.pop_front()

# FIXME this method does not work and tends to lock up the engine when the
# socket connection is dropped
func _reconnect():
	# notify if any logs were dropped since previous connection
	if _dropped_logs_since_last_connection > 0:
		pass
		# FIXM recover this warning log
#		warn(self,
#			"Logger connection was lost and %d logs were dropped",
#			[_dropped_logs_since_last_connection])
#		_dropped_logs_since_last_connection = 0

	# resend logs that were buffered while connection was down
	while _buffered_logs.size() > 0:
		var logdata = _buffered_logs.pop_front()
		var err = connection.put_data(logdata)
		if err != OK and not connection.is_connected_to_host():
			# host connection lost again... put log back into queue
			_buffered_logs.push_front(logdata)
		elif err != OK:
			print("Failed to write logging but connection to host is fine." +
				" Log is being dropped!" +
				" error code = %d" % err)
