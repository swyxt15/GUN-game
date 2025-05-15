extends CharacterBody2D


const HEALTH = 100

const DETECT_PLAYER_RANGE = 6*16
const UNDETECT_PLAYER_RANGE = 9*16
const SPEED = 35 * 60
const WATER_SPEED = 300

const OFFSET_WATER = Vector2(0,-7)

@onready var Player = $"../Player"

@onready var Sprite = $"AnimatedSprite2D"
@onready var Collision = $"CollisionShape2D"
@onready var Hurt_hitbox = $"Hurt_hitbox/CollisionShape2D"
@onready var Cooldown_animation = $"Cooldown_animation"
@onready var Attack_timer = $"Attack_timer"

@onready var tile_map_layer = $"../TileMap/Layer0"

var Water = preload("res://scenes/water.tscn")

var health = HEALTH

var on_screen : bool
var was_on_screen : bool
var last_pos : Vector2

var is_touching_ink = {"red" : 0}

var player_detected = false

var facing : int

var initial_position : Vector2

func _ready() -> void:
	Sprite.animation = "idle"
	initial_position = position
	facing = 1 if Sprite.flip_h else -1
	last_pos = position

func _physics_process(delta: float) -> void:
	var offscreen = Player.check_if_offscreen(["left","right","top","bottom"],0,delta,Player.Camera,self)
	on_screen = offscreen[0] or offscreen[1] or offscreen[2] or offscreen[3]
	on_screen = !on_screen
	if ((not was_on_screen) and on_screen) or (Player.reload_room and on_screen and dead):
		Sprite.visible = true
		Collision.disabled = false
		Hurt_hitbox.disabled = false
		health = HEALTH
		position = initial_position
		dead = false
		change_animation("idle",true)
	elif Player.reload_room and on_screen and not dead:
		Attack_timer.stop()
		health = HEALTH
		position = initial_position
	if on_screen:
		if is_touching_ink["red"]:
			player_detected = true
			take_damage(Player.BRUSH_INK_DAMAGE)
		if not Player.transition:
			if (position.distance_to(Player.position) <= DETECT_PLAYER_RANGE or (position.distance_to(Player.position) <= UNDETECT_PLAYER_RANGE and player_detected)) and Cooldown_animation.is_stopped() and abs(Player.position.x - position.x) > 1 and not dead and not Player.dead:
				player_detected = true
				
				if cos(position.angle_to_point(Player.position)) > 0:
					Sprite.flip_h = true
					facing = 1
					velocity.x = SPEED * delta
				else:
					Sprite.flip_h = false
					facing = -1
					velocity.x = -SPEED * delta
				
				var pos = Vector2(global_position.x + 17.0 * facing,global_position.y + 5)
				
				var cell = tile_map_layer.local_to_map(tile_map_layer.to_local(pos))
				var data = tile_map_layer.get_cell_tile_data(cell)
				
				if not data:
					velocity.x = 0
				
				pos = Vector2(global_position.x + 17.0 * facing,global_position.y - 5)
				
				cell = tile_map_layer.local_to_map(tile_map_layer.to_local(pos))
				data = tile_map_layer.get_cell_tile_data(cell)
				
				if data:
					velocity.x = 0
				
				if Sprite.animation != "attack" and velocity.x != 0:
					change_animation("move")
				else:
					if Sprite.animation != "attack":
						change_animation("idle")
				
			else:
				player_detected = false
				if Sprite.animation == "move":
					change_animation("idle")
				velocity.x = move_toward(velocity.x, 0, SPEED)
			
			if (position.distance_to(Player.position) <= DETECT_PLAYER_RANGE or (position.distance_to(Player.position) <= UNDETECT_PLAYER_RANGE and player_detected)) and not dead:
				if Attack_timer.is_stopped():
					Attack_timer.start()
	else:
		if not Player.transition:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			Sprite.visible = false
			Collision.disabled = true
			Hurt_hitbox.disabled = true
		else:
			for node in childs:
				node.kill()
				childs.erase(node)
	if last_pos == position:
		Sprite.global_position.x = round(global_position.x)
		Sprite.global_position.y = round(global_position.y) - 12
	was_on_screen = on_screen
	move_and_slide()
	last_pos = position

func take_damage(amount : int) -> void:
	if dead:
		return

	health -= amount
	if health <= 0:
		kill()
		return
	else:
		if Cooldown_animation.is_stopped() and Sprite.animation != "attack":
			print(Sprite.animation)
			Cooldown_animation.start()
			change_animation("hurt")
		flicker()

func flicker() -> void:
	var tween = create_tween()
	tween.tween_property(Sprite,"material:shader_parameter/amount", 1.0, 0.0)
	tween.tween_property(Sprite,"material:shader_parameter/amount", 0.0, 0.2)

func _on_cooldown_animation_timeout() -> void:
	change_animation("idle")

var dead = false

func kill() -> void:
	Attack_timer.stop()
	dead = true
	Cooldown_animation.start()
	Collision.set_deferred("disabled",true)
	Hurt_hitbox.set_deferred("disabled",true)
	change_animation("die")
	flicker()
	for node in childs:
		node.kill()
		childs.erase(node)
	await get_tree().create_timer(0.4).timeout
	Sprite.visible = false
	change_animation("idle")

func _on_hurt_hitbox_area_entered(_area: Area2D) -> void:
	if health > 0:
		take_damage(Player.BRUSH_DAMAGE)


func _on_attack_timer_timeout() -> void:
	if dead:
		return
	
	Cooldown_animation.stop()
	change_animation("attack")
	await get_tree().create_timer(0.3).timeout
	var aim_pos = Player.global_position
	aim_pos.y -= UNDETECT_PLAYER_RANGE - abs(global_position.x - aim_pos.x)
	if abs(global_position.y - Player.position.y) < 15:
		aim_pos.x = aim_pos.x * 0.5 + global_position.x * 0.5
	aim_pos = global_position.angle_to_point(aim_pos)
	create_water(OFFSET_WATER,WATER_SPEED,aim_pos)
	await get_tree().create_timer(0.2).timeout
	if velocity.x == 0:
		change_animation("idle")
	else:
		change_animation("move")

func change_animation(animation : String, bypass : bool = false) -> void:
	if Sprite.animation != "die" or bypass:
		Player.change_animation(animation,true,Sprite)

var childs = []

func create_water(offset : Vector2, velo : int, water_angle : float) -> void:
	var water_instance = Water.instantiate()
	
	var pos = get_global_position()
	pos.y += offset.y
	pos.x += offset.x * facing
	
	water_instance.position = pos
	water_instance.velo = velo
	water_instance.angle = water_angle
	water_instance.Parent = self
	water_instance.facing = facing
	get_parent().add_child(water_instance)
	childs.append(water_instance)
