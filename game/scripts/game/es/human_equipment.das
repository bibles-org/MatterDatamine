require ecs
require app
require perks
require strings
require DngNet
require DngHuman
require ecs.safe
require ecs.common
require PropsRegistry
require game.utils.net_utils
require game.events.inventory_events
require game.events.events_active_matter
require game.es.equipment_common
require game.es.inventory_equipment_mod_common
require game.es.inventory_item_common
require game.es.inventory_transactions_common
require game.es.inventory_checks_common
require game.es.inventory_slots_common
require game.es.status_tip_common
require game.es.inventory_common
require game.es.interrupt_item_use_common
require game.es.human_inventory_postponed_usage_common


let private PREFIX = "DROP ALL"


[es(tag=server)]
def process_armor_on_equipment_change(evt : EventOnEquipmentChanged;
                                      dm_parts__parts : Object;
                                      var dm_parts__partsArmor : FloatList;
                                      var dm_parts__partsArmorMin : FloatList?;
                                      var dm_parts__armorItemEids : EidList?)
  query(evt.oldEquipmentEid) <| $ [es] (item__armoredParts : Array;
                                        item__armorAmount : float)
    if item__armorAmount > 0.0
      for part in item__armoredParts
        let partId = get_part_data_node_id(dm_parts__parts, get_string(part, ""))
        if partId >= 0 && partId < length(dm_parts__partsArmor)
          dm_parts__partsArmor[partId] = 0.0
        if dm_parts__partsArmorMin != null && partId >= 0 && partId < length(*dm_parts__partsArmorMin)
          (*dm_parts__partsArmorMin)[partId] = 0.0
        if dm_parts__armorItemEids != null && partId >= 0 && partId < length(*dm_parts__armorItemEids)
          (*dm_parts__armorItemEids)[partId] = INVALID_ENTITY_ID
  query(evt.newEquipmentEid) <| $ [es] (item__armoredParts : Array;
                                        item__armorAmount : float = 0.f;
                                        item__armorAmountMin : float = 0.f)
    if item__armorAmount > 0.0
      for part in item__armoredParts
        let partId = get_part_data_node_id(dm_parts__parts, get_string(part, ""))
        if partId >= 0 && partId < length(dm_parts__partsArmor)
          (dm_parts__partsArmor)[partId] = item__armorAmount
        if dm_parts__partsArmorMin != null && partId >= 0 && partId < length(*dm_parts__partsArmorMin)
          (*dm_parts__partsArmorMin)[partId] = item__armorAmountMin
        if dm_parts__armorItemEids != null && partId >= 0 && partId < length(*dm_parts__armorItemEids)
          (*dm_parts__armorItemEids)[partId] = evt.newEquipmentEid


def get_inventory_for_item_with_priority(hero_eid : EntityId;
                                         item_volume : int;
                                         inventory_volume_extensions : table<EntityId; int>;
                                         try_inventory : bool = false)
  // inventory -> backpack -> stash / ground
  if try_inventory && is_inventory_have_free_volume(hero_eid, item_volume + (inventory_volume_extensions?[hero_eid] ?? 0))
    return hero_eid
  var result = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (militant_extra_inventories__backpackEid : EntityId;
                             player_on_base_components__stashEid : EntityId const?)
    if is_inventory_have_free_volume(militant_extra_inventories__backpackEid,
        item_volume + (inventory_volume_extensions?[militant_extra_inventories__backpackEid] ?? 0))
      result = militant_extra_inventories__backpackEid
    elif player_on_base_components__stashEid != null
      result = *player_on_base_components__stashEid
  return result


