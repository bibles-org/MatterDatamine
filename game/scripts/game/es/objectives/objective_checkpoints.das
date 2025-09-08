require ecs
require game.events.events
require ecs.common
require math.base
require game.es.objectives.objective_common
require game.es.objectives.objective_utils_common
require game.events.events_active_matter
require player


[es(tag=gameClient, on_appear, track=objective__currentValue, REQUIRE=objectiveCheckpoints)]
def visibility_objective_checkpoints_mgr(evt : Event;
                                         objective__playerEid : EntityId;
                                         objective__staticTargetsList : EidList;
                                         objective__currentValue : int)
  if objective__playerEid != get_local_player_eid()
    return
  for targetEid, idx in objective__staticTargetsList, iter_range(objective__staticTargetsList)
    let shouldEnable = idx == objective__currentValue
    sendEvent(targetEid, CmdToggleMapObject(value = shouldEnable))  // NOTE: mb add "id" component for checkpoints and increment their id on appear
                                                                      // relative previous checkpoint?


[es(tag=server, REQUIRE=objectiveCheckpoints, REQUIRE_NOT=disableObjectiveUpdate, no_order)]
def objective_checkpoint_progress(info : ParallelUpdateFrameDelayed;
                                  eid aka objective_eid : EntityId;
                                  objective__currentValue : int;
                                  objective__playerEid : EntityId;
                                  objective__staticTargetsList : EidList)
  query(objective__playerEid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $ [es] (transform aka hero_transform : float3x4;
                                isAlive : bool)
      if !isAlive
        return
      for idx in range(objective__currentValue, length(objective__staticTargetsList))
        assume targetEid = objective__staticTargetsList[idx]
        query(targetEid) <| $ [es(REQUIRE=checkpointTarget)] ()
          if is_point_in_objective_target_geometry(hero_transform[3], targetEid)
            do_progress_for_objective(objective_eid)