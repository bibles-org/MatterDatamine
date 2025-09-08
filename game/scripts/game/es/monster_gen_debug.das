options no_aot
require ecs
require level
require math.base
require pathfinder
require math.random
require DagorDebug3D
require game.es.ecs_common
require game.es.level_common
require game.es.net_console_macro
require game.es.custom_region_common
require game.events.events_active_matter
require active_matter.game.es.regions_common
require game.es.ai.agent_position_mapping_common
require DagorRandom


[net_console_cmd(name="am.monster_gen_regen")]
def console_monster_gen_regen()
  query() <| $ [es] (eid : EntityId;
                     monster_gen_gen__type : string;
                     monster_gen_gen__genTemplates : Object;
                     monster_gen_gen__numRegions = 0; monster_gen_gen__householdCount = 0; monster_gen_gen__useHouseholdsOnEuclid = false)
    createEntity(getEntityTemplateName(eid)) <| $(init)
      init |> set("monster_gen_gen__type", monster_gen_gen__type)
      init |> set("monster_gen_gen__genTemplates", monster_gen_gen__genTemplates)
      init |> set("monster_gen_gen__numRegions", monster_gen_gen__numRegions)
      init |> set("monster_gen_gen__householdCount", monster_gen_gen__householdCount)
      init |> set("monster_gen_gen__useHouseholdsOnEuclid", monster_gen_gen__useHouseholdsOnEuclid)
    destroyEntity(eid)
  query() <| $ [es(REQUIRE=monster_gen__type)] (eid : EntityId)
    destroyEntity(eid)
  broadcastEvent(CmdRegenMonsterGen())


[net_console_cmd(name="monsters.regen_generator")]
def monsters_regen_generator(generator_to_regen_eid = 0u)
  query() <| $ [es] (eid aka generator_eid : EntityId;
                     monster_gen__density : float2;
                     var monster_gen__spawnComplete : bool&;
                     var monster_gen__maxCount : int&;
                     regional_generator__region = "";
                     transform : float3x4 const?;
                     daeditor__selected : Tag const?)
    if generator_to_regen_eid != 0u
      if generator_eid != EntityId(generator_to_regen_eid)
        return
    elif daeditor__selected == null
      return

    query() <| $ [es] (eid, generated_monster__genEid : EntityId)
      if generated_monster__genEid == generator_eid
        destroyEntity(eid)
    if !empty(regional_generator__region)
      in_region_with_name(regional_generator__region) <| $ [unused_argument(a1, a2)] (a1, a2, data)
        monster_gen__maxCount = int(ceil(rnd_float(monster_gen__density) * data.area))
    elif transform != null
      monster_gen__maxCount = int(ceil(rnd_float(monster_gen__density) * tm_volume(*transform)))
    monster_gen__spawnComplete = false


[net_console_cmd(name="am.monster_gen_show_places")]
def am_monster_gen_show_places(frames_to_show = 1000)
  let up = float3(0.0, 40.0, 0.0)
  let color = E3DCOLOR(uint4(grnd() % 255, grnd() % 255, grnd() % 255, 255))
  query() <| $ [es(REQUIRE=daeditor__selected)] (monster_gen__maxCount : int;
                                                 monster_gen__onlyAccessiblePolygons : bool = true;
                                                 regional_generator__condenseToCenter = false;
                                                 transform : float3x4 const?;
                                                 regional_generator__region : das_string const?)
    var count = 0
    while count < monster_gen__maxCount
      var pos = float3()
      if transform != null
        pos = (*transform)[3] + (*transform)[0] * rnd_float(-0.5, 0.5) + (*transform)[1] * rnd_float(-0.5, 0.5) + (*transform)[2] * rnd_float(-0.5, 0.5)
      elif regional_generator__region != null
        let regionName = string(*regional_generator__region)
        in_region_with_name(regionName) <| $(points, indices, data)
          if regional_generator__condenseToCenter
            pos = generate_region_point_condense_to_center(data.center, data.bbox, points, indices)
          else
            pos = random_point_in_region(points, indices)
      else
        return

      var poly : dtPolyRef
      let mappingZone = navmesh_mapping_find_best_zone_for_position(pos)
      pos = navmesh_map_position_in_zone(pos, mappingZone)
      if project_to_nearest_navmesh_point(pos, float3(1.5, 50.0, 1.5), poly)
        pos = navmesh_unmap_position_in_zone(pos, mappingZone)
        validate_gameplay_position(pos) <| $()
          return <- "mappingZone={mappingZone}"
        let isValidPoly = monster_gen__onlyAccessiblePolygons ? is_polygon_accessible(poly) : true
        if isValidPoly
          draw_debug_line_buffered(pos, pos + up, color, frames_to_show)
          draw_debug_sphere_buffered(pos + up, 0.1, color, 6, frames_to_show)
      count++


[es(tag=render, no_order, REQUIRE=daeditor__selected)]
def show_monster_gen_gen__excludeBoxes(evt : UpdateStageInfoRenderDebug;
                                       monster_gen__genGenEid : EntityId;
                                       transform : float3x4)
  begin_draw_cached_debug_lines(false, true, false)
  set_cached_debug_lines_wtm(transform)
  draw_cached_debug_box(IDENT_BBOX, E3DCOLOR(0xFF36D7FF))

  query(monster_gen__genGenEid) <| $ [es] (monster_gen_gen__excludeBoxes : TMatrixList)
    for tm in monster_gen_gen__excludeBoxes
      if !check_bbox3_intersection(IDENT_BBOX, transform, IDENT_BBOX, tm)
        continue
      set_cached_debug_lines_wtm(tm)
      draw_cached_debug_box(IDENT_BBOX, E3DCOLOR(0xFFFF0000))

  end_draw_cached_debug_lines()
