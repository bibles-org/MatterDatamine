require ecs
require ecs.common
require DagorMath
require Grid
require GridCollision
require game.es.flanking_ai_common
require game.events.events_active_matter
require DagorDebug3D
require DagorDebug3DSolid
require danetlibs.render_debug.main.net_draw_debug_common
require DagorMath
require pathfinder


[es(tag=server, no_order)]
def update_crown_attack_count(act : ParallelUpdateFrameDelayed;
                              eid aka target_eid : EntityId;
                              transform aka target_transform : float3x4;
                              flanking_ai_target__interval : float;
                              flanking_ai_target__radius : float;
                              flanking_ai_target__debug : bool;
                              var flanking_ai_target__dirs : Point3List;
                              var flanking_ai_target__count : int&;
                              var flanking_ai_target__updateAt : float&)
  if act.curTime > flanking_ai_target__updateAt
    flanking_ai_target__updateAt = act.curTime + flanking_ai_target__interval * (flanking_ai_target__count > 0 ? 0.5 : 2.5)
    clear(flanking_ai_target__dirs)
    flanking_ai_target__count = 0
    let north = float3(1, 0, 0)
    var dirs : array<tuple<dir : float3; turn : float; attacker : EntityId>>
    let monstersGrid = fixed_array(ecs_hash("creatures"), ecs_hash("humans"))
    for_each_entity_in_grid(monstersGrid, BSphere3(target_transform[3], flanking_ai_target__radius), GridEntCheck.POS) <| $(attacker_eid : EntityId)
      query(attacker_eid) <| $ [es(REQUIRE_NOT=(deadEntity, sleeping_monster))] (eid : EntityId;
                                                                                 flanking_ai__priority : int;
                                                                                 flanking_ai__dir : float3 = float3();
                                                                                 walker_agent__targetEid : EntityId)
        if walker_agent__targetEid == target_eid && flanking_ai__priority == 0
          flanking_ai_target__count++
          if flanking_ai__dir != float3()
            dirs |> emplace((flanking_ai__dir, calc_turn_value(north, flanking_ai__dir), eid))
    dirs |> sort() <| $(a, b)
      return a.turn < b.turn

    // if attackers have too similar attack directions
    // make one recalculate its attack direction
    let originalLen = length(dirs)
    for i in range(originalLen)
      if i == 0
        continue
      let revIdx = originalLen - i - 1
      let revPrevIdx = revIdx + 1
      let prev = dirs[revPrevIdx].turn
      let cur = dirs[revIdx].turn
      if abs(cur - prev) < 0.1
        query(dirs[revPrevIdx].attacker) <| $ [es] (var flanking_ai__dir : float3&;
                                                    var flanking_ai__lastTarget : EntityId&)
          flanking_ai__lastTarget = INVALID_ENTITY_ID
          flanking_ai__dir = float3()
        erase(dirs, revPrevIdx)

    for d in dirs
      flanking_ai_target__dirs |> push(d.dir)

  if flanking_ai_target__debug
    query() <| $ [es(REQUIRE_NOT=(deadEntity, sleeping_monster))] (flanking_ai__dir : float3;
                                                                   flanking_ai__radius : float;
                                                                   flanking_ai__priority : int;
                                                                   walker_agent__targetEid : EntityId;
                                                                   transform aka ttransform : float3x4;
                                                                   eid aka eid2 : EntityId)
      if walker_agent__targetEid == target_eid
        if flanking_ai__priority == 0
          var poly : dtPolyRef
          if flanking_ai__dir != float3()
            var idx = -1
            for didx in iter_range(flanking_ai_target__dirs)
              if flanking_ai_target__dirs[didx] == flanking_ai__dir
                idx = didx
                break
            let pos = get_slot_position(target_transform[3], flanking_ai__dir, flanking_ai__radius, poly)
            net_draw_debug_sphere_buffered(pos, 0.5 + 0.1 * eid_frnd(eid2), E3DCOLOR(0xffffffff), 12, 1)
            draw_debug_text_mark_buffered(pos, "{idx}: <{eid2}>", 1)
            net_draw_debug_sphere_buffered(ttransform[3] + float3(0, 1, 0) * 1.5, 0.05, E3DCOLOR(0xffffff00), 12, 1)
          else
            net_draw_debug_sphere_buffered(ttransform[3] + float3(0, 1, 0) * 1.5, 0.05, E3DCOLOR(0xffff0000), 12, 1)
        else
          net_draw_debug_sphere_buffered(ttransform[3] + float3(0, 1, 0) * 1.5, 0.05, E3DCOLOR(0xff000000), 12, 1)
