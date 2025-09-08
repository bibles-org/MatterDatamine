options no_aot
require app
require ecs
require ecs.safe
require ecs.ecs_template
require math.base
require game.utils.hero
require game.es.ecs_common
require strings
require daslib.strings_boost
require game.es.riextra_damage_common
require DagorConsole
require DagorSystem
require DagorMath
require DagorDebug3D
require RendInst


[ecs_template]
struct swarm_debug_draw
  swarm__debugDraw : bool = false


[console_cmd(name="swarm.debug_draw")]
def swarm_debug_draw_cmd(draw : bool = true)
  let tmpl = "swarm_debug_draw"
  let exists = find_query() <| $ [es] (var swarm__debugDraw : bool&)
    swarm__debugDraw = draw
    return true

  if !exists
    createEntity(tmpl) <| $(var init)
      set(init, "swarm__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def swarm_debug_es(act : UpdateStageInfoRenderDebug;
                   swarm__debugDraw : bool)
  if !swarm__debugDraw
    return

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    query() <| $ [es(REQUIRE=(flyingSwarmObject, daeditor__selected))] (eid aka swarm_eid : EntityId;
                                                                        transform aka swarm_transform : float3x4;
                                                                        swarm_cluster__targetPos : float3;
                                                                        swarm__elementsBBoxMin : float3;
                                                                        swarm__elementsBBoxMax : float3)
      if distance_sq(camera_transform[3], swarm_transform[3]) > square(300.0)
        return

      // Boid Elements
      var haveElements = false
      query() <| $ [es(REQUIRE=boidElement)] (position : float3;
                                              parentSwarm : EntityId;
                                              boid__size : float = 0.35)
        if parentSwarm != swarm_eid
          return
        haveElements = true

        draw_debug_sphere_buffered(position, boid__size, E3DCOLOR(0xFFFF00FF), 4, 1)

      // Boids Idle
      query() <| $ [es(REQUIRE=boidIdle)] (position : float3;
                                           parentSwarm : EntityId;
                                           boid__size : float = 0.35)
        if parentSwarm != swarm_eid
          return
        draw_debug_sphere_buffered(position, boid__size, E3DCOLOR(0xFF78BCC5), 4, 1)

      // Boids Dead
      query() <| $ [es(REQUIRE=boidDead)] (position : float3;
                                           parentSwarm : EntityId;
                                           boid__size : float = 0.35)
        if parentSwarm != swarm_eid
          return
        draw_debug_sphere_buffered(position, boid__size, E3DCOLOR(0xFF383838), 4, 1)


      if haveElements
        let bbox = BBox3(swarm__elementsBBoxMin, swarm__elementsBBoxMax)
        draw_debug_box_buffered(bbox, E3DCOLOR(0xFF00FFFF), 1)

      draw_debug_line_buffered(swarm_transform[3], swarm_cluster__targetPos, E3DCOLOR(0xFFFFFF00), 1)

    return true


[ecs_template]
struct swarm_snake_debug_draw
  swarm_snake__debugDraw : bool = false


[console_cmd(name="swarm.snake_debug_draw")]
def swarm_snake_debug_draw_cmd(draw : bool = true)
  let tmpl = "swarm_snake_debug_draw"
  let exists = find_query() <| $ [es] (var swarm_snake__debugDraw : bool&)
    swarm_snake__debugDraw = draw
    return true

  if !exists
    createEntity(tmpl) <| $(var init)
      set(init, "swarm_snake__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def swarm_snake_debug_es(act : UpdateStageInfoRenderDebug;
                         swarm_snake__debugDraw : bool)
  if !swarm_snake__debugDraw
    return

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    query() <| $ [es(REQUIRE=nesting_swarm_snake)] (transform aka snake_transform : float3x4)
      if distance_sq(camera_transform[3], snake_transform[3]) > square(300.0)
        return

      draw_debug_sphere_buffered(snake_transform[3], 0.2, E3DCOLOR(0xFFFFFF00), 12, 1)

    query() <| $ [es(REQUIRE=nesting_swarm_snake_segment)] (transform aka swarm_transform : float3x4;
                                                            swarm__extraTargets : Point3List)
      if distance_sq(camera_transform[3], swarm_transform[3]) > square(300.0)
        return

      for extraTarget in swarm__extraTargets
        draw_debug_sphere_buffered(extraTarget, 0.2, E3DCOLOR(0xFFFF0000), 12, 1)


    return true


