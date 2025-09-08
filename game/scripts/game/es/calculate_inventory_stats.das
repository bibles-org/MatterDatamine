require ecs
require ecs.safe
require game.es.inventory_weapon_common
require game.es.inventory_checks_common
require game.es.ecs_common
require DagorSystem


def private get_items_capacity(items : EidList)
  var result : tuple<volume : int; weight : float>
  for itemEid in items
    query(itemEid) <| $ [es] (item__volume : float = 0.0;
                              item__weight : float = 0.0;
                              weapon_mods__modDelayedEquipEid : EntityId = INVALID_ENTITY_ID)
      result.volume += convert_volume_to_int(item__volume)
      result.weight += item__weight
      if !!weapon_mods__modDelayedEquipEid
        query(weapon_mods__modDelayedEquipEid) <| $ [es] (item__weight aka mod_item__weight : float)
          result.weight += mod_item__weight
  return result


def private calculate_current_capacities(itemContainer : EidList;
                                         human_equipment__slots : Object const?;
                                         human_weap__gunEids : EidList const?;
                                         var human_inventory__currentVolume : int&;
                                         var human_inventory__currentWeight : float&)
  human_inventory__currentVolume = 0
  human_inventory__currentWeight = 0.0

  let itemsCapacity = get_items_capacity(itemContainer)
  human_inventory__currentVolume += itemsCapacity.volume
  human_inventory__currentWeight += itemsCapacity.weight

  if human_equipment__slots != null
    for it in *human_equipment__slots
      let itemEid = get_Eid(it.value) ?? INVALID_ENTITY_ID
      query(itemEid) <| $ [es] (item__weight : float)
        human_inventory__currentWeight += item__weight

  if human_weap__gunEids != null
    let gunsCapacity = get_items_capacity(*human_weap__gunEids)
    human_inventory__currentWeight += gunsCapacity.weight


def private calculate_current_capacities(humanOwnerEid : EntityId)
  query(humanOwnerEid) <| $ [es] (itemContainer : EidList;
                                  var human_inventory__currentVolume : int&;
                                  var human_inventory__currentWeight : float&;
                                  human_equipment__slots : Object const?;
                                  human_weap__gunEids : EidList const?)
    calculate_current_capacities(itemContainer, human_equipment__slots,
      human_weap__gunEids,
      human_inventory__currentVolume, human_inventory__currentWeight)


[es(tag=server,
      on_appear,
      track=itemContainer,
      track=human_equipment__slots,
      track=human_weap__gunEids,
      on_event=EventScriptReloaded)]
def raid_calculate_current_volume_es(evt : Event;
                                     itemContainer : EidList;
                                     var human_inventory__currentVolume : int&;
                                     var human_inventory__currentWeight : float&;
                                     human_equipment__slots : Object const?;
                                     human_weap__gunEids : EidList const?)
  calculate_current_capacities(itemContainer, human_equipment__slots,
    human_weap__gunEids,
    human_inventory__currentVolume, human_inventory__currentWeight)


[es(tag=server,
      track=equipment_mods__curModInSlots,
      REQUIRE=equipment_mods__curModInSlots)]
def raid_calculate_current_volume_for_equipment_mods_es(evt : Event;
                                                        item__humanOwnerEid : EntityId)
  calculate_current_capacities(item__humanOwnerEid)


[es(tag=server,
      track=gun_mods__curModInSlots,
      REQUIRE=gun_mods__curModInSlots)]
def raid_calculate_current_volume_for_gun_mods_es(evt : Event;
                                                  gun__owner : EntityId)
  calculate_current_capacities(gun__owner)


[es(tag=server,
      on_appear,
      track=gun__ammo,
      REQUIRE=gun__ammo)]
def raid_calculate_current_volume_for_gun_es(evt : Event;
                                             gun__owner : EntityId)
  calculate_current_capacities(gun__owner)