[es(tag=server, track=human_equipment__slots, on_appear)]
def update_inventory_volume_es(evt : Event;
                               human_equipment__slots : Object;
                               human_inventory__maxVolume : float;
                               var human_inventory__maxVolumeInt : int&)
  var totalVolumeInt = convert_volume_to_int(human_inventory__maxVolume)
  for it in human_equipment__slots
    let itemEid = get_Eid(it.value) ?? INVALID_ENTITY_ID
    query(itemEid) <| $ [es] (item__inventoryExtension : float)
      let equipmentVolumeInt = convert_volume_to_int(item__inventoryExtension)
      totalVolumeInt += equipmentVolumeInt
  human_inventory__maxVolumeInt = totalVolumeInt


def handle_excess_volume(hero_eid, old_equipment_eid, new_equipment_eid : EntityId;
                         drop_prev_to : EntityId;
                         itemContainer : EidList;
                         human_inventory__currentVolume : int;
                         human_inventory__maxVolumeInt : int;
                         hero : Tag const?;
                         uniqueId : das_string const?)
  var prevInventoryExtention = 0
  var newInventoryExtention = 0
  var itemVolumeChange = 0
  var inventoryVolumeExtensions : table<EntityId; int>
  query(old_equipment_eid) <| $ [es] (item__inventoryExtension : float;
                                      item__volume : float)
    prevInventoryExtention = convert_volume_to_int(item__inventoryExtension)
    inventoryVolumeExtensions.insert(drop_prev_to, convert_volume_to_int(item__volume))

  query(new_equipment_eid) <| $ [es] (item__inventoryExtension : float;
                                      item__volume : float;
                                      item__containerOwnerEid : EntityId)
    newInventoryExtention = convert_volume_to_int(item__inventoryExtension)
    let volumeInt = convert_volume_to_int(item__volume)
    if item__containerOwnerEid == hero_eid
      itemVolumeChange = volumeInt
    inventoryVolumeExtensions.insert(item__containerOwnerEid, (inventoryVolumeExtensions?[item__containerOwnerEid] ?? 0) - volumeInt)

  let resultingCapacity = human_inventory__maxVolumeInt - prevInventoryExtention + newInventoryExtention
  let excessVolume = (human_inventory__currentVolume - itemVolumeChange) - resultingCapacity

  if excessVolume > 0
    var dropItemsOut : array<EntityId>
    gather_items_to_drop(hero_eid, itemContainer, excessVolume, dropItemsOut)
    for dropItem in dropItemsOut
      query(dropItem) <| $ [es] (item__volume : float)
        let volumeInt = convert_volume_to_int(item__volume)
        let inventoryEid = get_inventory_for_item_with_priority(hero_eid, volumeInt, inventoryVolumeExtensions, false)
        inventoryVolumeExtensions.insert(inventoryEid, (inventoryVolumeExtensions?[inventoryEid] ?? 0) + volumeInt)
        if inventoryEid != INVALID_ENTITY_ID
          if !is_true_net_server() && hero != null && uniqueId != null
            query(inventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
              report_item_move_transaction(dropItem, uniqueId, profile_server__slotName)
          move_item_to_inventory_container(dropItem, inventoryEid, hero_eid)
        else
          drop_item_from_inventory_container(dropItem, hero_eid)

  query(old_equipment_eid) <| $ [es] (equipment_mods__curModInSlots : Object)
    var mods_to_unequip : array<tuple<mod : EntityId; inventory : EntityId>>
    for mod in equipment_mods__curModInSlots
      if mod.key |> starts_with(pocket_slots_prefix)
        let modEid = mod.value ?? INVALID_ENTITY_ID
        query(modEid) <| $ [es] (item__volume : float)
          let volumeInt = convert_volume_to_int(item__volume)
          let inventoryEid = get_inventory_for_item_with_priority(hero_eid, volumeInt, inventoryVolumeExtensions, excessVolume <= 0)
          inventoryVolumeExtensions.insert(inventoryEid, (inventoryVolumeExtensions?[inventoryEid] ?? 0) + volumeInt)
          if !is_true_net_server() && hero != null && uniqueId != null
            query(inventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
              report_item_move_transaction(modEid, uniqueId, profile_server__slotName)
          mods_to_unequip |> emplace((modEid, inventoryEid))
    for unequipInfo in mods_to_unequip
      unequip_equipment_mod_from_slot(unequipInfo.mod, old_equipment_eid, hero_eid, unequipInfo.inventory)


[es(tag=server, before=on_equip_equipment_from_inventory_server)]
def process_inventory_volume_on_equipment_change(evt : CmdEquipEquipmentFromInventory;
                                                 eid : EntityId;
                                                 itemContainer : EidList;
                                                 human_inventory__currentVolume : int;
                                                 human_inventory__maxVolumeInt : int;
                                                 hero : Tag const?;
                                                 uniqueId : das_string const?)
  // check if operation is valid as in on_equip_equipment_from_inventory_server
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if evt.fromInventoryEid == INVALID_ENTITY_ID
    return
  let slotValid = hero_has_slot(eid, evt.slotName)
  if !slotValid
    return
  let slotItemEid = get_equipment_from_slot(eid, evt.slotName)
  if (!is_on_equip_equipment_prev_can_fit(evt.itemEid, evt.slotName, eid, evt.fromInventoryEid)
      && get_item_inventory_extension(evt.itemEid) == 0.f && get_item_inventory_extension(slotItemEid) == 0.f)
    return

  handle_excess_volume(eid, slotItemEid, evt.itemEid, evt.fromInventoryEid, itemContainer, human_inventory__currentVolume, human_inventory__maxVolumeInt, hero, uniqueId)


[es(tag=server, before=on_move_equipment_to_inventory_server)]
def process_inventory_volume_on_unequip(evt : CmdMoveEquipmentToInventory;
                                        eid : EntityId;
                                        itemContainer : EidList;
                                        human_inventory__currentVolume : int;
                                        human_inventory__maxVolumeInt : int;
                                        hero : Tag const?;
                                        uniqueId : das_string const?)
  // check if operation is valid as in on_move_equipment_to_inventory_server
  let slotItemEid = get_equipment_from_slot(eid, evt.slotName)
  if slotItemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(slotItemEid)
    return
  if !is_can_move_item_in_inventory(slotItemEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if is_inventory_in_use(slotItemEid)
    return
  if slotItemEid == eid
    return
  if evt.toInventoryEid != INVALID_ENTITY_ID && !is_inventory_have_volume_for_item(evt.toInventoryEid, slotItemEid)
    return

  handle_excess_volume(eid, slotItemEid, INVALID_ENTITY_ID, evt.toInventoryEid, itemContainer, human_inventory__currentVolume, human_inventory__maxVolumeInt, hero, uniqueId)


[es(tag=server, before=on_equip_equipment_from_ground_server)]
def process_inventory_volume_on_equipment_pickup(evt : CmdEquipEquipmentFromGround;
                                                 eid : EntityId;
                                                 itemContainer : EidList;
                                                 human_inventory__currentVolume : int;
                                                 human_inventory__maxVolumeInt : int;
                                                 hero : Tag const?;
                                                 uniqueId : das_string const?)
  // check if operation is valid as in on_equip_equipment_from_ground_server
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  let slotValid = hero_has_slot(eid, evt.slotName)
  if !slotValid
    return

  let slotItemEid = get_equipment_from_slot(eid, evt.slotName)
  handle_excess_volume(eid, slotItemEid, evt.itemEid, INVALID_ENTITY_ID, itemContainer, human_inventory__currentVolume, human_inventory__maxVolumeInt, hero, uniqueId)


[es(tag=server, before=item_pickup)]
def process_inventory_volume_on_pickup(evt : CmdItemPickup;
                                       eid : EntityId;
                                       itemContainer : EidList;
                                       human_inventory__currentVolume : int;
                                       human_inventory__maxVolumeInt : int;
                                       hero : Tag const?;
                                       uniqueId : das_string const?)
  // check if operation is valid as in item_pickup
  let equipmentSlotName = get_equipment_slot_for_item(eid, evt.item)
  if empty(equipmentSlotName)
    return

  handle_excess_volume(eid, INVALID_ENTITY_ID, evt.item, INVALID_ENTITY_ID, itemContainer, human_inventory__currentVolume, human_inventory__maxVolumeInt, hero, uniqueId)


[es(tag=server)]
def process_mods_on_equipment_change(evt : EventOnEquipmentChanged; eid : EntityId)
  query(evt.oldEquipmentEid) <| $ [es] (item__perkName : string)
    if !empty(item__perkName) && check_equpment_allowed(eid, item__perkName)
      let perkPropsId = get_props_id(item__perkName, "entity_mod")
      remove_perk(eid, item__perkName, perkPropsId)
  query(evt.newEquipmentEid) <| $ [es] (item__perkName : string)
    if !empty(item__perkName) && check_equpment_allowed(eid, item__perkName)
      let perkPropsId = register_props(item__perkName, "entity_mod")
      add_perk(eid, item__perkName, perkPropsId, 1.f)


[es(tag=server, on_event=EventEntityCreated)]
def process_inventory_volume_on_equipment_appear(evt : Event;
                                                 item__inventoryExtension : float;
                                                 slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es] (var human_inventory__maxVolumeInt : int&)
    human_inventory__maxVolumeInt += convert_volume_to_int(item__inventoryExtension)


[es(tag=server, on_event=EventEntityDestroyed)]
def process_inventory_volume_on_equipment_disappear(evt : Event;
                                                    item__inventoryExtension : float;
                                                    slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es] (var human_inventory__maxVolumeInt : int&)
    human_inventory__maxVolumeInt -= convert_volume_to_int(item__inventoryExtension)


[es(tag=server, on_event=EventEntityCreated)]
def process_mods_on_equipment_appear(evt : Event;
                                     item__perkName : string;
                                     slot_attach__attachedTo : EntityId)
  if slot_attach__attachedTo == INVALID_ENTITY_ID
    return
  if !empty(item__perkName) && check_equpment_allowed(slot_attach__attachedTo, item__perkName)
    let perkPropsId = register_props(item__perkName, "entity_mod")
    add_perk(slot_attach__attachedTo, item__perkName, perkPropsId, 1.f)


[es(tag=server, on_event=EventEntityCreated)]
def process_armor_on_equipment_appear(evt : Event;
                                      eid : EntityId;
                                      item__armoredParts : Array;
                                      item__armorAmount : float = 0.f;
                                      item__armorAmountMin : float = 0.f;
                                      slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es] (dm_parts__parts : Object;
                                            var dm_parts__partsArmor : FloatList;
                                            var dm_parts__partsArmorMin : FloatList?;
                                            var dm_parts__armorItemEids : EidList?)
    if item__armorAmount > 0.0
      for part in item__armoredParts
        let partId = get_part_data_node_id(dm_parts__parts, get_string(part, ""))
        if partId >= 0 && partId < length(dm_parts__partsArmor)
          (dm_parts__partsArmor)[partId] = item__armorAmount
        if dm_parts__partsArmorMin != null && partId >= 0 && partId < length(*dm_parts__partsArmorMin)
          (*dm_parts__partsArmorMin)[partId] = item__armorAmountMin
        if dm_parts__armorItemEids != null && partId >= 0 && partId < length(*dm_parts__armorItemEids)
          (*dm_parts__armorItemEids)[partId] = eid


enum CanDropContentResponse
  Approved
  Declined
  NoUseTime
  IsEmpty
  NotAllRecognized


[es(tag=server)]
def drop_all_content_in_inventory_start(evt : CmdDropAllItemsFromInventory;
                                        eid : EntityId;
                                        possessedByPlr : EntityId;
                                        human_weap__currentGunEid : EntityId;
                                        human_anim__vehicleSelected : EntityId;
                                        human_inventory__entityToUse : EntityId;
                                        isAlive : bool;
                                        isDowned : bool;
                                        isInVehicle : bool;
                                        human_net_phys__isInAir : bool;
                                        human_inventory__canUseItems : bool;
                                        human_inventory__canHeal : bool;
                                        human_inventory__canLoadCharges : bool;
                                        human_weap_anim__reloadAtTime : float;
                                        human_inventory__dropVolumePerSec : float;
                                        human_inventory__dropTimeCoef : float = 1.f;
                                        human_net_phys : HumanActor;
                                        var human_inventory__dropFromInventoryEid : EntityId&;
                                        var human_inventory__dropToInventoryEid : EntityId&;
                                        var human_inventory__lastDropAt : float&)
  var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
  if canUseItem != CanUseItemResponse.Approved
    if canUseItem == CanUseItemResponse.OtherItemInUse
      sendEvent(eid, EventInterruptItemUse())
    send_net_event(eid, ResponseFailureDropAllContent(inventoryEid = evt.fromInventoryEid, reason = int(canUseItem)), target_entity_conn(eid))
    return

  let curTime = get_sync_time()
  canUseItem = check_item_can_be_used(eid, evt.fromInventoryEid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                      curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                      human_inventory__canHeal, human_inventory__canLoadCharges)

  if canUseItem != CanUseItemResponse.Approved
    send_net_event(eid, ResponseFailureDropAllContent(inventoryEid = evt.fromInventoryEid, reason = int(canUseItem)), target_entity_conn(eid))
    return

  var canDropContent = CanDropContentResponse.Declined
  query(evt.fromInventoryEid) <| $ [es] (itemContainer : EidList;
                                         human_inventory__currentVolume : int;
                                         var item__unarmedUsage : bool?)
    if length(itemContainer) == 0
      canDropContent = CanDropContentResponse.IsEmpty
      return

    if human_inventory__dropTimeCoef == 0.f && item__unarmedUsage != null
      // Skip unarmed for instant reloads
      *item__unarmedUsage = false

    var allItemsRecognized = true
    var itemsToDrop : array<EntityId>
    for item in itemContainer
      query(item) <| $ [es] (item__recognizedByPlayers : EidList)
        allItemsRecognized &&= item__recognizedByPlayers |> has_value(possessedByPlr)
      itemsToDrop |> push(item)
    if !allItemsRecognized
      canDropContent = CanDropContentResponse.NotAllRecognized
      return

    var useTime = float(human_inventory__currentVolume) / (10.f * human_inventory__dropVolumePerSec)
    if useTime <= 0.0
      canDropContent = CanDropContentResponse.NoUseTime
      return
    useTime *= human_inventory__dropTimeCoef

    inventory_item_prepare_using(eid, evt.fromInventoryEid, eid, curTime, useTime)
    // currently only normal usage is supported
    human_inventory__dropFromInventoryEid = evt.fromInventoryEid
    human_inventory__dropToInventoryEid = evt.toInventoryEid
    human_inventory__lastDropAt = get_sync_time()
    canDropContent = CanDropContentResponse.Approved

  if canDropContent != CanDropContentResponse.Approved
    let reasonInt = int(CanUseItemResponse.End) + int(canDropContent)
    send_net_event(eid, ResponseFailureDropAllContent(inventoryEid = evt.fromInventoryEid, reason = reasonInt), target_entity_conn(eid))


[es(tag=server, no_order)]
def drop_all_content_in_inventory_update(info : UpdateStageInfoAct;
                                         eid : EntityId;
                                         human_inventory__dropVolumePerSec : float;
                                         human_inventory__entityToUse : EntityId;
                                         human_inventory__dropTimeCoef : float = 1.f;
                                         hero : Tag const?;
                                         uniqueId : das_string const?;
                                         var human_inventory__dropFromInventoryEid : EntityId&;
                                         var human_inventory__dropToInventoryEid : EntityId&;
                                         var human_inventory__lastDropAt : float&)
  if human_inventory__dropFromInventoryEid == INVALID_ENTITY_ID
    return
  if (!is_actor_can_move_item(eid, human_inventory__dropFromInventoryEid)
    || !is_actor_can_move_item(eid, human_inventory__dropToInventoryEid)
    || human_inventory__entityToUse != human_inventory__dropFromInventoryEid)
    human_inventory__dropFromInventoryEid = INVALID_ENTITY_ID
    human_inventory__dropToInventoryEid = INVALID_ENTITY_ID
    sendEvent(eid, EventInterruptItemUse())
    return

  var timeToDrop = info.curTime - human_inventory__lastDropAt
  var hasItemsToDrop = false
  query(human_inventory__dropFromInventoryEid) <| $ [es] (itemContainer : EidList)
    var itemsToDrop : array<EntityId>
    var dropVolume = 0
    for itemEid in itemContainer
      if is_item_inventory_move_blocked(itemEid)
        continue
      var continueDrop = true
      query(itemEid) <| $ [es] (item__volume : float)
        let volumeInt = convert_volume_to_int(item__volume)
        var canDrop = (human_inventory__dropToInventoryEid != INVALID_ENTITY_ID ?
          is_can_move_item_in_inventory(itemEid, human_inventory__dropToInventoryEid) :
          is_can_move_item_to_ground(itemEid))
        canDrop &&= is_can_move_item_in_inventory(itemEid, human_inventory__dropToInventoryEid)
        if !canDrop
          return
        if (human_inventory__dropToInventoryEid != INVALID_ENTITY_ID
          && !is_inventory_have_free_volume(human_inventory__dropToInventoryEid, dropVolume + volumeInt))
          // interrupt
          human_inventory__dropFromInventoryEid = INVALID_ENTITY_ID
          human_inventory__dropToInventoryEid = INVALID_ENTITY_ID
          sendEvent(eid, EventInterruptItemUse())
          continueDrop = false
          return
        hasItemsToDrop = true
        let dropTime = (item__volume /  human_inventory__dropVolumePerSec) * human_inventory__dropTimeCoef
        if dropTime > timeToDrop
          continueDrop = false
        else
          itemsToDrop |> push(itemEid)
          dropVolume += volumeInt
          timeToDrop -= dropTime
      if !continueDrop
        break
    human_inventory__lastDropAt = info.curTime - timeToDrop
    // drop them
    for dropItem in itemsToDrop
      if human_inventory__dropToInventoryEid != INVALID_ENTITY_ID
        if !is_true_net_server() && hero != null && uniqueId != null
          query(human_inventory__dropToInventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
            report_item_move_transaction(dropItem, uniqueId, profile_server__slotName)
        move_item_to_inventory_container(dropItem, human_inventory__dropToInventoryEid, eid)
      elif is_can_move_item_to_ground(dropItem)
        drop_item_from_inventory_container(dropItem, eid)

  if !hasItemsToDrop
    human_inventory__dropFromInventoryEid = INVALID_ENTITY_ID
    human_inventory__dropToInventoryEid = INVALID_ENTITY_ID
    sendEvent(eid, EventInterruptItemUse())


def create_tip_for_drop_all_decline_reason(inventory : EntityId;
                                           reason : int)
  debug_use_item_decline_reason(inventory, "{reason}", PREFIX, true)
  if reason == int(CanDropContentResponse.NotAllRecognized)
    create_status_tip("status_tip_drop_all_failed_by_unrecognized")


[es(tag=gameClient, REQUIRE=hero)]
def drop_all_content_on_request_failure(evt : ResponseFailureDropAllContent)
  let lastCanUseItemResponseCode = int(CanUseItemResponse.End)
  if lastCanUseItemResponseCode <= evt.reason
    create_tip_for_drop_all_decline_reason(evt.inventoryEid, evt.reason - lastCanUseItemResponseCode)
  else
    create_tip_for_use_item_decline_reason(evt.inventoryEid, evt.reason, PREFIX, true)

