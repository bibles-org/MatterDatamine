require ecs
require DagorSystem
require HeightmapQueryManager
require gpuReadbackQuery
require game.es.grav_zones_common

[es(tag=gameClient, no_order)]
def interesting_encounter_apply_displacement(act : UpdateStageInfoAct;
                                             eid : EntityId;
                                             interesting_encounter__dQueryQueueTemplate : string;
                                             interesting_encounter__dQueryAttemptsPerItem : int;
                                             var interesting_encounter__waitForEntitiesLeft : float&;
                                             var interesting_encounter__dQueryIdx : int&;
                                             var interesting_encounter__dQueryQueue : EidList;
                                             var interesting_encounter__dQueryAttemptsLeft : int&)
  if length(interesting_encounter__dQueryQueue) == 0
    removeSubTemplate(eid, interesting_encounter__dQueryQueueTemplate)
    return
  let nextEid = interesting_encounter__dQueryQueue[0]
  if doesEntityExist(nextEid)
    var querySuccess = false
    query(nextEid) <| $ [es] (var transform : float3x4)
      querySuccess = true
      if interesting_encounter__dQueryIdx < 0
        let qpos = transform[3].xyz
        interesting_encounter__dQueryIdx = heightmap_query_start(qpos, get_grav_dir(qpos))
        interesting_encounter__dQueryAttemptsLeft = interesting_encounter__dQueryAttemptsPerItem
      else
        var hmqr = HeightmapQueryResultWrapper()
        let qRes = heightmap_query_value(interesting_encounter__dQueryIdx, hmqr)
        if is_gpu_readback_query_successful(qRes)
          let delta = hmqr.hitDistWithOffsetDeform - hmqr.hitDistNoOffset
          transform[3] += delta * hmqr.normal
          interesting_encounter__dQueryIdx = -1
          erase(interesting_encounter__dQueryQueue, 0)
        elif is_gpu_readback_query_failed(qRes) || interesting_encounter__dQueryAttemptsLeft <= 0
          interesting_encounter__dQueryIdx = -1
          erase(interesting_encounter__dQueryQueue, 0)
        else
          interesting_encounter__dQueryAttemptsLeft--
    if !querySuccess
      interesting_encounter__waitForEntitiesLeft -= act.dt
      if interesting_encounter__waitForEntitiesLeft <= .0
        erase(interesting_encounter__dQueryQueue, 0)
        logerr("<{nextEid}>({getEntityTemplateName(nextEid)}) is marked 'compensateDisplacement' but has no transform.")