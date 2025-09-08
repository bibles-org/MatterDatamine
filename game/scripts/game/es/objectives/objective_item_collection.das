require ecs
require DngNet
require ecs.common
require DagorRandom
require DagorSystem
require game.utils.team
require daslib/algorithm
require game.es.objectives.objective_common


[es(tag=server, REQUIRE=item_created_by_zone, track=item__humanOwnerEid)]
def update_collect_objectives(evt : Event; eid aka item_eid, item__humanOwnerEid : EntityId)
  query() <| $ [es] (eid aka objective_eid, objective__playerEid : EntityId; var objective__collectedItemsList : EidList)
    query(objective__playerEid) <| $ [es] (possessed : EntityId)
      let idx = objective__collectedItemsList |> find_index(item_eid)
      if possessed == item__humanOwnerEid && idx == -1
        if check_is_item_for_collect_objective(item_eid, objective_eid) && do_progress_for_objective(objective_eid) > 0
          objective__collectedItemsList |> push(item_eid)
      elif idx != -1
        rollback_progress_for_objective(objective_eid)
        objective__collectedItemsList |> erase(idx)
        // find new
        query(possessed) <| $ [es] (inventories_owner__inventoryEids : EidList)
          for inventoryEid in inventories_owner__inventoryEids
            query(inventoryEid) <| $ [es] (itemContainer : EidList)
              for itemEid in itemContainer
                if -1 == objective__collectedItemsList |> find_index(itemEid)
                  if check_is_item_for_collect_objective(itemEid, objective_eid) && do_progress_for_objective(objective_eid) > 0
                    objective__collectedItemsList |> push(itemEid)


[es(tag=server, on_appear)]
def objective_selection_item_collection_tag(evt : Event;
                                            objective__playerEid : EntityId;
                                            objective__templateName, objective__itemTagNameInParams : string;
                                            var objective__params : Array&)
  var indexesWithTag : array<int>
  for i in iter_range(objective__params)
    let paramObj = get_ecs_object(objective__params[i])
    if paramObj != null
      let paramName = get_string(paramObj, "name", "")
      if paramName == objective__itemTagNameInParams
        indexesWithTag |> push(i)

  if length(indexesWithTag) > 1
    var playerTeam = TEAM_UNASSIGNED
    query(objective__playerEid) <| $ [es] (team : int)
      playerTeam = team
    var seed = int(ecs_hash("{get_session_id()}+{playerTeam}")) // rnd will be same for all teammates
    objectives_print_log("seed <{seed}> for objective__templateName <{objective__templateName}> and playerTeam <{playerTeam}>")
    indexesWithTag |> erase(_rnd_int(seed, 0, length(indexesWithTag) - 1))

    indexesWithTag |> reverse()
    for idx in indexesWithTag
      objective__params |> erase(idx)
