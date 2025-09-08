require ecs
require game.events.events_game
require active_matter.game.es.objectives.objective_common


[es(tag=server, REQUIRE=base_interesting_encounter__visitorsList)]
def objective_interact_encounters_visits_progress(evt : EventZoneEnter; eid aka zone_eid : EntityId)
  query(evt.visitorEid) <| $ [es] (possessedByPlr : EntityId; isAlive : bool)
    if !isAlive
      return
    find_query() <| $ [es(REQUIRE=objectiveInteractEncounter)] (eid aka objective_eid : EntityId;
                                                                objective__playerEid : EntityId;
                                                                var objective__visitedEncountersEids : EidList)
      if objective__playerEid == possessedByPlr
        if !has_value(objective__visitedEncountersEids, zone_eid)
          do_progress_for_objective(objective_eid)
          objective__visitedEncountersEids |> push(zone_eid)
        return true
      return false
