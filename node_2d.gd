extends Node2D

const MAP_CAVE_PATH: String = "C:/Users/maxim/OneDrive/Документы/nightmare/maps/пещера 1.jpg"
const MAP_BOSS_PATH: String = "C:/Users/maxim/OneDrive/Документы/nightmare/maps/арена босс первая пещера.jpg"

# Если true — показывает контуры стен прямо в игре для визуального контроля
const DEBUG_DRAW_COLLISION: bool = true

var bg_sprite: Sprite2D
var player: CharacterBody2D
var door_trigger: Area2D
var camera: Camera2D
var walls_body: StaticBody2D

var is_first_cave: bool = true

var bgm_player: AudioStreamPlayer
var sfx_teleport: AudioStreamPlayer
var debug_lines: Array = []

func _ready() -> void:
	# 1. Задний фон
	bg_sprite = Sprite2D.new()
	bg_sprite.centered = false
	add_child(bg_sprite)

	# 2. Физические стены
	walls_body = StaticBody2D.new()
	walls_body.name = "WallsCollision"
	add_child(walls_body)

	# 3. Аудиосистема
	_setup_audio_system()

	# 4. Игрок
	_create_player()

	# 5. Триггер перехода
	_create_door_trigger()

	# 6. Загрузка 1 локации
	load_cave_1()

func _draw() -> void:
	if DEBUG_DRAW_COLLISION and is_first_cave:
		for line in debug_lines:
			draw_line(line[0], line[1], Color(0.2, 1.0, 0.4, 0.6), 2.5)

# --- СПОКОЙНАЯ ФОНОВАЯ МЕЛОДИЯ ---
func _setup_audio_system() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BackgroundMusic"
	bgm_player.stream = _generate_relaxing_music_stream()
	bgm_player.volume_db = -12.0
	add_child(bgm_player)
	bgm_player.play()

	sfx_teleport = AudioStreamPlayer.new()
	sfx_teleport.name = "TeleportSound"
	sfx_teleport.stream = _generate_teleport_stream()
	sfx_teleport.volume_db = -7.0
	add_child(sfx_teleport)

func _generate_relaxing_music_stream() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 12.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()

	var melody_notes = [349.23, 440.00, 523.25, 659.25, 587.33, 440.00]

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var pad = sin(2.0 * PI * 174.61 * t) * 0.12 + sin(2.0 * PI * 261.63 * t) * 0.08
		var step = int(t / 2.0) % melody_notes.size()
		var freq = melody_notes[step]
		var local_t = fmod(t, 2.0)
		var bell_env = exp(-local_t * 1.8) * sin(PI * clamp(local_t / 0.1, 0.0, 1.0))
		var bell = sin(2.0 * PI * freq * t) * 0.22 * bell_env
		var mixed = (pad + bell) * 0.55
		var sample = int(clamp(mixed, -1.0, 1.0) * 127.0)
		data.append(sample & 0xFF)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	wav.data = data
	return wav

func _generate_teleport_stream() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.8
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = lerp(260.0, 620.0, t)
		var env = sin(PI * (t / duration))
		var wave = sin(2.0 * PI * freq * t)
		var sample = int(clamp(wave * env, -1.0, 1.0) * 127.0)
		data.append(sample & 0xFF)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

# --- ЗАГРУЗКА КАРТИНОК ---
func _load_image_texture(path: String) -> Texture2D:
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	push_error("Не удалось найти файл по пути: " + path)
	return null

# --- 1. ПЕРВАЯ ЛОКАЦИЯ (ПЕЩЕРА 1) ---
func load_cave_1() -> void:
	is_first_cave = true
	_clear_walls()

	var tex = _load_image_texture(MAP_CAVE_PATH)
	if not tex:
		return
	bg_sprite.texture = tex
	var size = tex.get_size()

	camera.reparent(player)
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(1.5, 1.5)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	camera.limit_smoothed = true

	# Спавн в центре фиолетового круга в нижнем левом зале
	player.position = Vector2(size.x * 0.135, size.y * 0.785)

	# Триггер северной арки
	door_trigger.position = Vector2(size.x * 0.825, size.y * 0.11)
	door_trigger.monitoring = true

	_build_cave_walls(size)
	queue_redraw()

# --- 2. ВТОРАЯ ЛОКАЦИЯ (АРЕНА БОССА) ---
func load_boss_arena() -> void:
	is_first_cave = false
	door_trigger.monitoring = false
	_clear_walls()
	debug_lines.clear()
	queue_redraw()

	sfx_teleport.play()

	var tex = _load_image_texture(MAP_BOSS_PATH)
	if not tex:
		return
	bg_sprite.texture = tex
	var size = tex.get_size()

	player.position = Vector2(size.x * 0.5, size.y * 0.88)

	camera.reparent(self)
	camera.position = size * 0.5
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000

	var vp_size = get_viewport_rect().size
	var zoom_factor = min(vp_size.x / size.x, vp_size.y / size.y)
	camera.zoom = Vector2(zoom_factor, zoom_factor)

	_build_arena_walls(size)

# --- СТРОИТЕЛЬСТВО СТЕНОК ---
func _clear_walls() -> void:
	debug_lines.clear()
	for child in walls_body.get_children():
		child.queue_free()

func _add_wall_segment(a: Vector2, b: Vector2) -> void:
	var col = CollisionShape2D.new()
	var segment = SegmentShape2D.new()
	segment.a = a
	segment.b = b
	col.shape = segment
	walls_body.add_child(col)
	debug_lines.append([a, b])

