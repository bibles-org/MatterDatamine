require ecs
require ecs.safe
require ecs.common
require game.es.am_nphys_common
require game.es.monster_common
require pathfinder
require DagorMath


[es(tag=server, on_appear)]
def minion_creature_teleport_to_master_on_init(evt : Event;
                                               minion_creature_teleport_to_master__cooldown : float;
                                               var minion_creature_teleport_to_master__updateAt : float&)
  minion_creature_teleport_to_master__updateAt = minion_creature_teleport_to_master__cooldown


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def minion_creature_teleport_to_master_update(act : UpdateStageInfoAct;
                                              eid aka minion_eid : EntityId;
                                              minion_creature__masterEid : EntityId;
                                              minion_creature_teleport_to_master__updateInterval : float;
                                              minion_creature_teleport_to_master__distanceToTeleportSq : float;
                                              minion_creature_teleport_to_master__pathLengthToTeleport : float;
                                              minion_creature_teleport_to_master__nearMasterDistanceSq : float;
                                              minion_creature_teleport_to_master__farFromMasterTimeToTeleport : float;
                                              minion_creature_teleport_to_master__teleportRadius : float = 5.0;
                                              minion_creature_teleport_to_master__cooldown : float;
                                              walker_agent__targetEid : EntityId = INVALID_ENTITY_ID;
                                              beh_tree__enabled : bool;
                                              transform aka minion_transform : float3x4;
                                              var minion_creature_teleport_to_master__updateAt : float&;
                                              var minion_creature_teleport_to_master__nearMasterTimestamp : float&)
  if act.curTime < minion_creature_teleport_to_master__updateAt
    return

  minion_creature_teleport_to_master__updateAt = act.curTime + minion_creature_teleport_to_master__updateInterval

  if !beh_tree__enabled
    return

  query(minion_creature__masterEid) <| $ [es] (transform aka master_transform : float3x4)

    if is_minion_walk_mark_exists(minion_eid)
      return

    var teleportRequired = false

    let distanceToMasterSq = distance_sq(minion_transform[3], master_transform[3])
    if distanceToMasterSq >= minion_creature_teleport_to_master__distanceToTeleportSq
      teleportRequired = true
    elif distanceToMasterSq < minion_creature_teleport_to_master__nearMasterDistanceSq
      minion_creature_teleport_to_master__nearMasterTimestamp = act.curTime
    elif walker_agent__targetEid == INVALID_ENTITY_ID
      let farFromMasterTime = act.curTime - minion_creature_teleport_to_master__nearMasterTimestamp
      if farFromMasterTime >= minion_creature_teleport_to_master__farFromMasterTimeToTeleport
        teleportRequired = true


    if !teleportRequired
      var approxPathLength = -1.0
      let threshold = 1.0
      let extents = float3(threshold, FLT_MAX, threshold)
      using(minion_transform[3], master_transform[3], extents) <| $(var req : FindRequest#)
        req.includeFlags |= int(PolyFlag.POLYFLAG_GROUND | PolyFlag.POLYFLAG_OBSTACLE | PolyFlag.POLYFLAG_JUMP)
        req.maxJumpUpHeight = FLT_MAX
        approxPathLength = calc_approx_path_length(req, 1.5, 0.5)
        if approxPathLength >= minion_creature_teleport_to_master__pathLengthToTeleport
          teleportRequired = true

    if teleportRequired
      var minionPos : float3
      if !find_random_point_inside_circle(master_transform[3],
                                          minion_creature_teleport_to_master__teleportRadius, 1.0, minionPos)
        return

      var minionTM : float3x4
      minionTM[0] = normalize(master_transform[0] - minionPos)
      minionTM[2] = cross(minionTM[0], master_transform[1])
      minionTM[1] = cross(minionTM[2], minionTM[0])
      minionTM[3] = minionPos

      nphys_teleport_to_tm(minion_eid, minionTM)

      minion_creature_teleport_to_master__updateAt = act.curTime + minion_creature_teleport_to_master__cooldown

      minion_creature_teleport_to_master__nearMasterTimestamp = act.curTime


[es(tag=server, on_appear)]
def minion_creature_alternate_targets_init(evt : Event;
                                           eid : EntityId;
                                           minion_creature_alternate_targets__updateInterval : float;
                                           var minion_creature_alternate_targets__updateAt : float&)
  minion_creature_alternate_targets__updateAt = eid_frnd(eid) * minion_creature_alternate_targets__updateInterval


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def minion_creature_alternate_targets_update(act : UpdateStageInfoAct;
                                             minion_creature_alternate_targets__ignoreLastTargetFromTo : float2;
                                             minion_creature_alternate_targets__updateInterval : float;
                                             beh_tree__interruptDisabled : bool = false;
                                             var minion_creature_alternate_targets__updateAt : float&;
                                             var minion_creature__lastDangerEid : EntityId&;
                                             var walker_agent__targetEid : EntityId&)
  assume ignoreLastTargetFromTo = minion_creature_alternate_targets__ignoreLastTargetFromTo

  if act.curTime < minion_creature_alternate_targets__updateAt
    return

  var processed = true

  if minion_creature__lastDangerEid == walker_agent__targetEid
    if ignoreLastTargetFromTo.x <= act.curTime && act.curTime <= ignoreLastTargetFromTo.y
      if !beh_tree__interruptDisabled
        walker_agent__targetEid = INVALID_ENTITY_ID
      else
        processed = false

    elif act.curTime > ignoreLastTargetFromTo.y
      minion_creature__lastDangerEid = INVALID_ENTITY_ID

  if processed
    minion_creature_alternate_targets__updateAt += minion_creature_alternate_targets__updateInterval