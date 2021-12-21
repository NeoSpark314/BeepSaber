tool
extends MarginContainer

const GRID_COL_ENABLED = 0
const GRID_COL_RESET = 1
const GRID_COL_NAME = 2
const GRID_COL_MIN = 3
const GRID_COL_MAX = 4
const GRID_COL_MEAN = 5
const GRID_COL_INTERVALS = 6

onready var _client := $Client
onready var _collect_timer := $CollectionTimer
onready var _connection_label := $VBox/TopBar/connection_label
onready var _hostname_edit := $VBox/TopBar/hostname_edit
onready var _connect_button := $VBox/TopBar/connect_button
onready var _grid := $VBox/HSplit/Grid

var _sw_rows = {}

func _ready():
	print('Plugin is here')

func _add_sw_to_grid(sw_id, sw_summary):
	if _sw_rows.has(sw_id):
		print("grid already contains row for sw_id %d" % sw_id)
		return
		
	var new_row = _create_new_row()
	new_row[GRID_COL_ENABLED].pressed = sw_summary['enabled']
	new_row[GRID_COL_ENABLED].connect("toggled",self,"_on_sw_checkbox_toggled",[sw_id])
	new_row[GRID_COL_RESET].connect("pressed",self,"_on_sw_reset_pressed",[sw_id])
	new_row[GRID_COL_NAME].text = sw_summary['name']
	new_row[GRID_COL_NAME].hint_tooltip = sw_summary['name']
	_sw_rows[sw_id] = new_row
	for ctrl in new_row:
		_grid.add_child(ctrl)

func _create_new_row():
	var new_row = []
	var enable_checkbox = CheckBox.new()
	enable_checkbox.hint_tooltip = "enables the stopwatch on the remote side"
	new_row.append(enable_checkbox)# enable
	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.hint_tooltip = "resets the stopwatch on the remote side"
	new_row.append(reset_button)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	new_row.append(name_label)
	var le = LineEdit.new()
	le.editable = false
	new_row.append(le.duplicate())# min
	new_row.append(le.duplicate())# max
	new_row.append(le.duplicate())# mean
	new_row.append(le.duplicate())# intervals
	return new_row
	
func _reset_grid():
	for row in _sw_rows.values():
		for ctrl in row:
			_grid.remove_child(ctrl)
	_sw_rows = {}

func _on_Client_connected():
	_connection_label.text = 'connected'
	_hostname_edit.editable = false
	_connect_button.text = "Disconnect"
	_collect_timer.start(1)

func _on_Client_disconnected():
	_connection_label.text = 'disconnected'
	_hostname_edit.editable = true
	_connect_button.text = "Connect"
	_reset_grid()

func _on_Client_stopwatch_list(stopwatches):
	for sw_id in stopwatches.keys():
		var sw_summary = stopwatches[sw_id]
		_add_sw_to_grid(sw_id,sw_summary)

func _on_Client_summary_data(data):
	for sw_id in data.keys():
		if ! _sw_rows.has(sw_id):
			continue
		
		var sw_data = data[sw_id]
		var sw_row = _sw_rows[sw_id]
		sw_row[GRID_COL_MIN].text = str(sw_data['min'])
		sw_row[GRID_COL_MAX].text = str(sw_data['max'])
		sw_row[GRID_COL_MEAN].text = str(sw_data['mean'])
		sw_row[GRID_COL_INTERVALS].text = str(sw_data['intervals'])

func _on_connect_button_pressed():
	if _client.connected():
		_client.reset()
	else:
		_client.connect_to_host(_hostname_edit.text)

func _on_sw_checkbox_toggled(pressed, sw_id):
	_client.enable_stopwatch(sw_id, pressed)
		
func _on_sw_reset_pressed(sw_id):
	_client.reset_stopwatch(sw_id)

func _on_CollectionTimer_timeout():
	if _client.connected():
		_client.request_summary_data()
