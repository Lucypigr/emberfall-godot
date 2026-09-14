extends Node
# 30 source pixels map to one world unit. All damage/timing values stay in source units.
const SCALE: float = 30.0
var app: Node
var model: EmberfallLoadout
var shots: Array = []
var delayed: Array = []
var fields: Array = []
var effects: Dictionary = {}
var clocks: Dictionary = {}
var leech_budget: float = 8.0
var leech_clock: float = 0.0
var elapsed: float = 0.0

func setup(owner_app: Node, data: EmberfallLoadout) -> void:
    app=owner_app
    model=data
    model.changed.connect(func(): clocks.clear())

func _physics_process(delta: float) -> void:
    if app.player == null: return
    elapsed += delta
    leech_clock += delta
    if leech_clock >= 1.0:
        leech_clock = fmod(leech_clock,1.0)
        leech_budget=8.0
    for row in model.skills():
        var def: Dictionary = model.definition("active:"+row.active)
        if def.has("aura"): continue
        clocks[row.key] = maxf(0,float(clocks.get(row.key,0))-delta)
        if clocks[row.key] <= 0:
            if def.get("trail",false) and app.player.velocity.length() < 0.1: continue
            var target: int = nearest(app.player.global_position,[],16.0)
            if target < 0 and row.active not in ["nova","orbit","cyclone"] and not def.get("trail",false): continue
            var s: Dictionary = model.compile(row)
            clocks[row.key] = 1.0/maxf(0.01,float(s.rate))
            cast(s,target)
            if s.echo: delayed.append({"time":0.22,"stats":s.duplicate(true),"target":target,"kind":"cast"})
    for i in range(delayed.size()-1,-1,-1):
        var event: Dictionary = delayed[i]
        event.time -= delta
        if event.time > 0: continue
        delayed.remove_at(i)
        if event.kind == "cast": cast(event.stats,event.target)
        elif event.kind == "area": area(event.position,event.stats,float(event.stats.radius)/SCALE)
        elif event.kind == "shot": launch(event.stats,event.position,event.direction)
    update_shots(delta)
    update_fields(delta)
    update_effects(delta)

func nearest(point: Vector3, excluded: Array, radius: float) -> int:
    var best: int = -1
    var dist: float = radius
    for entry in app.enemies:
        if entry.id in excluded: continue
        var enemy: CharacterBody3D = entry.node
        if not is_instance_valid(enemy): continue
        var d: float = point.distance_to(enemy.global_position)
        if d < dist: best=entry.id; dist=d
    return best

func position_of(id: int) -> Vector3:
    var index: int = app._enemy_index_by_id(id)
    if index >= 0: return app.enemies[index].node.global_position
    return app.player.global_position + app.last_aim_direction*6

func cast(s: Dictionary, target: int) -> void:
    var origin: Vector3 = app.player.global_position
    var target_pos: Vector3 = position_of(target)
    var def: Dictionary = model.definition("active:"+s.id)
    if def.get("trail",false):
        field(s,origin,0.5)
        return
    match s.id:
        "arc":
            var visited: Array = []
            var point: Vector3 = origin
            var next: int = target
            for hop in range(int(s.chain)+1):
                if next < 0: break
                var destination: Vector3 = position_of(next)
                beam(point,destination,Color(s.color))
                var hit_stats: Dictionary = s.duplicate(true)
                hit_stats.damage *= pow(0.85,hop)
                hit(next,hit_stats)
                visited.append(next)
                point=destination
                next=nearest(point,visited,6.0)
        "nova","shockwave","judgment","phoenix":
            area(origin,s,float(s.radius)/SCALE)
            if s.id == "phoenix": app.player_hp=minf(app.player_max_hp,app.player_hp+app.player_max_hp*0.12)
        "orbit","cyclone": area(origin,s,float(s.radius)/SCALE)
        "meteor","frostbomb","bladefall":
            var delay: float = 0.65 if s.id=="meteor" else (1.0 if s.id=="frostbomb" else 0.1)
            for wave in range(3 if s.id=="bladefall" else 1):
                delayed.append({"time":delay+wave*0.18,"kind":"area","position":target_pos,"stats":s.duplicate(true)})
            app._spawn_hit_flash(target_pos+Vector3.UP*0.1,Color(s.color),1.2)
        "blizzard": field(s,target_pos,0.5)
        "totem": field(s,origin,0.6)
        _:
            var direction: Vector3 = (target_pos-origin).normalized()
            if direction.length() < 0.1: direction=app.last_aim_direction
            for volley in range(4 if s.id=="barrage" else 1):
                for count in range(int(s.count)):
                    var angle: float = (count-(float(s.count)-1)/2.0)*0.15
                    var dir: Vector3 = direction.rotated(Vector3.UP,angle)
                    if volley == 0: launch(s,origin,dir)
                    else: delayed.append({"kind":"shot","time":volley*0.07,"stats":s.duplicate(true),"position":origin,"direction":dir})