def private inventory_calculate_container_capacities(eid : EntityId)
  query(eid) <| $ [es] (itemContainer : EidList;
                        var human_inventory__currentVolume : int&;
                        var human_inventory__currentWeight : float&)
    human_inventory__currentVolume = 0
    human_inventory__currentWeight = 0.0
    let itemsCapacity = get_items_capacity(itemContainer)
    human_inventory__currentVolume += itemsCapacity.volume
    human_inventory__currentWeight += itemsCapacity.weight


[es(tag=server, on_appear, track=itemContainer, REQUIRE=(human_inventory__autoCalculateCapacities, itemContainer), on_event=EventScriptReloaded)]
def raid_inventory_calculate_container_capacities(evt : Event;
                                                  eid : EntityId)
  inventory_calculate_container_capacities(eid)


def private inventory_calculate_gun_weight(eid : EntityId)
  query(eid) <| $ [es] (item__baseWeight : float;
                        gun__ammo : int;
                        gun_boxed_ammo_reload__reloadState : int const?;
                        gun__boxedAmmoHolderTemplate : das_string const?;
                        gun_mods__curModInSlots : Object const?;
                        var item__weight aka gun_item__weight : float&)
    gun_item__weight = item__baseWeight
    if gun_boxed_ammo_reload__reloadState != null && gun__boxedAmmoHolderTemplate != null
      gun_item__weight += calculate_boxed_item_weight(string(*gun__boxedAmmoHolderTemplate), gun__ammo)
    if gun_mods__curModInSlots != null
      for mod in *gun_mods__curModInSlots
        let modEid = get_Eid(mod.value) ?? INVALID_ENTITY_ID
        query(modEid) <| $ [es] (item__weight aka mod_item__weight : float;
                                 item_holder__boxedItemTemplate : das_string const?)
          gun_item__weight += mod_item__weight
          if item_holder__boxedItemTemplate != null
            gun_item__weight += calculate_boxed_item_weight(string(*item_holder__boxedItemTemplate), gun__ammo)


[es(tag=server, on_appear, track=gun_mods__curModInSlots, REQUIRE=gun_mods__curModInSlots)]
def raid_inventory_calculate_gun_weight_on_mods_change(evt : Event;
                                                       eid : EntityId)
  inventory_calculate_gun_weight(eid)


[es(tag=server, on_appear, track=gun__ammo, REQUIRE=gun__ammo)]
def raid_inventory_calculate_gun_weight_on_ammo_change(evt : Event;
                                                       eid : EntityId)
  inventory_calculate_gun_weight(eid)


[es(tag=server, on_appear, track=item__currentBoxedItemCount)]
def raid_inventory_calculate_magazine_weight(evt : Event;
                                             item__currentBoxedItemCount : int;
                                             item__baseWeight : float;
                                             item_holder__boxedItemTemplate : string;
                                             var item__weight : float&)
  item__weight = item__baseWeight + calculate_boxed_item_weight(item_holder__boxedItemTemplate, item__currentBoxedItemCount)


def private inventory_calculate_equipment_weight(eid : EntityId)
  query(eid) <| $ [es] (equipment_mods__curModInSlots : Object;
                        item__baseWeight : float;
                        var item__weight aka equip_item__weight : float&)
    equip_item__weight = item__baseWeight
    for mod in equipment_mods__curModInSlots
      let modEid = get_Eid(mod.value) ?? INVALID_ENTITY_ID
      query(modEid) <| $ [es] (item__weight aka mod_item__weight : float)
        equip_item__weight += mod_item__weight


[es(tag=server, on_appear, track=equipment_mods__curModInSlots, REQUIRE=equipment_mods__curModInSlots)]
def raid_inventory_calculate_equipment_weight(evt : Event;
                                              eid : EntityId)
  inventory_calculate_equipment_weight(eid)


