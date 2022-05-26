extends Object

class ImgLoadRequest:
	extends Reference
	
	var filepath : String = ""
	var callback_obj : Object = null
	var callback_func : String = ""
	var callback_args := []
	var thread := Thread.new()
	
var LinkedList := preload("res://game/scripts/LinkedList.gd")
var _img_load_request_queue = LinkedList.new()

# variable used to keep track of how many threads are currently loading images
var _img_load_mutex := Mutex.new()
var _running_img_load_threads = 0

var _max_img_load_threads = 1

func _init(num_threads = 10):
	_max_img_load_threads = num_threads

func load_texture(filepath: String, callback_obj: Object, callback_func: String, callback_args := []):
	var new_req := ImgLoadRequest.new()
	new_req.filepath = filepath
	new_req.callback_obj = callback_obj
	new_req.callback_func = callback_func
	new_req.callback_args = callback_args
	_img_load_request_queue.push_back(new_req)
	
	_start_next_img_load()

func _start_next_img_load():
	if _img_load_request_queue.size() > 0 and _running_img_load_threads < _max_img_load_threads:
		var next_req : ImgLoadRequest = _img_load_request_queue.pop_front()
		
		_img_load_mutex.lock()
		if next_req.thread.start(self,"_load_img_threaded",next_req) == OK:
			_running_img_load_threads += 1
		_img_load_mutex.unlock()

func _load_img_threaded(req: ImgLoadRequest):
	# read cover image data from file into a buffer
	var file = File.new()
	var img_data = null
	var tex : ImageTexture = null
	if file.open(req.filepath, File.READ) == OK:
		img_data = file.get_buffer(file.get_len())
		file.close()
		
		# parse buffer into an ImageTexture
		tex = ImageTexture.new()
		tex.create_from_image(ImageUtils.get_img_from_buffer(img_data))
	
	# perform callback in the form of my_callback(texture, filepath, ...)
	if req.callback_obj != null:
		var args = [tex, req.filepath]
		args.append_array(req.callback_args)
		req.callback_obj.callv(req.callback_func, args)
	
	# decrement count to show that this thread is done and another can start
	_img_load_mutex.lock()
	_running_img_load_threads -= 1
	_img_load_mutex.unlock()
	
	# start next load if there are any waiting
	_start_next_img_load()
