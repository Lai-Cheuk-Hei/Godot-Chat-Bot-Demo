extends Control

@export var API_URL = "http://192.168.32.58:8080"
@export var temperature = 0.8
@export var top_k = 40
@export var top_p = 0.9
@export var n_predict = 128
@export var n_keep = -1
@export var stop = ["\n#", "`", "<", ">"]
@export var stream = false  # True or False

@export var mirostat = 2
@export var mirostat_tau = 5
@export var mirostat_eta = 0.1

@onready var gpt_http_request = HTTPRequest.new()
@onready var tts_http_request = HTTPRequest.new()

var recording = false

var input = ""
# Chatbot variables
var Prompt = "You are a helpful AI assistant." #  你是一个乐于助人的 AI 助手. 您根据人们的問題和语言给出关心、有帮助、有价值和礼貌的回复
var HistoryChat = [
	{
		"human": "Hello, AI Helper", # 你好，人工智慧助手
		"assistant": "Hello, I am AI Helper. How may I help you today?" # 你好。我是工智能助理。今天我能为您提供什么帮助？
	}
]

# Called when the node enters the scene tree for the first time.
func _ready():
	add_child(gpt_http_request)
	add_child(tts_http_request)
	# Create an HTTP request node and connect its completion signal.
	gpt_http_request.request_completed.connect(self._gpt_http_request_completed)
	tts_http_request.request_completed.connect(self._tts_http_request_completed)
	var mic_list : Array = AudioServer.get_input_device_list()
	for i in mic_list:
#		print(i)
		$MicSelect.add_item(i)
	AudioServer.input_device = $MicSelect.get_item_text(0)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func scroll_to_bottom():
	await get_tree().create_timer(0.01).timeout
	$ScrollContainer.scroll_vertical = $ScrollContainer.get_v_scroll_bar().max_value


func format_prompt(question):
	#history = "\n".join([f"### Human: {m['human']}\n### Assistant: {m['assistant']}" for m in HistoryChat])
	#return f"{Prompt}\n{history}\n### Human: {question}\n### Assistant:"
	var tmp_history = ""
	for m in range(HistoryChat.size()):
		if m != 0:
			tmp_history += "\n"
		tmp_history += "### Human: %s\n### Assistant: %s" % [HistoryChat[m]["human"], HistoryChat[m]["assistant"]]
	
	return "%s\n%s\n### Human: %s\n### Assistant:" % [Prompt, tmp_history, input]

func add_new_lbl(actor, string):
	var label = Label.new()
	var style_box = StyleBoxFlat.new()
	var label_color
	if actor == "Human":
		label.text = "%s:\n%s" % ["You", string]
		label_color = Color("#464635", 1)
	else:
		label.text = "%s:\n%s" % [actor, string]
		label_color = Color("#354646", 1)
	
	style_box.bg_color = label_color
	style_box.border_color = label_color
	style_box.set_border_width_all(10)
	style_box.set_corner_radius_all(25)
	label.add_theme_stylebox_override("normal", style_box)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_mouse_filter(0)
	$ScrollContainer/VBoxContainer.add_child(label)
	pass

func submit_input():
#	print(input)
#	$RichTextLabel.text += "\nHuman: %s" % input
	add_new_lbl("Human", input)
	scroll_to_bottom()
	## Perform the HTTP request
	var payload = {
		"prompt": format_prompt(input),
		"temperature": temperature,
		"top_k": top_k,
		"top_p": top_p,
		"n_keep": n_keep,
		"n_predict": n_predict,
		"stop": stop,
		"stream": stream,
		"mirostat": mirostat,
		"mirostat_tau": mirostat_tau,
		"mirostat_eta": mirostat_eta
	}

	# Perform a POST request. The URL below returns JSON as of writing.
	# Note: Don't make simultaneous requests using a single HTTPRequest node.
	# The snippet below is provided for reference only.
	var body = JSON.new().stringify(payload)
	var error = gpt_http_request.request(API_URL + "/completion", [], HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
	$LineEdit.clear()

func _on_send_button_pressed():
	submit_input()
	pass # Replace with function body.


func _on_line_edit_text_submitted(new_text):
	submit_input()
	pass # Replace with function body.


func _on_line_edit_text_changed(new_text):
	input = new_text
	pass # Replace with function body.

# Called when the HTTP request is completed.
func _gpt_http_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()

	# Will print the user agent string used by the HTTPRequest node (as recognized by httpbin.org).
#	print(response.content)
#	$RichTextLabel.text += "\nAssistant: %s" % response.content
	add_new_lbl("Assistant", response.content)
	scroll_to_bottom()
#	BrianTTS(response.content)
	godot_tts(response.content)
	HistoryChat.append({"human": input, "assistant": response.content})


func _on_mic_select_item_selected(index):
	AudioServer.input_device = $MicSelect.get_item_text(index)
	pass # Replace with function body.


func _on_talk_button_2_button_down():
	print("start recording")
	$Textify.start_recording()
	$TalkButton2.text = "Recording..."
	pass # Replace with function body.


func _on_talk_button_2_button_up():
	print("stop recording")
	$Textify.stop_recording()
	$TalkButton2.text = "Talk\n(Hold)"
	pass # Replace with function body.


func _on_talk_button_pressed():
	if not recording:
		print("start recording")
		$Textify.start_recording()
		recording = true
		$TalkButton.text = "Recording..."
	else:
		print("stop recording")
		$Textify.stop_recording()
		recording = false
		$TalkButton.text = "Talk\n(Toggle)"
	pass # Replace with function body.




func godot_tts(text):
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var voice_id = voices[0]
	DisplayServer.tts_speak(text, voice_id)

func BrianTTS(text):
	print(text)
		# Create an HTTP request node and connect its completion signal.

	var error = tts_http_request.request("https://api.streamelements.com/kappa/v2/speech?voice=Brian&text=" + text)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _tts_http_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")
	
	print("**************************************************\n")
	print(result)
	print(response_code)
	print(headers)
	print(body)
	
	var audioTTS = AudioStreamMP3.new()
	audioTTS.data = body
	$AudioStreamPlayer.stream = audioTTS
	$AudioStreamPlayer.play()





func _on_textify_loading(time):
#	print(time)
	pass # Replace with function body.


func _on_textify_received(text):
	print(text)
	$LineEdit.text = text
	input = text
	pass # Replace with function body.