[es(tag=server, on_appear, track=item__weight, REQUIRE=item__weight)]
def raid_inventory_update_weight_on_item_weight_change(evt : Event;
                                                       item__humanOwnerEid : EntityId = INVALID_ENTITY_ID;
                                                       item__containerOwnerEid : EntityId = INVALID_ENTITY_ID;
                                                       slot_attach__attachedTo : EntityId = INVALID_ENTITY_ID)
  // weapons and equipment in slots
  if !!slot_attach__attachedTo && slot_attach__attachedTo == item__humanOwnerEid
    calculate_current_capacities(slot_attach__attachedTo)
    return
  // items in main inventory
  if !!item__containerOwnerEid && item__humanOwnerEid == item__containerOwnerEid
    calculate_current_capacities(item__humanOwnerEid)
    return
  // items in containers
  if has(item__containerOwnerEid, "human_inventory__autoCalculateCapacities")
    inventory_calculate_container_capacities(item__containerOwnerEid)
    return
  // gun mod
  if has(slot_attach__attachedTo, "gun_mods__curModInSlots")
    inventory_calculate_gun_weight(slot_attach__attachedTo)
  // equipment mod
  if has(slot_attach__attachedTo, "equipment_mods__curModInSlots")
    inventory_calculate_equipment_weight(slot_attach__attachedTo)


[es(tag=server, on_appear, track=item__volume, REQUIRE=item__volume)]
def raid_inventory_update_capacity_on_item_volume_change(evt : Event; item__containerOwnerEid : EntityId)
  query(item__containerOwnerEid) <| $ [es] (var human_inventory__currentVolume : int&; itemContainer : EidList)
    human_inventory__currentVolume = 0
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (item__volume : float)
        human_inventory__currentVolume += convert_volume_to_int(item__volume)


[es(on_appear, track=human_inventory__currentWeight)]
def raid_item_weight_from_human_inventory_weight(evt : Event;
                                                 human_inventory__currentWeight : float;
                                                 item_weight_from_human_inventory_weight__baseWeight : float = 0.0;
                                                 item_weight_from_human_inventory_weight__multiplier : float;
                                                 var item__weight : float&)
  assume baseWeight = item_weight_from_human_inventory_weight__baseWeight
  item__weight = baseWeight + human_inventory__currentWeight * item_weight_from_human_inventory_weight__multiplier

// human_inventory__maxVolume - value for designers
// human_inventory__maxVolumeInt - value for inner calculations
[es(tag=server, on_appear)]
def set_human_inventory_max_volume_from_capacity(evt : Event; var human_inventory__maxVolumeInt : int&; human_inventory__maxVolume : float)
  human_inventory__maxVolumeInt = human_inventory__maxVolume < 0.0f ? -1 : convert_volume_to_int(human_inventory__maxVolume)


[es(tag=(dev, gameClient), on_appear)]
def check_item_volume_dev(evt : Event;
                          eid : EntityId;
                          item__volume : float;
                          item__countPerStack : int = 0;
                          item__volumePerStack : float = 0f;
                          boxedItem : Tag const?)
  if boxedItem != null
    // check stack volume
    let intVol = convert_volume_to_int(item__volumePerStack)
    if abs(float(intVol) - item__volumePerStack * 10.f) > 0.1f
      logerr("[ITEM VOLUME] Bad volume {item__volumePerStack} of stack for {get_entity_info(eid)}. It should have 0.1 precision!")
    // check one item volume
    let oneVol = item__volumePerStack / float(item__countPerStack)
    let oneIntVol = convert_volume_to_int(oneVol)
    if abs(float(oneIntVol) - oneVol * 10.f) > 0.1f
      logerr("[ITEM VOLUME] Bad volume {oneVol} of one item of stack for {get_entity_info(eid)}. It should have 0.1 precision!")
  else
    // check volume
    let intVol = convert_volume_to_int(item__volume)
    if abs(float(intVol) - item__volume * 10.f) > 0.1f
      logerr("[ITEM VOLUME] Bad volume {item__volume} for {get_entity_info(eid)}. It should have 0.1 precision!")
