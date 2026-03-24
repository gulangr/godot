extends Camera2D

# ==========================================
# 镜头控制参数 (可以在右侧面板随时调手感)
# ==========================================
@export var pan_speed: float = 500.0  # 键盘移动的速度
@export var zoom_speed: float = 0.05   # 每次滚轮缩放的幅度
@export var min_zoom: float = 0.05     # 缩小极限（能看清全图的程度）
@export var max_zoom: float = 2.0     # 放大极限（贴地观察的程度）

var is_dragging: bool = false # 记录当前是否按住了鼠标右键

# ==========================================
# 键盘控制：平滑移动视角
# ==========================================
func _process(delta):
	var input_dir = Vector2.ZERO
	
	# 监听 WASD 或 上下左右 方向键
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1

	# 如果有按键按下，就移动摄像机
	if input_dir != Vector2.ZERO:
		# 这里的除以 zoom.x 是神来之笔：保证在你缩小地图时，键盘移动的速度也会成比例加快，手感极佳！
		position += input_dir.normalized() * pan_speed * delta / zoom.x


# ==========================================
# 鼠标控制：拖拽与缩放
# ==========================================
func _unhandled_input(event):
	if event is InputEventMouseButton:
		# 1. 拖拽逻辑 (保留你原来的代码)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging = true
			else:
				is_dragging = false
				
		# 2. 滚轮缩放逻辑 (保留你原来的代码)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var new_zoom = clamp(zoom.x + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)
			
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var new_zoom = clamp(zoom.x - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)

		# ==========================================
		# 【全新加入】：中键双击，一键还原 100% 视野！
		# ==========================================
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.double_click:
			zoom = Vector2(1.0, 1.0)
			print("罗盘视距已重置为 100% (1.0x)")

	# 3. 处理鼠标拖拽移动 (保留你原来的代码)
	if event is InputEventMouseMotion and is_dragging:
		position -= event.relative / zoom.x
