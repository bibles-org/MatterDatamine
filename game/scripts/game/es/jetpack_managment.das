require ecs
require ecs.common
require ecs.safe
require game.events.inventory_events


def add_jetpack_to_list(jetpack_eid : EntityId; list_weight : int; var jetpacks_list : Array)
  var indexExisting = -1
  for jetpackRecord, i in jetpacks_list, iter_range(jetpacks_list)
    let jetpackRecordObj = get_ecs_object(jetpackRecord)
    if jetpackRecordObj != null
      let jetpackEid = jetpackRecordObj?.eid ?? INVALID_ENTITY_ID
      if jetpackEid == jetpack_eid
        indexExisting = i
        break
  if indexExisting != -1
    return
  print("jetpack_managment: jetpack {jetpack_eid} added to list with weight {list_weight}")
  push_to_array(jetpacks_list) <| $(var obj : Object)
    obj |> set("eid", jetpack_eid)
    obj |> set("listWeight", list_weight)



def remove_jetpack_from_list(jetpack_eid : EntityId; var jetpacks_list : Array)
  var indexToDel = -1
  for jetpackRecord, i in jetpacks_list, iter_range(jetpacks_list)
    let jetpackRecordObj = get_ecs_object(jetpackRecord)
    if jetpackRecordObj != null
      let jetpackEid = jetpackRecordObj?.eid ?? INVALID_ENTITY_ID
      if jetpackEid == jetpack_eid
        indexToDel = i
        break
  if indexToDel >= 0
    print("jetpack_managment: jetpack {jetpack_eid} removed from list")
    jetpacks_list |> erase(indexToDel)



def set_jetpack(hero_eid, jetpack_eid : EntityId)
  print("jetpack_managment: new jetpack setted {jetpack_eid} to hero {hero_eid}")
  query(hero_eid) <| $ [es] (var human_jetpack__eid : EntityId&;
                             var human_jetpack__enabled : bool&)
    query(human_jetpack__eid) <| $ [es] (var jetpack__active : bool&)
      jetpack__active = false
    human_jetpack__eid = jetpack_eid
    human_jetpack__enabled = jetpack_eid != INVALID_ENTITY_ID


[es(tag=server)]
def jetpack_managment_on_jetpack_loot(evt : EventOnItemPickup; var human_jetpack__jetpacksList : Array)
  query(evt.itemEid) <| $ [es] (jetpack__priority : int)
    add_jetpack_to_list(evt.itemEid, jetpack__priority, human_jetpack__jetpacksList)


[es(tag=server, after=human_equipment_es)]
def jetpack_managment_on_jetpack_direct_equip(evt : EventOnEquipmentEquipped; var human_jetpack__jetpacksList : Array)
  query(evt.equipmentEid) <| $ [es] (jetpack__priority : int)
    add_jetpack_to_list(evt.equipmentEid, jetpack__priority, human_jetpack__jetpacksList)


[es(tag=server)]
def jetpack_managment_on_jetpack_drop(evt : EventOnItemDrop; var human_jetpack__jetpacksList : Array)
  remove_jetpack_from_list(evt.itemEid, human_jetpack__jetpacksList)


[es(tag=server, REQUIRE=eid)]
def jetpack_managment_on_jetpack_unequipped(evt : EventOnEquipmentUnequipped)
  let equipmentEid = evt.equipmentEid
  query(equipmentEid) <| $ [es(REQUIRE=jetpack__active)] (item__containerOwnerEid : EntityId)
    query(item__containerOwnerEid) <| $ [es] (var human_jetpack__jetpacksList : Array)
      remove_jetpack_from_list(equipmentEid, human_jetpack__jetpacksList)


[es(tag=server, track=(human_jetpack__jetpacksList, human_equipment__slots))]
def jetpack_managment_on_jetpack_changed(evt : Event;
                                         eid : EntityId;
                                         human_jetpack__jetpacksList : Array;
                                         human_equipment__slots : Object)
  var jetpackEid = INVALID_ENTITY_ID
  if human_jetpack__jetpacksList |> length() > 0
    var maxWeight = -1
    for jetpackRecord in human_jetpack__jetpacksList
      let jetpackRecordObj = get_ecs_object(jetpackRecord)
      if jetpackRecordObj != null
        let jetpackWeight = jetpackRecordObj?.listWeight ?? -1
        if jetpackWeight > maxWeight
          jetpackEid = jetpackRecordObj?.eid ?? INVALID_ENTITY_ID
          maxWeight = jetpackWeight
  if (human_equipment__slots["backpack"] ?? INVALID_ENTITY_ID) == jetpackEid
    set_jetpack(eid, jetpackEid)
