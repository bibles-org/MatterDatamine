options no_aot
require ecs
require DagorConsole
require math.base
require game.utils.hero
require DagorMathUtils

[console_cmd(name="enemy.spawn_around")]
def console_spawn_enemies(tmpl : string;
                          count = 1;
                          radius = 4f)
  find_query() <| $ [es(REQUIRE=hero)] (transform : float3x4)
    let playerPos = transform[3]
    var angle = dir_to_angles(transform[0])
    let step = TWOPI / float(count)
    for _ in range(0, count)
      var pos = IDENT_TM
      pos[3] = playerPos + angles_to_dir(angle) * radius
      angle.x += step
      createEntity(tmpl) <| $(init)
        set(init, "transform", pos)
    return true