func launch(stats: Dictionary, origin: Vector3, direction: Vector3, visited: Array = []) -> void:
    if shots.size() >= 160: return
    var s: Dictionary = stats.duplicate(true)
    var node: Node3D = app._create_orb("GemProjectile",Color(s.color),Color(s.color),0.12,0.22)
    app.projectiles_root.add_child(node)
    node.global_position=origin+Vector3.UP*0.85
    shots.append({"node":node,"stats":s,"direction":direction,"life":float(s.duration) if s.id=="ball" else 2.0,"visited":visited.duplicate(),"returning":false,"pulse":0.0})

func update_shots(delta: float) -> void:
    for i in range(shots.size()-1,-1,-1):
        var shot: Dictionary = shots[i]
        var node: Node3D = shot.node
        var s: Dictionary = shot.stats
        if not is_instance_valid(node): shots.remove_at(i); continue
        shot.life -= delta
        if shot.life <= 0: node.queue_free(); shots.remove_at(i); continue
        if s.returning and shot.life <= 1.0 and not shot.returning:
            shot.returning=true
            shot.visited.clear()
            var back: Vector3 = app.player.global_position-node.global_position
            back.y=0
            shot.direction=back.normalized()
        var start: Vector3 = node.global_position
        var end: Vector3 = start+shot.direction*(float(s.speed)/SCALE)*delta
        # World collision: spark reflects; other projectiles stop at solid terrain.
        var query := PhysicsRayQueryParameters3D.create(start,end)
        query.exclude = [app.player.get_rid()]
        for entry in app.enemies:
            if is_instance_valid(entry.node): query.exclude.append(entry.node.get_rid())
        var wall: Dictionary = app.player.get_world_3d().direct_space_state.intersect_ray(query)
        if not wall.is_empty():
            if int(s.ricochet)>0:
                s.ricochet -= 1
                shot.direction = (shot.direction as Vector3).bounce(wall.normal)
                end=wall.position+wall.normal*0.03
            else: node.queue_free(); shots.remove_at(i); continue
        node.global_position=end
        if s.id=="ball":
            shot.pulse-=delta
            if shot.pulse<=0:
                shot.pulse=0.3
                area(end,s,float(s.radius)/SCALE,false)
            continue
        var collisions: Array = []
        for entry in app.enemies:
            if entry.id in shot.visited or not is_instance_valid(entry.node): continue
            var enemy_pos: Vector3 = entry.node.global_position+Vector3.UP*0.85
            var closest: Vector3 = Geometry3D.get_closest_point_to_segment(enemy_pos,start,end)
            if closest.distance_to(enemy_pos)<0.6:
                collisions.append({"id":entry.id,"distance":start.distance_squared_to(enemy_pos)})
        collisions.sort_custom(func(a,b): return a.distance<b.distance)
        var remove: bool = false
        for collision in collisions:
            var id: int = collision.id
            var point: Vector3 = position_of(id)
            shot.visited.append(id)
            hit(id,s)
            if s.blast>0:
                var splash: Dictionary = s.duplicate(true)
                splash.damage *= 0.45
                area(point,splash,float(s.blast)/SCALE,true,id)
            if s.fork:
                s.fork=false
                var split: Dictionary = s.duplicate(true)
                split.damage *= 0.6
                for angle in [-0.45,0.45]: launch(split,point,shot.direction.rotated(Vector3.UP,angle),shot.visited)
            if int(s.pierce)>0:
                s.pierce-=1
                continue
            if int(s.chain)>0:
                var next: int = nearest(point,shot.visited,6.0)
                if next>=0:
                    s.chain-=1
                    s.damage*=0.85
                    var dir: Vector3 = position_of(next)-point
                    dir.y=0
                    shot.direction=dir.normalized()
                    node.global_position=point+Vector3.UP*0.85
                    break
            remove=true
            break
        if remove: node.queue_free(); shots.remove_at(i)

