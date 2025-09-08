require ecs
require game.events.events
require game.es.objectives.objective_common
require game.events.events_active_matter


[es(tag=server, no_order, REQUIRE=objectiveStayAlive, REQUIRE_NOT=disableObjectiveUpdate)]
def track_stay_alive_objective(act : ParallelUpdateFrameDelayed;
                               eid, objective__playerEid : EntityId;
                               objective__updateInterval : float;
                               var objective__nextUpdateAt : float&)
  if act.curTime > objective__nextUpdateAt
    if objective__nextUpdateAt != 0.f
      query(objective__playerEid) <| $ [es] (isAlive = true)
        if isAlive
          do_progress_for_objective(eid)
    objective__nextUpdateAt = act.curTime + objective__updateInterval
