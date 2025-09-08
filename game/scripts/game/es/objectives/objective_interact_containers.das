require ecs
require ecs.common
require game.events.events_active_matter
require active_matter.game.es.objectives.objective_common


[es(tag=server, REQUIRE=ri_extra)]
def objective_interact_containers_progress(evt : EventExternalInventoryContainerAccessedByHero;
                                           eid aka container_eid : EntityId)
  query(evt.heroEid) <| $ [es] (possessedByPlr : EntityId; isAlive : bool)
    if !isAlive
      return
    find_query() <| $ [es(REQUIRE=objectiveInteractContainers)] (eid aka objective_eid : EntityId;
                                                                 objective__playerEid : EntityId;
                                                                 var objective_interact_containers__usedContainers : EidList)
      if objective__playerEid == possessedByPlr
        if objective_interact_containers__usedContainers |> find_index(container_eid) == -1
          objective_interact_containers__usedContainers |> push(container_eid)
          do_progress_for_objective(objective_eid)
        return true
      return false
