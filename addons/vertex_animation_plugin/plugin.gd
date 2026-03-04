@tool
extends EditorPlugin

var _animation_editor_player_panel
var _editor_selection: EditorSelection = get_editor_interface().get_selection()


func _enter_tree() -> void:
	#RenderingServer.global_shader_parameter_add("global_shader_time", RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	add_autoload_singleton("GlobalShaderTimer", "res://addons/vertex_animation_plugin/scripts/runtime/global_shader_timer.gd")
	_animation_editor_player_panel = preload("res://addons/vertex_animation_plugin/vertex_animation_editor_player_ui.tscn").instantiate()
	add_control_to_bottom_panel(_animation_editor_player_panel, "Vertex Animation")
	_editor_selection.connect("selection_changed", _on_selection_changed)
	_on_selection_changed()


func _exit_tree() -> void:
	_editor_selection.disconnect("selection_changed", _on_selection_changed)
	remove_control_from_bottom_panel(_animation_editor_player_panel)
	_animation_editor_player_panel.free()
	remove_autoload_singleton("GlobalShaderTimer")
	#RenderingServer.global_shader_parameter_remove("global_shader_time")


func _on_selection_changed():
	var selection = _editor_selection.get_selected_nodes()
	var selected_node: Node
	if not selection.is_empty():
		selected_node = selection[0]
	if selected_node is VertexAnimationMeshPlayer or selected_node is VertexAnimationMultiMeshPlayer:
		make_bottom_panel_item_visible(_animation_editor_player_panel)
	_animation_editor_player_panel.initialize(selected_node)
