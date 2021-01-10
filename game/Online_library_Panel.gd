extends Panel

var song_codes = []
var current_page = 0
var current_list = 0
var list_modes = ["hot","rating","latest","downloads","plays"]
var searck_word = ""
var item_selected = -1
var downloading = []#[["name","key"]]
onready var httpreq = HTTPRequest.new()
onready var httpdownload = HTTPRequest.new()

export(NodePath) var game;
export(NodePath) var keyboard;

func _ready():
	game = get_node(game);
	keyboard = get_node(keyboard);
	
	httpreq.use_threads = true
	get_tree().get_root().add_child(httpreq)
	httpreq.connect("request_completed",self,"_on_HTTPRequest_request_completed")
	
	httpdownload.use_threads = true
	httpdownload.download_chunk_size = 65536
	get_tree().get_root().add_child(httpdownload)
	httpdownload.connect("request_completed",self,"_on_HTTPRequest_download_completed")
	
	keyboard.connect("text_input_enter",self,"_text_input_enter")
	keyboard.connect("text_input_cancel",self,"_text_input_cancel")
	
	update_list()

func update_list(page=0,list="hot"):
	$page.text = "Page: %d"%(page+1)
	$up.disabled = true
	$down.disabled = true
	$mode.disabled = true
	$ItemList.clear()
	song_codes = []
	item_selected = -1
	if list is String:
		httpreq.request("https://beatsaver.com/api/maps/%s/%s" % [list,page])
	else:
		httpreq.request("https://beatsaver.com/api/search/text/%s?q=%s" % [page,searck_word.percent_encode()])


func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	if result == 0:
		var json_data = parse_json(body.get_string_from_utf8())
		if json_data.has("docs"):
			json_data = json_data["docs"]
			for song in json_data:
				song_codes.insert(song_codes.size(),song["key"])
				$ItemList.add_item(song["name"])
	#		print(song_codes)
	else:
		vr.log_info("request error "+str(result))
	$up.disabled = false
	$down.disabled = false
	$mode.disabled = false


func _on_up_button_up():
	current_page = max(0,current_page-1)
	if current_list == -1:
		update_list(current_page,current_list)
		return
	update_list(current_page,list_modes[current_list])


func _on_down_button_up():
	current_page += 1
	if current_list == -1:
		update_list(current_page,current_list)
		return
	update_list(current_page,list_modes[current_list])

func _on_mode_button_up():
	current_list += 1
	current_list %= list_modes.size()
	$mode.text = list_modes[current_list].capitalize()
	current_page = 0
	update_list(current_page,list_modes[current_list])


func _on_ItemList_item_selected(index):
	item_selected = index


func _on_download_button_up():
	OS.request_permissions()
	if item_selected == -1: return
	downloading.insert(downloading.size(),[$ItemList.get_item_text(item_selected),song_codes[item_selected]])
	download_next()
#	$download.disabled = true
	
	
func download_next():
	if downloading.size() > 0:
		httpdownload.request("https://beatsaver.com/api/download/key/%s" % song_codes[item_selected])
		$Label.text = "Downloading: %s - %d left" % [str(downloading[0][0]),downloading.size()-1]
		$Label.visible = true
		

func _on_HTTPRequest_download_completed(result, response_code, headers, body):
#	$download.disabled = false
	if result == 0:
		var has_error = false
		var dir = Directory.new()
		var error = dir.make_dir_recursive(game.menu.bspath+"temp")
		if error != 0: 
			vr.log_info(str(error))
			has_error = true
		
		var file = File.new()
		file.open(game.menu.bspath+"temp/%s.zip"%downloading[0][0],File.WRITE)
		file.store_buffer(body)
		file.close()
		
		error = dir.make_dir_recursive(game.menu.bspath+("Songs/%s"%downloading[0][0]))
		if error != 0: 
			vr.log_info(str(error))
			has_error = true
		
		var Unzip = load('res://addons/gdunzip/unzip.gd').new()
		error = Unzip.unzip(game.menu.bspath+"temp/%s.zip"%downloading[0][0],game.menu.bspath+("Songs/%s/"%downloading[0][0]))
		
		dir.remove(game.menu.bspath+"temp/%s.zip"%downloading[0][0])
		
		downloading.remove(0)
		
		game.menu._on_LoadPlaylists_Button_pressed()
		
		if not downloading.size() > 0:
			$Label.text = "All downloaded"
	else:
		$Label.text = "Download error"
		vr.log_info("download error "+str(result))
		
	download_next()
		



func _on_search_button_up():
	keyboard.visible=true
	keyboard._text_edit.grab_focus();

func _text_input_enter(text):
	keyboard.visible=false
	searck_word = text
	$mode.text = searck_word
	current_list = -1
	update_list(current_page,current_list)
	
func _text_input_cancel():
	keyboard.visible=false