[console_cmd(name="swarm.snake_speed")]
def swarm_snake_debug_draw_cmd(moveSpeed : float;
                               rotSpeed : float)
  query() <| $ [es(REQUIRE=nesting_swarm_snake_segment_visual)] (var swarm__moveSpeed : float&;
                                                                 var swarm__rotSpeed : float&;
                                                                 var nesting_swarm_snake_segment_visual__flySwarmMoveSpeed : float?;
                                                                 var nesting_swarm_snake_segment_visual__flySwarmRotSpeed : float?)
    swarm__moveSpeed = moveSpeed
    swarm__rotSpeed = rotSpeed

    if nesting_swarm_snake_segment_visual__flySwarmMoveSpeed != null
      *nesting_swarm_snake_segment_visual__flySwarmMoveSpeed = moveSpeed

    if nesting_swarm_snake_segment_visual__flySwarmRotSpeed != null
      *nesting_swarm_snake_segment_visual__flySwarmRotSpeed = rotSpeed



[ecs_template]
struct swarm_hive_debug_draw
  swarm_hive__debugDraw : bool = false


[console_cmd(name="swarm.hive_debug_draw")]
def swarm_hive_debug_draw_cmd(draw : bool = true)
  let tmpl = "swarm_hive_debug_draw"
  let exists = find_query() <| $ [es] (var swarm_hive__debugDraw : bool&)
    swarm_hive__debugDraw = draw
    return true

  if !exists
    createEntity(tmpl) <| $(var init)
      set(init, "swarm_hive__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def swarm_hive_debug_es(act : UpdateStageInfoRenderDebug;
                        swarm_hive__debugDraw : bool)
  if !swarm_hive__debugDraw
    return

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    // Draw swarms
    query() <| $ [es] (eid aka swarm_eid : EntityId;
                       transform aka swarm_transform : float3x4;
                       swarm_cluster__serverCount : int;
                       swarm_cluster__maxCount : int = 0;
                       swarm_cluster__spawnMult : float = 1.0;
                       swarm_cluster__nextBoidsSpawnTime : float;
                       swarm_cluster__hiveClusterEid : EntityId const?)
      if distance_sq(camera_transform[3], swarm_transform[3]) > square(300.0)
        return

      let markPos = swarm_transform[3]
      var i = 0
      add_debug_text_mark(markPos, "{getEntityTemplateName(swarm_eid)}", -1, float(i++), E3DCOLOR(0xFF00FF00))
      add_debug_text_mark(markPos, "eid: {swarm_eid}", -1, float(i++), E3DCOLOR(0xFF00FF00))
      if swarm_cluster__maxCount > 0
        add_debug_text_mark(markPos, "hp: {swarm_cluster__serverCount}/{swarm_cluster__maxCount}", -1, float(i++), E3DCOLOR(0xFF00FF00))
      else
        add_debug_text_mark(markPos, "hp: {swarm_cluster__serverCount}", -1, float(i++), E3DCOLOR(0xFF00FF00))
      add_debug_text_mark(markPos, "spawn mult: x{fmt(":.1f", swarm_cluster__spawnMult)}", -1, float(i++), E3DCOLOR(0xFF00FF00))

      if swarm_cluster__serverCount < swarm_cluster__maxCount && swarm_cluster__spawnMult > 0.0
        let timeToNextSpawn = swarm_cluster__nextBoidsSpawnTime - get_sync_time()
        if timeToNextSpawn > 0.0
          add_debug_text_mark(markPos, "spawn cd: {fmt(":.2f", timeToNextSpawn)} s.", -1, float(i++), E3DCOLOR(0xFFFF0000))

      if swarm_cluster__hiveClusterEid != null
        query(*swarm_cluster__hiveClusterEid) <| $ [es] (transform aka hive_preset_transform : float3x4)
          draw_debug_line_buffered(swarm_transform[3], hive_preset_transform[3], E3DCOLOR(0xFFFFFF00), 1)

    // Draw swarms
    query() <| $ [es(REQUIRE=hiveCluster)] (eid aka hive_cluster_eid : EntityId;
                                            transform aka hive_cluster_transform : float3x4;
                                            hive_cluster_preset__rendinstsEids : EidList)
      if distance_sq(camera_transform[3], hive_cluster_transform[3]) > square(300.0)
        return

      let markPos = hive_cluster_transform[3]
      var i = 0

      add_debug_text_mark(markPos, "{getEntityTemplateName(hive_cluster_eid)}", -1, float(i++), E3DCOLOR(0xFFFFFF00))
      add_debug_text_mark(markPos, "eid: {hive_cluster_eid}", -1, float(i++), E3DCOLOR(0xFFFFFF00))

      let aliveHives = calculate_ri_alive_count(hive_cluster_preset__rendinstsEids)
      add_debug_text_mark(markPos, "hives: {aliveHives}/{length(hive_cluster_preset__rendinstsEids)}", -1, float(i++), E3DCOLOR(0xFFFFFF00))


    return true