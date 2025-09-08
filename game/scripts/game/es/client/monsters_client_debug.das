options no_aot
require app
require ecs
require ecs.safe
require ecs.ecs_template
require ecs.soa_template
require math.base
require strings
require dm
require game.es.monsters_common
require RendInst
require DagorConsole
require DagorDebug3D
require DagorSystem
require DngDm



[ecs_template]
struct invisible_man_manager_debug_draw
  invisible_man_manager__debugDrawDist : float = 0.0
  invisible_man_manager__debugDrawDistSq : float = 0.0


[console_cmd(name="invisible_man_manager.debug_draw")]
def invisible_man_manager_debug_draw_cmd(dist = 100.0)
  let tmpl = "invisible_man_manager_debug_draw"
  let distSq = square(dist)

  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var invisible_man_manager__debugDrawDist : float&;
                                       var invisible_man_manager__debugDrawDistSq : float&)
    if invisible_man_manager__debugDrawDist == dist
      destroyEntity(eid)
    else
      invisible_man_manager__debugDrawDist = dist
      invisible_man_manager__debugDrawDistSq = distSq
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("invisible_man_manager__debugDrawDist", dist)
      init |> set("invisible_man_manager__debugDrawDistSq", distSq)


[soa_es, es(tag=(render, dev), no_order)]
def debug_draw_invisible_man_manager_es(evt : UpdateStageInfoRenderDebug;
                                        invisible_man_manager__debugDrawDistSq : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    find_query() <| $ [soa_blk, es] (invisible_man_manager__requiredMovementDistanceSq : float;
                                     invisible_man_manager__noMovementPenaltyTime : float;
                                     invisible_man_manager__noAttackPenaltyTime : float;
                                     invisible_man_manager__noDangerPenaltyTime : float;
                                     invisible_man_manager__shootProtectionTime : float = 0.0;
                                     invisible_man_manager__noMovementPenaltyKoef : float;
                                     invisible_man_manager__noAttackPenaltyKoef : float;
                                     invisible_man_manager__noDangerPenaltyKoef : float;
                                     invisible_man_target_data : InvisibleManTargetData_SOA)
      let requiredMovementDistance = sqrt(invisible_man_manager__requiredMovementDistanceSq)
      for targetData in invisible_man_target_data
        query(targetData.invisible_man_target_data__eid) <| $ [es] (transform aka target_transform : float3x4;
                                                                    human_weap__lastShotAtTime : float;
                                                                    human_weap__lastMeleeAttackAtTime : float)
          let distSq = distance_sq(camera_transform[3], target_transform[3])
          if distSq > invisible_man_manager__debugDrawDistSq
            return

          assume noMovementPenaltyTime = invisible_man_manager__noMovementPenaltyTime
          let noMovementTime = get_sync_time() - targetData.invisible_man_target_data__lastMovementTime
          let movementDistance = length(target_transform[3] - targetData.invisible_man_target_data__lastMovementStartPos)
          let metersToReset = requiredMovementDistance - movementDistance

          assume noAttackPenaltyTime = invisible_man_manager__noAttackPenaltyTime
          let lastAttackAtTime = max(human_weap__lastShotAtTime, human_weap__lastMeleeAttackAtTime)
          let noShootingTime = get_sync_time() - lastAttackAtTime

          assume noDangerPenaltyTime = invisible_man_manager__noDangerPenaltyTime
          let noDangerTime = get_sync_time() - targetData.invisible_man_target_data__lastDangerTime


          let insvisibleManTime = targetData.invisible_man_target_data__spawnTime - get_sync_time()

          let shootProtectionTime = invisible_man_manager__shootProtectionTime - (get_sync_time() - human_weap__lastShotAtTime)


          let markPos = target_transform[3] + target_transform[0] * 1.0 + target_transform[1] * 1.5
          var i = 0
          let colorDefault = E3DCOLOR(0xffffffff)
          let colorWarning = E3DCOLOR(0xFFF7570D)
          let movementTimerText = "{fmt(":.1f", noMovementTime)}/{fmt(":.1f", noMovementPenaltyTime)}"
          if invisible_man_manager__noMovementPenaltyKoef > 0.0
            add_debug_text_mark(markPos, "No Movement: {movementTimerText} s. ({fmt(":.1f", metersToReset)} m. to reset)", -1,
                                float(i++), noMovementTime < noMovementPenaltyTime ? colorDefault : colorWarning)

          if invisible_man_manager__noAttackPenaltyKoef > 0.0
            let attackTimerText = "{fmt(":.1f", noShootingTime)}/{fmt(":.1f", noAttackPenaltyTime)}"
            add_debug_text_mark(markPos, "No Attack: {attackTimerText} s.", -1,
                                float(i++), noShootingTime < noAttackPenaltyTime ? colorDefault : colorWarning)

          if invisible_man_manager__noDangerPenaltyKoef > 0.0
            let dangerTimerText = "{fmt(":.1f", noDangerTime)}/{fmt(":.1f", noDangerPenaltyTime)}"
            add_debug_text_mark(markPos, "No Danger: {dangerTimerText} s.", -1,
                                float(i++), noDangerTime < noDangerPenaltyTime ? colorDefault : colorWarning)

          add_debug_text_mark(markPos, "Invisible man will come in: {fmt(":.1f", insvisibleManTime)} s.", -1,
                              float(i++), E3DCOLOR(0xFFFF71FF))

          if shootProtectionTime > 0.0
            add_debug_text_mark(markPos, "Shoot protection for: {fmt(":.1f", shootProtectionTime)} s.", -1,
                              float(i++), E3DCOLOR(0xAAAAFFFF))
      return true
    return true
