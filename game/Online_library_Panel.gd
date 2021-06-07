extends Panel

var song_data = []
var current_list = 0
# the next requestable pages for the current list; null if prev/next page is
# not requestable (ie. reached end of the list)
var prev_page_available = null
var next_page_available = null
var list_modes = ["hot","rating","latest","downloads","plays"]
var search_word = ""
var item_selected = -1
var downloading = []#[["name","key"]]
onready var httpreq = HTTPRequest.new()
onready var httpdownload = HTTPRequest.new()
onready var httpcoverdownload = HTTPRequest.new()
onready var placeholder_cover = preload("res://game/data/beepsaber_logo.png")
onready var goto_maps_by = $gotoMapsBy
onready var v_scroll = $ItemList.get_v_scroll()

const MAX_BACK_STACK_DEPTH = 10
# series of previous requests that you can go back to
var back_stack = []

# structure representing the previous HTTP request we made to beatsaver
var prev_request = {
	# required fields
	"type" : "list",# can be "list","text_search", or "uploader"
	"page" : 0,
	
	# type-specific fields when type is "list"
	"list" : "hot"
	
	# type-specific fields when type is "text_search"
	# "search_text" = ""
	
	# type-specific fields when type is "uploader"
	# "uploader_id" = ""
}

export(NodePath) var game;
export(NodePath) var keyboard;

func enable():
	update_list({"type":"list","page":0,"list":"hot"})
	$ColorRect.visible = false

func _ready():
	game = get_node(game);
	keyboard = get_node(keyboard);
	$ColorRect.visible = true
	$back.visible = false
	v_scroll.connect("value_changed",self,"_on_ListV_Scroll_value_changed")
	
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
	
	if keyboard != null:
		keyboard.connect("text_input_enter",self,"_text_input_enter")
		keyboard.connect("text_input_cancel",self,"_text_input_cancel")

func update_list(request):
	var page = request.page
	$mode.disabled = true
	if page == 0:
		# brand new request, clear list to prep for reload
		$ItemList.clear()
		goto_maps_by.visible = false
		song_data = []
		item_selected = -1
	httpcoverdownload.cancel_request()
	httpreq.cancel_request()
	
	match request.type:
		"list":
			var list : String = request.list
			$mode.text = list.substr(0,1).capitalize() + list.substr(1)
			httpreq.request("https://beatsaver.com/api/maps/%s/%s" % [list,page])
		"text_search":
			var search_text = request.search_text
			$mode.text = search_text
			httpreq.request("https://beatsaver.com/api/search/text/%s?q=%s" % [page,search_text.percent_encode()])
		"uploader":
			var uploader_id = request.uploader_id
			$mode.text = "Uploader"
			httpreq.request("https://beatsaver.com/api/maps/uploader/%s/%s" % [uploader_id,page])
		_:
			vr.log_warning("Unsupported request type '%s'" % request.type)
			
func _add_to_back_stack(request):
	back_stack.push_back(request)
	if back_stack.size() > MAX_BACK_STACK_DEPTH:
		back_stack.pop_front()

# return the selected song's data, or null if not song is selected
func _get_selected_song():
	if item_selected >= 0 && song_data.size():
		return song_data[item_selected]
	return null

func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	if result == 0:
		var json_data = parse_json(body.get_string_from_utf8())
		prev_page_available = null
		next_page_available = null
		if json_data.has("prevPage"):
			prev_page_available = json_data["prevPage"]
		if json_data.has("nextPage"):
			next_page_available = json_data["nextPage"]
			
		if json_data.has("docs"):
			json_data = json_data["docs"]
			_current_cover_to_download = song_data.size()
			for song in json_data:
				song_data.insert(song_data.size(),song)
				$ItemList.add_item(song["name"])
				var tooltip = "Map author: %s" % song["metadata"]["levelAuthorName"]
				$ItemList.set_item_tooltip($ItemList.get_item_count()-1,tooltip)
				$ItemList.set_item_icon($ItemList.get_item_count()-1,placeholder_cover)
	else:
		vr.log_error("request error "+str(result))
	$mode.disabled = false
	$back.visible = back_stack.size() > 0
	_scroll_page_request_pending = false
	_update_all_covers()


