module human_use_object_common shared
require ecs
require DngNet
require game.events.events
require game.events.events_active_matter


def human_use_object(hero_eid, object_eid : EntityId)
  if !is_server()
    sendEvent(hero_eid, HumanUseObjectRequest(objectEid = object_eid))
  else
    sendEvent(object_eid, CmdUse(requesterEid = hero_eid))


def human_use_alt_object(hero_eid, object_eid : EntityId)
  if !is_server()
    send_net_event(hero_eid, HumanUseAltObjectRequest(objectEid = object_eid))
  else
    sendEvent(object_eid, CmdUseAlt(requesterEid = hero_eid))


def human_pickup_item(heroEid, selectedObject : EntityId)
  sendEvent(heroEid, RequestItemPickup(itemEid = selectedObject))
  sendEvent(heroEid, CmdRumble(eventName = "pickupItem"))


def handle_use_object(heroEid, selectedObject : EntityId;
                      canUseSelected : bool)
  query(selectedObject) <| $ [es] (item__id : int const?;
                                   item__disablePickup : bool = false;
                                   boxed_item__actionsBlock : bool = false;
                                   item__replacePickupWithUse : Tag const?;
                                   item__blockInventoryMove : Tag const?;
                                   interaction_menu : Array const?;
                                   interaction_menu_available : bool const?)
    let isItemPickable = item__id != null && !item__disablePickup && item__replacePickupWithUse == null && item__blockInventoryMove == null && !boxed_item__actionsBlock
    if isItemPickable
      human_pickup_item(heroEid, selectedObject)
      return

    if interaction_menu != null
      sendEventImmediate(selectedObject, CmdPrepareInteractionMenu(interactorEid = heroEid))
    let interactionMenuAvailable = interaction_menu_available ?? false
    if interactionMenuAvailable
      broadcastEvent(CmdShowUiMenu(menuName = "Interaction"))
      return

    if canUseSelected
      human_use_object(heroEid, selectedObject)
    else
      sendEvent(selectedObject, EventUseObjectBlocked())