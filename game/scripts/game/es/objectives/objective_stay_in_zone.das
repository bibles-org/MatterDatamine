require ecs
require game.es.objectives.objective_common
require game.es.objectives.objective_utils_common
require game.events.events_active_matter


[es(tag=server, no_order, REQUIRE=objectiveStayInZone, REQUIRE_NOT=disableObjectiveUpdate)]
def objective_stay_in_zone(info : ParallelUpdateFrameDelayed;
                           eid aka objective_eid : EntityId;
                           objective__playerEid : EntityId;
                           objective__staticTargetsList : EidList;
                           objective__updateInterval : float;
                           var objective__nextUpdateAt : float&)

  if info.curTime < objective__nextUpdateAt
    return
  objective__nextUpdateAt = info.curTime + objective__updateInterval

  query(objective__playerEid) <| $ [es] (possessed : EntityId)

    query(possessed) <| $ [es(REQUIRE_NOT=deadEntity)] (transform : float3x4)

      let heroPos = transform[3]

      for targetEid in objective__staticTargetsList
        if is_point_in_objective_target_geometry(heroPos, targetEid)
          do_progress_for_objective(objective_eid)