extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var app = load("res://main.tscn").instantiate()
    root.add_child(app)
    await process_frame
    await process_frame
    check(app.player != null, "player initialized")
    check(app.loadout != null, "free socket loadout initialized")
    check(app.gem_combat != null, "gem combat initialized")
    check(app.forge_panel != null, "touch loadout panel initialized")
    check(app.loadout.item_at(0).sockets.size() == 2, "starter item has two sockets")
    app.loadout.owned.append("support:multi")
    var message: String = app.loadout.install(0, 1, "support:multi")
    check(message.begins_with("已裝入"), "support gem installs into open socket")
    check(app.loadout.skills()[0].supports.has("multi"), "linked compatible support is active")
    check(app.loadout.compile(app.loadout.skills()[0]).count == 3, "multi support changes projectile count")
    app.queue_free()
    await process_frame
    print("EMBERFALL_SMOKE failures=", failures)
    quit(0 if failures == 0 else 1)
