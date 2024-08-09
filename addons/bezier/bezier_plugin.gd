@tool
extends EditorPlugin

const HANDLE_SIZE = Vector2.ONE * 10
var bezier = null
var dragged_handle = null
var hover_handle = null
var handles = []
var shift_pressed = false;
var ctrl_pressed = false;

func _enter_tree():
	dragged_handle = null
	hover_handle = null
	shift_pressed = false
	ctrl_pressed = false

	update_overlays()
	
func _edit(object):
	bezier = object as Bezier
	
func _handles(object):
	return object is Bezier

func _forward_canvas_draw_over_viewport(overlay):
	if not bezier or not bezier.is_inside_tree():
		return
		
	handles = []
	for i in range(bezier.points.size()):
		var p = bezier.points[i]
		var handle_center = bezier.get_viewport_transform() * bezier.get_global_transform() * p
		handles.append({
			'index': i,
			'position': p,
			'screen_position': handle_center,
			'rect': Rect2(handle_center - HANDLE_SIZE, 2*HANDLE_SIZE)
		})
		
		if bezier.in_curve(i):
			overlay.draw_circle(handle_center, HANDLE_SIZE.x * (1.5 if hover_handle!=null and i == hover_handle['index'] else 1.0), Color.LIGHT_CORAL)
			overlay.draw_circle(handle_center, HANDLE_SIZE.x*0.6, Color.WHITE)
		else:
			overlay.draw_circle(handle_center, HANDLE_SIZE.x*0.5, Color.LIGHT_CORAL)
			overlay.draw_line(handle_center, local_to_screen(bezier.points[bezier.get_affected_curve_point(i)]), Color.LIGHT_CORAL)
			

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not bezier or not bezier.visible :
		return false
	
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		shift_pressed = event.is_pressed()
		return true
	if event is InputEventKey and event.keycode == KEY_CTRL:
		ctrl_pressed = event.is_pressed()
		return true
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			if ctrl_pressed and hover_handle!=null:
				bezier.delete_point(hover_handle['index'])
				return true
			if not dragged_handle and shift_pressed:
				bezier.add_point(screen_to_local(event.position))
				return true
				
		# START DRAGGING
		if not dragged_handle and hover_handle:
			dragged_handle = hover_handle
			return true
				
	# FINISH DRAGGING
		elif dragged_handle:
			drag_handle(event.position)
			dragged_handle = null
			return true
			
		return false
				
	if event is InputEventMouseMotion:
		hover_handle = null
	
		for h in handles:
			if not h['rect'].has_point(event.position):
				continue
			hover_handle = h
		
		drag_handle(event.position)
		update_overlays()
		return true
	if event.is_action_pressed("ui_cancel"):
		dragged_handle = null
		get_undo_redo().commit_action()
		get_undo_redo().undo()
		return true
		
	return false
	
func drag_handle(event_pos: Vector2):
	if not dragged_handle:
		return
	
	bezier.move_point(dragged_handle['index'], screen_to_local(event_pos))

func screen_to_local(screen_coor: Vector2):
	var viewport_transform_inverted = bezier.get_viewport().get_global_canvas_transform().affine_inverse()
	var viewport_pos =  viewport_transform_inverted * screen_coor
	var global_transform_inverted = bezier.get_global_transform().affine_inverse()
	return (global_transform_inverted * viewport_pos).round()
	
func local_to_screen(local_coor: Vector2):
	return bezier.get_viewport_transform() * bezier.get_global_transform() * local_coor
