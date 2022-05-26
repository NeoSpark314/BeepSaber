extends Node

class StopwatchFactoryEntry:
	extends Reference
	var name : String = ''
	var sw : Stopwatch = null
	
	func _init(sw_name, max_intervals, wrap):
		name = sw_name
		sw = Stopwatch.new(max_intervals, wrap)

const DEFAULT_PORT = 4242

var _stopwatches = {}
var _next_sw_id = 0
var _server := UDPServer.new()
var _unique_id = ''
var _peer : PacketPeerUDP = null
onready var _heartbeat_timer := Timer.new()

func _ready():
	_server.listen(DEFAULT_PORT)
	_unique_id = str(randi()).sha256_text()
	add_child(_heartbeat_timer)
	connect("tree_exited",self,"_on_tree_exited")
	_heartbeat_timer.connect("timeout",self,"_on_heartbeat_timeout")

func _process(delta):
	_server.poll()
	if _peer == null:
		_try_connect()
	else:
		if _peer.get_available_packet_count() == 0:
			return
			
		var packet_str = _peer.get_packet().get_string_from_utf8()
		var json_res = JSON.parse(packet_str)
		if json_res.error != OK:
			print("SERVER: json_res.error = %d; packet_str = %s" % [json_res.error,packet_str])
			return
		
		var packet = json_res.result
		if ! packet.has('type'):
			print("SERVER: packet does not contain type! %s" % packet)
			return
			
		match packet.type:
			"hello":
				pass
			"list":
				_respond_to_list()
			"summary_data":
				_respond_to_summary_data()
			"enable_sw":
				_handle_enable_sw(packet.sw_id, packet.enabled)
			"reset_sw":
				_handle_reset_sw(packet.sw_id)
			_:
				print("SERVER: unsupported packet type! %s" % [packet])

var HELLO_PACKET = '{"type":"hello","id":"%s"}'
func _try_connect():
	if _server.is_connection_available():
		_peer = _server.take_connection()
		print("SERVER: accepted peer: %s:%s" % [_peer.get_packet_ip(), _peer.get_packet_port()])
		var hello = HELLO_PACKET % _unique_id
		_peer.put_packet(hello.to_utf8())
		_heartbeat_timer.one_shot = false
		_heartbeat_timer.start(1)

func create(name, max_intervals, wrap = false) -> Stopwatch:
	var new_entry := StopwatchFactoryEntry.new(name,max_intervals,wrap)
	_stopwatches[_next_sw_id] = new_entry
	_next_sw_id += 1
	return new_entry.sw
	
func _respond_to_list():
	var data = {
		'type': 'list',
		'stopwatches': {}
	}
	
	for sw_id in _stopwatches.keys():
		data.stopwatches[sw_id] = {
			'name' : _stopwatches[sw_id].name,
			'enabled' : _stopwatches[sw_id].sw.enabled
		}
	
	var packet = JSON.print(data).to_utf8()
	_peer.put_packet(packet)
	
func _respond_to_summary_data():
	var data = {
		'type': 'summary_data',
		'summary_data': {}
	}
	
	for sw_id in _stopwatches.keys():
		var sw : Stopwatch = _stopwatches[sw_id].sw
		if ! sw.enabled:
			continue
		
		data.summary_data[sw_id] = {
			'min' : sw.min_duration,
			'max' : sw.max_duration,
			'mean' : sw.mean(),
			'intervals' : sw.total_intervals
		}
	
	var packet = JSON.print(data).to_utf8()
	_peer.put_packet(packet)

func _handle_enable_sw(sw_id : int, enabled : bool):
	if _stopwatches.has(sw_id):
		_stopwatches[sw_id].sw.enabled = enabled

func _handle_reset_sw(sw_id : int):
	if _stopwatches.has(sw_id):
		_stopwatches[sw_id].sw.reset()

var GOODBYE_PACKET = '{"type":"goodbye"}'.to_utf8()
func _on_tree_exited():
	if _peer != null:
		_peer.put_packet(GOODBYE_PACKET)

var HEARTBEAT_PACKET = '{"type":"heartbeat"}'.to_utf8()
func _on_heartbeat_timeout():
	if _peer != null:
#		print("SERVER: heartbeat")
		_peer.put_packet(HEARTBEAT_PACKET)
