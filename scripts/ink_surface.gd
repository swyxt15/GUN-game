extends Area2D


@onready var ink = self.get_parent()

func _on_body_entered(body: Node2D) -> void:
	if "is_touching_ink" in body:
		if ink.color_to_node[ink.modulate] in body.is_touching_ink.keys():
			body.is_touching_ink[ink.color_to_node[ink.modulate]] += 1
			if ink.color_to_node[ink.modulate] == "red":
				ink.will_kill = true
				return
			elif ink.color_to_node[ink.modulate] == "blue" and "blue_portals" in body:
				if len(body.blue_portals) == 2 and not body.teleported:
					var index_ink_portal = body.blue_portals.find(ink)
					body.teleported = true
					var pos = body.blue_portals[(index_ink_portal + 1) % 2].position
					var rot = round(body.blue_portals[(index_ink_portal + 1) % 2].rotation / PI * 2)
					if rot == 0:
						pass
					elif rot == 1:
						pos.x += 5
					elif rot == -1:
						pos.x -= 5
					else:
						pos.y += 26
					
					body.position = pos
					body.velocity = Vector2(0,0)

func _on_body_exited(body: Node2D) -> void:
	if "is_touching_ink" in body:
		if ink.color_to_node[ink.modulate] in body.is_touching_ink.keys():
			body.is_touching_ink[ink.color_to_node[ink.modulate]] -= 1
			if ink.color_to_node[ink.modulate] == "blue" and "blue_portals" in body:
				if body.teleported and body.is_touching_ink["blue"] == 0:
					body.teleported = false
