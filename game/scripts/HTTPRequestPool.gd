extends Node

signal request_complete(result, response_code, headers, body, token, user_data)

export var max_simultaneous_request = 5

var _next_token = 0
var _request_queue = []
var _pending_requests_by_token = {}

func request(url, user_data=null):
	var token = _next_token
	_next_token = _next_token + 1
	
	if _pending_requests_by_token.size() == max_simultaneous_request:
		# queue request for later
		_request_queue.push_back([url,user_data,token])
	else:
		# handle request now
		_request(url, user_data, token)
	
	return token
	
# internal method for creating a new request
func _request(url, user_data, token):
	var new_request = HTTPRequest.new()
	add_child(new_request)
	new_request.connect("request_completed",self,"_on_request_complete",[token,user_data])
	var res = new_request.request(url)
	if res == OK:
		_pending_requests_by_token[token] = new_request
	else:
		vr.log_error('failed to request url = "%s"' % url)
		new_request.disconnect("request_completed",self,"_on_request_complete")
		remove_child(new_request)
	
func cancel_request(token):
	if _pending_requests_by_token.has(token):
		var request : HTTPRequest = _pending_requests_by_token[token]
		request.disconnect("request_completed",self,"_on_request_complete")
		request.cancel_request()
		remove_child(request)
		_pending_requests_by_token.erase(token)
	
func cancel_all():
	for token in _pending_requests_by_token.keys():
		self.cancel_request(token)

func _on_request_complete(result, response_code, headers, body, token, user_data):
	# clean up request
	remove_child(_pending_requests_by_token[token])
	_pending_requests_by_token.erase(token)
	
	# initiate next queued request if there is one
	if ! _request_queue.empty():
		var request_args = _request_queue[0]
		_request_queue.pop_front()
		self.request(request_args[0],request_args[1])
		
	emit_signal("request_complete",result, response_code, headers, body, token, user_data)
