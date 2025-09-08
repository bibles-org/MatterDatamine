require ecs
require game.events.events
require DagorSystem
require net
require game.events.events_active_matter
require game.es.ecs_common
require game.es.inventory_common
require game.es.external_inventory_common
require game.es.inventory_equipment_common


[es(tag=server, track=militant_extra_inventories__backpackEid)]
def external_inventory_interactor_track_backpack(evt : Event;
                                                 militant_extra_inventories__backpackEid : EntityId;
                                                 var external_inventory_interactor__accesspointEid : EntityId&;
                                                 var external_inventory_interactor__inventoryEid : EntityId&)
  assume backpackEid = militant_extra_inventories__backpackEid
  if backpackEid != INVALID_ENTITY_ID && backpackEid == external_inventory_interactor__inventoryEid
    external_inventory_interactor__accesspointEid = INVALID_ENTITY_ID
    external_inventory_interactor__inventoryEid = INVALID_ENTITY_ID


[es(tag=(gameClient, server), REQUIRE=usable_backpack)]
def on_backpack_accesspoint_offline_cancel_use(evt : CmdUse;
                                               eid aka accesspoint_eid : EntityId)
  query(evt.requesterEid) <| $ [es(REQUIRE=hero)] (external_inventory_interactor__accesspointEid : EntityId)
    if external_inventory_interactor__accesspointEid == accesspoint_eid
      close_external_inventory()


[es(tag=netClient, REQUIRE=hero)]
def on_backpack_accesspoint_online_cancel_use(evt : HumanUseObjectRequest;
                                              external_inventory_interactor__accesspointEid : EntityId)
  query(evt.objectEid) <| $ [es(REQUIRE=usable_backpack)] ()
    if external_inventory_interactor__accesspointEid == evt.objectEid
      close_external_inventory()


[es(tag=gameClient, REQUIRE=hero)]
def on_backpack_accesspoint_use_alt(evt : HumanUseAltObjectRequest;
                                    eid : EntityId;
                                    external_inventory_interactor__accesspointEid : EntityId)
  query(evt.objectEid) <| $ [es(REQUIRE=usable_backpack)] ()
    if external_inventory_interactor__accesspointEid != evt.objectEid
      send_net_event(evt.objectEid, CmdUseExternalInventoryAccesspointRequest(heroEid = eid))


[es(tag=(gameClient, server), REQUIRE=usable_backpack)]
def on_backpack_accesspoint_use_alt_offline(evt : CmdUseAlt;
                                            eid aka accesspoint_eid : EntityId)
  query(evt.requesterEid) <| $ [es(REQUIRE=hero)] (external_inventory_interactor__accesspointEid : EntityId)
    if external_inventory_interactor__accesspointEid != accesspoint_eid
      send_net_event(accesspoint_eid, CmdUseExternalInventoryAccesspointRequest(heroEid = evt.requesterEid))