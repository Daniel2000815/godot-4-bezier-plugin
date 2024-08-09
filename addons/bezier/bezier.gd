@tool
@icon("res://addons/bezier/bezier_icon.svg")
extends Node2D
class_name Bezier

const draw_point_count : int = 100

@export_category("Debug")
@export var reset: bool:
	set(value):
		set_points(PackedVector2Array([Vector2(0, 0), Vector2(100, 50), Vector2(200, -50), Vector2(300, 0)]))
		pathColor = Color.FLORAL_WHITE
		arrowColor = Color.AQUAMARINE
		rotate_speed = 0.0
		rotation = 0.0
		flip_h = false
		flip_v = false
		draw_width = 5.0

@export var circle_radius: float
@export var make_circle: bool:
	set(value):
		set_points_circle(circle_radius)
		
@export_category("Appearance")
@export var draw_arrows: bool = true
@export var dash_amount : int = 10
@export var rotate_speed: float = 0.0
@export var animation: bool = true
var animation_t : float = 0.0
@export var pathColor: Color = Color.FLORAL_WHITE
@export var arrowColor: Color = Color.AQUAMARINE
@export var draw_width : float = 5.0

@export_category("Properties")
@export var force_C1: bool:
	set(value):
		force_C1 = value
		if(value):
			allow_sharp_corners = false
			make_controls_equidistant()
		
@export var allow_sharp_corners: bool:
	set(value):
		allow_sharp_corners = value
		if not value:
			make_controls_aligned()
		else:
			force_C1 = false
		
@export var points : PackedVector2Array : set = set_points

@export var flip_h : bool :
	set(value):
		if value != flip_h:
			flip_h = value
			var new_points : PackedVector2Array = []
			for p in points:
				new_points.push_back(Vector2(-p.x, p.y))
				set_points(new_points)

@export var flip_v : bool :
	set(value):
		if value != flip_v:
			flip_v = value
			var new_points : PackedVector2Array = []
			for p in points:
				new_points.push_back(Vector2(p.x, -p.y))
				set_points(new_points)

class MovingObject:
	var node: Node2D = null
	var t : float = 0.0
	var total_time = 0.0
	var align_rot = false

	signal 	on_finish
	
var moving_objects : Array[MovingObject] = []
	
func _enter_tree():
	if points==null or points.size()==0:
		set_points(PackedVector2Array([Vector2(0, 0), Vector2(100, 50), Vector2(200, -50), Vector2(300, 0)]))
	moving_objects = []
	flip_h = false;
	flip_v = false;

func set_points(value : PackedVector2Array):
	points = value
	queue_redraw()

func add_point(pos: Vector2):
	points.append(points[-1] - (points[-2] - points[-1]))
	points.append(points[-1] + pos/2)
	points.append(pos)
	
	queue_redraw()
	
func delete_point(idx: int) -> bool:
	if is_control(idx) or n_segments()<2:
		return false
		
	if idx == 0:
		points = points.slice(3)
	elif idx == points.size()-1:
		points = points.slice(0, idx-2)
	else:
		points.remove_at(idx-1)
		points.remove_at(idx-1)
		points.remove_at(idx-1)
		
	return true

func set_points_circle(radius: float):
	var a = 1.00005519 * radius
	var b = 0.55342686 * radius
	var c = 0.99873585 * radius

	set_points(PackedVector2Array([
		Vector2(0, a), Vector2(b, c), Vector2(c, b), Vector2(a, 0),
		Vector2(c, -b), Vector2(b, -c), Vector2(0, -a),
		Vector2(-b,-c), Vector2(-c, -b), Vector2(-a, 0),
		Vector2(-c, b), Vector2(-b, c), Vector2(0, a)
	]))
	

func in_curve(idx: int) -> bool:
	return idx>=0 and idx<points.size() and idx%3 == 0
	
func is_control(idx: int) -> bool:
	return idx>=0 and idx<points.size() and not in_curve(idx)

func get_point(idx: int) -> Vector2:
	if idx>=0 and idx<points.size():
		return points[idx]

	return points[0]

func get_opposite_control(idx: int) -> int:
	if in_curve(idx):
		return -1
	if in_curve(idx+1) and is_control(idx+2):
		return idx+2
	elif is_control(idx-2):
		return idx-2
		
	return -1
	
	
func get_affected_curve_point(idx: int):
	if in_curve(idx):
		return idx
		
	elif in_curve(idx-1): return idx-1
	elif in_curve(idx+1): return idx+1
	
