options no_aot
require ecs
require app
require ecs.common
require math.random
require strings
require DagorConsole
require DagorDebug3D
require game.es.net_console_macro
require game.es.extraction_point.extraction_point_common


[console_cmd(name="spawn.debug_spawns")]
def spawn_debug_spawns(spawn_group_id = -1)
  let isFounded = find_query() <| $ [es(REQUIRE=debug_spawn_points__groupId)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !isFounded
    createEntity("debug_spawn_points") <| $(var init)
      init |> set("debug_spawn_points__groupId", spawn_group_id)


[es(tag=dev, tag=render, no_order)]
def debug_spawn_draw(evt : UpdateStageInfoRenderDebug; debug_spawn_points__groupId : int)
  let lineEnd = float3(0.0, 150.0, 0.0)
  let sphereRad = 3.0
  query() <| $ [es] (spawnBase__spawnGroupId : int;
                     transform : float3x4;
                     team : int = -1)
    if debug_spawn_points__groupId != -1 && debug_spawn_points__groupId != spawnBase__spawnGroupId
      return
    var seed = spawnBase__spawnGroupId
    let color = _rnd_int(seed, int2(0, 16777215))
    let finalColor = E3DCOLOR(0xFF000000 + uint(color))
    draw_debug_line_buffered(transform[3], transform[3] + lineEnd, finalColor, 1)

    let markPos = transform[3] + lineEnd - float3(0.0, 15.0, 0.0)
    var j = 0
    add_debug_text_mark(markPos, "g: {spawnBase__spawnGroupId}", -1, float(j++), finalColor)

    if team != -1
      add_debug_text_mark(markPos, "t: {team}", -1, float(j++), finalColor)

  query() <| $ [es] (extraction__connectedSpawnGroups : IntList;
                     transform : float3x4;
                     extraction_for_everyone : Tag const?;
                     dynamic_extraction_point : Tag const?;
                     extraction_disable_time__at : float const?;
                     final_extraction_point : Tag const?)
    if debug_spawn_points__groupId != -1 && -1 == extraction__connectedSpawnGroups |> find_index(debug_spawn_points__groupId)
      return
    draw_debug_line_buffered(transform[3], transform[3] + lineEnd, E3DCOLOR(0xFFFFFFFF), 1)

    if extraction_for_everyone != null
      let markPos = transform[3] + lineEnd - float3(0.0, 15.0, 0.0)

      if dynamic_extraction_point != null
        var j = 0
        add_debug_text_mark(markPos, "dynamic", -1, float(j++), E3DCOLOR(0xFFFFFFFF))
        draw_debug_sphere_buffered(transform[3] + lineEnd, sphereRad, E3DCOLOR(0xFFFFFFFF), 12, 1)

        if extraction_disable_time__at != null
          let disabledIn = *extraction_disable_time__at - get_sync_time()
          if disabledIn > 0.0
            add_debug_text_mark(markPos, "disabled in {fmt(":.1f", disabledIn)} s.", -1, float(j++), E3DCOLOR(0xFF00FF00))
      elif final_extraction_point != null
        add_debug_text_mark(markPos, "final", -1, 0.0, E3DCOLOR(0xFF000000))
        draw_debug_sphere_buffered(transform[3] + lineEnd, sphereRad, E3DCOLOR(0xFF000000), 12, 1)
      else
        add_debug_text_mark(markPos, "all", -1, 0.0, E3DCOLOR(0xFFFFFFFF))
        draw_debug_sphere_buffered(transform[3] + lineEnd, sphereRad, E3DCOLOR(0xFFFFFFFF), 12, 1)
    else
      for i in iter_range(extraction__connectedSpawnGroups)
        var seed = extraction__connectedSpawnGroups[i]
        let color = _rnd_int(seed, int2(0, 16777215))
        let finalColor = E3DCOLOR(0xFF000000 + uint(color))

        let sphereOffset = float3(0.0, float(i) * sphereRad * 2.0, 0.0)
        draw_debug_sphere_buffered(transform[3] + lineEnd + sphereOffset, sphereRad, finalColor, 12, 1)


[net_console_cmd(name="spawn.validation")]
def validate_spawns_and_extractions()
  var ok = true
  // spawns
  query() <| $ [es] (spawnBase__spawnGroupId : int;
                     transform : float3x4)
    if spawnBase__spawnGroupId == -1
      error("[LEVEL]: spawnBase in {transform[3]} has invalid spawnBase__spawnGroupId = -1!")
      ok = false
    else
      let canExtract = find_query() <| $ [es] (extraction__connectedSpawnGroups : IntList)
        return extraction__connectedSpawnGroups |> has_value(spawnBase__spawnGroupId)
      if !canExtract
        error("[LEVEL]: no extractions for spawnBase in {transform[3]} with spawnBase__spawnGroupId = {spawnBase__spawnGroupId}")
        ok = false
  // extracions
  query() <| $ [es] (extraction__connectedSpawnGroups : IntList;
                     extraction_for_everyone : Tag const?;
                     transform : float3x4)
    if extraction_for_everyone != null
      return

    if extraction__connectedSpawnGroups |> empty()
      error("[LEVEL]: extraction in {transform[3]} has empty extraction__connectedSpawnGroups!")
      ok = false
    // else
    //   for spawnGroupId in extraction__connectedSpawnGroups
    //     let spawnExists = find_query() <| $ [es] (spawnBase__spawnGroupId : int)
    //       return spawnGroupId == spawnBase__spawnGroupId
    //     if !spawnExists
    //       error("[LEVEL]: extration in {transform[3]} has {spawnGroupId} that not actually exist in any spawn")
    //       ok = false
  if ok
    console_print("[LEVEL]: spawn and extraction points are fine")


[net_console_cmd(name="spawn.activate_final_extractions")]
def activate_final_extractions()
  activate_final_extraction_points()