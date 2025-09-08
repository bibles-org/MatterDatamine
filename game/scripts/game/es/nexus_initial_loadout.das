require app
require ecs
require ecs.safe



def nexus_mode_do_init_loot(container_eid : EntityId;
                            container_team : int;
                            loadout_team : int;
                            nexus_battle_loot__loot : Array;
                            itemContainer : EidList;
                            var nexus_battle_container__initialItemsCount : int&)
  if container_team != loadout_team
    return false
  if !empty(itemContainer)
    return true
  var numItems = 0
  for lootItem in nexus_battle_loot__loot
    let obj = lootItem as Object
    let templateName = get_string(obj, "templateName", "")
    let count = get_int(obj, "count") ?? 1
    numItems += count
    for _ in range(count)
      createEntity("{templateName}+nexus_battle_container_item_initialize_tracker") <| $(init)
        set(init, "team", container_team)
        set(init, "item__wantToBeCorrupted", false)
        set(init, "item__containerOwnerEid", container_eid)
  nexus_battle_container__initialItemsCount = numItems
  return true


[es(on_appear, REQUIRE=nexus_battle_initial_loot)]
def nexus_mode_initial_loadout_init(evt : Event; team aka loadout_team : int; nexus_battle_loot__loot : Array)
  find_query() <| $ [es(REQUIRE=nexus_battle_container)] (eid aka container_eid : EntityId;
                                                          nexus_battle_container__team : int;
                                                          itemContainer : EidList;
                                                          var nexus_battle_container__initialItemsCount : int&)
    return nexus_mode_do_init_loot(container_eid, nexus_battle_container__team, loadout_team, nexus_battle_loot__loot, itemContainer, nexus_battle_container__initialItemsCount)


[es(on_appear, REQUIRE=nexus_battle_container)]
def nexus_mode_initial_loadout_init_reverse(evt : Event;
                                            eid aka container_eid : EntityId;
                                            nexus_battle_container__team : int;
                                            itemContainer : EidList;
                                            var nexus_battle_container__initialItemsCount : int&)
  find_query() <| $ [es(REQUIRE=nexus_battle_initial_loot)] (team aka loadout_team : int; nexus_battle_loot__loot : Array)
    return nexus_mode_do_init_loot(container_eid, nexus_battle_container__team, loadout_team, nexus_battle_loot__loot, itemContainer, nexus_battle_container__initialItemsCount)


[es(REQUIRE=nexus_battle_container_item_initialize_tracker, on_appear)]
def nexus_battle_container_item_initialize_tracker(evt : Event; eid : EntityId; item__containerOwnerEid : EntityId)
  query(item__containerOwnerEid) <| $ [es(REQUIRE=nexus_battle_container)] (nexus_battle_container__initialItemsCount : int;
                                                                            var nexus_battle_container__initializedItems : int&;
                                                                            var nexus_battle_container__allItemsInitialized : bool&)
    if nexus_battle_container__allItemsInitialized
      return
    nexus_battle_container__initializedItems += 1
    if nexus_battle_container__initializedItems == nexus_battle_container__initialItemsCount
      nexus_battle_container__allItemsInitialized = true
  removeSubTemplate(eid, "nexus_battle_container_item_initialize_tracker")