func _on_mode_button_up():
	current_list += 1
	current_list %= list_modes.size()
	$mode.text = list_modes[current_list].capitalize()
	_add_to_back_stack(prev_request)
	prev_request = {
		"type" : "list",
		"page" : 0,
		"list" : list_modes[current_list]
	}
	update_list(prev_request)


func _on_ItemList_item_selected(index):
	item_selected = index
	var selected_data = _get_selected_song()
	var metadata = selected_data["metadata"]
	goto_maps_by.text = "Maps by %s" % metadata["levelAuthorName"]
	goto_maps_by.visible = true
	var difficulties = ""
	for d in metadata["difficulties"].keys():
		if metadata["difficulties"][d] == true:
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
		var tempdir = game.menu.bspath+"temp"
		var error = dir.make_dir_recursive(tempdir)
		if error != OK: 
			vr.log_error(
				"_on_HTTPRequest_download_completed - " +
				"Failed to create temp directory '%s'" % tempdir)
			has_error = true
		
		# sanitize path separators from song directory name
		var song_dir_name = downloading[0][0].replace('/','')
		
		var zippath = game.menu.bspath+"temp/%s.zip"%song_dir_name
		var file = File.new()
		if not has_error:
			if file.open(zippath,File.WRITE) == OK:
				file.store_buffer(body)
				file.close()
			else:
				vr.log_error(
					"_on_HTTPRequest_download_completed - " +
					"Failed to save song zip to '%s'" % zippath)
				has_error = true
		
		var song_out_dir = game.menu.bspath+("Songs/%s/"%song_dir_name)
		if not has_error:
			error = dir.make_dir_recursive(song_out_dir)
			if error != OK: 
				vr.log_error(
					"_on_HTTPRequest_download_completed - " +
					"Failed to create song output dir '%s'" % song_out_dir)
				has_error = true
		
		var Unzip = load('res://addons/gdunzip/unzip.gd').new()
		if not has_error:
			error = Unzip.unzip(zippath,song_out_dir)
			
		dir.remove(zippath)
		
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
	_add_to_back_stack(prev_request)
	prev_request = {
		"type" : "text_search",
		"page" : 0,
		"search_text" : search_word
	}
	update_list(prev_request)
	
func _text_input_cancel():
	keyboard.visible=false


var _current_cover_to_download = 0

func _update_all_covers():
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

func _on_gotoMapsBy_pressed():
	var selected_song = _get_selected_song()
	_add_to_back_stack(prev_request)
	prev_request = {
		"type" : "uploader",
		"page" : 0,
		"uploader_id" : selected_song["uploader"]["_id"]
	}
	update_list(prev_request)
	
# SCROLL_TO_FETCH_THRESHOLD
# Range: 0.0 to 1.0
# Description: Used to request the next page of songs from the current list
# once the user scrolls past this threshold
const SCROLL_TO_FETCH_THRESHOLD = 0.9
var _scroll_page_request_pending = false
	
func _on_ListV_Scroll_value_changed(new_value):
	var scroll_range = v_scroll.max_value - v_scroll.min_value
	var scroll_ratio = (new_value + v_scroll.page) / scroll_range
	if scroll_ratio > SCROLL_TO_FETCH_THRESHOLD:
		if next_page_available == null:
			# no next page to load
			return
		
		# prevent back to back requests
		if _scroll_page_request_pending:
			return
		
		# request next page and update list
		prev_request.page += 1
		update_list(prev_request)
		_scroll_page_request_pending = true

func _on_back_pressed():
	if back_stack.empty():
		return
		
	# re-request latest entry
	prev_request = back_stack.back()
	prev_request.page = 0
	back_stack.pop_back()
	update_list(prev_request)
	
	$back.visible = back_stack.size() > 0
