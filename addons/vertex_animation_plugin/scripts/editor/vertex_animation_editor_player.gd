@tool
extends Control

var _vertex_animation_player
var _selected_animation: VertexAnimation
var _start_global_time_offset: float = 0.0
var _is_play := false
var _current_frame := 0.0:
	set(value):
		_current_frame = value
		_frame_slider.set_value_no_signal(_current_frame)
		_frame_slider_box.set_value_no_signal(_current_frame)
		_frame_slider_second_value.set_value_no_signal(_change_animation_frame_to_second(_selected_animation, _current_frame))

@onready var _animation_clips_options: OptionButton = %AnimationClipsOptions
@onready var _frame_slider: Slider = %FrameSlider
@onready var _frame_slider_box: SpinBox = %SliderFrameValue
@onready var _frame_slider_second_value: SpinBox = %SliderSecondsValue
@onready var _speed_value_box: SpinBox = %SpeedValue
@onready var _main_panel: MarginContainer = %MainPanel


func _process(delta: float) -> void:
	if _is_play:
		_current_frame = _get_shader_current_frame(_selected_animation, _start_global_time_offset)
	

func initialize(selection: Node) -> void:
	if selection is not VertexAnimationMeshPlayer and selection is not VertexAnimationMultiMeshPlayer:
		_main_panel.hide()
		return
	
	_main_panel.show()
	_vertex_animation_player = selection
	_update_animation_clips(selection)
	_on_animation_clip_selected(0)


func _update_animation_clips(animation_player):
	_animation_clips_options.clear()
	if animation_player.animations.size() == 0:
		return
	for animation in animation_player.animations:
		_animation_clips_options.add_item(animation.name)


func _play(animation: VertexAnimation, from_frame := 0.0) -> void:
	_is_play = true
	_start_global_time_offset = GlobalShaderTimer.time - (from_frame * _vertex_animation_player.get_animation_frame_time(animation))
	var anim_data := Vector4(animation.start_frame, animation.frame_count, animation.speed, _start_global_time_offset)
	_set_instance_shader_parameter(anim_data)


func _stop() -> void:
	var anim_data := Vector4(_selected_animation.start_frame, _selected_animation.frame_count, 0.0, 0.0)
	_set_instance_shader_parameter(anim_data)
	_start_global_time_offset = 0.0
	_current_frame = 0.0
	_is_play = false


func _pause() -> void:
	if not _is_play:
		return
	_move_to_frame(_selected_animation, _current_frame)


func _move_to_frame(animation: VertexAnimation, frame: float) -> void:
	var anim_data := Vector4(animation.start_frame + frame, animation.frame_count, 0.0, 0.0)
	_set_instance_shader_parameter(anim_data)
	_is_play = false


func _get_shader_current_frame(animation: VertexAnimation, start_global_time_offset: float) -> float:
	var time: float = (GlobalShaderTimer.time - start_global_time_offset) * animation.speed
	var current_frame: float = time * _vertex_animation_player.animation_FPS
	return fmod(current_frame, animation.frame_count)


func _change_animation_frame_to_second(animation: VertexAnimation, frame: float) -> float:
	return frame * _vertex_animation_player.get_animation_frame_time(animation)


func _set_instance_shader_parameter(animation_data: Vector4) -> void:
	if _vertex_animation_player is VertexAnimationMeshPlayer:
		_vertex_animation_player.mesh_instance.set_instance_shader_parameter(_vertex_animation_player.INSTANCE_SHADER_PARAMETER, animation_data)
	else:
		var anim_data_color := Color(animation_data.x, animation_data.y, animation_data.z, animation_data.w)
		_vertex_animation_player.multi_mesh_instance.multimesh.set_instance_custom_data(0, anim_data_color)


#region UIControl
func _on_animation_clip_selected(index: int) -> void:
	_selected_animation = _vertex_animation_player.animations[index]
	_frame_slider_box.max_value = _selected_animation.frame_count
	_frame_slider.max_value = _selected_animation.frame_count
	_frame_slider.tick_count = _selected_animation.frame_count + 1
	_speed_value_box.set_value_no_signal(_selected_animation.speed)
	_stop()


func _on_play_button_pressed() -> void:
	_play(_selected_animation, _current_frame)


func _on_pause_button_pressed() -> void:
	_pause()


func _on_stop_button_pressed() -> void:
	_stop()


func _on_speed_value_changed(value: float) -> void:
	_selected_animation.speed = value
	_pause()


func _on_frame_value_changed(value: float) -> void:
	_current_frame = value
	_move_to_frame(_selected_animation, value)
#endregion
