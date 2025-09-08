module external_inventory_common shared
require ecs
require ecs.safe
require game.events.events_active_matter
require DngNet


def open_external_inventory(hero_eid, accesspoint_eid : EntityId)
  send_net_event(accesspoint_eid, CmdUseExternalInventoryAccesspointRequest(heroEid = hero_eid))


def close_external_inventory()
  find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId;
                                        var external_inventory_interactor__accesspointEid : EntityId&;
                                        var external_inventory_interactor__inventoryEid : EntityId&)
    if (external_inventory_interactor__accesspointEid == INVALID_ENTITY_ID &&
        external_inventory_interactor__inventoryEid == INVALID_ENTITY_ID)
      return true

    let closedInventoryEid = external_inventory_interactor__inventoryEid
    external_inventory_interactor__accesspointEid = INVALID_ENTITY_ID
    external_inventory_interactor__inventoryEid = INVALID_ENTITY_ID
    send_net_event(hero_eid, CmdCloseExternalInventoryRequest(inventoryEid = closedInventoryEid))
    return true