extends Panel

var song_data = []
var current_page = 0
var current_list = 0
var list_modes = ["hot","rating","latest","downloads","plays"]
var search_word = ""
var item_selected = -1
var downloading = []#[["name","key"]]
onready var httpreq = HTTPRequest.new()
onready var httpdownload = HTTPRequest.new()
onready var httpcoverdownload = HTTPRequest.new()
onready var placeholder_cover = preload("res://game/data/beepsaber_logo.png")

export(NodePath) var game;
export(NodePath) var keyboard;

func enable():
	update_list()
	$ColorRect.visible = false

func _ready():
	game = get_node(game);
	keyboard = get_node(keyboard);
	$ColorRect.visible = true
	
	httpreq.use_threads = true
	get_tree().get_root().add_child(httpreq)
	httpreq.connect("request_completed",self,"_on_HTTPRequest_request_completed")
	
	httpdownload.use_threads = true
	httpdownload.download_chunk_size = 65536
	get_tree().get_root().add_child(httpdownload)
	httpdownload.connect("request_completed",self,"_on_HTTPRequest_download_completed")
	
	httpcoverdownload.use_threads = true
	httpcoverdownload.download_chunk_size = 65536
	get_tree().get_root().add_child(httpcoverdownload)
	httpcoverdownload.connect("request_completed",self,"_update_cover")
	
	keyboard.connect("text_input_enter",self,"_text_input_enter")
	keyboard.connect("text_input_cancel",self,"_text_input_cancel")
	

func update_list(page=0,list="hot"):
	$page.text = "Page: %d"%(page+1)
	$up.disabled = true
	$down.disabled = true
	$mode.disabled = true
	$ItemList.clear()
	song_data = []
	item_selected = -1
	httpcoverdownload.cancel_request()
	httpreq.cancel_request()
	if list is String:
		httpreq.request("https://beatsaver.com/api/maps/%s/%s" % [list,page])
	else:
		httpreq.request("https://beatsaver.com/api/search/text/%s?q=%s" % [page,search_word.percent_encode()])


func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	if result == 0:
		var json_data = parse_json(body.get_string_from_utf8())
		if json_data.has("docs"):
			json_data = json_data["docs"]
			for song in json_data:
				song_data.insert(song_data.size(),song)
				$ItemList.add_item(song["name"])
				var tooltip = "Map author: %s" % song["metadata"]["levelAuthorName"]
				$ItemList.set_item_tooltip($ItemList.get_item_count()-1,tooltip)
				$ItemList.set_item_icon($ItemList.get_item_count()-1,placeholder_cover)
	#		print(song_codes)
	else:
		vr.log_info("request error "+str(result))
	$up.disabled = false
	$down.disabled = false
	$mode.disabled = false
	_update_all_covers()


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
	var selected_data = song_data[index]
	var difficulties = ""
	for d in selected_data["metadata"]["difficulties"].keys():
		if selected_data["metadata"]["difficulties"][d] == true:
			difficulties += " %s"%d
	var text = """[center]%s By %s[/center]

Map author: %s
Duration: %s
difficulties:%s

[center]Description:[/center]
%s""" % [
		selected_data["metadata"]["songName"],
		selected_data["metadata"]["songAuthorName"],
		selected_data["metadata"]["levelAuthorName"],
		selected_data["metadata"]["duration"],
		difficulties,
		selected_data["description"],
	]
	$song_data.bbcode_text = text
	
	$TextureRect.texture = $ItemList.get_item_icon(index)


func _on_download_button_up():
	OS.request_permissions()
	if item_selected == -1: return
	downloading.insert(downloading.size(),[song_data[item_selected]["name"],song_data[item_selected]["key"]])
	download_next()
#	$download.disabled = true
	
	
func download_next():
	if downloading.size() > 0:
		httpdownload.request("https://beatsaver.com/api/download/key/%s" % downloading[0][1])
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
		
		if not downloading.size() > 0:
			game.menu._on_LoadPlaylists_Button_pressed()
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
	search_word = text
	$mode.text = search_word
	current_list = -1
	update_list(current_page,current_list)
	
func _text_input_cancel():
	keyboard.visible=false


var _current_cover_to_download = 0

func _update_all_covers():
	_current_cover_to_download = 0
	httpcoverdownload.cancel_request()
	update_next_cover()

func update_next_cover():
	if _current_cover_to_download < song_data.size():
		httpcoverdownload.request("https://beatsaver.com%s" % song_data[_current_cover_to_download]["coverURL"])

func _update_cover(result, response_code, headers, body):
	if result == 0:
		var img = Image.new()
		if not img.load_jpg_from_buffer(body) == 0:
			img.load_png_from_buffer(body)
		var img_tex = ImageTexture.new()
		img_tex.create_from_image(img)
		$ItemList.set_item_icon(_current_cover_to_download,img_tex)
	_current_cover_to_download += 1
	update_next_cover()
