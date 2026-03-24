@tool 
extends Node2D

var _is_searching = false 

# ==========================================
# 1. 雷达面板：只要打勾，立刻拆墙，再去搜图纸！
# ==========================================
@export_flags("北 (North):1", "东 (East):2", "南 (South):4", "西 (West):8") var quick_setup_doors: int = 0:
	set(value):
		if quick_setup_doors == value: return
		quick_setup_doors = value
		
		# 第一时间强行刷新墙壁！
		if is_node_ready():
			update_walls_visibility()
			
		# 然后再去硬盘里翻图纸
		if Engine.is_editor_hint() and not _is_searching:
			search_and_apply_room_data()

# ==========================================
# 2. 图纸槽位：如果被塞了新图纸，才去同步雷达面板
# ==========================================
@export var data: RoomData:
	set(value):
		if data != null and data.changed.is_connected(refresh_editor_preview):
			data.changed.disconnect(refresh_editor_preview)
		
		data = value
		
		if data != null:
			if not data.changed.is_connected(refresh_editor_preview):
				data.changed.connect(refresh_editor_preview)
				
			# 【修复核心】：只有塞入新图纸时，雷达面板才跟着图纸变！
			_is_searching = true
			quick_setup_doors = data.doors_bitmask
			_is_searching = false
			
		if is_node_ready():
			refresh_editor_preview()

@export_category("模块专属视觉 (覆盖底色)")
@export var local_texture: Texture2D:
	set(value):
		local_texture = value
		if is_node_ready():
			refresh_editor_preview()

@onready var bg = $ColorRect
@onready var label = $Label
@onready var wall_north = $WallNorth
@onready var wall_east = $WallEast
@onready var wall_south = $WallSouth
@onready var wall_west = $WallWest
@onready var floor_sprite = $FloorSprite

func _ready():
	if data != null and not data.changed.is_connected(refresh_editor_preview):
		data.changed.connect(refresh_editor_preview)
	refresh_editor_preview()

func search_and_apply_room_data():
	_is_searching = true
	var path = "res://ROOM/"
	var dir = DirAccess.open(path)
	var found = false
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var res = load(path + file_name) as RoomData
				if res != null and res.doors_bitmask == quick_setup_doors:
					self.data = res 
					found = true
					break
			file_name = dir.get_next()
			
	if not found:
		print("【罗盘警告】未找到对应门向的图纸！临时变为空地砖！")
		self.data = null # 没找到图纸就清空，但墙壁依然会保留你勾选的缺口
		
	_is_searching = false

# ==========================================
# 独立拆墙逻辑（绝对服从 quick_setup_doors）
# ==========================================
func update_walls_visibility():
	if not is_node_ready(): return
	wall_north.visible = (quick_setup_doors & 1) == 0
	wall_east.visible  = (quick_setup_doors & 2) == 0
	wall_south.visible = (quick_setup_doors & 4) == 0
	wall_west.visible  = (quick_setup_doors & 8) == 0

func refresh_editor_preview():
	if not is_node_ready(): return
	update_walls_visibility()
	setup(data)

# ==========================================
# 游戏运行时的原版逻辑 + 贴图自适应系统
# ==========================================
func setup(room_data: RoomData):
	if local_texture != null:
		floor_sprite.texture = local_texture
		floor_sprite.visible = true
		bg.visible = false 
		var tex_size = local_texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			floor_sprite.scale = Vector2(512.0 / tex_size.x, 512.0 / tex_size.y)
	else:
		floor_sprite.visible = false
		bg.visible = true 
		
	# 【修复安全锁】：如果没有图纸，显示灰色空地砖
	if room_data == null:
		bg.color = Color(0.4, 0.4, 0.4)
		label.text = "空地砖"
		label.modulate = Color(1, 1, 1)
		return
		
	if room_data.room_type == "塌方":
		bg.color = Color(0.25, 0.18, 0.1) 
		label.text = "✖\n塌方"
		label.modulate = Color(0.9, 0.6, 0.2) 
	elif room_data.doors_bitmask == 0:
		bg.color = Color(0.05, 0.05, 0.08) 
		label.text = "深渊\n裂缝"
		label.modulate = Color(0.4, 0.4, 0.5) 
	else:
		label.text = room_data.room_name
		label.modulate = Color(1, 1, 1) 
		if room_data.room_type == "宝藏":
			bg.color = Color(0.8, 0.6, 0.2)
		elif room_data.room_type == "起点":
			bg.color = Color(0.2, 0.6, 0.2)
		else:
			bg.color = Color(0.4, 0.4, 0.4) 

func set_walls(n: bool, e: bool, s: bool, w: bool):
	wall_north.visible = n
	wall_east.visible = e
	wall_south.visible = s
	wall_west.visible = w
