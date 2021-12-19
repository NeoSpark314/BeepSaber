tool
extends Node

signal connected()
signal disconnected()
signal stopwatch_list(stopwatches)
signal summary_data(data)

const RECONNECT_DELAY = 1
const DEFAULT_PORT = 4242

var _hostname = '127.0.0.1'
var _port = DEFAULT_PORT
var _udp := PacketPeerUDP.new()
var _connected = false
var _unqiue_id = 0
var _dropped_heartbeats = 0
var _heartbeat_count = 0
var retry_count = 0
onready var _reconnect_timer := $ReconnectTimer
onready var _watchdog_timer := $WatchdogTimer

func _ready():
	_unqiue_id = str(randi()).sha256_text()

func _process(delta):
	if _udp.get_available_packet_count() > 0:
		var packet_str = _udp.get_packet().get_string_from_utf8()
		var json_res = JSON.parse(packet_str)
		if json_res.error != OK:
			print("CLIENT: json_res.error = %d; packet_str = %s" % [json_res.error,packet_str])
			return
			
		var packet = json_res.result
		if ! packet.has('type'):
			print("CLIENT: packet doesn't contain type! %s" % packet)
			return
		
		match packet.type:
			"hello":
				if ! _connected:
					_connected = true
					_reconnect_timer.stop()
					emit_signal("connected")
					_watchdog_timer.start(3)
					request_stopwatch_list()
				else:
					print("CLIENT: [ERROR] client already connect but received another hello")
			"heartbeat":
				_heartbeat_count += 1
#				print("CLIENT: received heartbeat")
				# reset the watchdog
				_watchdog_timer.stop()
				_watchdog_timer.start(3)
			"goodbye":
				reset()
			"list":
				emit_signal("stopwatch_list",packet.stopwatches)
			"summary_data":
				emit_signal("summary_data",packet.summary_data)
			_:
				print("CLIENT: unsupported packet type! %s" % packet)

func connected():
	return _connected

func connect_to_host(hostname, port = DEFAULT_PORT):
	if connected():
		print('CLIENT: [WARN] already connected to server')
	else:
		_udp.connect_to_host(_hostname, _port) == OK
		_hostname = hostname
		_port = port
		_reconnect_timer.start(RECONNECT_DELAY)
		
func reset():
	if _connected:
		_udp = PacketPeerUDP.new()
		emit_signal("disconnected")
	_watchdog_timer.stop()
	_reconnect_timer.stop()
	_hostname = '127.0.0.1'
	_port = DEFAULT_PORT
	_connected = false
	
var LIST_PACKET = '{"type":"list"}'.to_utf8()
func request_stopwatch_list():
	if ! connected():
		print('CLIENT: [WARN] cant request stopwatch list while disconnected')
		return
	_udp.put_packet(LIST_PACKET)

var SUMMARY_DATA_PACKET = '{"type":"summary_data"}'.to_utf8()
func request_summary_data():
	if ! connected():
		print('CLIENT: [WARN] cant request summary_data while disconnected')
		return
	_udp.put_packet(SUMMARY_DATA_PACKET)

var ENABLE_PACKET = '{"type":"enable_sw","sw_id":%d,"enabled":%s}'
func enable_stopwatch(sw_id, enabled):
	if ! connected():
		print('CLIENT: [WARN] cant enable stopwatch while disconnected')
		return
	var enabled_str = ENABLE_PACKET % [int(sw_id),"true" if enabled else "false"]
	_udp.put_packet(enabled_str.to_utf8())

var RESET_PACKET = '{"type":"reset_sw","sw_id":%d}'
func reset_stopwatch(sw_id):
	if ! connected():
		print('CLIENT: [WARN] cant reset stopwatch while disconnected')
		return
	_udp.put_packet((RESET_PACKET % [int(sw_id)]).to_utf8())

var HELLO_PACKET = '{"type":"hello","id":"%s"}'
func _on_ReconnectTimer_timeout():
	retry_count += 1
	if ! connected():
		print('CLIENT: retry host connection...')
		var hello = HELLO_PACKET % _unqiue_id
		_udp.put_packet(hello.to_utf8())

func _on_WatchdogTimer_timeout():
	print("CLIENT: watchdog engaged!")
	reset()
