module equipment_common shared
require ecs
require DngNet
require ecs.safe
require inventory
require ecs.common
require DagorSystem
require game.events.events
require game.es.inventory_common
require game.es.inventory_checks_common


def is_item_for_slot(item_eid : EntityId;
                     slot_name : string) : bool
  var res = false
  query(item_eid) <| $ [es] (item__equipmentSlots : StringList)
    for slotName in item__equipmentSlots
      if slotName == slot_name
        res = true
        return
  return res


def get_part_data_node_id(parts : Object;
                          part_name : string) : int
  var part = get_ecs_object(parts, part_name)
  if part == null
    return -1

  return (*part).collNodeId ?? -1


def check_equpment_allowed(human_eid : EntityId;
                           new_perk_name : string) : bool
  var allowed = true
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          disableArtifacts : Array)
    if game_effect__attachedTo != human_eid
      return false
    for name in disableArtifacts
      if get_string(name, "") == new_perk_name
        allowed = false
        return true
    return true

  return allowed


def check_equpment_allowed_by_id(human_eid : EntityId;
                                 equip_eid : EntityId) : bool
  var allowed = true
  query(equip_eid) <| $ [es] (item__perkName : string)
    allowed = allowed && check_equpment_allowed(human_eid, item__perkName)
  return allowed


def check_and_request_enable_flag(prev_item_eid : EntityId;
                                  new_item_eid : EntityId;
                                  slot_name : string;
                                  slots : Object;
                                  eid : EntityId) : void
  query(prev_item_eid) <| $ [es] (item_mods__enableFlag aka flagToRemove_item_mods__enableFlag : string;
                                  item_mods__eidComp : das_string const?)
    // Check if we really need to remove it (i.e. it's unique to this part)
    var shouldRemove = true
    for slot in slots
      if slot.key == slot_name
        continue
      let slotObj = get_ecs_object(slot.value)
      let item = slotObj?.item ?? INVALID_ENTITY_ID
      query(item) <| $ [es] (item_mods__enableFlag : string)
        if item_mods__enableFlag == flagToRemove_item_mods__enableFlag
          shouldRemove = false
      if !shouldRemove
        break

    if shouldRemove
      var flag = getRW_bool(eid, flagToRemove_item_mods__enableFlag, ecs_hash(flagToRemove_item_mods__enableFlag))
      if flag != null
        *flag = false
      if item_mods__eidComp != null
        var eidComp = getRW_Eid(eid, string(*item_mods__eidComp), ecs_hash(string(*item_mods__eidComp)))
        if eidComp != null
          *eidComp = INVALID_ENTITY_ID

  query(new_item_eid) <| $ [es] (item_mods__enableFlag aka flagToAdd_item_mods__enableFlag : string;
                                 item_mods__eidComp : das_string const?)
    let activate = check_equpment_allowed_by_id(eid, new_item_eid)
    var flag = getRW_bool(eid, flagToAdd_item_mods__enableFlag, ecs_hash(flagToAdd_item_mods__enableFlag))
    if flag != null
      *flag = activate
    if item_mods__eidComp != null
      var eidComp = getRW_Eid(eid, string(*item_mods__eidComp), ecs_hash(string(*item_mods__eidComp)))
      if eidComp != null
        *eidComp = new_item_eid


def gather_items_to_drop(container_eid : EntityId;
                         item_container : EidList;
                         drop_volume : int;
                         var drop_items_out : array<EntityId>&)
  var dropVolume = drop_volume
  for item in item_container
    if dropVolume <= 0
      break
    query(item) <| $ [es(REQUIRE_NOT=item__nonDroppable)] (item__containerOwnerEid : EntityId;
                                                           item__volume : float)
      // don't drop items that don't belong to this container
      // they are in this array only because "remove_item_from_owners_container_on_drop" es hasn't removed them yet
      if item__containerOwnerEid == container_eid
        drop_items_out |> push(item)
        dropVolume -= convert_volume_to_int(item__volume)
  return dropVolume <= 0
