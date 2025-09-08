require ecs
require active_matter.game.es.objectives.objective_common


[es(tag=server, track=itemContainer, REQUIRE=(human))]
def track_inventory_for_datacard_objective(evt : Event; itemContainer : EidList; possessedByPlr : EntityId)
  query() <| $ [es] (eid aka objective__eid : EntityId;
                     objective__playerEid : EntityId;
                     objective__contentKey : string;
                     objective__requireValue : int;
                     objective__currentValue : int)
    if objective__playerEid == possessedByPlr
      reset_progress_for_objective(objective__eid)
      for item_eid in itemContainer
        query(item_eid) <| $ [es] (datacard__value : float; datacard__contentKey : string)
          if datacard__contentKey == objective__contentKey
            if datacard__value >= float(objective__requireValue)
              set_progress_for_objective(objective__eid, int(datacard__value))
        if objective__currentValue >= objective__requireValue
          break