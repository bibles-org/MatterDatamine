module inventory_item_common shared
require ecs
require ecs.safe
require Grid
require DngNet
require math.base
require DagorSystem
require DagorMath
require game.es.ecs_common
require game.utils.net_utils
require game.events.inventory_events
require game.es.inventory_drop_common
require game.es.inventory_checks_common
require game.es.inventory_transactions_common
require game.events.events_active_matter


def try_merge_with_boxed_item_in_inventory(container_eid : EntityId; boxed_template : string; count : int)
  var found = false
  query(container_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (boxed_item__template aka item_boxed_item__template : string; var item__currentBoxedItemCount : int&)
        if (item_boxed_item__template != boxed_template)
          return
        found = true
        item__currentBoxedItemCount += count
        print("[INVENTORY] Item {get_entity_info(itemEid)} merged with other item, adding {count} charges")
      if found
        return
  return found


def move_item_to_inventory_container(item_eid, to_container_eid, actor_eid : EntityId)
  query(item_eid) <| $ [es] (boxed_item__template : string = "";
                             var item__currentBoxedItemCount : int?;
                             var item__containerOwnerEid : EntityId&;
                             var item__humanOwnerEid : EntityId&;
                             var item__lastContainerOwnerEid : EntityId&;
                             var item__isOnGround : bool&)
    if !empty(boxed_item__template) && try_merge_with_boxed_item_in_inventory(to_container_eid, boxed_item__template, *item__currentBoxedItemCount)
      print("[INVENTORY] Item {get_entity_info(item_eid)} moved from container {get_entity_info(item__containerOwnerEid)} to container {get_entity_info(to_container_eid)} and merged.")
      (*item__currentBoxedItemCount) = -1 // invalid box will be destroyed
      destroyEntity(item_eid)
      return
    var previousHeroOwner = INVALID_ENTITY_ID
    var newHeroOwner = INVALID_ENTITY_ID
    query(to_container_eid) <| $ [es] (inventory__humanOwnerEid : EntityId)
      newHeroOwner = inventory__humanOwnerEid
    item__humanOwnerEid = newHeroOwner

    if item__isOnGround
      item__isOnGround = false
      item__lastContainerOwnerEid = INVALID_ENTITY_ID
    elif item__containerOwnerEid != INVALID_ENTITY_ID
      item__lastContainerOwnerEid = item__containerOwnerEid
      query(item__lastContainerOwnerEid) <| $ [es] (inventory__humanOwnerEid : EntityId)
        previousHeroOwner = inventory__humanOwnerEid

    item__containerOwnerEid = to_container_eid

    if previousHeroOwner == INVALID_ENTITY_ID && newHeroOwner != INVALID_ENTITY_ID
      send_net_event(newHeroOwner, EventOnItemPickup(itemEid = item_eid, toInventoryEid = item__containerOwnerEid))
    elif previousHeroOwner == INVALID_ENTITY_ID
      send_net_event(item__containerOwnerEid, EventOnItemPickup(itemEid = item_eid, toInventoryEid = item__containerOwnerEid))
    elif previousHeroOwner != INVALID_ENTITY_ID
      var evt = EventOnItemMovedBetweenInventory(itemEid = item_eid, oldInventoryEid = item__lastContainerOwnerEid, newInventoryEid = item__containerOwnerEid)
      if previousHeroOwner != newHeroOwner
        send_net_event(previousHeroOwner, evt)
      send_net_event(newHeroOwner, evt)
    send_net_event(item_eid, EventOnMovingBetweenInventories(
        oldInventoryEid = item__lastContainerOwnerEid,
        newInventoryEid = item__containerOwnerEid,
        actorEid = actor_eid))
    print("[INVENTORY] Item {get_entity_info(item_eid)} moved from container {get_entity_info(item__lastContainerOwnerEid)} to container {get_entity_info(item__containerOwnerEid)}")

    //update target container volume immediately to limit how much can be put in there on this same frame
    //The rest of the stats can be updated asynchronously
    query(item_eid) <| $ [es] (item__volume : float)
      query(to_container_eid) <| $ [es] (var human_inventory__currentVolume : int&)
        human_inventory__currentVolume += convert_volume_to_int(item__volume)


def try_merge_with_boxed_item_on_ground(center : float3; radius : float; boxed_template : string; count : int)
  var found = false
  for_each_entity_in_grid(ecs_hash("loot"), BSphere3(center, radius), GridEntCheck.BOUNDING) <| $[unused_argument(pos)] (groundItemEid : EntityId; pos : float3)
    if (found)
      return
    query(groundItemEid) <| $ [es] (boxed_item__template aka ground_boxed_item__template : string; var item__currentBoxedItemCount : int&)
      if (ground_boxed_item__template != boxed_template)
        return

      found = true
      item__currentBoxedItemCount += count
      print("[INVENTORY] Item {get_entity_info(groundItemEid)} merged with other item, adding {item__currentBoxedItemCount} charges")

  return found


def drop_item_from_inventory_container(item_eid : EntityId; hero_eid = INVALID_ENTITY_ID)
  query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId; boxed_item__template : string = ""; var item__currentBoxedItemCount : int?)
    query(item__containerOwnerEid) <| $ [es] (inventory__humanOwnerEid : EntityId;
                                              human_inventory__pickupRadius : float = 3.0)
      let heroOwner = !!inventory__humanOwnerEid ? inventory__humanOwnerEid : item__containerOwnerEid
      let lastOwner = item__containerOwnerEid
      let tmPtr = get_TMatrix(heroOwner, "transform")
      if (tmPtr != null && !empty(boxed_item__template)
          && try_merge_with_boxed_item_on_ground((*tmPtr)[3], human_inventory__pickupRadius, boxed_item__template, *item__currentBoxedItemCount))
        (*item__currentBoxedItemCount) = -1 // invalid box will be destroyed
        print("[INVENTORY] Item {get_entity_info(item_eid)} dropped from container {get_entity_info(lastOwner)} to ground and merged.")
        destroyEntity(item_eid)
        return

      drop_item(item_eid, hero_eid)

      send_net_event(heroOwner, EventOnItemDrop(itemEid = item_eid, fromInventoryEid = lastOwner))
      print("[INVENTORY] Item {get_entity_info(item_eid)} dropped from container {get_entity_info(lastOwner)} to ground.")


