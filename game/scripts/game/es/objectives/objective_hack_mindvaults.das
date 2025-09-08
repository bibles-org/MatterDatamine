require ecs
require game.es.objectives.objective_common
require game.events.events_active_matter


[es(tag=server, REQUIRE=objective_hack_corticals)]
def progress_hack_mindvaults_contract(evt : EventAmStorageHacked;
                                      eid aka objective_eid : EntityId;
                                      objective__playerEid : EntityId)
  query(objective__playerEid) <| $ [es] (possessed : EntityId)
    if possessed != evt.hackerActorEid
      return
    do_progress_for_objective(objective_eid)