func move_point(idx: int, value: Vector2):
	if idx<0 or idx>=points.size():
		return
		
	var delta = points[idx] - value
	points[idx] = value
	
	if in_curve(idx):
		if idx>0:	points[idx-1] -= delta
		if idx<points.size()-1: points[idx+1] -= delta
	else:
		var other_control = get_opposite_control(idx)
		if other_control != -1:
			var dir = (points[get_affected_curve_point(idx)] - points[idx]).normalized()
			
			if force_C1:
				points[get_opposite_control(idx)] = 2*points[get_affected_curve_point(idx)] - points[idx]
			elif not allow_sharp_corners:
				var other_control_dst = (points[get_opposite_control(idx)] - points[get_affected_curve_point(idx)]).length()
				points[get_opposite_control(idx)] = points[get_affected_curve_point(idx)] + dir*other_control_dst
			else:
				points[idx] = value
				
func make_controls_equidistant():
	for i in range(n_segments()-1):
		points[3*i+4] = 2*points[3*i+3] - points[3*i+2]
		
func make_controls_aligned():
	for i in range(n_segments()-1):
		var dir = (points[3*i+2] - points[3*i+3])
		points[3*i+4] = points[3*i+3]-dir.normalized()*(points[3*i+4] - points[3*i+3]).length()
		
func n_segments() -> int:
	return points.size() / 3
	
func draw_segment(segment_index):
	var curve_points = PackedVector2Array()
	
	for i in range(draw_point_count):

		if dash_amount==0 || ((i)/(draw_point_count/(2*dash_amount)))%2 == 1:
			var t = float(i) / (draw_point_count-1)
			var point = eval_segment(segment_index,t)
			curve_points.append(point)
		
		elif curve_points.size() >=2:
			draw_polyline(curve_points, pathColor, draw_width)
			curve_points = PackedVector2Array()

	if curve_points.size() >=2:
		draw_polyline(curve_points, pathColor, draw_width)

func draw_arrow(t: float):
	var p = eval(wrap(t, 0.0, 1.0))
	var dir = eval_deriv(wrap(t, 0.0, 1.0)).normalized() * 7
	var arrowHead = p + dir
	
	draw_polyline(PackedVector2Array([p+Vector2(-dir.y, dir.x), arrowHead, p+Vector2(dir.y, -dir.x)]), arrowColor, 4)
	
func _draw():
	if(points.size() == 0 or not animation):
		return
		
	for i in range(n_segments()):
		draw_segment(i)

	animation_t += 0.001/n_segments()
	var n_arrows = n_segments() * 4

	if draw_arrows:
		for i in range(n_arrows):
			draw_arrow(animation_t - (float)(i)/n_arrows)

func _process(delta):
	if animation and Engine.is_editor_hint():
		queue_redraw()
		
	rotation = fposmod(rotation + rotate_speed * delta, 360)
	if moving_objects.size() > 0:
		for i in range(moving_objects.size()):
			moving_objects[i].t += delta/moving_objects[i].total_time
			if moving_objects[i].t < 1.0:
				moving_objects[i].node.global_position = global_position + eval(moving_objects[i].t)
				if(moving_objects[i].align_rot):
					moving_objects[i].node.rotation = eval_deriv(moving_objects[i].t).angle()
			else:
				moving_objects[i].on_finish.emit()

		moving_objects = moving_objects.filter(func(m): return m.t < 1.0)

func eval_segment(segment_index: int, t: float):
	return cubic_bezier(points[3*segment_index], points[3*segment_index+1], points[3*segment_index+2], points[3*segment_index+3], t)
	
func eval_segment_deriv(segment_index: int, t: float):
	return cubic_bezier_deriv(points[3*segment_index], points[3*segment_index+1], points[3*segment_index+2], points[3*segment_index+3], t)
	
func eval(t: float):
	var u = t*n_segments()
	var segment = int(u)
	var local_t = u - segment

	return eval_segment(segment, local_t) 
	
func eval_deriv(t: float):
	var u = t*n_segments()
	var segment = int(u)
	var local_t = u - segment
	
	return eval_segment_deriv(segment, local_t)
	
func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float):
	return pow(1-t,3)*p0 + 3*pow(1-t,2)*t*p1 + 3*(1-t)*t*t*p2 + t*t*t*p3
	
func cubic_bezier_deriv(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float):
	return 3*pow(1-t,2)*(p1-p0) + 6*(1-t)*t*(p2-p1) + 3*t*t*(p3-p2)
	
func move_node_along_path(node: Node2D, time: float, on_finish_action: Callable = func() : return, align_rot: bool = false):
	var m = MovingObject.new()
	m.node = node
	m.total_time = time
	m.t = 0.0
	m.on_finish.connect(on_finish_action)
	m.align_rot = align_rot
	
	moving_objects.push_back(m)

	

