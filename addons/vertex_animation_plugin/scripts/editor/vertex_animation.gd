class_name VertexAnimation extends Resource

@export var name: String
@export var start_frame: float
@export var frame_count: float
@export var speed := 1.0


func init(name: String, start_frame: float, frame_count: float) -> void:
	self.name = name
	self.start_frame = start_frame
	self.frame_count = frame_count