require ecs
require ecs.safe
require ecs.common
require game.es.objectives.objective_common
require game.events.inventory_events
require game.events.events_active_matter


def create_secret_objectivies(possessedByPlr : EntityId;
                              secret_quest_item_generated_for_players : EidList;
                              secret_objective_template : string;
                              secret_objective_name : string;
                              secret_quest_tag : string;
                              secret_quest_item_template : string;
                              objective_current_value : int = 0;
                              objective_require_value : int = 1;
                              objective_require_extraction : bool = true)
  if has_value(secret_quest_item_generated_for_players, possessedByPlr)
    return INVALID_ENTITY_ID
  var lock = false
  query(possessedByPlr) <| $ [es] (player__unlocks : StringList)
    if has_value(player__unlocks, secret_quest_tag)
      lock = true
  if lock
    return INVALID_ENTITY_ID
  var objectiveEid : EntityId
  using <| $(var object : Object)
    set(object, "handledByGameTemplate", secret_objective_template)
    set(object, "name", secret_objective_name)
    set(object, "currentValue", objective_current_value)
    set(object, "requireValue", objective_require_value)
    set(object, "requireExtraction", objective_require_extraction)
    using() <| $(var params : Array&)
      using() <| $(var paramObj : Object&)
        paramObj |> set("name", "itemTemplate")
        paramObj |> set("value", secret_quest_item_template)
        params |> push(paramObj)
      set(object, "params", params)
    objectiveEid = make_objective_entity(object, possessedByPlr)
  return objectiveEid


[es(tag=server)]
def generate_secret_quest_item_for_player_on_pick_quest_item(evt : EventOnItemPickup;
                                                             possessedByPlr : EntityId)
  if !has(evt.itemEid, "secretDiscoveredQuestItem")
    return
  query() <| $[es] (secret_quest_item_generator__itemTemplate : string;
                    secret_quest_item_generator__objectiveTemplate : string;
                    secret_quest_item_generator__objectiveName : string;
                    secret_quest_item_generator__tag : string;
                    var secret_quest_item_generator__generatedForPlayers : EidList)
    let objectiveEid = create_secret_objectivies(possessedByPlr,
                                                 secret_quest_item_generator__generatedForPlayers,
                                                 secret_quest_item_generator__objectiveTemplate,
                                                 secret_quest_item_generator__objectiveName,
                                                 secret_quest_item_generator__tag,
                                                 secret_quest_item_generator__itemTemplate)
    if !!objectiveEid
      query(objectiveEid) <| $[es] (var objective__collectedItemsList : EidList&)
        objective__collectedItemsList |> push(evt.itemEid)
      push(secret_quest_item_generator__generatedForPlayers, possessedByPlr)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def show_secret_objective_on_item_pickup(evt : EventOnItemPickup;
                                         possessedByPlr : EntityId)
  if !has(evt.itemEid, "secretDiscoveredQuestItem")
    return
  query() <| $ [es(REQUIRE=secretObjective)] (eid aka objective_eid : EntityId;
                                              objective__playerEid : EntityId;
                                              var objective__show : bool&)
    if objective__playerEid == possessedByPlr && check_is_item_for_collect_objective(evt.itemEid, objective_eid)
      objective__show = true


[es(tag=gameClient, on_appear, REQUIRE=secretObjective)]
def show_secret_objective_on_appear(evt : Event;
                                    objective__playerEid : EntityId;
                                    objective__collectedItemsList : EidList;
                                    var objective__show : bool&)
  find_query() <| $[es(REQUIRE=watchedByPlr)] (possessedByPlr : EntityId)
    if objective__playerEid == possessedByPlr && !empty(objective__collectedItemsList)
      objective__show = true
    return true


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def hide_secret_objective(evt : EventOnItemDrop;
                          inventories_owner__inventoryEids : EidList;
                          possessedByPlr : EntityId)
  if !has(evt.itemEid, "secretDiscoveredQuestItem")
    return
  query() <| $ [es(REQUIRE=secretObjective)] (eid aka objective_eid : EntityId;
                                              objective__playerEid : EntityId;
                                              var objective__show : bool&)
    if objective__playerEid == possessedByPlr && is_item_collected_for_some_objective(evt.itemEid) == objective_eid
      var showObjective = false
      for inventoryEid in inventories_owner__inventoryEids
        query(inventoryEid) <| $ [es] (itemContainer : EidList)
          for itemEid in itemContainer
            if check_is_item_for_collect_objective(itemEid, objective_eid)
              showObjective = true
              break
        if showObjective
          break
      objective__show = showObjective


[es(tag=server, on_disappear, REQUIRE=secretDiscoveredQuestItem)]
def reset_players_bind_for_secret_quest_item_generator(evt : Event;
                                                       eid : EntityId;
                                                       quest_item__playerEid : EntityId)
  find_query() <| $ [es] (var secret_quest_item_generator__itemEids : EidList;
                          var secret_quest_item_generator__generatedForPlayers : EidList)
    let itemIdx = find_index(secret_quest_item_generator__itemEids, eid)
    let playerIdx = find_index(secret_quest_item_generator__generatedForPlayers, quest_item__playerEid)
    if itemIdx != -1 && playerIdx != -1
      erase(secret_quest_item_generator__itemEids, itemIdx)
      erase(secret_quest_item_generator__generatedForPlayers, playerIdx)
      return true
    return false


[es(tag=server)]
def generate_secret_quest_item_for_player(evt : EventExternalInventoryContainerAccessedByHero;
                                          eid aka container_eid : EntityId;
                                          secret_quest_item_generator__itemTemplate : string;
                                          secret_quest_item_generator__objectiveTemplate : string;
                                          secret_quest_item_generator__objectiveName : string;
                                          secret_quest_item_generator__tag : string;
                                          var secret_quest_item_generator__generatedForPlayers : EidList;
                                          var secret_quest_item_generator__itemEids : EidList)
  query(evt.heroEid) <| $ [es] (possessedByPlr : EntityId)
    let objectiveEid = create_secret_objectivies(possessedByPlr,
                                                 secret_quest_item_generator__generatedForPlayers,
                                                 secret_quest_item_generator__objectiveTemplate,
                                                 secret_quest_item_generator__objectiveName,
                                                 secret_quest_item_generator__tag,
                                                 secret_quest_item_generator__itemTemplate)
    if !!objectiveEid
      let itemEid = create_quest_item_in_container(secret_quest_item_generator__itemTemplate,
        container_eid, possessedByPlr, [ objectiveEid])
      push(secret_quest_item_generator__itemEids, itemEid)
      push(secret_quest_item_generator__generatedForPlayers, possessedByPlr)