def get_item_template_volume(item_template : Template)
  let volumePerStack = getTemplateComponent(item_template, "item__volumePerStack") ?? 0.0
  if volumePerStack > 0.0
    return volumePerStack

  return getTemplateComponent(item_template, "item__volume") ?? 0.0


def split_item_to_inventory_container(item_eid, to_container_eid, actor_eid : EntityId; count : int)
  if !is_transation_disabled()
    return //This item will be added by the profile server.

  query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                             boxed_item__template aka splitted_boxed_item__template : string;
                             var item__currentBoxedItemCount : int&)
    item__currentBoxedItemCount -= count
    query(to_container_eid) <| $ [es] (itemContainer : EidList)
      var existEid = INVALID_ENTITY_ID
      for item in itemContainer
        query(item) <| $ [es] (boxed_item__template : string; var item__currentBoxedItemCount : int&)
          if boxed_item__template == splitted_boxed_item__template
            item__currentBoxedItemCount += count
            existEid = item
        if existEid != INVALID_ENTITY_ID
          print("[INVENTORY] Item {get_entity_info(item_eid)} splitted count = {count} from container {get_entity_info(item__containerOwnerEid)}
                to container {get_entity_info(to_container_eid)} to existing box {get_entity_info(existEid)}.")
          break
      if !existEid
        create_item_in_inventory_container(boxed_item__template, to_container_eid) <| $(init)
          init |> set("item__currentBoxedItemCount", count)
          using() <| $(var list : EidList)
            query(actor_eid) <| $ [es] (possessedByPlr : EntityId)
              list |> push(possessedByPlr)
              init |> set("item__recognizedByPlayers", list)
        print("[INVENTORY] Item {get_entity_info(item_eid)} splitted count = {count} from container {get_entity_info(item__containerOwnerEid)}
              to container {get_entity_info(to_container_eid)} to new box.")


def split_item_to_ground(item_eid, hero_eid : EntityId; count : int)
  query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                             item__recognizedByPlayers : EidList;
                             boxed_item__template : string;
                             var item__currentBoxedItemCount : int&)
    item__currentBoxedItemCount -= count
    var tm = IDENT_TM

    query(hero_eid) <| $ [es] (transform aka hero_transform : float3x4;
                               human_inventory__pickupRadius : float;
                               human_inventory__dropLootOffset = float3(0))
      if (try_merge_with_boxed_item_on_ground(transform[3], human_inventory__pickupRadius, boxed_item__template, count))
        print("[INVENTORY] Item {get_entity_info(item_eid)} splitted count = {count} from container {get_entity_info(item__containerOwnerEid)} to ground and merged.")
        return
      tm = get_drop_tm(item_eid, transform * human_inventory__dropLootOffset)
      create_item_on_ground(boxed_item__template, tm) <| $(init)
        init |> set("item__currentBoxedItemCount", count)
        init |> set("item__recognizedByPlayers", item__recognizedByPlayers)
      print("[INVENTORY] Item {get_entity_info(item_eid)} splitted count = {count} from container {get_entity_info(item__containerOwnerEid)} to ground.")


def create_item_in_inventory_container(item_template : string; container_eid : EntityId;
                                       init_block : block<(var init_obj : ComponentsInitializer) : void>)
  let containerExists = doesEntityExist(container_eid) && !isLoadingEntity(container_eid)

  let itemTempl = getOrBuildTemplateByName(item_template)
  if itemTempl == null
    logerr("[INVENTORY] Can't find template for item: <{item_template}>")
    return INVALID_ENTITY_ID

  var itemTemplate = item_template

  let inContainerSubTemplate = getTemplateComponent(*itemTempl, "item__recreateInInventory") ?? ""
  if inContainerSubTemplate != ""
    itemTemplate = add_sub_template_name(itemTemplate, inContainerSubTemplate)

  let itemEid = createEntity(itemTemplate) <| $(var init)
    init |> set("item__containerOwnerEid", container_eid)
    init |> set("item__lastContainerOwnerEid", INVALID_ENTITY_ID)
    init |> set("item__isOnGround", false)
    invoke(init_block, init)

  if containerExists
    print("[INVENTORY] Item <{itemEid}> ({itemTemplate}) start creating in container {get_entity_info(container_eid)}")
  else
    print("[INVENTORY] Item <{itemEid}> ({itemTemplate}) waiting for a container {container_eid} creation.")

  return itemEid


def create_item_in_inventory_container(item_template : string; container_eid : EntityId)
  return create_item_in_inventory_container(item_template, container_eid) <| $ [unused_argument(init)] (init) {}


def notify_equip_in_occupied_slot_failed(human_eid, inventory_eid : EntityId)
  send_net_event(human_eid, EventCapacityExceeded(containerEid = inventory_eid), target_entity_conn(human_eid))
  send_net_event(human_eid, ShowStatusTip(statusTip = "status_tip_equip_in_occupied_slot_failed_by_capacity"))


def find_items_in_inventory_by_template_name(item_template : string; container_eid : EntityId)
  var result : array<EntityId>
  query(container_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (item__proto : string)
        if (item_template == item__proto)
          result |> push(itemEid)
  return <- result


def can_pickup_item_for_immediate_use(hero_eid : EntityId;
                                      item_eid : EntityId;
                                      item__disablePickup : bool)
  if item__disablePickup || is_item_inventory_move_blocked(item_eid)
    print("[INVENTORY] Move from ground to inventory is blocked for item {get_entity_info(item_eid)}. disablePickup:{item__disablePickup}")
    return false
  if is_quest_item_for_other_player_by_hero(item_eid, hero_eid)
    return false
  if !is_can_move_item_to_item_container(item_eid)
    print("[INVENTORY] Item {get_entity_info(item_eid)} cannot pick up item for temporary use")
    return false
  return true


//This allows to pick up item for which there is no free space
//The item goes to limbo, isn't displayed, isn't equipped, isn't added to a container, but belong to the hero
def pickup_item_for_immediate_use(hero_eid : EntityId;
                                  item_eid : EntityId)
  query(item_eid) <| $ [es] (item__recreateOnGround : string = "";
                             item__recreateInWorldPhys : string = "";
                             item__recreateInInventory : string = "";
                             item__removeTemplatesInInventory : StringList const?;
                             var item__humanOwnerEid : EntityId&;
                             var item__lastContainerOwnerEid : EntityId&;
                             var item__containerOwnerEid : EntityId&;
                             var item__isOnGround : bool?)
    item__humanOwnerEid = hero_eid
    if item__isOnGround != null && *item__isOnGround
      *item__isOnGround = false
      item__lastContainerOwnerEid = INVALID_ENTITY_ID
    else
      item__lastContainerOwnerEid = item__containerOwnerEid
    item__containerOwnerEid = INVALID_ENTITY_ID
    move_item_to_inventory_container(item_eid, hero_eid, hero_eid)
    send_net_event(hero_eid, EventOnItemPickup(itemEid = item_eid, toInventoryEid = item__containerOwnerEid))

    if item__lastContainerOwnerEid == INVALID_ENTITY_ID
      if !empty(item__recreateOnGround)
        item_eid |> removeSubTemplate(item__recreateOnGround)
      if !empty(item__recreateInWorldPhys)
        item_eid |> removeSubTemplate(item__recreateInWorldPhys)
      if item__removeTemplatesInInventory != null
        for templateName in *item__removeTemplatesInInventory
          item_eid |> removeSubTemplate(string(templateName))
      if !empty(item__recreateInInventory)
        item_eid |> addSubTemplate(item__recreateInInventory)
    print("[INVENTORY] Item {get_entity_info(item_eid)} moved from {get_entity_info(item__lastContainerOwnerEid)} to {get_entity_info(hero_eid)} temporarily, to be used immediately.")