func _add_polygon_boundary(points: PackedVector2Array) -> void:
	var count = points.size()
	for i in range(count):
		_add_wall_segment(points[i], points[(i + 1) % count])

func _add_circle_col(pos: Vector2, radius: float) -> void:
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	col.position = pos
	walls_body.add_child(col)

func _build_cave_walls(s: Vector2) -> void:
	# СПЛОШНОЙ ПЕРИМЕТР ВСЕХ ЗАЛОВ И ПРОХОДОВ КАРТЫ:
	# Все проходы шириной не менее 60-80 пикселей для идеального перемещения
	var cave_outer_walls = PackedVector2Array([
		# Стартовый зал: левая стенка и дно
		Vector2(s.x * 0.045, s.y * 0.91),
		Vector2(s.x * 0.045, s.y * 0.58),
		Vector2(s.x * 0.10, s.y * 0.58),
		Vector2(s.x * 0.10, s.y * 0.44),

		# Левый верхний зал (тупик с кристаллами)
		Vector2(s.x * 0.045, s.y * 0.44),
		Vector2(s.x * 0.045, s.y * 0.12),
		Vector2(s.x * 0.22, s.y * 0.12),
		Vector2(s.x * 0.22, s.y * 0.44),
		Vector2(s.x * 0.18, s.y * 0.44),
		Vector2(s.x * 0.18, s.y * 0.60),
		Vector2(s.x * 0.22, s.y * 0.60),

		# Нижний туманный коридор (широкий проход направо)
		Vector2(s.x * 0.22, s.y * 0.72),
		Vector2(s.x * 0.40, s.y * 0.72),
		Vector2(s.x * 0.40, s.y * 0.58),

		# Центральный зал
		Vector2(s.x * 0.26, s.y * 0.58),
		Vector2(s.x * 0.26, s.y * 0.15),
		Vector2(s.x * 0.63, s.y * 0.15),
		Vector2(s.x * 0.63, s.y * 0.35),
		Vector2(s.x * 0.69, s.y * 0.35),

		# Верхний зал с аркой босса
		Vector2(s.x * 0.69, s.y * 0.09),
		Vector2(s.x * 0.96, s.y * 0.09),
		Vector2(s.x * 0.96, s.y * 0.52),
		Vector2(s.x * 0.88, s.y * 0.52),

		# Правый нижний зал (зона валунов)
		Vector2(s.x * 0.88, s.y * 0.91),
		Vector2(s.x * 0.56, s.y * 0.91),
		Vector2(s.x * 0.56, s.y * 0.53),
		Vector2(s.x * 0.42, s.y * 0.53),
		Vector2(s.x * 0.42, s.y * 0.84),
		Vector2(s.x * 0.22, s.y * 0.84),
		Vector2(s.x * 0.22, s.y * 0.91)
	])
	_add_polygon_boundary(cave_outer_walls)

	# ВНУТРЕННИЙ ОСТРОВ СКАЛ (разделитель нижнего коридора и центра)
	var rock_island = PackedVector2Array([
		Vector2(s.x * 0.28, s.y * 0.38),
		Vector2(s.x * 0.34, s.y * 0.38),
		Vector2(s.x * 0.34, s.y * 0.62),
		Vector2(s.x * 0.28, s.y * 0.62)
	])
	_add_polygon_boundary(rock_island)

	# Одиночные крупные валуны в правом зале
	_add_circle_col(Vector2(s.x * 0.68, s.y * 0.71), 18.0)
	_add_circle_col(Vector2(s.x * 0.75, s.y * 0.68), 16.0)
	_add_circle_col(Vector2(s.x * 0.67, s.y * 0.83), 18.0)
	_add_circle_col(Vector2(s.x * 0.86, s.y * 0.77), 20.0)

func _build_arena_walls(s: Vector2) -> void:
	var center = Vector2(s.x * 0.5, s.y * 0.52)
	var radius_x = s.x * 0.44
	var radius_y = s.y * 0.42
	var points_count = 36

	var prev_pt = center + Vector2(cos(0) * radius_x, sin(0) * radius_y)
	for i in range(1, points_count + 1):
		var angle = (float(i) / points_count) * TAU
		var cur_pt = center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		_add_wall_segment(prev_pt, cur_pt)
		prev_pt = cur_pt

# --- ИГРОК ---
func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"

	var mesh = MeshInstance2D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(24, 34)
	mesh.mesh = quad
	mesh.modulate = Color(0.2, 0.65, 1.0)
	player.add_child(mesh)

	# Точечный круг коллизии (7 px) строго в ногах персонажа
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 7.0
	col.shape = shape
	col.position = Vector2(0, 8)
	player.add_child(col)

	camera = Camera2D.new()
	camera.name = "GameCamera"
	camera.position_smoothing_enabled = true
	add_child(camera)

	var move_code = GDScript.new()
	move_code.source_code = """extends CharacterBody2D

var speed: float = 290.0

func _physics_process(_delta: float) -> void:
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_vec.x += 1.0

	velocity = move_vec.normalized() * speed
	move_and_slide()
"""
	move_code.reload()
	player.set_script(move_code)
	add_child(player)

# --- ТРИГГЕР ПЕРЕХОДА ---
func _create_door_trigger() -> void:
	door_trigger = Area2D.new()
	door_trigger.name = "DoorTrigger"

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50.0
	col.shape = shape
	door_trigger.add_child(col)

	door_trigger.body_entered.connect(_on_door_entered)
	add_child(door_trigger)

func _on_door_entered(body: Node2D) -> void:
	if body == player and is_first_cave:
		load_boss_arena()