func hit(id: int, s: Dictionary, dot: bool = false) -> void:
    var index: int = app._enemy_index_by_id(id)
    if index<0: return
    var entry: Dictionary = app.enemies[index]
    var damage: float = float(s.damage)
    if not dot and randf()<float(s.crit): damage*=2.0
    var actual: float = minf(damage,float(entry.hp))
    app._damage_enemy(index,damage)
    if dot: return
    var heal: float = minf(leech_budget,actual*float(s.leech))
    leech_budget-=heal
    app.player_hp=minf(app.player_max_hp,app.player_hp+heal)
    index=app._enemy_index_by_id(id)
    if index<0: return
    entry=app.enemies[index]
    if s.execute and float(entry.hp)<float(entry.max_hp)*0.1:
        app._damage_enemy(index,float(entry.hp)+1)
        return
    var state: Dictionary = effects.get(id,{"slow":0.0,"slow_time":0.0,"burn":0.0,"burn_time":0.0,"poison":0.0,"poison_time":0.0})
    if s.slow>0: state.slow=maxf(state.slow,s.slow); state.slow_time=2.0
    for effect in ["burn","poison"]:
        if s[effect]>0:
            state[effect]=maxf(state[effect],damage*float(s[effect]))
            state[effect+"_time"]=3.0
    effects[id]=state
    if s.knockback>0:
        var enemy: CharacterBody3D = entry.node
        var direction: Vector3 = (enemy.global_position-app.player.global_position).normalized()
        var distance: float = float(s.knockback)/SCALE*(0.5 if entry.elite else 1.0)
        enemy.move_and_collide(direction*distance)

func area(center: Vector3, s: Dictionary, radius: float, flash: bool = true, exclude: int = -1) -> void:
    if flash: app._spawn_hit_flash(center+Vector3.UP*0.3,Color(s.color),maxf(0.5,radius*2))
    var ids: Array = []
    for entry in app.enemies:
        if entry.id == exclude or not is_instance_valid(entry.node): continue
        var point: Vector3 = entry.node.global_position
        point.y=center.y
        if point.distance_to(center)<=radius: ids.append(entry.id)
    for id in ids: hit(id,s)

func field(s: Dictionary, center: Vector3, interval: float) -> void:
    if fields.size()>=48: return
    var marker: Node3D = app._create_orb("SkillField",Color(s.color),Color(s.color),0.10,0.2)
    app.projectiles_root.add_child(marker)
    marker.global_position=center+Vector3.UP*0.15
    fields.append({"stats":s.duplicate(true),"position":center,"life":float(s.duration),"interval":interval,"clock":0.0,"node":marker})

func update_fields(delta: float) -> void:
    for i in range(fields.size()-1,-1,-1):
        var f: Dictionary = fields[i]
        f.life-=delta
        f.clock-=delta
        if f.life<=0: f.node.queue_free(); fields.remove_at(i); continue
        if f.clock>0: continue
        f.clock=f.interval
        if f.stats.id=="totem":
            var target: int = nearest(f.position,[],12.0)
            if target>=0:
                var s: Dictionary = f.stats.duplicate(true)
                s.blast=28
                launch(s,f.position,(position_of(target)-f.position).normalized())
        else: area(f.position,f.stats,float(f.stats.radius)/SCALE)

func update_effects(delta: float) -> void:
    for id in effects.keys():
        var index: int = app._enemy_index_by_id(id)
        if index<0: effects.erase(id); continue
        var state: Dictionary = effects[id]
        state.slow_time=maxf(0,state.slow_time-delta)
        var entry: Dictionary = app.enemies[index]
        if not entry.has("base_speed"): entry.base_speed=entry.archetype.speed
        entry.archetype.speed=float(entry.base_speed)*(1.0-float(state.slow) if state.slow_time>0 else 1.0)
        for effect in ["burn","poison"]:
            var dt: float = minf(delta,float(state[effect+"_time"]))
            if dt>0:
                state[effect+"_time"]-=dt
                var fresh_index: int = app._enemy_index_by_id(id)
                if fresh_index>=0: app._damage_enemy(fresh_index,float(state[effect])*dt)

func beam(start: Vector3, end: Vector3, color: Color) -> void:
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_add_vertex(start+Vector3.UP)
    mesh.surface_add_vertex(end+Vector3.UP)
    mesh.surface_end()
    var node := MeshInstance3D.new()
    node.mesh=mesh
    var mat := StandardMaterial3D.new()
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color=color
    node.material_override=mat
    app.projectiles_root.add_child(node)
    app.get_tree().create_timer(0.12,false).timeout.connect(node.queue_free)
