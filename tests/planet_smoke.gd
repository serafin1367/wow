extends SceneTree
## Headless integration check: planet switch cannot touch the game economy.


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Test: main.tscn is missing")
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    await process_frame

    if game.planet_env == null or game.hud == null:
        push_error("Test: planet environment or HUD not initialized")
        quit(1)
        return

    if game.planet_env.current_planet != "Mars":
        push_error("Test: game should start on Mars")
        quit(1)
        return

    var original_resources: Dictionary = game.resource_totals.duplicate(true)
    var original_unit_count: int = game.workers.size()
    var original_sources: int = get_nodes_in_group("resource_nodes").size()
    var ground = game.get_node_or_null("Ground/Grass")
    if ground == null or not ground.material_override is ShaderMaterial:
        push_error("Test: ground needs a procedural planet shader")
        quit(1)
        return

    for expected_planet in ["Ziemia", "Kepler", "Mars"]:
        game._cycle_planet()
        if game.planet_env.current_planet != expected_planet:
            push_error("Test: planet cycling failed: %s" % expected_planet)
            quit(1)
            return
        if game.resource_totals != original_resources:
            push_error("Test: visual planet switch modified resources")
            quit(1)
            return
        if game.workers.size() != original_unit_count:
            push_error("Test: visual planet switch modified robot count")
            quit(1)
            return
        if get_nodes_in_group("resource_nodes").size() != original_sources:
            push_error("Test: visual planet switch modified resource nodes")
            quit(1)
            return

    print("PLANET SMOKE OK: Mars -> Ziemia -> Kepler -> Mars")
    game.queue_free()
    await process_frame
    quit(0)
